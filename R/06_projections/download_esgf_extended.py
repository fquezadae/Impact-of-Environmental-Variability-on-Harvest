"""
download_esgf_extended.py - ESGF fallback for combos missing in Pangeo Cloud.
============================================================================

After running download_cmip6_ensemble.py (Pangeo Cloud Zarr) for the full
ensemble, four (model, variable) combinations consistently turned up empty
in the Pangeo catalog:

    - CESM2          / uas    (atmospheric, no Pangeo entry)
    - CESM2          / vas    (atmospheric, no Pangeo entry)
    - CNRM-ESM2-1    / chlos  (ocean BGC, no Pangeo entry)
    - UKESM1-0-LL    / chlos  (ocean BGC, no Pangeo entry)

These exist on ESGF (verified via the search facets), but Pangeo's curated
mirror does not include them. This script falls back to ESGF for those 4
combinations across all 3 experiments (historical + ssp245 + ssp585) =
12 files total.

Adapted from INCAR2-RL8/download_esgf.py (which has OPeNDAP + HTTP fallback
strategy but only handled IPSL-CM6A-LR). The extension here:
  - Iterates over a list of (model, variable) tuples instead of a single
    model/variable.
  - Uses the same bounding box as download_cmip6_ensemble.py
    (lon [-90, -65] x lat [-56, -20]).
  - Preserves the same output naming convention so 01_cmip6_deltas.R picks
    these files up alongside the Pangeo-downloaded ones.

Strategy per file:
  1. Search ESGF (DKRZ index node) for the dataset.
  2. Try OPeNDAP across ALL replicas and ALL files within each replica.
  3. If OPeNDAP exhausted, fall back to HTTP download + local subset.
  4. Skip if output already exists.

Expected runtime: 5-15 min per file depending on ESGF server response;
total ~30-90 min for the 12 files. ESGF is intermittent — if a replica
times out, the script tries the next one.
"""

import os
os.environ["ESGF_PYCLIENT_NO_FACETS_STAR_WARNING"] = "1"

import xarray as xr
import requests
from pyesgf.search import SearchConnection

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

OUTPUT_DIR = r"D:\GitHub\climate_projections\CMIP6"
TMP_DIR = os.path.join(OUTPUT_DIR, "_tmp_esgf")
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(TMP_DIR, exist_ok=True)

# Bbox: matches download_cmip6_ensemble.py (covers Centro-Sur EEZ + offshore
# extended band + Southeast Pacific regional, all 3 nested Appendix E domains)
LAT_MIN, LAT_MAX = -56, -20
LON_MIN, LON_MAX = -90, -65

# Combos to fetch from ESGF (Pangeo gap-fill list)
# Each tuple: (source_id, variable_id, default_variant, fallback_variants)
COMBOS = [
    ("CESM2",         "uas",   "r1i1p1f1", ["r4i1p1f1"]),
    ("CESM2",         "vas",   "r1i1p1f1", ["r4i1p1f1"]),
    ("CNRM-ESM2-1",   "chlos", "r1i1p1f2", ["r1i1p1f1"]),
    ("UKESM1-0-LL",   "chlos", "r1i1p1f2", ["r1i1p1f1"]),
]

# Three experiments, with date ranges matching download_cmip6_ensemble.py
DATE_RANGES = {
    "historical": ("1993-01-01", "2014-12-30"),
    "ssp245":     ("2015-01-01", "2100-12-30"),
    "ssp585":     ("2015-01-01", "2100-12-30"),
}

FACETS = "project,source_id,experiment_id,variable,frequency,variant_label"


# -----------------------------------------------------------------------------
# UTILITIES (mostly inherited from INCAR2-RL8/download_esgf.py)
# -----------------------------------------------------------------------------

def model_filename_token(model_id):
    """IPSL-CM6A-LR -> ipsl_cm6a_lr (matches Pangeo script naming)."""
    return model_id.lower().replace("-", "_")


def detect_grid(ds, varname):
    """Return ('regular' or 'curvilinear', lon_name, lat_name)."""
    lon_candidates = ["lon", "longitude", "nav_lon"]
    lat_candidates = ["lat", "latitude", "nav_lat"]

    lon_name = next((c for c in lon_candidates
                     if c in ds.coords or c in ds.variables), None)
    lat_name = next((c for c in lat_candidates
                     if c in ds.coords or c in ds.variables), None)

    if lon_name is None or lat_name is None:
        raise RuntimeError(
            f"Could not identify lon/lat coords for {varname}. "
            f"Vars: {list(ds.variables)[:25]}"
        )

    ndim = ds[lon_name].ndim
    if ndim == 1:
        return "regular", lon_name, lat_name
    elif ndim == 2:
        return "curvilinear", lon_name, lat_name
    else:
        raise RuntimeError(f"Unexpected lon ndim {ndim}")


def bbox_subset(ds, varname):
    import numpy as np
    grid_type, lon_name, lat_name = detect_grid(ds, varname)

    if grid_type == "regular":
        lon_vals = ds[lon_name].values
        if lon_vals.min() >= 0 and LON_MIN < 0:
            ds = ds.assign_coords({lon_name: ((lon_vals + 180) % 360) - 180})
            ds = ds.sortby(lon_name)
        lat_vals = ds[lat_name].values
        lat_slice = (slice(LAT_MAX, LAT_MIN) if lat_vals[0] > lat_vals[-1]
                     else slice(LAT_MIN, LAT_MAX))
        ds = ds.sel({lon_name: slice(LON_MIN, LON_MAX), lat_name: lat_slice})
        return ds

    # curvilinear
    lon = ds[lon_name].values
    lat = ds[lat_name].values
    if lon.min() >= 0 and LON_MIN < 0:
        lon = np.where(lon > 180, lon - 360, lon)
    mask = ((lon >= LON_MIN) & (lon <= LON_MAX) &
            (lat >= LAT_MIN) & (lat <= LAT_MAX))
    rows = mask.any(axis=1)
    cols = mask.any(axis=0)
    if not rows.any() or not cols.any():
        raise RuntimeError("Empty bbox in curvilinear subset")
    i0, i1 = np.where(rows)[0][[0, -1]]
    j0, j1 = np.where(cols)[0][[0, -1]]
    dims = list(ds[lon_name].dims)
    return ds.isel({dims[0]: slice(i0, i1+1), dims[1]: slice(j0, j1+1)})


def time_subset(ds, t0, t1):
    return ds.sel(time=slice(t0, t1))


def surface_subset(ds, variable):
    for d in ("olevel", "lev", "depth"):
        if d in ds[variable].dims:
            ds = ds.isel({d: 0})
            break
    return ds


def drop_bounds(ds):
    drops = [v for v in [
        "bounds_nav_lon", "bounds_nav_lat", "bounds_lon", "bounds_lat",
        "lon_bnds", "lat_bnds", "time_bounds", "time_bnds",
        "lat_verticies", "lon_verticies", "vertices_latitude",
        "vertices_longitude", "area", "areacello", "areacella",
    ] if v in ds.variables]
    return ds.drop_vars(drops) if drops else ds


# -----------------------------------------------------------------------------
# DOWNLOAD STRATEGIES (OPeNDAP first, HTTP fallback)
# -----------------------------------------------------------------------------

def try_opendap(opendap_urls, variable, t0, t1, out_path):
    if len(opendap_urls) == 1:
        ds = xr.open_dataset(opendap_urls[0], decode_times=True)
    else:
        ds = xr.open_mfdataset(opendap_urls, combine="by_coords",
                               decode_times=True)
    ds = time_subset(ds, t0, t1)
    ds = bbox_subset(ds, variable)
    ds = surface_subset(ds, variable)
    ds = ds.load()
    ds = drop_bounds(ds)
    ds.to_netcdf(out_path)
    ds.close()


def try_http(files, variable, t0, t1, out_path):
    tmp_paths = []
    try:
        for f in files:
            http_url = None
            for url_tuple in f.urls.get("HTTPServer", []):
                http_url = url_tuple[0]
                break
            if http_url is None:
                continue
            tmp_name = os.path.join(TMP_DIR, os.path.basename(http_url))
            if not os.path.exists(tmp_name):
                print(f"      HTTP: {os.path.basename(http_url)}")
                r = requests.get(http_url, stream=True, timeout=300)
                r.raise_for_status()
                with open(tmp_name, "wb") as out:
                    for chunk in r.iter_content(chunk_size=1024 * 1024):
                        out.write(chunk)
            tmp_paths.append(tmp_name)
        if not tmp_paths:
            raise RuntimeError("No HTTP URLs found in any file")
        ds = xr.open_mfdataset(tmp_paths, combine="by_coords",
                               decode_times=True)
        ds = time_subset(ds, t0, t1)
        ds = bbox_subset(ds, variable)
        ds = surface_subset(ds, variable)
        ds = ds.load()
        ds = drop_bounds(ds)
        ds.to_netcdf(out_path)
        ds.close()
    finally:
        for p in tmp_paths:
            try:
                os.remove(p)
            except OSError:
                pass


# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------

def fetch_one(conn, model, variable, variants_to_try, experiment, t0, t1, out_path):
    """Search ESGF and download one (model, variable, experiment)."""
    last_err = None
    for variant in variants_to_try:
        ctx = conn.new_context(
            facets=FACETS, project="CMIP6", source_id=model,
            experiment_id=experiment, variable=variable,
            frequency="mon", variant_label=variant,
        )
        if ctx.hit_count == 0:
            print(f"      no ESGF datasets for {model}/{variant}/{variable}/{experiment}")
            continue

        # Strategy 1: OPeNDAP across replicas
        for ds_idx, esgf_ds in enumerate(ctx.search()):
            try:
                files = list(esgf_ds.file_context().search())
            except Exception as e:
                print(f"      replica {ds_idx} file list failed: {str(e)[:60]}")
                continue
            opendap_urls = []
            for f in files:
                for url_tuple in f.urls.get("OPENDAP", []):
                    url = url_tuple[0]
                    if url.endswith(".html"):
                        url = url[:-5]
                    opendap_urls.append(url)
            if not opendap_urls:
                continue
            try:
                try_opendap(opendap_urls, variable, t0, t1, out_path)
                print(f"      OK (OPeNDAP, {variant})")
                return True
            except Exception as e:
                last_err = e
                print(f"      replica {ds_idx} OPeNDAP failed: {type(e).__name__}: {str(e)[:80]}")

        # Strategy 2: HTTP fallback
        for ds_idx, esgf_ds in enumerate(ctx.search()):
            try:
                files = list(esgf_ds.file_context().search())
                try_http(files, variable, t0, t1, out_path)
                print(f"      OK (HTTP, {variant})")
                return True
            except Exception as e:
                last_err = e
                print(f"      replica {ds_idx} HTTP failed: {type(e).__name__}: {str(e)[:80]}")

    if last_err:
        raise last_err
    return False


def main():
    print("=" * 72)
    print("ESGF fallback for Pangeo-missing combos (paper 1 ensemble)")
    print(f"Bbox: lon [{LON_MIN}, {LON_MAX}], lat [{LAT_MIN}, {LAT_MAX}]")
    print(f"Combos: {[(m, v) for m, v, _, _ in COMBOS]}")
    print(f"Experiments: {list(DATE_RANGES.keys())}")
    print(f"Output: {OUTPUT_DIR}")
    print("=" * 72)

    conn = SearchConnection("https://esgf-data.dkrz.de/esg-search", distrib=True)

    total = len(COMBOS) * len(DATE_RANGES)
    completed = 0
    skipped = 0
    failed = []

    for i, (model, variable, default_variant, fallback_variants) in enumerate(COMBOS, 1):
        token = model_filename_token(model)
        variants_to_try = [default_variant] + fallback_variants

        for j, (experiment, (t0, t1)) in enumerate(DATE_RANGES.items(), 1):
            idx = (i - 1) * len(DATE_RANGES) + j
            out_name = f"CMIP6_{token}_{variable}_{experiment}_monthly.nc"
            out_path = os.path.join(OUTPUT_DIR, out_name)

            print(f"\n[{idx:>2}/{total}] {model} | {variable} | {experiment}")

            if os.path.exists(out_path):
                print(f"      SKIP (exists): {out_name}")
                skipped += 1
                continue

            try:
                ok = fetch_one(conn, model, variable, variants_to_try,
                               experiment, t0, t1, out_path)
                if ok:
                    sz = os.path.getsize(out_path) // 1024
                    print(f"      written: {sz} kB -> {out_name}")
                    completed += 1
                else:
                    failed.append((model, variable, experiment, "no datasets across all variants"))
            except Exception as e:
                print(f"      FAILED: {type(e).__name__}: {str(e)[:120]}")
                failed.append((model, variable, experiment,
                               f"{type(e).__name__}: {str(e)[:120]}"))

    print("\n" + "=" * 72)
    print(f"Completed: {completed}/{total - skipped}  (skipped existing: {skipped})")
    print(f"Failed:    {len(failed)}")
    if failed:
        print("\nFailures:")
        for m, v, e, err in failed:
            print(f"  - {m:14s} | {v:5s} | {e:11s} | {err}")
        print("\nFor persistent ESGF failures: check ESGF status at "
              "https://esgf-node.llnl.gov/projects/esgf-llnl/, "
              "or try https://esgf-data.dkrz.de manually.")
    print("=" * 72)

    # Cleanup
    try:
        if not os.listdir(TMP_DIR):
            os.rmdir(TMP_DIR)
    except OSError:
        pass


if __name__ == "__main__":
    main()
