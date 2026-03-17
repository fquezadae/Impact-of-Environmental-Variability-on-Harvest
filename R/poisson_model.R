###------------------------------------------------------###
###         Annual Fishing Trips: Data Preparation        ###
###  Builds poisson_dt.rds for Poisson/NB estimation     ###
###  Following Kasperski (2015), equation U_vy           ###
###------------------------------------------------------###
#
# OUTPUT: data/trips/poisson_dt.rds
#
# Variables included when all sources available:
#   T_vy          : annual trips per vessel-year (dependent variable)
#   CAPACIDAD_BODEGA, TIPO_EMB : vessel characteristics (Z_v)
#   H_alloc_vy    : vessel-level allocated harvest (omega_vs * TAC_sy)
#   price_*       : ex-vessel price by species, annual avg over peak months
#   sst_c, chl_c  : environmental conditions (centered)
#   days_closed_sa: regulatory closure days, sardina+anchoveta
#   [diesel_price]: input price — PENDING (Banco Central)
#   [TAC_sy]      : official TAC by species-year — PENDING (SUBPESCA)
#
# Data availability status (update as sources are loaded):
#   [x] Trips T_vy          : logbooks
#   [x] Vessel chars Z_v    : logbooks
#   [x] Harvest H_vys       : logbooks
#   [x] Ex-vessel prices    : IFOP manufacturing survey (PRECIO sheet)
#   [x] Environmental vars  : Copernicus (already in manuscript)
#   [ ] Diesel price        : Banco Central — PENDING
#   [ ] TAC_sy              : SUBPESCA resoluciones — PENDING
#   [ ] Veda days           : SUBPESCA resoluciones — PENDING

rm(list = ls())
gc()

library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)

# ---- Directory setup (same convention as manuscript.rmd) ----

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
# 1. LOGBOOKS: Load raw data
# =========================================================================

logbooks <- readRDS("data/logbooks/logbooks.rds")

# SPF species codes in logbooks
# Confirm: table(logbooks$COD_ESPECIE, logbooks$NOMBRE_ESPECIE)
spf_codes <- c(26, 33, 114)   # JUREL=26, SARDINA COMUN=33, ANCHOVETA=114

# CS regions
cs_regions_logbooks <- c(5, 6, 7, 8, 9, 10, 14, 16)


# =========================================================================
# 2. TRIPS PER VESSEL-YEAR (T_vy)
# =========================================================================
# A trip = unique combination of (COD_BARCO, FECHA_HORA_ZARPE)
# NUMERO_LANCE_EX == 1 flags the first haul of a trip

log_spf <- logbooks %>%
  filter(
    REGION %in% cs_regions_logbooks,
    COD_ESPECIE %in% spf_codes
  ) %>%
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

trips_vy <- log_spf %>%
  distinct(COD_BARCO, year, trip_id) %>%
  count(COD_BARCO, year, name = "T_vy")

cat("Trips summary:\n")
cat("  Vessel-year observations:", nrow(trips_vy), "\n")
cat("  Year range:", range(trips_vy$year), "\n")
cat("  Vessels:", n_distinct(trips_vy$COD_BARCO), "\n")


# =========================================================================
# 3. VESSEL CHARACTERISTICS (Z_v)
# Time-invariant: modal fleet/vessel type, median hold capacity
# CAPACIDAD_BODEGA = 0 treated as missing (no vessel has zero hold)
# Imputation hierarchy: (1) vessel median, (2) TIPO_EMB median, (3) TIPO_FLOTA median
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
  # Impute remaining missing by TIPO_EMB median, then TIPO_FLOTA median
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

cat("Vessel characteristics:\n")
vessel_chars %>%
  group_by(TIPO_FLOTA) %>%
  summarise(n         = n(),
            med_bodega = median(CAPACIDAD_BODEGA),
            max_bodega = max(CAPACIDAD_BODEGA),
            n_missing  = sum(is.na(CAPACIDAD_BODEGA)),
            .groups = "drop") %>%
  print()


# =========================================================================
# 4. HARVEST PER VESSEL-YEAR-SPECIES (H_vys)
# =========================================================================

harvest_vys <- log_spf %>%
  filter(COD_ESPECIE %in% spf_codes) %>%
  group_by(COD_BARCO, year, COD_ESPECIE) %>%
  summarise(
    H_vys = sum(CAPTURA_RETENIDA, na.rm = TRUE) / 1000,
    .groups = "drop"
  )

harvest_vy_wide <- harvest_vys %>%
  pivot_wider(
    names_from   = COD_ESPECIE,
    values_from  = H_vys,
    names_prefix = "H_",
    values_fill  = 0
  )

cat("Harvest wide — columnas:", names(harvest_vy_wide), "\n")
cat("Filas:", nrow(harvest_vy_wide), "\n")
cat("Zeros por especie:\n")
harvest_vy_wide %>%
  summarise(across(starts_with("H_"), ~sum(. == 0))) %>%
  print()


# =========================================================================
# 5. VESSEL SHARES omega_vs
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

cat("\nomega_vs check (debe sumar ~1.0 por especie):\n")
shares_vs %>%
  group_by(COD_ESPECIE) %>%
  summarise(sum_omega = round(sum(omega_vs, na.rm = TRUE), 4)) %>%
  print()

# =========================================================================
# 6. ALLOCATED HARVEST H_alloc_vy  [PARTIAL — TAC PENDING]
# H_alloc_vys = omega_vs * TAC_sy
# Aggregated across species: H_alloc_vy = sum_s(H_alloc_vys)
#
# PENDING: Replace tac_proxy with official SUBPESCA TAC data.
# Format needed:
#   tac_sy: data.frame with columns year, COD_ESPECIE, TAC_sy (tons)
#   Source: SUBPESCA anuarios or resoluciones de cuota global
#   URL: https://www.subpesca.cl/portal/619/w3-propertyvalue-50335.html
# =========================================================================

# PLACEHOLDER: aggregate observed harvest as TAC proxy
# Valid under binding TAC assumption (total harvest ≈ quota)
tac_proxy <- harvest_vys %>%
  group_by(year, COD_ESPECIE) %>%
  summarise(TAC_sy = sum(H_vys, na.rm = TRUE), .groups = "drop")


cat("\n[PLACEHOLDER] TAC_sy: using aggregate fleet harvest as proxy.",
    "\nReplace with official SUBPESCA TAC when available.\n")

# Compute H_alloc_vy
halloc <- shares_vs %>%
  left_join(tac_proxy, by = "COD_ESPECIE", relationship = "many-to-many") %>%
  mutate(H_alloc_vys = omega_vs * TAC_sy) %>%
  group_by(COD_BARCO, year) %>%
  summarise(
    H_alloc_vy = sum(H_alloc_vys, na.rm = TRUE),
    .groups = "drop"
  )

cat("H_alloc_vy:\n")
cat("  Filas:", nrow(halloc), "\n")
summary(halloc$H_alloc_vy)




# =========================================================================
# 7. EX-VESSEL PRICES (p_sy) — IFOP Manufacturing Survey
# PRECIO sheet: price paid by plant to fishers (pesos/ton, fresh resource)
# TIPO_MP = 1: fresh resource (ex-vessel) — only this
# =========================================================================

prices_raw <- read_excel(
  paste0(dirdata, "IFOP/2025.04.21.pelagicos_proceso-precios.mp.2012-2024.xlsx"),
  sheet = "PRECIO"
)

cs_regions_prices <- c(5, 8, 9, 10, 14, 16)

peak_months <- list(
  "SARDINA COMUN" = c(3L, 4L, 5L, 6L, 11L, 12L),
  "ANCHOVETA"     = c(3L, 4L, 5L, 6L, 11L, 12L),
  "JUREL"         = 1L:12L
)

prices_cs <- prices_raw %>%
  filter(
    RG         %in% cs_regions_prices,
    TIPO_MP    == 1,
    NM_RECURSO %in% names(peak_months),
    !is.na(PRECIO), PRECIO > 0
  ) %>%
  filter(
    (NM_RECURSO == "SARDINA COMUN" & MES %in% peak_months[["SARDINA COMUN"]]) |
      (NM_RECURSO == "ANCHOVETA"     & MES %in% peak_months[["ANCHOVETA"]])     |
      (NM_RECURSO == "JUREL"         & MES %in% peak_months[["JUREL"]])
  ) %>%
  rename(year = ANIO, price_nominal = PRECIO)

# Diagnóstico: cobertura por especie-año
cat("Obs por especie-año (CS + peak months + TIPO_MP=1):\n")
prices_cs %>%
  count(year, NM_RECURSO) %>%
  pivot_wider(names_from = NM_RECURSO, values_from = n, values_fill = 0) %>%
  print(n = 15)


# Annual average price per species (simple mean across plants and months)
# NOTE: switch to quantity-weighted mean if you merge with PROCESO volumes
prices_sy_nominal <- prices_cs %>%
  group_by(year, NM_RECURSO) %>%
  summarise(
    price_nominal = mean(price_nominal, na.rm = TRUE),
    n_plants      = n_distinct(NUI),
    n_obs         = n(),
    .groups = "drop"
  )

# ---- Deflate to real prices ----
# Source: Banco Central, IPC serie anual
# Download: https://si3.bcentral.cl -> Estadísticas -> Precios -> IPC
# Format: ipc_y with columns year (int) and ipc (index, e.g. 2013=100)
#
# ipc_y <- read_excel(paste0(dirdata, "BancoCentral/ipc_anual.xlsx")) %>%
#   rename(year = año, ipc = ipc_index) %>%
#   mutate(year = as.integer(year))
# base_year <- 2013
# base_ipc  <- ipc_y$ipc[ipc_y$year == base_year]
# prices_sy <- prices_sy_nominal %>%
#   left_join(ipc_y, by = "year") %>%
#   mutate(price_real = price_nominal * (base_ipc / ipc)) %>%
#   select(year, NM_RECURSO, price_real, n_plants, n_obs)

# PLACEHOLDER: use nominal prices until IPC is loaded
prices_sy <- prices_sy_nominal %>%
  mutate(price_real = price_nominal)


cat("\n[NOTE] Prices are nominal (pesos/ton).",
    "Deflate with IPC once available.\n")

# Wide format for model merge
prices_wide <- prices_sy %>%
  select(year, NM_RECURSO, price_nominal) %>%
  pivot_wider(
    names_from  = NM_RECURSO,
    values_from = price_nominal
  ) %>%
  rename(
    price_jurel   = JUREL,
    price_sardina = `SARDINA COMUN`,
    price_anchov  = ANCHOVETA
  ) %>%
  mutate(year = as.integer(year))

cat("Precios nominales anuales (pesos/ton):\n")
print(prices_wide, n = 15)


# Diagnóstico: variación relativa entre especies
cat("\nRatio precio sardina/anchoveta (debería ser ~1, pesquería mixta):\n")
prices_wide %>%
  mutate(ratio_sa = round(price_sardina / price_anchov, 2)) %>%
  select(year, price_sardina, price_anchov, ratio_sa) %>%
  print(n = 15)


# =========================================================================
# 8. ENVIRONMENTAL VARIABLES (Env_y)
# Annual averages, centered — same convention as SUR biomass model
# Requires env_dt and env_dt_00_11 objects from manuscript
# =========================================================================
env_dt       <- readRDS(paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"))
env_dt_00_11 <- readRDS(paste0(dirdata, "Environmental/env/2000-2011/EnvCoastDaily_2000_2011_0.25deg.rds"))

env_annual <- bind_rows(env_dt_00_11, env_dt) %>%
  mutate(year = year(date)) %>%
  group_by(year) %>%
  summarise(
    sst_mean  = mean(sst,       na.rm = TRUE),
    chl_mean  = mean(chl,       na.rm = TRUE),
    wind_mean = mean(speed_max, na.rm = TRUE),
    .groups   = "drop"
  ) %>%
  mutate(
    sst_c  = sst_mean  - mean(sst_mean,  na.rm = TRUE),
    chl_c  = chl_mean  - mean(chl_mean,  na.rm = TRUE),
    wind_c = wind_mean - mean(wind_mean, na.rm = TRUE)
  )


# =========================================================================
# 9. VEDA DAYS (fixed calendar from SUBPESCA)
# =========================================================================

veda_fixed <- tibble(
  year           = 2012L:2024L,
  days_closed_sa = 151L   # Ago-Oct (92) + Ene-Feb (59)
)

# =========================================================================
# 10. DIESEL PRICE (w_y)  [PENDING]
# Source: Banco Central de Chile
# URL: https://si3.bcentral.cl -> Estadísticas -> Precios -> Combustibles
# Serie: Precio del petróleo diesel (CLP/litro o USD/barril)
# Deflate to real terms using same IPC base year as prices
#
# diesel_y <- read_excel(paste0(dirdata, "BancoCentral/diesel_price.xlsx")) %>%
#   rename(year = año, diesel_price_nominal = precio_diesel) %>%
#   left_join(ipc_y, by = "year") %>%
#   mutate(diesel_price_real = diesel_price_nominal * (base_ipc / ipc)) %>%
#   select(year, diesel_price_real)
# =========================================================================

cat("\n[PENDING] Diesel price: download from Banco Central combustibles series.\n")
diesel_y <- tibble(year = integer(), diesel_price_real = double())




# =========================================================================
# DÍAS DE MAL CLIMA (wind threshold = 10 m/s)
# Agregado anual: promedio entre puntos espaciales del área CS
# =========================================================================


# Bounding box: zona de pesca efectiva CS (p05-p95 de lances)
lat_min_cs <- -40.8
lat_max_cs <- -33.6
lon_min_cs <- -78.4
lon_max_cs <- -72.2

# ¿Qué puertos de zarpe hay y cuántos viajes por puerto?
log_spf %>%
  group_by(PUERTO_ZARPE) %>%
  summarise(
    n_trips   = n_distinct(trip_id),
    n_vessels = n_distinct(COD_BARCO),
    .groups   = "drop"
  ) %>%
  arrange(desc(n_trips)) %>%
  print(n = 20)


# =========================================================================
# 11. MERGE ALL COMPONENTS INTO FINAL DATASET
# =========================================================================

poisson_df <- trips_vy %>%
  left_join(vessel_chars,                                       by = "COD_BARCO") %>%
  left_join(harvest_vy_wide,                                    by = c("COD_BARCO", "year")) %>%
  left_join(halloc,                                             by = c("COD_BARCO", "year")) %>%
  left_join(prices_wide,                                        by = "year") %>%
  left_join(env_annual %>% select(year, sst_c, chl_c, wind_c), by = "year") %>%
  left_join(veda_fixed,                                         by = "year") %>%
  mutate(across(starts_with("H_"), ~replace_na(., 0)))

poisson_df <- poisson_df %>%
  filter(year >= 2013)

cat("Vessel-years 2013-2024:", nrow(poisson_df), "\n")

poisson_df %>%
  group_by(TIPO_FLOTA) %>%
  summarise(
    n_vessel_years = n(),
    n_vessels      = n_distinct(COD_BARCO),
    mean_trips     = round(mean(T_vy), 1),
    .groups        = "drop"
  ) %>%
  print()

cat("\nVariable availability (% non-missing):\n")
poisson_df %>%
  summarise(across(
    c(T_vy, log_bodega, H_alloc_vy,
      price_jurel, price_sardina, price_anchov,
      sst_c, chl_c, days_closed_sa),
    ~round(100 * mean(!is.na(.)), 1)
  )) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "pct_nonmissing") %>%
  print()


# =========================================================================
# 12. SAVE
# =========================================================================

# Save
dir.create("data/trips", showWarnings = FALSE, recursive = TRUE)
saveRDS(poisson_df, file = "data/trips/poisson_dt.rds")
cat("✓ Saved: data/trips/poisson_dt.rds\n")
cat("  Rows:", nrow(poisson_df), "\n")
cat("  Cols:", paste(names(poisson_df), collapse = ", "), "\n")

# Distribución T_vy por flota — decide Poisson vs NB
cat("\nT_vy distribution:\n")
poisson_df %>%
  group_by(TIPO_FLOTA) %>%
  summarise(
    n      = n(),
    mean   = round(mean(T_vy), 1),
    var    = round(var(T_vy), 1),
    ratio  = round(var(T_vy) / mean(T_vy), 1),  # >1 = overdispersion
    median = median(T_vy),
    max    = max(T_vy),
    .groups = "drop"
  ) %>%
  print







# =========================================================================
# ESTIMATION: Negative Binomial, separate by fleet
# Current spec: available variables
# Pending: diesel price, official TAC
# =========================================================================
library(MASS)
library(sandwich)
library(lmtest)

df_ind <- poisson_df %>% filter(TIPO_FLOTA == "IND")
df_art <- poisson_df %>% filter(TIPO_FLOTA == "ART")

nb_ind <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    sst_c + chl_c + days_closed_sa +
    TIPO_EMB,
  data = df_ind
)

nb_art <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    sst_c + chl_c + days_closed_sa +
    TIPO_EMB,
  data = df_art
)

# Robust SEs clustered by vessel
se_ind <- coeftest(nb_ind,
                   vcov = vcovCL(nb_ind, cluster = ~COD_BARCO, data = df_ind))
se_art <- coeftest(nb_art,
                   vcov = vcovCL(nb_art, cluster = ~COD_BARCO, data = df_art))

cat("====== INDUSTRIAL ======\n")
print(se_ind)
cat("\n====== ARTISANAL ======\n")
print(se_art)








