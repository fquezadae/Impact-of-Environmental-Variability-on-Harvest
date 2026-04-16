# =============================================================================
# FONDECYT -- 02_project_and_predict.R
# Apply CMIP6 deltas to observed wind data and predict NB trip counts
# under climate change scenarios.
#
# Approach:
#   1. Load CMIP6 wind speed deltas (from 01_cmip6_deltas.R)
#   2. Load observed daily wind data (0.125° grid)
#   3. Interpolate CMIP6 delta (~1° grid) to the finer wind grid
#   4. Shift daily wind speed by the monthly delta
#   5. Recompute days_bad_weather per vessel-year under each scenario
#   6. Predict T_vy (trips) using the estimated NB model
#   7. Summarize % change in effort by fleet, scenario, and window
#
# Prerequisites:
#   - Run 01_cmip6_deltas.R first (outputs data/projections/cmip6_deltas.rds)
#   - Run poisson_model.R first (outputs data/trips/poisson_dt.rds and the
#     NB model objects, or re-estimate here)
# =============================================================================

library(data.table)
library(dplyr)
library(MASS)
library(sandwich)
library(lmtest)
library(lubridate)

source("R/00_config/config.R")

# =============================================================================
# 1. LOAD INPUTS
# =============================================================================

cat("Loading inputs...\n")

# CMIP6 deltas
deltas_all <- readRDS("data/projections/cmip6_deltas.rds")
wind_deltas <- deltas_all[variable == "wind_speed"]

# Observed daily wind (0.125° grid, used in poisson_model.R)
env_dt <- readRDS(paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"))

# NB estimation dataset
poisson_df <- readRDS("data/trips/poisson_dt.rds")

# Vessel COG mappings (to link vessels to grid points)
# Re-create from poisson_model.R objects
vessel_chars <- readRDS("data/trips/vessel_chars.rds")

cat("  Wind grid:", env_dt[, uniqueN(lon)], "x", env_dt[, uniqueN(lat)], "cells\n")
cat("  CMIP6 delta grid:", wind_deltas[, uniqueN(lon)], "x",
    wind_deltas[, uniqueN(lat)], "cells\n")
cat("  Estimation sample:", nrow(poisson_df), "vessel-years\n")

# =============================================================================
# 2. INTERPOLATE CMIP6 DELTAS TO OBSERVED WIND GRID
# =============================================================================
# CMIP6 atmospheric grid is ~2.5° x 1.25° (IPSL-CM6A-LR).
# Observed wind is 0.125°. We interpolate via nearest-neighbor from the
# CMIP6 grid. The delta field is smooth at ~100 km scale, so bilinear
# or nearest-neighbor give nearly identical results at this resolution.

cat("\nInterpolating deltas to wind grid...\n")

# Observed grid points
obs_grid <- env_dt[, .(lon, lat)] |> unique()

# For each obs grid point, find nearest CMIP6 delta point
# (do this once for each unique CMIP6 (ssp, window) since grid is the same)
cmip_grid <- wind_deltas[ssp == SSPS[1] & window == "mid" & month == 1,
                          .(lon, lat)] |> unique()

# Nearest-neighbor matching
find_nearest <- function(target_lon, target_lat, source_dt) {
  dists <- sqrt((source_dt$lon - target_lon)^2 + (source_dt$lat - target_lat)^2)
  idx <- which.min(dists)
  list(cmip_lon = source_dt$lon[idx], cmip_lat = source_dt$lat[idx])
}

obs_grid[, c("cmip_lon", "cmip_lat") := {
  res <- find_nearest(lon, lat, cmip_grid)
  list(res$cmip_lon, res$cmip_lat)
}, by = .(lon, lat)]

cat("  Matched", nrow(obs_grid), "obs grid points to",
    obs_grid[, uniqueN(paste(cmip_lon, cmip_lat))], "CMIP6 cells\n")


# =============================================================================
# 3. COMPUTE PROJECTED days_bad_weather UNDER EACH SCENARIO
# =============================================================================

WIND_THRESHOLD <- 8  # m/s (same as poisson_model.R)

# Vessel COG to grid mapping (from poisson_model.R logic)
# We need each vessel's nearest env grid point
env_grid_pts <- unique(env_dt[, .(lat, lon)])

# Get vessel COG from poisson_df (it has cog_lat, cog_lon)
poisson_dt <- as.data.table(poisson_df)
cog_vessel <- unique(poisson_dt[, .(COD_BARCO, cog_lat, cog_lon)])

# Match vessels to nearest wind grid point
cog_vessel[, c("grid_lat", "grid_lon") := {
  dists <- sqrt((env_grid_pts$lat - cog_lat)^2 + (env_grid_pts$lon - cog_lon)^2)
  idx <- which.min(dists)
  list(env_grid_pts$lat[idx], env_grid_pts$lon[idx])
}, by = .(COD_BARCO)]

cat("\nComputing projected bad weather days...\n")

# Historical baseline: days with speed_max > threshold
# (this should match poisson_model.R section 9)
bw_historical <- env_dt[year(date) >= 2013 & year(date) <= 2024,
                         .(days_bad_weather_hist = sum(speed_max > WIND_THRESHOLD, na.rm = TRUE)),
                         by = .(lon, lat, year = year(date))]

# For each scenario: shift daily speed_max by monthly delta, recount
scenarios <- CJ(ssp = SSPS, window = c("mid", "end"))

projected_bw_list <- list()

for (i in seq_len(nrow(scenarios))) {
  sc_ssp <- scenarios$ssp[i]
  sc_win <- scenarios$window[i]
  key <- paste(sc_ssp, sc_win, sep = "_")

  cat(sprintf("  Scenario: %s %s\n", sc_ssp, sc_win))

  # Get deltas for this scenario (month x cmip_grid)
  sc_deltas <- wind_deltas[ssp == sc_ssp & window == sc_win,
                            .(cmip_lon = lon, cmip_lat = lat, month, delta)]

  # Map obs grid -> delta via nearest CMIP6 cell
  obs_delta <- merge(obs_grid, sc_deltas,
                     by = c("cmip_lon", "cmip_lat"),
                     allow.cartesian = TRUE)
  obs_delta <- obs_delta[, .(lon, lat, month, delta)]

  # Apply delta to daily wind and recount bad weather days
  env_proj <- copy(env_dt[year(date) >= 2013 & year(date) <= 2024])
  env_proj[, month := month(date)]

  # Merge delta by (lon, lat, month)
  env_proj <- merge(env_proj, obs_delta, by = c("lon", "lat", "month"), all.x = TRUE)

  # Shift speed_max by delta (additive)
  # Ensure non-negative
  env_proj[, speed_max_proj := pmax(0, speed_max + delta)]

  # Count projected bad weather days
  bw_proj <- env_proj[, .(days_bad_weather_proj = sum(speed_max_proj > WIND_THRESHOLD, na.rm = TRUE)),
                       by = .(lon, lat, year = year(date))]

  bw_proj[, `:=`(ssp = sc_ssp, window = sc_win)]
  projected_bw_list[[key]] <- bw_proj

  rm(env_proj, obs_delta, sc_deltas, bw_proj); gc()
}

projected_bw <- rbindlist(projected_bw_list)

cat("  Done. Projected bad weather summary:\n")
print(projected_bw[, .(
  mean_days = round(mean(days_bad_weather_proj, na.rm = TRUE), 1),
  sd_days   = round(sd(days_bad_weather_proj, na.rm = TRUE), 1)
), by = .(ssp, window)])


# =============================================================================
# 4. RE-ESTIMATE NB MODELS (to have model objects for prediction)
# =============================================================================

cat("\nEstimating NB models...\n")

# Check if prices are already rescaled (in 1000s of pesos/ton)
# If max price > 100, they're still in pesos/ton and need rescaling
if (max(poisson_df$price_jurel, na.rm = TRUE) > 100) {
  cat("  Rescaling prices to 1000s of pesos/ton...\n")
  poisson_df <- poisson_df %>%
    mutate(across(starts_with("price_"), ~ . / 1000))
}
if (max(poisson_df$diesel_real, na.rm = TRUE) > 100) {
  cat("  Rescaling diesel to 100s of pesos/litro...\n")
  poisson_df <- poisson_df %>%
    mutate(diesel_real = diesel_real / 100)
}

df_ind <- poisson_df %>% filter(TIPO_FLOTA == "IND")
df_art <- poisson_df %>% filter(TIPO_FLOTA == "ART")

nb_ind <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy + TIPO_EMB,
  data = df_ind
)

nb_art <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy + TIPO_EMB,
  data = df_art
)

cat("  IND AIC:", round(AIC(nb_ind), 1), "\n")
cat("  ART AIC:", round(AIC(nb_art), 1), "\n")


# =============================================================================
# 5. PREDICT TRIPS UNDER EACH SCENARIO
# =============================================================================

cat("\nPredicting trips under scenarios...\n")

# For each vessel-year, swap days_bad_weather with the projected value
# and predict T_vy. All other covariates held constant.

prediction_results <- list()

for (i in seq_len(nrow(scenarios))) {
  sc_ssp <- scenarios$ssp[i]
  sc_win <- scenarios$window[i]
  key <- paste(sc_ssp, sc_win, sep = "_")

  cat(sprintf("  %s %s:\n", sc_ssp, sc_win))

  # Get projected bad weather for this scenario
  bw_sc <- projected_bw[ssp == sc_ssp & window == sc_win,
                         .(lon, lat, year, days_bad_weather_proj)]

  # Map vessel -> projected days via COG grid
  vessel_bw_proj <- merge(
    cog_vessel[, .(COD_BARCO, grid_lat, grid_lon)],
    bw_sc,
    by.x = c("grid_lon", "grid_lat"),
    by.y = c("lon", "lat"),
    allow.cartesian = TRUE
  )
  vessel_bw_proj <- vessel_bw_proj[, .(COD_BARCO, year, days_bad_weather_proj)]

  # --- INDUSTRIAL ---
  df_ind_proj <- df_ind %>%
    left_join(vessel_bw_proj, by = c("COD_BARCO", "year")) %>%
    mutate(
      days_bad_weather_orig = days_bad_weather,
      days_bad_weather = coalesce(days_bad_weather_proj, days_bad_weather)
    )

  df_ind_proj$T_vy_pred_baseline <- predict(nb_ind, newdata = df_ind, type = "response")
  df_ind_proj$T_vy_pred_proj     <- predict(nb_ind, newdata = df_ind_proj, type = "response")

  # --- ARTISANAL ---
  df_art_proj <- df_art %>%
    left_join(vessel_bw_proj, by = c("COD_BARCO", "year")) %>%
    mutate(
      days_bad_weather_orig = days_bad_weather,
      days_bad_weather = coalesce(days_bad_weather_proj, days_bad_weather)
    )

  df_art_proj$T_vy_pred_baseline <- predict(nb_art, newdata = df_art, type = "response")
  df_art_proj$T_vy_pred_proj     <- predict(nb_art, newdata = df_art_proj, type = "response")

  # Combine
  results_sc <- bind_rows(
    df_ind_proj %>%
      select(COD_BARCO, year, TIPO_FLOTA,
             T_vy, T_vy_pred_baseline, T_vy_pred_proj,
             days_bad_weather_orig, days_bad_weather),
    df_art_proj %>%
      select(COD_BARCO, year, TIPO_FLOTA,
             T_vy, T_vy_pred_baseline, T_vy_pred_proj,
             days_bad_weather_orig, days_bad_weather)
  ) %>%
    mutate(ssp = sc_ssp, window = sc_win,
           pct_change = 100 * (T_vy_pred_proj - T_vy_pred_baseline) / T_vy_pred_baseline)

  prediction_results[[key]] <- results_sc

  rm(df_ind_proj, df_art_proj, vessel_bw_proj, bw_sc); gc()
}

predictions <- bind_rows(prediction_results)


# =============================================================================
# 6. SUMMARY TABLES
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("PROJECTION RESULTS: % Change in predicted trips\n")
cat(strrep("=", 60), "\n\n")

summary_table <- predictions %>%
  group_by(TIPO_FLOTA, ssp, window) %>%
  summarise(
    n_vy = n(),
    mean_trips_baseline  = round(mean(T_vy_pred_baseline, na.rm = TRUE), 1),
    mean_trips_projected = round(mean(T_vy_pred_proj, na.rm = TRUE), 1),
    mean_pct_change      = round(mean(pct_change, na.rm = TRUE), 2),
    median_pct_change    = round(median(pct_change, na.rm = TRUE), 2),
    sd_pct_change        = round(sd(pct_change, na.rm = TRUE), 2),
    mean_delta_bw_days   = round(mean(days_bad_weather - days_bad_weather_orig, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(TIPO_FLOTA, ssp, window)

print(summary_table, n = 20)

# Additional: distribution by region
cat("\n\nBy region and fleet:\n")
region_summary <- predictions %>%
  left_join(
    poisson_df %>% select(COD_BARCO, year, reg_zone) %>% distinct(),
    by = c("COD_BARCO", "year")
  ) %>%
  group_by(TIPO_FLOTA, reg_zone, ssp, window) %>%
  summarise(
    mean_pct_change = round(mean(pct_change, na.rm = TRUE), 2),
    n_vy = n(),
    .groups = "drop"
  ) %>%
  arrange(TIPO_FLOTA, reg_zone, ssp, window)

print(region_summary, n = 50)

# =============================================================================
# 7. SAVE RESULTS
# =============================================================================

saveRDS(predictions, file = "data/projections/nb_predictions_climate.rds")
saveRDS(summary_table, file = "data/projections/summary_pct_change.rds")

cat("\nSaved:\n")
cat("  data/projections/nb_predictions_climate.rds\n")
cat("  data/projections/summary_pct_change.rds\n")
cat(strrep("=", 60), "\n")
