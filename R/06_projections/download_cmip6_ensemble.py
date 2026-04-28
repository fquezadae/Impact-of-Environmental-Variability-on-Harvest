"""
download_cmip6_ensemble.py - CMIP6 multi-model ensemble download via Pangeo Cloud.
=================================================================================

Adapted from INCAR2-RL8/download_pangeo_o2.py. Reads CMIP6 directly from Google
Cloud Storage (Zarr format) and only transfers the chunks needed (study area +
valid period). Bypasses ESGF servers entirely; no authentication required.

Ensemble (6 models, selected to span CMIP6 ECS distribution):
    - IPSL-CM6A-LR     (Institut Pierre Simon Laplace, France)
    - GFDL-ESM4        (NOAA Geophysical Fluid Dynamics Laboratory, USA)
    - CESM2            (National Center for Atmospheric Research, USA)
    - CNRM-ESM2-1      (Centre National de Recherches Meteorologiques, France)
    - UKESM1-0-LL      (UK Met Office Hadley Centre, UK)
    - MPI-ESM1-2-HR    (Max Planck Institute, Germany)

Variables:
    - tos     surface ocean temperature       (Omon, ORCA-like curvilinear)
    - chlos   surface chlorophyll-a           (Omon, ORCA-like curvilinear)
    - uas     eastward near-surface wind      (Amon, regular lon-lat grid)
    - vas     northward near-surface wind     (Amon, regular lon-lat grid)

Naming convention (preserved from INCAR2 pipeline so 01_cmip6_deltas.R can
iterate over models with minimal changes):

    CMIP6_<model_lowercase_underscore>_<variable>_<experiment>_monthly.nc

Examples:
    CMIP6_ipsl_cm6a_lr_tos_historical_monthly.nc
    CMIP6_gfdl_esm4_chlos_ssp585_monthly.nc
    CMIP6_mpi_esm1_2_hr_uas_ssp245_monthly.nc

Run order recommendation:
    1. Activate the Python env that has intake-esm + xarray + zarr installed:
         & "$env:LOCALAPPDATA\\r-miniconda\\envs\\cmems_env\\python.exe" download_cmip6_ensemble.py
    2. Skip logic: existing files are preserved; rerun to fill gaps only.
    3. Failed (model, variable, experiment) combinations are reported at the
       end. Some Pangeo entries may be missing for specific combos; for those
       we fall back to ESGF in a follow-up script (TBD).

Cost expectation per file:
    - Surface ocean (tos, chlos): 2-10 MB each (curvilinear grid, bbox subset)
    - Atmospheric (uas, vas):     1-5 MB each (regular grid, bbox subset)
Total for full ensemble (6 x 4 x 3 = 72 files): roughly 200-500 MB on disk.
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

OUTPUT_DIR = r"D:\GitHub\climate_projections\CMIP6"
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Bounding box for Centro-Sur Chile (matches INCAR2 + paper 1 Section 3.1)
LAT_MIN, LAT_MAX = -56, -32
LON_MIN, LON_MAX = -81, -65

# Six-model ensemble (source_id values as used in CMIP6 metadata)
MODELS = [
    "IPSL-CM6A-LR",
    "GFDL-ESM4",
    "CESM2",
    "CNRM-ESM2-1",
    "UKESM1-0-LL",
    "MPI-ESM1-2-HR",
]

# Variant priorities: try r1i1p1f1 first (most common), then known per-model
# defaults. CNRM-ESM2-1 commonly publishes r1i1p1f2 (different forcing index).
# UKESM1-0-LL commonly uses r1i1p1f2 too. We attempt the first that works.
VARIANT_PRIORITY = {
    "IPSL-CM6A-LR":    ["r1i1p1f1"],
    "GFDL-ESM4":       ["r1i1p1f1"],
    "CESM2":           ["r1i1p1f1", "r4i1p1f1"],
    "CNRM-ESM2-1":     ["r1i1p1f2", "r1i1p1f1"],
    "UKESM1-0-LL":     ["r1i1p1f2", "r1i1p1f1"],
    "MPI-ESM1-2-HR":   ["r1i1p1f1"],
}

# Variables grouped by their CMIP6 table_id (Omon = ocean monthly,
# Amon = atmospheric monthly).
VARIABLES = {
    "tos":   {"table_id": "Omon", "kind": "ocean"},
    "chlos": {"table_id": "Omon", "kind": "ocean"},
    "uas":   {"table_id": "Amon", "kind": "atmos"},
    "vas":   {"table_id": "Amon", "kind": "atmos"},
}

PERIODS = {
    "historical": ("1993-01-01", "2014-12-31"),
    "ssp245":     ("2015-01-01", "2100-12-31"),
    "ssp585":     ("2015-01-01", "2100-12-31"),
}

# Pangeo's curated CMIP6 catalog on Google Cloud
CATALOG_URL = "https://storage.googleapis.com/cmip6/pangeo-cmip6.json"


# =============================================================================
# UTILITIES
# =============================================================================

def model_filename_token(model_id):
    """Convert CMIP6 source_id to lowercase-underscore filename token.

    Examples:
        IPSL-CM6A-LR  -> ipsl_cm6a_lr
        GFDL-ESM4     -> gfdl_esm4
        MPI-ESM1-2-HR -> mpi_esm1_2_hr
    """
    return model_id.lower().replace("-", "_")


def detect_grid(ds, varname):
    """Detect grid type by inspecting lat/lon dimensionality.

    Returns a tuple (grid_type, lon_name, lat_name) where grid_type is one of:
      - 'regular': 1D lat and lon coords; use ds.sel(lat=..., lon=...)
      - 'curvilinear': 2D lat and lon coords (nav_lon/nav_lat or 2D lat/lon);
        requires masking and isel on underlying y/x or i/j dims.

    CMIP6 model behaviour observed:
      - IPSL-CM6A-LR, UKESM1-0-LL:    curvilinear (ORCA, nav_lon/nav_lat)
      - GFDL-ESM4, CESM2 with 'gr':   regular interpolated grid (1D lat/lon)
      - CNRM-ESM2-1, MPI-ESM1-2-HR:   regular for atmospheric, varies for ocean
      - Atmospheric vars (uas, vas):  almost always regular
    """
    # Candidate coord names to probe
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

    # Dimensionality dispatch
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
    """Apply bounding-box subset with automatic grid-type detection."""
    grid_type, lon_name, lat_name = detect_grid(ds, varname)

    if grid_type == "regular":
        lon_vals = ds[lon_name].values
        # Handle 0-360 vs -180..180 longitude convention
        if np.nanmin(lon_vals) >= 0 and LON_MIN < 0:
            ds = ds.assign_coords(
                {lon_name: ((lon_vals + 180) % 360) - 180}
            )
            ds = ds.sortby(lon_name)
        # Need to know if lat is increasing or decreasing for slice direction
        lat_vals = ds[lat_name].values
        if lat_vals[0] > lat_vals[-1]:
            lat_slice = slice(LAT_MAX, LAT_MIN)  # decreasing
        else:
            lat_slice = slice(LAT_MIN, LAT_MAX)
        ds = ds.sel({lon_name: slice(LON_MIN, LON_MAX),
                     lat_name: lat_slice})
        return ds

    # curvilinear case
    lon = ds[lon_name].values
    lat = ds[lat_name].values
    if np.nanmin(lon) >= 0 and LON_MIN < 0:
        lon = np.where(lon > 180, lon - 360, lon)
    mask = (lon >= LON_MIN) & (lon <= LON_MAX) & \
           (lat >= LAT_MIN) & (lat <= LAT_MAX)
    rows = np.any(mask, axis=1)
    cols = np.any(mask, axis=0)
    if not rows.any() or not cols.any():
        raise RuntimeError("Empty bounding box in curvilinear subset")
    i0, i1 = np.where(rows)[0][[0, -1]]
    j0, j1 = np.where(cols)[0][[0, -1]]

    # Identify the y/x dims of the 2D lon array
    dims = [d for d in ds[lon_name].dims]
    if len(dims) != 2:
        raise RuntimeError(
            f"Expected 2D dims for curvilinear {lon_name}, got {dims}"
        )
    y_dim, x_dim = dims[0], dims[1]
    return ds.isel({y_dim: slice(i0, i1+1), x_dim: slice(j0, j1+1)})


def drop_bounds(ds):
    """Drop common bounds variables to keep NetCDF lean."""
    drop_candidates = [
        "bounds_nav_lon", "bounds_nav_lat", "bounds_lon", "bounds_lat",
        "lon_bnds", "lat_bnds", "time_bounds", "time_bnds",
        "lat_verticies", "lon_verticies", "vertices_latitude",
        "vertices_longitude", "area", "areacello", "areacella",
    ]
    drop = [v for v in drop_candidates if v in ds.variables]
    return ds.drop_vars(drop) if drop else ds


def try_download_one(cat, model, variant, variable, experiment, t0, t1, out_path):
    """Search Pangeo catalog and write subsetted NetCDF for one combo.

    Returns True on success, False if no matching entry found, raises on
    network / processing failure.
    """
    table_id = VARIABLES[variable]["table_id"]
    kind = VARIABLES[variable]["kind"]

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

    # Time subset first (cheap on Zarr)
    ds = ds.sel(time=slice(t0, t1))
    if ds.sizes.get("time", 0) == 0:
        raise RuntimeError(f"No time steps in window {t0} to {t1}")

    # Spatial subset with automatic grid-type detection
    # (CMIP6 ocean variables can be published on curvilinear ORCA-like grids
    # OR on regular interpolated grids depending on model and grid_label;
    # atmospheric variables are almost always regular. detect_grid handles all.)
    ds = bbox_subset(ds, variable)

    # Some 3D ocean variables sneak in a depth dim with size 1; drop it
    for d in ("olevel", "lev", "depth"):
        if d in ds[variable].dims and ds.sizes.get(d, 1) > 0:
            ds = ds.isel({d: 0})

    # Trigger transfer of the small subset
    ds = ds.load()
    ds = drop_bounds(ds)

    # Sanity: check the data is not all-NaN over the bbox (some models leave
    # the Centro-Sur region masked depending on land/ocean mask alignment).
    arr = ds[variable].isel(time=0).values
    n_valid = np.sum(~np.isnan(arr))
    if n_valid == 0:
        raise RuntimeError(
            f"All-NaN over bbox for {model}/{variable}/{experiment}. "
            "May be a land/ocean mask issue or grid convention mismatch."
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
    print("CMIP6 multi-model ensemble download via Pangeo Cloud (Zarr)")
    print(f"Models:    {models}")
    print(f"Variables: {list(variables.keys())}")
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
        out_name = f"CMIP6_{token}_{variable}_{experiment}_monthly.nc"
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
            completed += 0
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
        print("  - For persistent failures, fall back to ESGF via download_esgf.py")
        print("    (adapt MODEL list there, but expect intermittent server issues)")
    print("=" * 72)
    return 0 if not failed else 2


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="CMIP6 ensemble download via Pangeo Cloud Zarr."
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
        "--variable", default=None,
        help="Override: run only this single variable (tos, chlos, uas, vas)."
    )
    parser.add_argument(
        "--experiment", default=None,
        help="Override: run only this single experiment (historical, ssp245, ssp585)."
    )
    args = parser.parse_args()

    if args.test:
        print("\n>>> TEST MODE: GFDL-ESM4 / tos / historical only.\n"
              "    This validates Pangeo access, bbox subset on curvilinear "
              "grid, and write path before committing to the full ensemble.\n")
        sys.exit(main(
            models=["GFDL-ESM4"],
            variables={"tos": VARIABLES["tos"]},
            periods={"historical": PERIODS["historical"]},
        ))

    # Custom single-combo mode (any combination of overrides)
    if any([args.model, args.variable, args.experiment]):
        m = [args.model] if args.model else MODELS
        v = ({args.variable: VARIABLES[args.variable]}
             if args.variable else VARIABLES)
        p = ({args.experiment: PERIODS[args.experiment]}
             if args.experiment else PERIODS)
        sys.exit(main(models=m, variables=v, periods=p))

    sys.exit(main())
