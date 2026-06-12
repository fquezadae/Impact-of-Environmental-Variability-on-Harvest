###============================================================###
###   Master pipeline: Impact of Environmental Variability     ###
###                    on Harvest Decisions                     ###
###============================================================###
#
#  Run this script to execute the full data processing pipeline.
#  Each step can also be run independently by sourcing the
#  individual script after sourcing 00_config/config.R.
#
#  Project structure:
#
#  R/
#  |-- 00_config/config.R          <- Paths, libraries, constants
#  |-- 00_run_all.R                <- THIS FILE (master pipeline)
#  |
#  |-- 01_data_cleaning/           <- Raw data -> clean .rds
#  |   |-- harvest_data.R          <- SERNAPESCA + IFOP harvest
#  |   |-- logbook_data.R          <- IFOP logbooks (trip records)
#  |   |-- biomass_data.R          <- Stock biomass + interpolation
#  |   |-- tac_processing.R        <- TAC allocation by species/region
#  |
#  |-- 02_env_processing/          <- NetCDF -> daily env grids
#  |   |-- load_glorys.R           <- SST, salinity, currents (GLORYS12)
#  |   |-- load_wind.R             <- Wind speed/direction (hourly->daily)
#  |   |-- load_chl.R              <- Chlorophyll-a (ocean colour)
#  |   |-- merge_env_data.R        <- Merge to common 0.125deg grid
#  |
#  |-- 03_env_spatial/             <- Spatial operations on env data
#  |   |-- dist_coast_env_data.R   <- Add distance-to-coast
#  |   |-- obtain_env_by_ports.R   <- Extract env by port buffers
#  |
#  |-- 04_models/                  <- Econometric estimation
#  |   |-- poisson_model.R         <- Trip count + harvest allocation
#  |
#  |-- 05_students/                <- Student-led modules
#  |   |-- base_datos_costos.R     <- Trip reconstruction from logbooks
#  |   |-- base_datos_precios.R    <- Ex-vessel prices database
#  |
#  |-- 06_projections/             <- Climate change projections
#  |   |-- 01_cmip6_deltas.R       <- CMIP6 delta-method (wind, SST, CHL)
#  |   |-- 02_project_and_predict.R <- Apply deltas + NB prediction
#  |
#  |-- env_2000_2011/              <- Legacy pipeline (2000-2011 data)
#  |-- archive/                    <- Deprecated / reference code
#
###============================================================###

cat("=== Starting pipeline ===\n\n")

# --- 0. Configuration ---
source("R/00_config/config.R")

# --- 1. Data cleaning ---
# Uncomment each step as needed (these read from Excel/CSV files)

# source("R/01_data_cleaning/harvest_data.R")   # -> data/harvest/*.rds
# source("R/01_data_cleaning/logbook_data.R")    # -> data/logbooks/logbooks.rds
# source("R/01_data_cleaning/biomass_data.R")    # -> data/biomass/biomass_dt.rds
# source("R/01_data_cleaning/tac_processing.R")  # -> TAC data

# --- 2. Environmental data processing ---
# These read large netCDF files; run only when updating env data

# source("R/02_env_processing/load_glorys.R")    # -> data/env/glorysDaily_2012_2025.rds
# source("R/02_env_processing/load_wind.R")      # -> data/env/WindDaily_2012_2025.rds
# source("R/02_env_processing/load_chl.R")       # -> data/env/chlDaily_2012_2025.rds
# source("R/02_env_processing/merge_env_data.R") # -> data/env/EnvMergedDaily_2012_2025_0.125deg.rds

# --- 3. Spatial environmental data ---
# source("R/03_env_spatial/dist_coast_env_data.R")    # -> data/env/EnvCoastDaily_2012_2025_0.125deg.rds
# source("R/03_env_spatial/obtain_env_by_ports.R")    # Functions; see script for usage

# --- 4. Models ---
# source("R/04_models/poisson_model.R")

# --- 5. Student modules ---
# source("R/05_students/base_datos_costos.R")    # -> data/outputs/trip_base_wide.xlsx
# source("R/05_students/base_datos_precios.R")   # -> base_precios.rds

# --- 6. Climate projections ---
# Requires: CMIP6 NetCDF files in D:/GitHub/climate_projections/CMIP6/
#           EnvCoastDaily_2012_2025_0.125deg.rds from step 3
#           poisson_dt.rds from step 4
# source("R/06_projections/01_cmip6_deltas.R")        # -> data/projections/cmip6_deltas.rds
# source("R/06_projections/02_project_and_predict.R") # -> data/projections/nb_predictions_climate.rds
# source("R/06_projections/03_project_biomass.R")     # -> data/projections/decomposition_table.rds

cat("\n=== Pipeline complete ===\n")
