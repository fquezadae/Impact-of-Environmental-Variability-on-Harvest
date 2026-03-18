###------------------------------------------------------###
###         Annual Fishing Trips: Poisson/NB Model        ###
###  Following Kasperski (2015), equation U_vy            ###
###------------------------------------------------------###
#
# OUTPUT: data/trips/poisson_dt.rds
#
# Specification:
#   T_vy ~ log_bodega + H_alloc_vy +
#          price_jurel + price_sardina + price_anchov +
#          days_bad_weather + days_closed_vy + TIPO_EMB
#
# Data status:
#   [x] Trips T_vy             : logbooks
#   [x] Vessel chars Z_v       : logbooks
#   [x] Harvest shares omega_vs: logbooks
#   [x] H_alloc_vy             : shares × lagged TAC proxy
#   [x] Ex-vessel prices       : IFOP survey (PRECIO), deflated approx IPC
#   [x] COG per vessel         : catch-weighted centroid from hauls
#   [x] days_bad_weather_vy    : wind > 10 m/s at nearest grid to COG
#   [x] days_closed_vy         : SUBPESCA veda calendar × COG reg zone
#   [ ] Diesel price           : Banco Central — PENDING
#   [ ] Official TAC_sy        : SUBPESCA — PENDING (using lagged proxy)
#   [ ] Year-varying vedas     : SUBPESCA resolutions — PENDING

rm(list = ls())
gc()

library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)

# ---- Directory setup ----
usuario <- Sys.info()[["user"]]
if (usuario == "felip") {
  dirdata <- "C:/Users/felip/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "FACEA") {
  dirdata <- "C:/Users/FACEA/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "Felipe") {
  dirdata <- "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else {
  stop("Usuario no reconocido.")
}
rm(usuario)


# =========================================================================
# 1. LOGBOOKS
# =========================================================================

logbooks <- readRDS("data/logbooks/logbooks.rds")

spf_codes          <- c(26, 33, 114)        # JUREL, SARDINA COMUN, ANCHOVETA
cs_regions_logbooks <- c(5, 6, 7, 8, 9, 10, 14, 16)

log_spf <- logbooks %>%
  filter(REGION %in% cs_regions_logbooks,
         COD_ESPECIE %in% spf_codes) %>%
  arrange(COD_BARCO, FECHA_HORA_ZARPE, FECHA_LANCE) %>%
  group_by(COD_BARCO) %>%
  mutate(
    new_trip = case_when(
      NUMERO_LANCE_EX == 1                      ~ 1L,
      is.na(lag(FECHA_HORA_ZARPE))              ~ 1L,
      FECHA_HORA_ZARPE != lag(FECHA_HORA_ZARPE) ~ 1L,
      TRUE                                      ~ 0L
    ),
    trip_seq = cumsum(new_trip)
  ) %>%
  ungroup() %>%
  mutate(trip_id = paste(COD_BARCO, trip_seq, sep = "_"))

rm(logbooks)  # free memory


# =========================================================================
# 2. TRIPS PER VESSEL-YEAR (T_vy)
# =========================================================================

trips_vy <- log_spf %>%
  distinct(COD_BARCO, year, trip_id) %>%
  count(COD_BARCO, year, name = "T_vy")

cat("Trips: ", nrow(trips_vy), " vessel-years,",
    n_distinct(trips_vy$COD_BARCO), "vessels,",
    paste(range(trips_vy$year), collapse = "-"), "\n")


# =========================================================================
# 3. VESSEL CHARACTERISTICS (Z_v) — time-invariant
# =========================================================================

Mode <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_character_)
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

vessel_chars <- log_spf %>%
  mutate(
    TIPO_EMB_clean   = if_else(TIPO_EMB %in% c("1", "2", "3"), NA_character_, TIPO_EMB),
    CAPACIDAD_BODEGA = if_else(CAPACIDAD_BODEGA <= 0, NA_real_, CAPACIDAD_BODEGA)
  ) %>%
  group_by(COD_BARCO) %>%
  summarise(
    TIPO_FLOTA       = Mode(TIPO_FLOTA),
    TIPO_EMB         = Mode(TIPO_EMB_clean),
    CAPACIDAD_BODEGA = median(CAPACIDAD_BODEGA, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(TIPO_EMB = replace_na(TIPO_EMB, "UNK")) %>%
  # Impute missing bodega: TIPO_EMB median → TIPO_FLOTA median
  group_by(TIPO_EMB) %>%
  mutate(CAPACIDAD_BODEGA = if_else(is.na(CAPACIDAD_BODEGA),
                                    median(CAPACIDAD_BODEGA, na.rm = TRUE),
                                    CAPACIDAD_BODEGA)) %>%
  group_by(TIPO_FLOTA) %>%
  mutate(CAPACIDAD_BODEGA = if_else(is.na(CAPACIDAD_BODEGA),
                                    median(CAPACIDAD_BODEGA, na.rm = TRUE),
                                    CAPACIDAD_BODEGA)) %>%
  ungroup() %>%
  mutate(log_bodega = log(CAPACIDAD_BODEGA))


# =========================================================================
# 4. HARVEST PER VESSEL-YEAR-SPECIES (H_vys)
# =========================================================================

harvest_vys <- log_spf %>%
  filter(COD_ESPECIE %in% spf_codes) %>%
  group_by(COD_BARCO, year, COD_ESPECIE) %>%
  summarise(H_vys = sum(CAPTURA_RETENIDA, na.rm = TRUE) / 1000,
            .groups = "drop")

harvest_vy_wide <- harvest_vys %>%
  pivot_wider(names_from = COD_ESPECIE, values_from = H_vys,
              names_prefix = "H_", values_fill = 0)


# =========================================================================
# 5. VESSEL SHARES omega_vs (time-invariant, full sample)
# =========================================================================

vessel_total_vs <- harvest_vys %>%
  group_by(COD_BARCO, COD_ESPECIE) %>%
  summarise(total_H_vs = sum(H_vys, na.rm = TRUE), .groups = "drop")

fleet_total_s <- harvest_vys %>%
  group_by(COD_ESPECIE) %>%
  summarise(fleet_total_s = sum(H_vys, na.rm = TRUE), .groups = "drop")

shares_vs <- vessel_total_vs %>%
  left_join(fleet_total_s, by = "COD_ESPECIE") %>%
  mutate(omega_vs = total_H_vs / fleet_total_s) %>%
  select(COD_BARCO, COD_ESPECIE, omega_vs)

cat("omega_vs sums by species (should ≈ 1.0):\n")
shares_vs %>%
  group_by(COD_ESPECIE) %>%
  summarise(sum_omega = round(sum(omega_vs), 4)) %>%
  print()

rm(vessel_total_vs, fleet_total_s)


# =========================================================================
# 6. ALLOCATED HARVEST: H_alloc_vy = omega_vs × TAC_{s,y-1}
# =========================================================================
# Using lagged aggregate harvest as TAC proxy (predetermined).
# Replace with official SUBPESCA TAC when available.

tac_lagged <- harvest_vys %>%
  group_by(year, COD_ESPECIE) %>%
  summarise(TAC_sy = sum(H_vys, na.rm = TRUE), .groups = "drop") %>%
  arrange(COD_ESPECIE, year) %>%
  group_by(COD_ESPECIE) %>%
  mutate(TAC_sy_lag = lag(TAC_sy)) %>%
  ungroup() %>%
  filter(!is.na(TAC_sy_lag)) %>%
  select(year, COD_ESPECIE, TAC_sy_lag)

halloc <- shares_vs %>%
  left_join(tac_lagged, by = "COD_ESPECIE", relationship = "many-to-many") %>%
  mutate(H_alloc_vys = omega_vs * TAC_sy_lag) %>%
  group_by(COD_BARCO, year) %>%
  summarise(H_alloc_vy = sum(H_alloc_vys, na.rm = TRUE), .groups = "drop")

cat("H_alloc_vy: using lagged TAC proxy. First year:", min(tac_lagged$year), "\n")

rm(tac_lagged)


# =========================================================================
# 7. EX-VESSEL PRICES — deflated to real pesos (base 2018)
# =========================================================================
# Source: IFOP manufacturing survey, PRECIO sheet
# TIPO_MP = 1: fresh resource (ex-vessel price)

prices_raw <- read_excel(
  paste0(dirdata, "IFOP/2025.04.21.pelagicos_proceso-precios.mp.2012-2024.xlsx"),
  sheet = "PRECIO"
)

cs_regions_prices <- c(5, 8, 9, 10, 14, 16)

# Peak fishing months by species (following Dresdner 2013)
peak_months <- list(
  "SARDINA COMUN" = c(3L, 4L, 5L, 6L, 11L, 12L),
  "ANCHOVETA"     = c(3L, 4L, 5L, 6L, 11L, 12L),
  "JUREL"         = 1L:12L
)

prices_cs <- prices_raw %>%
  filter(RG %in% cs_regions_prices, TIPO_MP == 1,
         NM_RECURSO %in% names(peak_months),
         !is.na(PRECIO), PRECIO > 0) %>%
  filter(
    (NM_RECURSO == "SARDINA COMUN" & MES %in% peak_months[["SARDINA COMUN"]]) |
    (NM_RECURSO == "ANCHOVETA"     & MES %in% peak_months[["ANCHOVETA"]])     |
    (NM_RECURSO == "JUREL"         & MES %in% peak_months[["JUREL"]])
  ) %>%
  rename(year = ANIO, price_nominal = PRECIO)

rm(prices_raw)

# Annual average (simple mean across plants × months)
prices_sy_nominal <- prices_cs %>%
  group_by(year, NM_RECURSO) %>%
  summarise(price_nominal = mean(price_nominal, na.rm = TRUE),
            n_obs = n(), .groups = "drop")

# Deflate with approximate IPC (replace with official Banco Central series)
ipc_approx <- tibble(
  year = 2012:2024,
  ipc  = c(100.0, 101.8, 106.3, 110.7, 114.6, 117.1,
           119.9, 123.3, 127.0, 131.7, 143.5, 153.8, 160.7)
)
base_year <- 2018
base_ipc  <- ipc_approx$ipc[ipc_approx$year == base_year]

prices_wide <- prices_sy_nominal %>%
  left_join(ipc_approx, by = "year") %>%
  mutate(price_real = price_nominal * (base_ipc / ipc)) %>%
  select(year, NM_RECURSO, price_real) %>%
  pivot_wider(names_from = NM_RECURSO, values_from = price_real) %>%
  rename(price_jurel = JUREL, price_sardina = `SARDINA COMUN`,
         price_anchov = ANCHOVETA) %>%
  mutate(year = as.integer(year))

cat("Prices: deflated to", base_year, "pesos (approx IPC).\n")
cat("  Jurel coverage:", sum(!is.na(prices_wide$price_jurel)), "of",
    nrow(prices_wide), "years\n")

rm(prices_cs, prices_sy_nominal, ipc_approx)


# =========================================================================
# 8. COG: CENTER OF GRAVITY PER VESSEL
# =========================================================================
# Catch-weighted centroid over full sample — time-invariant.
# sd_lat diagnostic flags vessels with unstable fishing locations.

cog_vessel <- log_spf %>%
  filter(!is.na(LATITUD), !is.na(LONGITUD),
         !is.na(CAPTURA_RETENIDA), CAPTURA_RETENIDA > 0) %>%
  group_by(COD_BARCO) %>%
  summarise(
    cog_lat = weighted.mean(LATITUD,  w = CAPTURA_RETENIDA),
    cog_lon = weighted.mean(LONGITUD, w = CAPTURA_RETENIDA),
    n_hauls = n(),
    sd_lat  = sd(LATITUD),
    .groups = "drop"
  ) %>%
  mutate(cog_stable = sd_lat <= 0.5)   # ~55 km threshold

cat("\nCOG: ", nrow(cog_vessel), "vessels.",
    sum(cog_vessel$cog_stable, na.rm = TRUE), "with stable range (sd_lat ≤ 0.5°)\n")


# =========================================================================
# 9. COG → REGULATORY ZONE → days_closed_vy
# =========================================================================
# Source: SUBPESCA "Vedas en Chile" (articles-100030_documento_.pdf)
# Anchoveta + sardina común: biological closures by zone
# Jack mackerel: open year-round (no biological closures)
#
# V-VIII  (lat ≥ -38.4°): Aug-Oct (92d) + Jan-Feb (59d) = 151d
# IX-XIV  (lat < -38.4°): Jul-Oct (123d) + Jan-Feb (59d) = 182d
#
# NOTE: These are fixed calendar periods. Replace with exact dates
# from annual SUBPESCA resolutions for year-level variation.

cog_vessel <- cog_vessel %>%
  mutate(reg_zone = if_else(cog_lat >= -38.4, "V_VIII", "IX_XIV"))

cat("Vessels by regulatory zone:\n")
cog_vessel %>% count(reg_zone) %>% print()

veda_by_zone <- expand_grid(
  year     = 2013:2024,
  reg_zone = c("V_VIII", "IX_XIV")
) %>%
  mutate(
    days_closed_vy = case_when(
      reg_zone == "V_VIII" ~ 151L,   # Aug-Oct (92) + Jan-Feb (59)
      reg_zone == "IX_XIV" ~ 182L    # Jul-Oct (123) + Jan-Feb (59)
    )
  )


# =========================================================================
# 10. COG → days_bad_weather_vy
# =========================================================================
# Wind speed > 10 m/s at nearest grid point to vessel COG.
# Threshold ≈ Beaufort 5-6, difficult conditions for purse seine.

env_dt <- readRDS(paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"))

wind_threshold <- 10  # m/s

# Unique env grid points
env_grid <- env_dt %>%
  distinct(lat, lon) %>%
  filter(!is.na(lat), !is.na(lon))

# Match each vessel COG to nearest grid point
find_nearest_grid <- function(target_lat, target_lon, grid_df) {
  dists <- sqrt((grid_df$lat - target_lat)^2 + (grid_df$lon - target_lon)^2)
  idx   <- which.min(dists)
  data.frame(grid_lat = grid_df$lat[idx], grid_lon = grid_df$lon[idx])
}

cog_with_grid <- cog_vessel %>%
  rowwise() %>%
  mutate(nearest = list(find_nearest_grid(cog_lat, cog_lon, env_grid))) %>%
  unnest(nearest) %>%
  ungroup()

# Count bad weather days per grid point per year
bad_weather_grid <- env_dt %>%
  mutate(year = year(date)) %>%
  filter(year >= 2013, year <= 2024) %>%
  group_by(lat, lon, year) %>%
  summarise(days_bad_weather = sum(speed_max > wind_threshold, na.rm = TRUE),
            .groups = "drop")

days_bad_weather_vy <- cog_with_grid %>%
  select(COD_BARCO, grid_lat, grid_lon) %>%
  left_join(bad_weather_grid,
            by = c("grid_lat" = "lat", "grid_lon" = "lon")) %>%
  select(COD_BARCO, year, days_bad_weather)

cat("Bad weather days: ", nrow(days_bad_weather_vy), "vessel-years\n")
cat("  Mean:", round(mean(days_bad_weather_vy$days_bad_weather, na.rm = TRUE), 1),
    " Median:", median(days_bad_weather_vy$days_bad_weather, na.rm = TRUE), "\n")

rm(env_dt, env_grid, bad_weather_grid, cog_with_grid)


# =========================================================================
# 11. MERGE ALL COMPONENTS
# =========================================================================

poisson_df <- trips_vy %>%
  left_join(vessel_chars,     by = "COD_BARCO") %>%
  left_join(harvest_vy_wide,  by = c("COD_BARCO", "year")) %>%
  left_join(halloc,           by = c("COD_BARCO", "year")) %>%
  left_join(prices_wide,      by = "year") %>%
  left_join(cog_vessel %>% select(COD_BARCO, cog_lat, cog_lon, reg_zone, cog_stable),
            by = "COD_BARCO") %>%
  left_join(days_bad_weather_vy, by = c("COD_BARCO", "year")) %>%
  left_join(veda_by_zone,        by = c("year", "reg_zone")) %>%
  mutate(across(starts_with("H_"), ~replace_na(., 0))) %>%
  filter(year >= 2013)

cat("\n====== FINAL DATASET ======\n")
cat("Vessel-years:", nrow(poisson_df), "\n")
poisson_df %>%
  group_by(TIPO_FLOTA) %>%
  summarise(n_vy = n(), n_v = n_distinct(COD_BARCO),
            mean_T = round(mean(T_vy), 1), .groups = "drop") %>%
  print()

cat("\nVariable availability (% non-missing):\n")
poisson_df %>%
  summarise(across(
    c(T_vy, log_bodega, H_alloc_vy,
      price_jurel, price_sardina, price_anchov,
      days_bad_weather, days_closed_vy),
    ~round(100 * mean(!is.na(.)), 1)
  )) %>%
  pivot_longer(everything(), names_to = "var", values_to = "pct") %>%
  print()

# Overdispersion diagnostic
cat("\nOverdispersion (var/mean ratio of T_vy):\n")
poisson_df %>%
  group_by(TIPO_FLOTA) %>%
  summarise(mean = round(mean(T_vy), 1),
            var  = round(var(T_vy), 1),
            ratio = round(var(T_vy) / mean(T_vy), 1),
            .groups = "drop") %>%
  print()

# Save
dir.create("data/trips", showWarnings = FALSE, recursive = TRUE)
saveRDS(poisson_df, file = "data/trips/poisson_dt.rds")
cat("\n✓ Saved: data/trips/poisson_dt.rds\n")


# =========================================================================
# 12. ESTIMATION: Negative Binomial, separate by fleet
# =========================================================================

library(MASS)
library(sandwich)
library(lmtest)

df_ind <- poisson_df %>% filter(TIPO_FLOTA == "IND")
df_art <- poisson_df %>% filter(TIPO_FLOTA == "ART")

nb_ind <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB,
  data = df_ind
)

nb_art <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB,
  data = df_art
)

# Robust SEs clustered by vessel
se_ind <- coeftest(nb_ind, vcov = vcovCL(nb_ind, cluster = df_ind$COD_BARCO))
se_art <- coeftest(nb_art, vcov = vcovCL(nb_art, cluster = df_art$COD_BARCO))

cat("\n====== INDUSTRIAL ======\n")
print(se_ind)
cat("\n====== ARTISANAL ======\n")
print(se_art)

cat("\nTheta (small = high overdispersion → NB preferred):\n")
cat("  IND:", round(nb_ind$theta, 2), "(SE:", round(nb_ind$SE.theta, 2), ")\n")
cat("  ART:", round(nb_art$theta, 2), "(SE:", round(nb_art$SE.theta, 2), ")\n")

# LR test: NB vs Poisson
pois_ind <- glm(T_vy ~ log_bodega + H_alloc_vy +
                  price_jurel + price_sardina + price_anchov +
                  days_bad_weather + days_closed_vy + TIPO_EMB,
                family = poisson, data = df_ind)
pois_art <- glm(T_vy ~ log_bodega + H_alloc_vy +
                  price_jurel + price_sardina + price_anchov +
                  days_bad_weather + days_closed_vy + TIPO_EMB,
                family = poisson, data = df_art)

lr_ind <- 2 * (logLik(nb_ind) - logLik(pois_ind))
lr_art <- 2 * (logLik(nb_art) - logLik(pois_art))

cat("\nLR test NB vs Poisson (chi2, 1 df):\n")
cat("  IND:", round(as.numeric(lr_ind), 1),
    "p =", format.pval(pchisq(as.numeric(lr_ind), 1, lower.tail = FALSE)), "\n")
cat("  ART:", round(as.numeric(lr_art), 1),
    "p =", format.pval(pchisq(as.numeric(lr_art), 1, lower.tail = FALSE)), "\n")
