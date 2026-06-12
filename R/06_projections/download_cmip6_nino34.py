"""
download_cmip6_nino34.py - CMIP6 multi-model ensemble download for the Nino 3.4
==============================================================================
basin-scale ENSO index (lat [-5,+5] x lon [-170,-120]) over the same period
window as the costero downloads.

Sister script of download_cmip6_ensemble.py. Reuses the same Pangeo-on-GCS
pipeline, the same six-model ensemble, the same periods and the same variant-
priority logic. Three deltas with respect to the original script:

  1. Bounding box swapped from SE Pacific (-90,-65 lon x -56,-20 lat) to the
     Nino 3.4 region (-170,-120 lon x -5,+5 lat). The negative-longitude
     convention is the same; bbox_subset() already handles 0-360 -> -180,+180
     reorientation when models publish in 0-360.
  2. Variables restricted to {tos} only. ENSO is a pure SST index. We do NOT
     need chlos (no chl identification expected basin-scale), nor uas/vas
     (winds at the equator do enter ENSO physics but the Nino 3.4 index is
     by definition SST-based; CMIP6 wind proxies for ENSO have known biases
     and would dilute the signal).
  3. Output directory: D:\\GitHub\\climate_projections\\CMIP6_NINO34. Kept
     separate so existing costero netCDFs are NOT touched and so the R-side
     loaders for ENSO can iterate over a clean directory.
  4. Filename suffix `_nino34` added so even if files end up in the same dir
     by accident there is no clobber risk:
         CMIP6_<model>_tos_<experiment>_monthly_nino34.nc

Decided 2026-05-04 in the ENSO pivot for paper 1 (project_paper1_enso_pivot).
Felipe runs this in parallel to the R-side pipeline (extract OISST + power
calc are upstream and independent).

Run order:
    1. Activate the Python env that has intake-esm + xarray + zarr installed
       (same env used for download_cmip6_ensemble.py):
         & "$env:LOCALAPPDATA\\r-miniconda\\envs\\cmems_env\\python.exe" download_cmip6_nino34.py
    2. Smoke test first:
         python download_cmip6_nino34.py --test
       This downloads only GFDL-ESM4 / tos / historical, ~2 MB, ~30 sec.
       Validates Pangeo access, the new bbox, and the write path.
    3. Full ensemble: 6 models x 1 variable x 3 periods = 18 files, ~30-100 MB
       total, ~10-20 minutes of network time.
    4. Skip logic: existing files preserved; rerun fills gaps only.

Cost expectation per file:
    - tos (curvilinear ORCA or regular grid): 1-5 MB each, 18 files total.

Outputs (in CMIP6_NINO34/ directory):
    CMIP6_ipsl_cm6a_lr_tos_historical_monthly_nino34.nc
    CMIP6_ipsl_cm6a_lr_tos_ssp245_monthly_nino34.nc
    CMIP6_ipsl_cm6a_lr_tos_ssp585_monthly_nino34.nc
    ... (six models x three experiments)

Downstream:
    R/06_projections/01_cmip6_deltas.R extended to also iterate over
    CMIP6_NINO34/ files and produce ENSO_delta per (model, scenario, window).
"""

import argparse
import os
import sys
import time
import xarray as xr
import intake
import numpy as np

# =============================================================================
# CONFIGURATION
# =============================================================================

# Separate output dir from the costero downloads (D:\GitHub\climate_projections\CMIP6).
OUTPUT_DIR = r"D:\GitHub\climate_projections\CMIP6_NINO34"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Nino 3.4 bbox: equatorial central-eastern Pacific.
# Convention: longitudes in [-180, 180]. Some CMIP6 models publish in [0, 360];
# bbox_subset() reorients automatically.
LAT_MIN, LAT_MAX = -5, 5
LON_MIN, LON_MAX = -170, -120

# Same six-model ensemble as the costero pipeline (selected to span CMIP6 ECS).
MODELS = [
    "IPSL-CM6A-LR",
    "GFDL-ESM4",
    "CESM2",
    "CNRM-ESM2-1",
    "UKESM1-0-LL",
    "MPI-ESM1-2-HR",
]

# Same variant priority as costero pipeline.
VARIANT_PRIORITY = {
    "IPSL-CM6A-LR":    ["r1i1p1f1"],
    "GFDL-ESM4":       ["r1i1p1f1"],
    "CESM2":           ["r1i1p1f1", "r4i1p1f1"],
    "CNRM-ESM2-1":     ["r1i1p1f2", "r1i1p1f1"],
    "UKESM1-0-LL":     ["r1i1p1f2", "r1i1p1f1"],
    "MPI-ESM1-2-HR":   ["r1i1p1f1"],
}

# ENSO is SST-only by definition. tos is the surface ocean temperature.
VARIABLES = {
    "tos":   {"table_id": "Omon", "kind": "ocean"},
}

# Same temporal windows as the costero pipeline (apples-to-apples splice).
PERIODS = {
    # End dates use day 30 to remain valid across CMIP6 calendar variants.
    "historical": ("1993-01-01", "2014-12-30"),
    "ssp245":     ("2015-01-01", "2100-12-30"),
    "ssp585":     ("2015-01-01", "2100-12-30"),
}

CATALOG_URL = "https://storage.googleapis.com/cmip6/pangeo-cmip6.json"

# Filename suffix to disambiguate from costero downloads (defensive).
FNAME_SUFFIX = "_nino34"


# =============================================================================
# UTILITIES (identical to download_cmip6_ensemble.py; duplicated for stand-alone
# operation -- if the parent script is ever refactored, sync these manually.)
# =============================================================================

def model_filename_token(model_id):
    return model_id.lower().replace("-", "_")


def detect_grid(ds, varname):
    lon_candidates = ["lon", "longitude", "nav_lon"]
    lat_candidates = ["lat", "latitude", "nav_lat"]

    lon_name = None
    lat_name = None
    for c in lon_candidates:
        if c in ds.coords or c in ds.variables:
            lon_name = c
            break
    for c in lat_candidates:
        if c in ds.coords or c in ds.variables:
            lat_name = c
            break

    if lon_name is None or lat_name is None:
        raise RuntimeError(
            f"Could not identify lon/lat coords for {varname}. "
            f"Vars: {list(ds.variables)[:25]}"
        )

    lon_arr = ds[lon_name]
    if lon_arr.ndim == 1:
        return "regular", lon_name, lat_name
    elif lon_arr.ndim == 2:
        return "curvilinear", lon_name, lat_name
    else:
        raise RuntimeError(
            f"Unexpected {lon_name} dimensionality {lon_arr.ndim} for {varname}"
        )


def bbox_subset(ds, varname):
    grid_type, lon_name, lat_name = detect_grid(ds, varname)

    if grid_type == "regular":
        lon_vals = ds[lon_name].values
        if np.nanmin(lon_vals) >= 0 and LON_MIN < 0:
            ds = ds.assign_coords(
                {lon_name: ((lon_vals + 180) % 360) - 180}
            )
            ds = ds.sortby(lon_name)
        lat_vals = ds[lat_name].values
        if lat_vals[0] > lat_vals[-1]:
            lat_slice = slice(LAT_MAX, LAT_MIN)
        else:
            lat_slice = slice(LAT_MIN, LAT_MAX)
        ds = ds.sel({lon_name: slice(LON_MIN, LON_MAX),
                     lat_name: lat_slice})
        return ds

    # curvilinear case (ORCA-like 2D nav_lon/nav_lat)
    lon = ds[lon_name].values
    lat = ds[lat_name].values
    if np.nanmin(lon) >= 0 and LON_MIN < 0:
        lon = np.where(lon > 180, lon - 360, lon)
    mask = (lon >= LON_MIN) & (lon <= LON_MAX) & \
           (lat >= LAT_MIN) & (lat <= LAT_MAX)
    rows = np.any(mask, axis=1)
    cols = np.any(mask, axis=0)
    if not rows.any() or not cols.any():
        raise RuntimeError("Empty bounding box in curvilinear subset (Nino 3.4)")
    i0, i1 = np.where(rows)[0][[0, -1]]
    j0, j1 = np.where(cols)[0][[0, -1]]

    dims = [d for d in ds[lon_name].dims]
    if len(dims) != 2:
        raise RuntimeError(
            f"Expected 2D dims for curvilinear {lon_name}, got {dims}"
        )
    y_dim, x_dim = dims[0], dims[1]
    return ds.isel({y_dim: slice(i0, i1+1), x_dim: slice(j0, j1+1)})


def drop_bounds(ds):
    drop_candidates = [
        "bounds_nav_lon", "bounds_nav_lat", "bounds_lon", "bounds_lat",
        "lon_bnds", "lat_bnds", "time_bounds", "time_bnds",
        "lat_verticies", "lon_verticies", "vertices_latitude",
        "vertices_longitude", "area", "areacello", "areacella",
    ]
    drop = [v for v in drop_candidates if v in ds.variables]
    return ds.drop_vars(drop) if drop else ds


def try_download_one(cat, model, variant, variable, experiment, t0, t1, out_path):
    table_id = VARIABLES[variable]["table_id"]

    query = cat.search(
        source_id=model,
        experiment_id=experiment,
        variable_id=variable,
        table_id=table_id,
        member_id=variant,
    )

    if len(query.df) == 0:
        return False

    print(f"      Pangeo entries: {len(query.df)} | first zstore: "
          f"{query.df['zstore'].iloc[0][:90]}...")

    ds_dict = query.to_dataset_dict(
        xarray_open_kwargs={"consolidated": True, "use_cftime": True},
        storage_options={"token": "anon"},
        progressbar=False,
    )
    key = list(ds_dict.keys())[0]
    ds = ds_dict[key]

    ds = ds.sel(time=slice(t0, t1))
    if ds.sizes.get("time", 0) == 0:
        raise RuntimeError(f"No time steps in window {t0} to {t1}")

    ds = bbox_subset(ds, variable)

    for d in ("olevel", "lev", "depth"):
        if d in ds[variable].dims and ds.sizes.get(d, 1) > 0:
            ds = ds.isel({d: 0})

    ds = ds.load()
    ds = drop_bounds(ds)

    arr = ds[variable].isel(time=0).values
    n_valid = np.sum(~np.isnan(arr))
    if n_valid == 0:
        raise RuntimeError(
            f"All-NaN over Nino 3.4 bbox for {model}/{variable}/{experiment}. "
            "Likely a land/ocean mask issue or grid convention mismatch -- "
            "the equator should be ALL-OCEAN in this bbox."
        )
    units = ds[variable].attrs.get("units", "?")
    print(f"      first-slice valid cells: {n_valid}, "
          f"range [{np.nanmin(arr):.4g}, {np.nanmax(arr):.4g}] {units}")

    ds.to_netcdf(out_path)
    ds.close()
    return True


# =============================================================================
# MAIN
# =============================================================================

def main(models=None, variables=None, periods=None):
    if models is None:
        models = MODELS
    if variables is None:
        variables = VARIABLES
    if periods is None:
        periods = PERIODS

    print("=" * 72)
    print("CMIP6 ensemble download for Nino 3.4 (ENSO basin-scale shifter)")
    print(f"Models:    {models}")
    print(f"Variables: {list(variables.keys())}  (SST only -- ENSO is SST-based)")
    print(f"Periods:   {list(periods.keys())}")
    print(f"Bbox:      lon [{LON_MIN}, {LON_MAX}], lat [{LAT_MIN}, {LAT_MAX}]")
    print(f"Output:    {OUTPUT_DIR}")
    print("=" * 72)

    print("\nLoading Pangeo CMIP6 catalog...")
    cat = intake.open_esm_datastore(CATALOG_URL)
    print(f"  catalog has {len(cat.df):,} entries\n")

    combos = [(m, v, e)
              for m in models
              for v in variables
              for e in periods]
    total = len(combos)
    failed = []
    skipped = 0
    completed = 0

    t_start = time.time()

    for i, (model, variable, experiment) in enumerate(combos, 1):
        token = model_filename_token(model)
        out_name = f"CMIP6_{token}_{variable}_{experiment}_monthly{FNAME_SUFFIX}.nc"
        out_path = os.path.join(OUTPUT_DIR, out_name)
        elapsed = time.time() - t_start

        print(f"[{i:>3}/{total}] {model:14s} | {variable:5s} | {experiment:11s}"
              f" | elapsed {elapsed/60:.1f} min")

        if os.path.exists(out_path):
            print(f"      SKIP (exists): {out_name}")
            skipped += 1
            continue

        t0, t1 = periods[experiment]
        success = False
        last_err = None

        for variant in VARIANT_PRIORITY.get(model, ["r1i1p1f1"]):
            try:
                success = try_download_one(
                    cat, model, variant, variable, experiment, t0, t1, out_path
                )
                if success:
                    sz = os.path.getsize(out_path) // 1024
                    print(f"      OK ({variant}, {sz} kB): {out_name}")
                    break
                else:
                    print(f"      no Pangeo entry for {model}/{variant}/{variable}/{experiment}")
            except Exception as e:
                last_err = e
                print(f"      variant {variant} failed: "
                      f"{type(e).__name__}: {str(e)[:120]}")
                continue

        if not success:
            failed.append((model, variable, experiment, last_err))
        else:
            completed += 1

    elapsed_total = time.time() - t_start
    print("\n" + "=" * 72)
    print(f"Completed: {completed}/{total - skipped}  (skipped existing: {skipped})")
    print(f"Failed:    {len(failed)}")
    print(f"Total time: {elapsed_total/60:.1f} min")
    if failed:
        print("\nFailed combinations (model | variable | experiment | error):")
        for m, v, e, err in failed:
            err_str = f"{type(err).__name__}: {str(err)[:80]}" if err else "no Pangeo entry"
            print(f"  - {m:14s} | {v:5s} | {e:11s} | {err_str}")
        print("\nSuggested follow-up:")
        print("  - Re-run this script (skip logic preserves successes)")
        print("  - For persistent failures, fall back to ESGF.")
    print("=" * 72)
    return 0 if not failed else 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="CMIP6 ensemble download for Nino 3.4 (ENSO) via Pangeo Cloud Zarr."
    )
    parser.add_argument(
        "--test", action="store_true",
        help=(
            "Test mode: download only GFDL-ESM4 / tos / historical "
            "to validate the pipeline before committing to the full ensemble."
        )
    )
    parser.add_argument(
        "--model", default=None,
        help="Override: run only this single model (e.g. 'GFDL-ESM4')."
    )
    parser.add_argument(
        "--experiment", default=None,
        help="Override: run only this single experiment (historical, ssp245, ssp585)."
    )
    args = parser.parse_args()

    if args.test:
        print("\n>>> TEST MODE: GFDL-ESM4 / tos / historical only.\n"
              "    Validates Pangeo access, Nino 3.4 bbox subset, and write path\n"
              "    before committing to the full ensemble.\n")
        sys.exit(main(
            models=["GFDL-ESM4"],
            variables={"tos": VARIABLES["tos"]},
            periods={"historical": PERIODS["historical"]},
        ))

    if any([args.model, args.experiment]):
        m = [args.model] if args.model else MODELS
        p = ({args.experiment: PERIODS[args.experiment]}
             if args.experiment else PERIODS)
        sys.exit(main(models=m, periods=p))

    sys.exit(main())
