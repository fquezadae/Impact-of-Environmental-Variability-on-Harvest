## Context for FONDECYT project: Climate projections infrastructure

### What is available from the INCAR2-RL8 project

The INCAR2-RL8 project has a fully operational delta-method projection pipeline (`01_delta_method_INCAR.R`) that:

1. Downloads and processes CMIP6 data from IPSL-CM6A-LR (the IPSL Earth system model)
2. Applies delta-method bias correction against Copernicus satellite baselines
3. Fills coastal gaps via iterative focal interpolation (for fjords and narrow channels not resolved by the ~1 deg CMIP6 ORCA grid)
4. Outputs projected NetCDF files compatible with downstream risk index and CBA modules

### CMIP6 files already downloaded (local: `D:/GitHub/climate_projections/CMIP6/`)

All files are from IPSL-CM6A-LR, monthly resolution, global ocean coverage:

**Sea surface temperature (tos):**
- `CMIP6_ipsl_cm6a_lr_sea_surface_temperature_historical_monthly.nc` (1850-2014)
- `CMIP6_ipsl_cm6a_lr_sea_surface_temperature_ssp2_4_5_monthly.nc` (2015-2100)
- `CMIP6_ipsl_cm6a_lr_sea_surface_temperature_ssp5_8_5_monthly.nc` (2015-2100)

**Dissolved oxygen (o2):**
- `CMIP6_ipsl_cm6a_lr_o2_historical_monthly.nc`
- `CMIP6_ipsl_cm6a_lr_o2_ssp245_monthly.nc`
- `CMIP6_ipsl_cm6a_lr_o2_ssp585_monthly.nc`

**Surface chlorophyll (chlos):**
- `CMIP6_ipsl_cm6a_lr_chlos_historical_monthly.nc`
- `CMIP6_ipsl_cm6a_lr_chlos_ssp245_monthly.nc`
- `CMIP6_ipsl_cm6a_lr_chlos_ssp585_monthly.nc`

Additional variables downloaded but not yet used:
- **Sea surface salinity (sos):** historical + ssp245 + ssp585
- **Eastward wind (uas):** historical + ssp245 + ssp585
- **Northward wind (vas):** historical + ssp245 + ssp585

Total: 15 NetCDF files. Grid: ORCA curvilinear (~1 deg) for ocean variables, regular grid for atmospheric variables. **Global coverage** -- these files cover any ocean region, not just southern Chile.

### Copernicus baselines already downloaded (`model/data/raw/climate/`)

These are the high-resolution satellite baselines used for the INCAR project. They cover lon [-76, -65], lat [-56, -38] (southern Chile, Regions X-XII):

- `INCAR_SST_monthly_1993_2025.nc` -- GLORYS12, ~8 km, variable `thetao`
- `INCAR_O2_monthly_1993_2024.nc` -- BGC hindcast, ~25 km, variable `o2`
- `INCAR_CHL_monthly_1998_2024.nc` -- Ocean Colour L4, ~4 km, variable `CHL`

**For FONDECYT:** new Copernicus baselines would need to be downloaded for the FONDECYT study area (specify the bounding box). The same Copernicus products are available globally. The CDS API key is configured and the download scripts exist.

### What is needed to run projections for a different geographic area (FONDECYT)

1. **Define the FONDECYT study area bounding box** (lon_min, lon_max, lat_min, lat_max). For example, if the SPF harvest project covers the central Chilean coast, the bounding box might be lon [-80, -70], lat [-40, -25] or similar.

2. **Download Copernicus baselines for that area** using the same products:
   - SST from GLORYS12 (`cmems_mod_glo_phy_my_0.083deg_P1M-m`)
   - O2 from BGC hindcast (`cmems_mod_glo_bgc_my_0.25deg_P1M-m`)
   - CHL from Ocean Colour L4 (`cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M`)

3. **Reuse the existing CMIP6 files** -- they are global, so no new download is needed. The `01_delta_method_INCAR.R` pipeline subsets to the target grid automatically during regridding.

4. **Adapt the pipeline** -- the only changes needed in `01_delta_method_INCAR.R` are:
   - Point the baseline paths to the new Copernicus files
   - Adjust the output directory
   - The delta-method logic, regridding, gap-filling, and output format are all reusable

### Delta-method approach (summary)

For each variable (SST, O2, CHL):
- **Additive delta** (SST, O2): `projected = observed_baseline + (CMIP6_future_climatology - CMIP6_historical_climatology)`
- **Multiplicative delta** (CHL): `projected = observed_baseline * (CMIP6_future_climatology / CMIP6_historical_climatology)`

Baseline period: 1995-2014 (20-year climatology, matches CMIP6 historical run overlap with Copernicus).
Future windows: mid-century (2041-2060), end-century (2081-2100).
SSPs: SSP2-4.5 (moderate), SSP5-8.5 (high emissions).

The delta is computed as a 12-layer monthly climatology (one delta per calendar month), then applied cyclically to each month of the observed baseline time series. This preserves interannual variability and fine-scale spatial structure from the satellite record while imposing the climate change signal.

### Coastal gap-filling

The CMIP6 ORCA grid (~1 deg) leaves NA in coastal cells not resolved by the Earth system model. The `fill_coastal_delta()` function propagates the delta from nearest valid ocean cells using iterative 3x3 focal mean, constrained to the Copernicus ocean mask. This recovered ~2,100 SST cells and ~145 O2 cells per scenario in the INCAR project. The same procedure applies to any coastal study area.

### Key references for the delta method
- Burke, Hsiang & Miguel (2015, Nature) -- delta method in climate economics
- Free et al. (2019, Science) -- fisheries application
- Hawkins & Sutton (2009, BAMS) -- bias correction theory
