"""
download_copernicus_paper1_extended.py - Re-download paper 1 baselines on
extended bbox to support Appendix E (spatial robustness of jurel n.i.).
========================================================================

Adapted from INCAR2-RL8/download_copernicus_INCAR.py. Same Copernicus
Marine API (`copernicusmarine.subset`), same product IDs, but with the
*extended* bounding box that contains all three nested spatial domains
used in paper 1:

    1. Centro-Sur EEZ (main results, sec 4.1):
         approx lat [-42, -32], lon [-75, -70]
    2. Offshore-extended band (Appendix E variant 1):
         lat [-41, -32], lon [-85, -65]
    3. Southeast Pacific regional (Appendix E variant 2):
         lat [-45, -20], lon [-90, -65]

The previously downloaded Copernicus files cover only domain 1 (Centro-Sur
EEZ). This script downloads SST and CHL with the extended bbox so the
state-space refit for Appendix E can compute anomalies over domains 2 and 3.

Output: 2 NetCDF files in <paper1_data>/raw/climate/ — adjust OUTPUT_DIR
below to your local FONDECYT SPF data tree.

Variables:
    - SST monthly  : GLORYS12 reanalysis (cmems_mod_glo_phy_my_0.083deg_P1M-m)
                     surface depth slice (0.49-1.55 m)
    - CHL monthly  : Ocean Colour L4 multi-sensor (cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M)
                     surface

Period: 2000-2024 (matches paper 1 state-space estimation window).

Authentication: copernicusmarine credentials must already be configured
(`copernicusmarine login` once, stored in ~/.copernicusmarine/).

Estimated time: SST ~10-20 min, CHL ~15-25 min (single subset request each;
copernicusmarine handles chunking internally). Total ~30-45 min.
"""

import os
import copernicusmarine

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# Adjust to where you keep the FONDECYT SPF environmental data.
# In the paper1 R script, dirdata is:
#   "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
# under user "Felipe". The Copernicus baselines are typically in a subfolder
# like "raw/climate/" inside that. Update if your tree differs.
OUTPUT_DIR = (
    r"D:\OneDrive - Universidad de Concepción\FONDECYT Iniciacion\Data\raw\climate_extended"
)
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Extended bbox covering all three Appendix E spatial domains.
# Matches the bbox of download_cmip6_ensemble.py so spatial averages can be
# computed consistently across observed and CMIP6 sources.
LON_MIN, LON_MAX = -90, -65
LAT_MIN, LAT_MAX = -56, -20

# Paper 1 state-space estimation window
START_DATE = "2000-01-01T00:00:00"
END_DATE   = "2024-12-31T00:00:00"

# CHL Ocean Colour L4 starts in 1998-09; we still pull from 1998 to keep the
# door open for sensitivity analyses, but the paper uses 2000-2024.
CHL_START = "1998-09-01T00:00:00"
CHL_END   = "2024-12-31T00:00:00"


# -----------------------------------------------------------------------------
# RUN
# -----------------------------------------------------------------------------

def main():
    print("=" * 72)
    print("Copernicus Marine — paper 1 baselines on EXTENDED bbox")
    print("for Appendix E (spatial robustness of jurel non-identification)")
    print("=" * 72)
    print(f"Bbox: lon [{LON_MIN}, {LON_MAX}], lat [{LAT_MIN}, {LAT_MAX}]")
    print(f"Period: {START_DATE[:10]} to {END_DATE[:10]} (CHL from {CHL_START[:10]})")
    print(f"Output: {OUTPUT_DIR}")
    print()

    # --- 1. SST monthly (GLORYS12 reanalysis) ---
    sst_path = os.path.join(OUTPUT_DIR, "paper1_SST_monthly_2000_2024_extended.nc")
    if os.path.exists(sst_path):
        print(f"[1/2] SST: SKIP (exists: {os.path.basename(sst_path)})")
    else:
        print("[1/2] SST monthly (GLORYS12, surface) ...")
        copernicusmarine.subset(
            dataset_id="cmems_mod_glo_phy_my_0.083deg_P1M-m",
            variables=["thetao"],
            minimum_longitude=LON_MIN, maximum_longitude=LON_MAX,
            minimum_latitude=LAT_MIN,  maximum_latitude=LAT_MAX,
            start_datetime=START_DATE, end_datetime=END_DATE,
            minimum_depth=0.49, maximum_depth=1.55,
            output_directory=OUTPUT_DIR,
            output_filename=os.path.basename(sst_path),
        )
        sz = os.path.getsize(sst_path) // (1024 * 1024)
        print(f"      OK ({sz} MB): {os.path.basename(sst_path)}")

    # --- 2. CHL monthly (Ocean Colour L4 multi-sensor) ---
    chl_path = os.path.join(OUTPUT_DIR, "paper1_CHL_monthly_1998_2024_extended.nc")
    if os.path.exists(chl_path):
        print(f"[2/2] CHL: SKIP (exists: {os.path.basename(chl_path)})")
    else:
        print("\n[2/2] CHL monthly (Ocean Colour L4 multi-sensor) ...")
        copernicusmarine.subset(
            dataset_id="cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M",
            variables=["CHL"],
            minimum_longitude=LON_MIN, maximum_longitude=LON_MAX,
            minimum_latitude=LAT_MIN,  maximum_latitude=LAT_MAX,
            start_datetime=CHL_START, end_datetime=CHL_END,
            output_directory=OUTPUT_DIR,
            output_filename=os.path.basename(chl_path),
        )
        sz = os.path.getsize(chl_path) // (1024 * 1024)
        print(f"      OK ({sz} MB): {os.path.basename(chl_path)}")

    print()
    print("=" * 72)
    print("Both baselines downloaded. Next steps in R:")
    print("  1. Read both NetCDFs and compute monthly anomalies (vs climatology")
    print("     1995-2014 baseline) over the THREE nested spatial domains.")
    print("  2. Aggregate to annual SST and log-CHL series for each domain.")
    print("  3. Re-fit the T4b state-space (paper 1 sec 3.3.1) on each domain")
    print("     and report the posterior-to-prior std-dev ratio of the jurel")
    print("     shifters in Appendix E Table.")
    print("=" * 72)


if __name__ == "__main__":
    main()
