###------------------------------------------------------###
###  CORRECTIONS TO poisson_data.r                       ###
###  1. TAC proxy → lagged TAC (predeterminado)          ###
###  2. Remove constant days_closed_sa                   ###
###  3. Deflate prices (placeholder IPC structure)        ###
###  4. Handle price_jurel missings                       ###
###  5. COG construction for days_bad_weather_vy          ###
###  6. Days_closed_vy from COG → regulatory region       ###
###------------------------------------------------------###
#
# Insert these blocks into poisson_data.r, replacing the
# corresponding sections. Section numbers match the original.


# =========================================================================
# FIX 1: SECTION 6 — REPLACE TAC PROXY WITH LAGGED TAC
# =========================================================================
#
# Problem: Using observed aggregate harvest as TAC proxy makes
#   H_alloc_vy = omega_vs * sum(H_vys_t) ≈ H_vys_t (the outcome).
#   This introduces mechanical endogeneity.
#
# Solution: Use the TAC from year t-1 as a predetermined proxy.
#   Under gradual TAC adjustment, TAC_{t-1} is a reasonable
#   predictor of TAC_t and is strictly predetermined.
#
# When official SUBPESCA TAC data is available, replace tac_lagged
# with the actual TAC_sy for year t.

# Step 1: Aggregate observed harvest by species-year (same as before)
tac_observed <- harvest_vys %>%
  group_by(year, COD_ESPECIE) %>%
  summarise(TAC_sy = sum(H_vys, na.rm = TRUE), .groups = "drop")

# Step 2: Lag by one year
tac_lagged <- tac_observed %>%
  arrange(COD_ESPECIE, year) %>%
  group_by(COD_ESPECIE) %>%
  mutate(TAC_sy_lag = lag(TAC_sy)) %>%
  ungroup() %>%
  select(year, COD_ESPECIE, TAC_sy_lag) %>%
  filter(!is.na(TAC_sy_lag))

cat("\n[FIX 1] Using lagged TAC (t-1) as predetermined proxy.\n")
cat("  First usable year:", min(tac_lagged$year), "\n")
cat("  Replace with official SUBPESCA TAC when available.\n")

# Step 3: Compute H_alloc_vy using lagged TAC
halloc <- shares_vs %>%
  left_join(tac_lagged, by = "COD_ESPECIE", relationship = "many-to-many") %>%
  mutate(H_alloc_vys = omega_vs * TAC_sy_lag) %>%
  group_by(COD_BARCO, year) %>%
  summarise(
    H_alloc_vy = sum(H_alloc_vys, na.rm = TRUE),
    .groups    = "drop"
  )


# =========================================================================
# FIX 2: SECTION 9 — REMOVE CONSTANT VEDA DAYS
# =========================================================================
#
# Problem: days_closed_sa = 151 for all observations is collinear
#   with the intercept. The NB cannot estimate its coefficient.
#
# Solution: Remove until vessel-year variation is available via COG.
#   See Section COG below for the construction of days_closed_vy.
#
# DELETE the veda_fixed block entirely. Do NOT merge it.


# =========================================================================
# FIX 3: SECTION 7 — DEFLATE PRICES
# =========================================================================
#
# Problem: Nominal prices 2013-2024 have ~45% accumulated inflation.
#   The model would attribute part of the price trend to real incentives.
#
# Solution: Deflate to constant pesos using IPC.
#
# OPTION A: When you have the IPC series from Banco Central:
#
# ipc_y <- read_excel(paste0(dirdata, "BancoCentral/ipc_anual.xlsx")) %>%
#   rename(year = año, ipc = ipc_index) %>%
#   mutate(year = as.integer(year))
# base_year <- 2018  # midpoint of sample
# base_ipc  <- ipc_y$ipc[ipc_y$year == base_year]
#
# prices_sy <- prices_sy_nominal %>%
#   left_join(ipc_y, by = "year") %>%
#   mutate(price_real = price_nominal * (base_ipc / ipc)) %>%
#   select(year, NM_RECURSO, price_real, n_plants, n_obs)
#
# OPTION B: Quick approximation using Chile's annual CPI
# (from INE/Banco Central, approximate values)

ipc_approx <- tibble(
  year = 2012:2024,
  ipc  = c(100.0, 101.8, 106.3, 110.7, 114.6, 117.1,
           119.9, 123.3, 127.0, 131.7, 143.5, 153.8, 160.7)
  # Base 2012 = 100. Source: approximate from INE annual CPI
  # REPLACE WITH OFFICIAL SERIES
)

base_year <- 2018
base_ipc  <- ipc_approx$ipc[ipc_approx$year == base_year]

prices_sy <- prices_sy_nominal %>%
  left_join(ipc_approx, by = "year") %>%
  mutate(price_real = price_nominal * (base_ipc / ipc)) %>%
  select(year, NM_RECURSO, price_real, n_plants, n_obs)

cat("\n[FIX 3] Prices deflated to", base_year, "constant pesos.\n")
cat("  NOTE: Using approximate IPC. Replace with official series.\n")

# Wide format with real prices
prices_wide <- prices_sy %>%
  select(year, NM_RECURSO, price_real) %>%
  pivot_wider(
    names_from  = NM_RECURSO,
    values_from = price_real
  ) %>%
  rename(
    price_jurel   = JUREL,
    price_sardina = `SARDINA COMUN`,
    price_anchov  = ANCHOVETA
  ) %>%
  mutate(year = as.integer(year))


# =========================================================================
# FIX 4: HANDLE JUREL PRICE MISSINGS
# =========================================================================
#
# Jurel ex-vessel prices are available in CS (region 8) for 2013-2024.
# Year 2012 has no TIPO_MP=1 data → already excluded by year >= 2013.
#
# If any year has missing jurel price after the merge:
#   Option 1: Impute with national average (regions 2,3,4,8)
#   Option 2: Impute with FOB jurel congelado from Banco Central
#
# Check and report:

cat("\n[FIX 4] Jurel price coverage check:\n")
cat("  Years with jurel price in CS:\n")
prices_wide %>%
  mutate(jurel_available = !is.na(price_jurel)) %>%
  select(year, jurel_available, price_jurel) %>%
  print(n = 15)

# If missings exist, uncomment:
# prices_wide <- prices_wide %>%
#   mutate(price_jurel = if_else(
#     is.na(price_jurel),
#     mean(price_jurel, na.rm = TRUE),  # simple mean imputation
#     price_jurel
#   ))


# =========================================================================
# COG: CENTER OF GRAVITY PER VESSEL
# =========================================================================
#
# Compute the catch-weighted centroid of each vessel's fishing locations
# over the full sample period. This is a time-invariant vessel
# characteristic that summarizes its "home range."
#
# Uses haul-level lat/lon from logbooks.
# Weight = CAPTURA_RETENIDA (catch in kg)

cog_vessel <- log_spf %>%
  filter(
    !is.na(LATITUD), !is.na(LONGITUD),
    !is.na(CAPTURA_RETENIDA), CAPTURA_RETENIDA > 0
  ) %>%
  group_by(COD_BARCO) %>%
  summarise(
    cog_lat = weighted.mean(LATITUD,  w = CAPTURA_RETENIDA),
    cog_lon = weighted.mean(LONGITUD, w = CAPTURA_RETENIDA),
    n_hauls = n(),
    sd_lat  = sd(LATITUD),   # dispersion diagnostic
    sd_lon  = sd(LONGITUD),
    .groups = "drop"
  )

cat("\n====== COG DIAGNOSTICS ======\n")
cat("Vessels with COG:", nrow(cog_vessel), "\n")
cat("\nCOG latitude summary:\n")
summary(cog_vessel$cog_lat)
cat("\nLatitude dispersion (sd_lat) summary:\n")
summary(cog_vessel$sd_lat)
cat("  Vessels with sd_lat > 0.5°:", sum(cog_vessel$sd_lat > 0.5, na.rm = TRUE),
    "of", nrow(cog_vessel), "\n")

# Flag vessels with high spatial dispersion
cog_vessel <- cog_vessel %>%
  mutate(cog_stable = sd_lat <= 0.5)  # ~55 km threshold

cat("  Vessels with stable COG (sd_lat ≤ 0.5°):",
    sum(cog_vessel$cog_stable, na.rm = TRUE), "\n")


# =========================================================================
# COG → REGULATORY REGION → days_closed_vy
# =========================================================================
#
# Map each vessel's COG latitude to its regulatory region.
# Veda calendars differ by region and year.
#
# Regulatory zones for sardina-anchoveta vedas (approximate):
#   Regiones V-VIII:  Reproduction veda ~ Aug-Sep; Recruitment ~ Jan-Feb
#   Regiones IX-XIV:  Reproduction veda ~ Aug-Oct; Recruitment ~ Dec-Feb
#   (Exact dates vary by year — from SUBPESCA resolutions)
#
# Jack mackerel: Open year-round (no veda in most years)
#
# Latitude boundaries (approximate):
#   Region V  : -33.4 to -32.2
#   Region VI : -35.0 to -33.4
#   Region VII: -36.4 to -35.0
#   Region VIII: -38.4 to -36.4
#   Region IX:  -39.6 to -38.4
#   Region XIV: -40.4 to -39.6
#   Region X:   -44.0 to -40.4

cog_vessel <- cog_vessel %>%
  mutate(
    reg_zone = case_when(
      cog_lat >= -38.4 ~ "V_VIII",    # Valparaíso to Biobío
      cog_lat <  -38.4 ~ "IX_XIV",    # Araucanía to Los Ríos
      TRUE             ~ NA_character_
    )
  )

cat("\nVessels by regulatory zone:\n")
cog_vessel %>% count(reg_zone) %>% print()

# ---- VEDA CALENDAR FROM SUBPESCA OFFICIAL DOCUMENT ----
#
# Source: SUBPESCA "Vedas en Chile" (articles-100030_documento_.pdf)
#
# Species: "Anchoveta y sardina común" (mixed fishery, same closures)
# Type: Biológica (biological closures for reproduction and recruitment)
# Jack mackerel: NO biological closures (open year-round)
#
# REPRODUCTION VEDAS:
#   Sardina común: Julio-Octubre → Regiones V, VI, VII, VIII, XVI, IX, XIV
#   Anchoveta+Sardina: Agosto-Octubre → Regiones V, VI, VII, VIII, XVI, X, XIV
#   → Conservative: use Aug-Oct (92 days) for reproduction, all CS zones
#   → But sardina adds July in some regions
#
# RECRUITMENT VEDAS:
#   Anchoveta+Sardina: Enero-Febrero → Regiones V, VI, VII
#   Anchoveta+Sardina: Enero-Febrero → Regiones IX y XIV
#   → Both zones: Jan-Feb (59 days)
#
# ZONE DIFFERENCES:
#   V-VIII (lat >= -38.4): Aug-Oct reproduction (92d) + Jan-Feb recruitment (59d) = 151d
#   IX-XIV (lat <  -38.4): Jul-Oct reproduction (123d) + Jan-Feb recruitment (59d) = 182d
#     (sardina común has julio-octubre for IX-XIV; more conservative)
#
# NOTE: These are FIXED CALENDAR periods from the SUBPESCA summary document.
#   Actual closure dates vary annually by resolution (e.g., reproduction may
#   start July 25 or August 5 depending on the year). To introduce year-level
#   variation, collect exact start/end dates from annual SUBPESCA resolutions
#   (Resoluciones Exentas) for each year 2013-2024.
#   URL: https://www.subpesca.cl/portal/619/w3-propertyvalue-50335.html
#
# For now, the cross-sectional variation (V-VIII vs IX-XIV) from the COG
# provides identification. Year-level variation would strengthen this further.

veda_by_zone <- expand_grid(
  year     = 2013:2024,
  reg_zone = c("V_VIII", "IX_XIV")
) %>%
  mutate(
    # Reproduction veda days
    days_repro = case_when(
      reg_zone == "V_VIII" ~ 92L,   # Aug 1 - Oct 31
      reg_zone == "IX_XIV" ~ 123L   # Jul 1 - Oct 31 (sardina común extends to July)
    ),
    # Recruitment veda days (same for both zones)
    days_recruit = 59L,              # Jan 1 - Feb 28 (or 29 in leap years)
    # Total closed days for sardina-anchoveta
    days_closed_vy = days_repro + days_recruit
  )

cat("\nVeda days by zone (from SUBPESCA official calendar):\n")
veda_by_zone %>%
  distinct(reg_zone, days_repro, days_recruit, days_closed_vy) %>%
  print()
cat("  V-VIII: Aug-Oct (92d) + Jan-Feb (59d) = 151 days closed\n")
cat("  IX-XIV: Jul-Oct (123d) + Jan-Feb (59d) = 182 days closed\n")
cat("  Jurel: 0 days closed (open year-round)\n")
cat("\n  [TO DO] Add year-level variation from annual SUBPESCA resolutions.\n")


# =========================================================================
# COG → days_bad_weather_vy
# =========================================================================
#
# For each vessel, count annual days with wind speed above threshold
# at the spatial location closest to its COG.
#
# This requires the daily environmental data (env_dt) with lat/lon.
# Strategy:
#   1. For each vessel COG, find the nearest grid point(s) in env_dt
#   2. Count days per year where wind speed > threshold
#
# Wind threshold: 10 m/s (approx Beaufort 5-6, difficult for purse seine)
# Adjust based on fleet knowledge.

wind_threshold <- 10  # m/s

# env_dt has columns: date, lat, lon, speed_max, sst, chl, ...
# Check structure:
cat("\n====== ENV DATA STRUCTURE ======\n")
cat("Columns:", names(env_dt)[1:10], "\n")

# Get unique grid points from env_dt
env_grid <- env_dt %>%
  distinct(lat, lon) %>%
  filter(!is.na(lat), !is.na(lon))

cat("Environmental grid points:", nrow(env_grid), "\n")

# Function: find nearest grid point to a given COG
find_nearest_grid <- function(target_lat, target_lon, grid_df) {
  dists <- sqrt((grid_df$lat - target_lat)^2 + (grid_df$lon - target_lon)^2)
  idx   <- which.min(dists)
  return(data.frame(grid_lat = grid_df$lat[idx], grid_lon = grid_df$lon[idx]))
}

# Match each vessel to its nearest env grid point
cog_with_grid <- cog_vessel %>%
  rowwise() %>%
  mutate(
    nearest = list(find_nearest_grid(cog_lat, cog_lon, env_grid))
  ) %>%
  unnest(nearest) %>%
  ungroup()

# Count bad weather days per grid point per year
bad_weather_grid <- env_dt %>%
  mutate(year = year(date)) %>%
  filter(year >= 2013, year <= 2024) %>%
  group_by(lat, lon, year) %>%
  summarise(
    days_bad_weather = sum(speed_max > wind_threshold, na.rm = TRUE),
    days_total       = n(),
    .groups = "drop"
  )

# Merge: vessel → nearest grid → bad weather count
days_bad_weather_vy <- cog_with_grid %>%
  select(COD_BARCO, grid_lat, grid_lon) %>%
  left_join(
    bad_weather_grid,
    by = c("grid_lat" = "lat", "grid_lon" = "lon")
  ) %>%
  select(COD_BARCO, year, days_bad_weather)

cat("\ndays_bad_weather_vy:\n")
cat("  Vessel-years:", nrow(days_bad_weather_vy), "\n")
cat("  Bad weather days summary:\n")
summary(days_bad_weather_vy$days_bad_weather)


# =========================================================================
# UPDATED MERGE (replaces Section 11)
# =========================================================================

poisson_df <- trips_vy %>%
  left_join(vessel_chars,     by = "COD_BARCO") %>%
  left_join(harvest_vy_wide,  by = c("COD_BARCO", "year")) %>%
  left_join(halloc,           by = c("COD_BARCO", "year")) %>%
  left_join(prices_wide,      by = "year") %>%
  left_join(cog_vessel %>% select(COD_BARCO, cog_lat, cog_lon, reg_zone),
            by = "COD_BARCO") %>%
  left_join(days_bad_weather_vy, by = c("COD_BARCO", "year")) %>%
  left_join(veda_by_zone,        by = c("year", "reg_zone")) %>%
  mutate(across(starts_with("H_"), ~replace_na(., 0))) %>%
  filter(year >= 2013)

cat("\n====== FINAL DATASET ======\n")
cat("Vessel-years:", nrow(poisson_df), "\n")

cat("\nVariable availability (% non-missing):\n")
poisson_df %>%
  summarise(across(
    c(T_vy, log_bodega, H_alloc_vy,
      price_jurel, price_sardina, price_anchov,
      days_bad_weather, days_closed_vy),
    ~round(100 * mean(!is.na(.)), 1)
  )) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "pct_nonmissing") %>%
  print()


# =========================================================================
# UPDATED ESTIMATION
# =========================================================================

library(MASS)
library(sandwich)
library(lmtest)

df_ind <- poisson_df %>% filter(TIPO_FLOTA == "IND")
df_art <- poisson_df %>% filter(TIPO_FLOTA == "ART")

# --- Industrial fleet ---
nb_ind <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB,
  data = df_ind
)

# --- Artisanal fleet ---
nb_art <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB,
  data = df_art
)

# Robust SEs clustered by vessel
se_ind <- coeftest(nb_ind,
                   vcov = vcovCL(nb_ind, cluster = df_ind$COD_BARCO))
se_art <- coeftest(nb_art,
                   vcov = vcovCL(nb_art, cluster = df_art$COD_BARCO))

cat("\n====== INDUSTRIAL ======\n")
print(se_ind)
cat("\n====== ARTISANAL ======\n")
print(se_art)

# Overdispersion test: NB vs Poisson
cat("\nOverdispersion (theta):\n")
cat("  Industrial:", nb_ind$theta, "(SE:", nb_ind$SE.theta, ")\n")
cat("  Artisanal: ", nb_art$theta, "(SE:", nb_art$SE.theta, ")\n")
cat("  Small theta = high overdispersion → NB preferred over Poisson\n")


# =========================================================================
# SAVE FINAL DATASET
# =========================================================================

dir.create("data/trips", showWarnings = FALSE, recursive = TRUE)
saveRDS(poisson_df, file = "data/trips/poisson_dt.rds")
cat("\n✓ Saved: data/trips/poisson_dt.rds\n")
cat("  Rows:", nrow(poisson_df), "\n")
cat("  Cols:", paste(names(poisson_df), collapse = ", "), "\n")
