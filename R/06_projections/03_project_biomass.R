# =============================================================================
# FONDECYT -- 03_project_biomass.R
# Project biomass via SUR model under climate change scenarios,
# then combine with wind projections for full NB prediction.
#
# Channels:
#   DIRECT:   Wind delta -> days_bad_weather -> T_vy  (from 02_project_and_predict.R)
#   INDIRECT: SST/CHL delta -> biomass (SUR) -> TAC -> H_alloc_vy -> T_vy
#   COMBINED: Both channels simultaneously
#
# Approach:
#   1. Re-estimate the SUR to get coefficients
#   2. Compute projected annual SST and CHL by applying deltas
#   3. Forward-simulate biomass using the SUR growth equation
#   4. Translate biomass changes to H_alloc changes (proportional TAC rule)
#   5. Predict NB trips with both wind AND H_alloc changes
#
# Prerequisites:
#   - 01_cmip6_deltas.R (data/projections/cmip6_deltas.rds)
#   - 02_project_and_predict.R (data/projections/nb_predictions_climate.rds)
#   - poisson_model.R (data/trips/poisson_dt.rds)
#   - biomass_data.R (data/biomass/biomass_dt.rds)
#   - EnvCoastDaily and EnvMergedDaily RDS files
# =============================================================================

library(data.table)
library(dplyr)
library(tidyr)
library(lavaan)
library(MASS)
library(lubridate)

source("R/00_config/config.R")
select <- dplyr::select

# =============================================================================
# 1. LOAD DATA
# =============================================================================

cat("Loading data...\n")

# Biomass
biomass <- readRDS("data/biomass/biomass_dt.rds")

# Harvest (built from component files, same as manuscript.Rmd harvest_data chunk)
harvest_SERNAPESCA_v2 <- readRDS("data/harvest/sernapesca_v2.rds")
harvest_SERNAPESCA    <- readRDS("data/harvest/sernapesca.rds")
harvest_IFOP          <- readRDS("data/harvest/IFOP.rds")

# Logbook-based harvest
logbooks_path <- ifelse(file.exists("data/logbooks/logbooks.rds"),
                        "data/logbooks/logbooks.rds", "data/trips/log_spf.rds")
logbooks <- readRDS(logbooks_path)
harvest_IFOP_logbooks <- logbooks %>%
  filter(year >= 2012) %>%
  filter(REGION %in% CENTRO_SUR_REGIONS) %>%
  group_by(NOMBRE_ESPECIE, year) %>%
  summarise(harvest_IFOP_loogbook_centrosur = sum(CAPTURA_RETENIDA, na.rm = TRUE),
            .groups = "drop") %>%
  rename(specie = NOMBRE_ESPECIE) %>%
  mutate(harvest_IFOP_loogbook_centrosur = harvest_IFOP_loogbook_centrosur / 1000)

harvest <- left_join(harvest_SERNAPESCA_v2, harvest_SERNAPESCA, by = c("year", "specie"))
harvest <- left_join(harvest, harvest_IFOP, by = c("year", "specie"))
harvest <- left_join(harvest, harvest_IFOP_logbooks, by = c("year", "specie"))

rm(harvest_SERNAPESCA_v2, harvest_SERNAPESCA, harvest_IFOP, harvest_IFOP_logbooks)

# Environmental (annual means for SUR) - same paths as manuscript.Rmd
env_dt <- readRDS(paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"))

# Legacy 2000-2011 env data (0.25 deg, different resolution)
env_00_11_path <- paste0(dirdata, "Environmental/env/2000-2011/EnvCoastDaily_2000_2011_0.25deg.rds")
if (file.exists(env_00_11_path)) {
  env_dt_00_11 <- readRDS(env_00_11_path)
} else {
  cat("  WARNING: 2000-2011 env data not found. SUR will use 2012+ only.\n")
  env_dt_00_11 <- NULL
}

# Climate deltas
deltas_all <- readRDS("data/projections/cmip6_deltas.rds")

# NB estimation data
poisson_df <- readRDS("data/trips/poisson_dt.rds")

# Wind projections (from 02_project_and_predict.R)
wind_predictions <- readRDS("data/projections/nb_predictions_climate.rds")


# =============================================================================
# 2. BUILD SUR DATASET (same as manuscript.Rmd chunks)
# =============================================================================

cat("\nBuilding SUR dataset...\n")

# Annual environmental means
env_year_1 <- as.data.table(env_dt)[, .(
  sst  = mean(sst, na.rm = TRUE),
  chl  = mean(chl, na.rm = TRUE),
  wind = mean(speed_max, na.rm = TRUE)
), by = .(year = year(date))]

if (!is.null(env_dt_00_11)) {
  env_year_2 <- as.data.table(env_dt_00_11)[, .(
    sst  = mean(sst, na.rm = TRUE),
    chl  = mean(chl, na.rm = TRUE),
    wind = mean(speed_max, na.rm = TRUE)
  ), by = .(year = year(date))]
  env_year <- rbind(env_year_2, env_year_1)
} else {
  env_year <- env_year_1
}

# Biomass wide
biomass_wide <- biomass %>%
  select(year, sardine_biomass, anchoveta_biomass,
         jurel_biomass_cs, jurel_cs_interp_primary) %>%
  mutate(jurel_main = jurel_cs_interp_primary)

# Harvest wide
harvest_wide <- harvest %>%
  select(specie, year, total_harvest_sernapesca_v2_centro_sur) %>%
  pivot_wider(names_from = specie,
              values_from = total_harvest_sernapesca_v2_centro_sur,
              names_prefix = "h_") %>%
  janitor::clean_names()

biomass_harvest_wide <- left_join(biomass_wide, harvest_wide, by = "year") %>%
  left_join(as.data.frame(env_year), by = "year")

# Build dependent variable: biomass_{t+1} + harvest_t
biomass_harvest_wide <- biomass_harvest_wide %>%
  arrange(year) %>%
  mutate(
    sardine_t1   = lead(sardine_biomass),
    anchoveta_t1 = lead(anchoveta_biomass),
    jurel_main_t1 = lead(jurel_main),
    y_sardine   = sardine_t1   + h_sardina_comun,
    y_anchoveta = anchoveta_t1 + h_anchoveta,
    y_jurel     = jurel_main_t1 + h_jurel
  )

# Scale and center (same as manuscript)
scale_b <- 1e5

sur_main <- biomass_harvest_wide %>%
  filter(!is.na(y_sardine), !is.na(y_anchoveta), !is.na(y_jurel),
         !is.na(sardine_biomass), !is.na(anchoveta_biomass), !is.na(jurel_main),
         !is.na(sst), !is.na(chl)) %>%
  mutate(
    y_s = y_sardine   / scale_b,
    y_a = y_anchoveta / scale_b,
    y_j = y_jurel     / scale_b,
    b_s = sardine_biomass   / scale_b,
    b_a = anchoveta_biomass / scale_b,
    b_j = jurel_main        / scale_b,
    b_s_c = b_s - mean(b_s), b_a_c = b_a - mean(b_a), b_j_c = b_j - mean(b_j),
    b_s_c2 = b_s_c^2, b_a_c2 = b_a_c^2, b_j_c2 = b_j_c^2,
    sst_c  = sst - mean(sst),
    chl_c  = chl - mean(chl),
    sst_c2 = sst_c^2,
    chl_c2 = chl_c^2
  )

# Store centering constants for projection
SST_MEAN <- mean(sur_main$sst + sur_main$sst_c * 0 + 0)  # reconstruct from data
CHL_MEAN <- mean(sur_main$chl + sur_main$chl_c * 0 + 0)
# Actually, simpler:
sst_raw <- biomass_harvest_wide %>%
  filter(!is.na(y_sardine), !is.na(sst)) %>% pull(sst)
chl_raw <- biomass_harvest_wide %>%
  filter(!is.na(y_sardine), !is.na(chl)) %>% pull(chl)

SST_MEAN <- mean(sst_raw)
CHL_MEAN <- mean(chl_raw)
B_S_MEAN <- mean(sur_main$b_s)
B_A_MEAN <- mean(sur_main$b_a)
B_J_MEAN <- mean(sur_main$b_j)

# Mean of dependent variable y_i (growth = biomass_{t+1} + harvest_t, scaled)
Y_S_MEAN <- mean(sur_main$y_s, na.rm = TRUE)
Y_A_MEAN <- mean(sur_main$y_a, na.rm = TRUE)
Y_J_MEAN <- mean(sur_main$y_j, na.rm = TRUE)

cat("  SUR sample: N =", nrow(sur_main), "\n")
cat("  Centering: SST_MEAN =", round(SST_MEAN, 2),
    "  CHL_MEAN =", round(CHL_MEAN, 4), "\n")
cat("  Mean y (growth, scaled): sardine =", round(Y_S_MEAN, 2),
    " anchoveta =", round(Y_A_MEAN, 2),
    " jurel =", round(Y_J_MEAN, 2), "\n")


# =============================================================================
# 3. ESTIMATE SUR (main specification)
# =============================================================================

cat("\nEstimating SUR...\n")

model_main <- '
  y_s ~ 1 + b_s_c + b_s_c2 + sst_c + sst_c2 + chl_c
  y_a ~ 1 + b_a_c + b_a_c2 + sst_c + sst_c2 + chl_c
  y_j ~ 1 + b_j_c + b_j_c2 + sst_c + sst_c2 + chl_c
'

fit_main <- sem(model_main, data = sur_main, estimator = "MLR")

# Extract coefficients by equation
coefs <- parameterEstimates(fit_main)
coefs_reg <- coefs %>% filter(op == "~")

cat("  SUR coefficients:\n")
print(coefs_reg %>% select(lhs, rhs, est, pvalue) %>% as.data.frame(), digits = 3)


# =============================================================================
# 4. PROJECT ANNUAL SST AND CHL UNDER SCENARIOS
# =============================================================================

cat("\nProjecting environmental variables...\n")

# Get SST and CHL deltas (spatially averaged over study area, by month)
sst_deltas <- deltas_all[variable == "sst",
                          .(delta = mean(delta, na.rm = TRUE)),
                          by = .(ssp, window)]

chl_deltas <- deltas_all[variable == "chl",
                          .(delta = mean(delta, na.rm = TRUE)),
                          by = .(ssp, window)]

# Historical annual mean SST and CHL (baseline for projections)
hist_sst <- mean(sst_raw)
hist_chl <- mean(chl_raw)

# Projected annual mean env under each scenario
proj_env <- merge(sst_deltas, chl_deltas, by = c("ssp", "window"),
                  suffixes = c("_sst", "_chl"))

proj_env[, `:=`(
  sst_proj = hist_sst + delta_sst,              # additive
  chl_proj = hist_chl * delta_chl,              # multiplicative
  sst_c_proj = (hist_sst + delta_sst) - SST_MEAN,
  chl_c_proj = (hist_chl * delta_chl) - CHL_MEAN
)]
proj_env[, sst_c2_proj := sst_c_proj^2]

cat("  Historical: SST =", round(hist_sst, 2), "C, CHL =", round(hist_chl, 4), "mg/m3\n")
cat("  Projections:\n")
print(proj_env[, .(ssp, window,
                    sst_proj = round(sst_proj, 2),
                    chl_proj = round(chl_proj, 4),
                    delta_sst = round(delta_sst, 2),
                    delta_chl = round(delta_chl, 3))])


# =============================================================================
# 5. COMPARATIVE STATICS: Biomass change from SUR environmental effects
# =============================================================================
# Instead of forward simulation (unstable with transboundary species),
# use comparative statics: compute the change in the growth term y_i
# due to environmental change, holding biomass at historical levels.
#
# The SUR predicts: y_i = intercept + beta*b_c + eta*b_c2 + rho1*sst_c + rho2*sst_c2 + rho3*chl_c
# At historical mean biomass (b_c = 0, b_c2 = 0):
#   y_i_hist = intercept + rho1*0 + rho2*0 + rho3*0 = intercept
#   y_i_proj = intercept + rho1*delta_sst + rho2*(delta_sst)^2 + rho3*delta_chl_c
#
# The % change in growth capacity = (y_proj - y_hist) / y_hist
# Under proportional TAC management, this translates to % change in TAC and H_alloc.

cat("\nComputing biomass comparative statics...\n")

# Extract SUR coefficients by species
get_sur_coefs <- function(species_var) {
  eq_coefs <- coefs_reg %>% filter(lhs == species_var)
  intercept <- coefs %>% filter(lhs == species_var, op == "~1") %>% pull(est)
  list(
    intercept = intercept,
    sst  = eq_coefs %>% filter(rhs == "sst_c") %>% pull(est),
    sst2 = eq_coefs %>% filter(rhs == "sst_c2") %>% pull(est),
    chl  = eq_coefs %>% filter(rhs == "chl_c") %>% pull(est)
  )
}

coefs_s <- get_sur_coefs("y_s")
coefs_a <- get_sur_coefs("y_a")
coefs_j <- get_sur_coefs("y_j")

# For each scenario, compute change in growth at mean biomass
biomass_projections <- list()

for (i in seq_len(nrow(proj_env))) {
  sc <- proj_env[i]

  # Change in growth term for each species (at mean biomass)
  # delta_y_i = rho_sst * delta_sst_c + rho_sst2 * delta_sst_c^2 + rho_chl * delta_chl_c
  # where delta_sst_c = sst_proj - SST_MEAN (projected centered value)
  # and sst_c_hist = 0 (by construction at mean)

  dy_s <- coefs_s$sst * sc$sst_c_proj + coefs_s$sst2 * sc$sst_c2_proj + coefs_s$chl * sc$chl_c_proj
  dy_a <- coefs_a$sst * sc$sst_c_proj + coefs_a$sst2 * sc$sst_c2_proj + coefs_a$chl * sc$chl_c_proj
  dy_j <- coefs_j$sst * sc$sst_c_proj + coefs_j$sst2 * sc$sst_c2_proj + coefs_j$chl * sc$chl_c_proj

  # % change in growth capacity: delta_y relative to mean observed y_i
  # (y_i = biomass_{t+1} + harvest_t, in scale_b units)
  # This is the correct denominator: total growth, not just biomass
  pct_s <- 100 * dy_s / Y_S_MEAN
  pct_a <- 100 * dy_a / Y_A_MEAN
  pct_j <- 100 * dy_j / Y_J_MEAN

  biomass_projections[[i]] <- data.frame(
    ssp = sc$ssp, window = sc$window,
    dy_sardine = dy_s, dy_anchoveta = dy_a, dy_jurel = dy_j,
    pct_sardine = pct_s, pct_anchoveta = pct_a, pct_jurel = pct_j
  )
}

biomass_proj <- bind_rows(biomass_projections)

cat("\n  Growth capacity % change (comparative statics):\n")
print(biomass_proj %>% select(ssp, window, pct_sardine, pct_anchoveta, pct_jurel) %>%
        mutate(across(starts_with("pct"), ~round(., 2))))


# =============================================================================
# 6. TRANSLATE BIOMASS CHANGE TO H_ALLOC CHANGE
# =============================================================================
# Assumption: TAC is set proportional to biomass (standard MSY-based rule).
# If biomass changes by X%, TAC and hence H_alloc change by X%.
# We compute a species-weighted average change for each vessel.

cat("\nTranslating biomass to harvest allocation changes...\n")

# Get each vessel's species composition from historical harvest
poisson_dt <- as.data.table(poisson_df)
harvest_vys <- readRDS("data/trips/harvest_vys.rds")

# Species codes: JUREL=26, SARDINA COMUN=33, ANCHOVETA=114
# harvest_vys has: COD_BARCO, year, COD_ESPECIE, H_vys
vessel_shares <- harvest_vys %>%
  mutate(species = case_when(
    COD_ESPECIE == 26  ~ "jurel",
    COD_ESPECIE == 33  ~ "sardine",
    COD_ESPECIE == 114 ~ "anchoveta",
    TRUE ~ "other"
  )) %>%
  filter(species != "other") %>%
  group_by(COD_BARCO, species) %>%
  summarise(h_total_sp = sum(H_vys, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = species, values_from = h_total_sp, values_fill = 0) %>%
  mutate(
    h_total = sardine + anchoveta + jurel,
    share_s = sardine / h_total,
    share_a = anchoveta / h_total,
    share_j = jurel / h_total
  ) %>%
  select(COD_BARCO, share_s, share_a, share_j) %>%
  mutate(across(starts_with("share"), ~replace_na(., 0)))


# =============================================================================
# 7. COMBINED PREDICTION: Wind + Biomass channels
# =============================================================================

cat("\nPredicting trips with combined channels...\n")

# Re-estimate NB models
if (max(poisson_df$price_jurel, na.rm = TRUE) > 100) {
  poisson_df <- poisson_df %>%
    mutate(across(starts_with("price_"), ~ . / 1000))
}
if (max(poisson_df$diesel_real, na.rm = TRUE) > 100) {
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

# Load projected bad weather (from 02_project_and_predict.R)
projected_bw <- readRDS("data/projections/nb_predictions_climate.rds") %>%
  select(COD_BARCO, year, ssp, window, days_bad_weather) %>%
  rename(days_bad_weather_proj = days_bad_weather)

SCENARIOS <- expand.grid(ssp = c("ssp245", "ssp585"),
                         window = c("mid", "end"),
                         stringsAsFactors = FALSE)

combined_results <- list()

for (i in seq_len(nrow(SCENARIOS))) {
  sc_ssp <- SCENARIOS$ssp[i]
  sc_win <- SCENARIOS$window[i]
  key <- paste(sc_ssp, sc_win, sep = "_")

  cat(sprintf("  %s %s:\n", sc_ssp, sc_win))

  # Get biomass % changes for this scenario
  bp <- biomass_proj %>% filter(ssp == sc_ssp, window == sc_win)

  # Compute vessel-specific H_alloc scaling factor
  # weighted by each vessel's species mix
  vessel_halloc_scale <- vessel_shares %>%
    mutate(
      halloc_pct_change = share_s * bp$pct_sardine +
        share_a * bp$pct_anchoveta +
        share_j * bp$pct_jurel,
      # Cap scaling factor: TAC can't go below 20% or above 300% of current
      halloc_scale = pmin(3.0, pmax(0.2, 1 + halloc_pct_change / 100))
    )

  # Get projected wind data for this scenario
  bw_sc <- projected_bw %>%
    filter(ssp == sc_ssp, window == sc_win)

  # --- INDUSTRIAL ---
  df_ind_combined <- df_ind %>%
    left_join(vessel_halloc_scale %>% select(COD_BARCO, halloc_scale),
              by = "COD_BARCO") %>%
    left_join(bw_sc %>% select(COD_BARCO, year, days_bad_weather_proj),
              by = c("COD_BARCO", "year")) %>%
    mutate(
      halloc_scale = coalesce(halloc_scale, 1),
      H_alloc_vy_orig = H_alloc_vy,
      H_alloc_vy = H_alloc_vy * halloc_scale,
      days_bad_weather_orig = days_bad_weather,
      days_bad_weather = coalesce(days_bad_weather_proj, days_bad_weather)
    )

  df_ind_combined$T_pred_baseline <- predict(nb_ind, newdata = df_ind, type = "response")
  df_ind_combined$T_pred_combined <- predict(nb_ind, newdata = df_ind_combined, type = "response")

  # --- ARTISANAL ---
  df_art_combined <- df_art %>%
    left_join(vessel_halloc_scale %>% select(COD_BARCO, halloc_scale),
              by = "COD_BARCO") %>%
    left_join(bw_sc %>% select(COD_BARCO, year, days_bad_weather_proj),
              by = c("COD_BARCO", "year")) %>%
    mutate(
      halloc_scale = coalesce(halloc_scale, 1),
      H_alloc_vy_orig = H_alloc_vy,
      H_alloc_vy = H_alloc_vy * halloc_scale,
      days_bad_weather_orig = days_bad_weather,
      days_bad_weather = coalesce(days_bad_weather_proj, days_bad_weather)
    )

  df_art_combined$T_pred_baseline <- predict(nb_art, newdata = df_art, type = "response")
  df_art_combined$T_pred_combined <- predict(nb_art, newdata = df_art_combined, type = "response")

  results_sc <- bind_rows(
    df_ind_combined %>%
      select(COD_BARCO, year, TIPO_FLOTA,
             T_vy, T_pred_baseline, T_pred_combined,
             halloc_scale, days_bad_weather_orig, days_bad_weather),
    df_art_combined %>%
      select(COD_BARCO, year, TIPO_FLOTA,
             T_vy, T_pred_baseline, T_pred_combined,
             halloc_scale, days_bad_weather_orig, days_bad_weather)
  ) %>%
    mutate(
      ssp = sc_ssp, window = sc_win,
      pct_change_combined = 100 * (T_pred_combined - T_pred_baseline) / T_pred_baseline
    )

  combined_results[[key]] <- results_sc
}

combined_predictions <- bind_rows(combined_results)


# =============================================================================
# 8. SUMMARY: Direct vs Indirect vs Combined effects
# =============================================================================

cat("\n", strrep("=", 70), "\n")
cat("COMBINED PROJECTION RESULTS\n")
cat(strrep("=", 70), "\n\n")

# Wind-only effect (from 02 script)
wind_only <- readRDS("data/projections/summary_pct_change.rds") %>%
  rename(pct_wind_only = mean_pct_change) %>%
  select(TIPO_FLOTA, ssp, window, pct_wind_only)

# Combined effect
combined_summary <- combined_predictions %>%
  group_by(TIPO_FLOTA, ssp, window) %>%
  summarise(
    n_vy = n(),
    pct_combined = round(mean(pct_change_combined, na.rm = TRUE), 2),
    .groups = "drop"
  )

# Merge for decomposition
decomposition <- combined_summary %>%
  left_join(wind_only, by = c("TIPO_FLOTA", "ssp", "window")) %>%
  mutate(
    pct_indirect = round(pct_combined - pct_wind_only, 2)
  ) %>%
  arrange(TIPO_FLOTA, ssp, window)

cat("Decomposition of climate effects on fishing effort:\n\n")
cat("  pct_wind_only : direct weather effect (days_bad_weather)\n")
cat("  pct_indirect  : via biomass -> TAC -> H_alloc\n")
cat("  pct_combined  : total effect (both channels)\n\n")
print(as.data.frame(decomposition), row.names = FALSE)

# Biomass projections
cat("\n\nProjected biomass changes:\n")
print(biomass_proj %>%
        select(ssp, window, pct_sardine, pct_anchoveta, pct_jurel) %>%
        mutate(across(starts_with("pct"), ~round(., 1))) %>%
        as.data.frame(), row.names = FALSE)

# =============================================================================
# 9. SAVE
# =============================================================================

saveRDS(combined_predictions, file = "data/projections/nb_predictions_combined.rds")
saveRDS(decomposition, file = "data/projections/decomposition_table.rds")
saveRDS(biomass_proj, file = "data/projections/biomass_projections.rds")

cat("\nSaved:\n")
cat("  data/projections/nb_predictions_combined.rds\n")
cat("  data/projections/decomposition_table.rds\n")
cat("  data/projections/biomass_projections.rds\n")
cat(strrep("=", 70), "\n")
