###============================================================###
###   Master pipeline — Differential Climate Impacts on        ###
###   Fishing Effort in Chilean Small Pelagic Fisheries        ###
###============================================================###
#
#  End-to-end run order for the paper. Most steps are commented out on
#  purpose: they either read non-redistributable raw inputs (see
#  data/README.md) or are expensive Stan fits. The processed series and
#  posterior summaries the manuscript needs are already tracked in data/,
#  so rendering the paper only requires `source("knit.R")`.
#
#  Project structure (R/):
#    00_config/         Paths, libraries, constants
#    01_data/           Raw ingestion (catch aggregation, ENSO Niño 3.4)
#    01_data_cleaning/  Raw microdata -> clean .rds
#    02_env_processing/ NetCDF -> daily environmental grids
#    03_env_spatial/    Spatial operations (distance-to-coast, port buffers)
#    04_models/         Trip-panel construction + NB inputs
#    06_projections/    CMIP6 ensemble deltas (+ Copernicus extended)
#    07_structural_bio/ Schaefer hindcast + official priors
#    08_stan_t4/        Bayesian state-space (T4b) + comparative statics
#
###============================================================###

cat("=== Starting pipeline ===\n\n")

# --- 0. Configuration ---
source("R/00_config/config.R")

# --- 1. Data ingestion and cleaning ---
# Read non-redistributable raw inputs; see data/README.md for access.
# source("R/01_data_cleaning/harvest_data.R")   # -> data/harvest/*.rds
# source("R/01_data_cleaning/logbook_data.R")    # -> data/logbooks/logbooks.rds
# source("R/01_data_cleaning/biomass_data.R")    # -> data/biomass/biomass_dt.rds
# source("R/01_data_cleaning/tac_processing.R")  # -> TAC allocation
# source("R/01_data/extract_oisst_nino34.R")     # -> ENSO Niño 3.4 (App E.6)

# --- 2. Environmental data processing (large NetCDF) ---
# source("R/02_env_processing/load_glorys.R")    # -> data/env/glorysDaily_2012_2025.rds
# source("R/02_env_processing/load_wind.R")      # -> data/env/WindDaily_2012_2025.rds
# source("R/02_env_processing/load_chl.R")       # -> data/env/chlDaily_2012_2025.rds
# source("R/02_env_processing/merge_env_data.R") # -> data/env/EnvMergedDaily_2012_2025_0.125deg.rds

# --- 3. Spatial environmental data ---
# source("R/03_env_spatial/dist_coast_env_data.R")   # -> data/env/EnvCoastDaily_2012_2025_0.125deg.rds
# source("R/03_env_spatial/obtain_env_by_ports.R")   # functions; see script for usage

# --- 4. Structural biology: official priors + Schaefer hindcast ---
# source("R/07_structural_bio/01_load_official_params.R")  # IFOP/SPRFMO priors (r0, K, sigmas)
# source("R/07_structural_bio/05_load_official_biomass.R") # official biomass series
# source("R/07_structural_bio/06_load_catch_series.R")     # catch series by stock
# source("R/07_structural_bio/02_hindcast_check.R")        # deterministic Schaefer hindcast

# --- 5. Trip panel (negative-binomial inputs) ---
# source("R/04_models/poisson_model.R")          # -> data/trips/poisson_dt.rds

# --- 6. CMIP6 ensemble deltas (one-shot; cached in data/cmip6/) ---
# source("R/06_projections/01_cmip6_deltas.R")        # 6-model SST/CHL/wind deltas
# source("R/06_projections/00b_sanity_check_ensemble.R")

# --- 7. Bayesian state-space (T4b) — core models (expensive Stan fits) ---
# source("R/08_stan_t4/04_fit_t4b_ind.R")    # no-shifter baseline
# source("R/08_stan_t4/06_fit_t4b_omega.R")  # + residual covariance
# source("R/08_stan_t4/08_fit_t4b_full.R")   # + SST/CHL shifters (leading model)
# source("R/08_stan_t4/10_loo_t4b_compare.R")# PSIS-LOO across specs
# source("R/08_stan_t4/11_lfo_t4b_compare.R")# PSIS-LFO across specs

# --- 8. Comparative statics + variance decompositions (headline results) ---
# options(t5.run_main = TRUE)
# source("R/08_stan_t4/12_growth_comparative_statics.R")   # productivity response (Table 5)
# options(t6.run_main = TRUE)
# source("R/08_stan_t4/13_trip_comparative_statics.R")     # fleet trip response (Table 7)
# options(t5.run_main = FALSE, appf.run_main = TRUE)
# source("R/08_stan_t4/16_appendix_f_variance_decomposition.R")
# options(t6.run_main = FALSE, appg.run_main = TRUE)
# source("R/08_stan_t4/17_appendix_g_trips_variance_decomposition.R")

# --- 9. Appendix E — non-identification evidence (basin-scale ENSO) ---
# One-shot block; see README "Reproducibility" for the exact option flags:
#   01_data/extract_oisst_nino34.R -> 06_projections/01b_cmip6_enso_deltas.R ->
#   08_stan_t4/18_power_calculation_enso.R -> 14b/14c refits ->
#   15_appendix_e_sigma_ratios.R -> 19_project_jurel_enso_prior_propagation.R

cat("\n=== Pipeline complete ===\n")
cat("To render the manuscript: source('knit.R')\n")
