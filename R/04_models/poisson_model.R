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
# Units:
#   prices: 1000s of real pesos/ton (base 2018)
#   diesel: 100s of real pesos/litro (base 2018)
#   H_alloc_vy: tons
#   days_bad_weather: count (wind > threshold at COG grid)
#   days_closed_vy: count (veda days by zone)
#
# Data status:
#   [x] Trips T_vy             : logbooks
#   [x] Vessel chars Z_v       : logbooks
#   [x] Harvest shares omega_vs: logbooks
#   [x] H_alloc_vy             : shares × proxy
#   [x] Ex-vessel prices       : IFOP survey (PRECIO), deflated approx IPC
#   [x] COG per vessel         : catch-weighted centroid from hauls
#   [x] days_bad_weather_vy    : wind > 10 m/s at nearest grid to COG
#   [x] days_closed_vy         : SUBPESCA veda calendar × COG reg zone
#   [X] Diesel price           : CNE
#   [X] Official TAC_sy        : SUBPESCA 
#   [ ] Year-varying vedas     : SUBPESCA resolutions — PENDING

rm(list = ls())
gc()

library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)
library(stringr)


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
# 5. ALLOCATED HARVEST: H_alloc_vy = omega_reg × TAC_region (official)
# =========================================================================
# Source: SERNAPESCA/SUBPESCA cuotas efectivas 2012-2024
# Artisanal: regional TAC × vessel share within region
# Industrial: zonal TAC × vessel share within zone
# Processed in tac_processing.R

halloc <- readRDS("data/trips/halloc_official.rds")
cat("H_alloc_vy: official TAC (regional/zonal).\n")
cat("  Vessel-years:", nrow(halloc), "\n")


# =========================================================================
# 6. EX-VESSEL PRICES — deflated to real pesos (base 2018)
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

# Serie: IPC General, variación mensual (%)
# Fuente: Banco Central, base 2023=100

ipc_monthly <- read_excel(
  paste0(dirdata, "BancoCentral/PEM_VAR_IPC_BS23.xlsx"),
  sheet = "Cuadro",
  skip  = 2                    # skip title rows; row 3 = header
) %>%
  rename(date = 1, var_pct = 2) %>%
  filter(!is.na(date), !is.na(var_pct)) %>%
  mutate(
    date    = as.Date(date),
    year    = year(date),
    month   = month(date),
    var_pct = as.numeric(var_pct)
  ) %>%
  filter(year >= 2011)          # start one year before sample for cumulation

# Accumulate monthly variations into an index
# Base: December 2011 = 100 (so Jan 2012 starts accumulating)
ipc_monthly <- ipc_monthly %>%
  arrange(date) %>%
  mutate(
    factor  = 1 + var_pct / 100,
    ipc_idx = cumprod(factor) * 100   # index with first obs = 100*(1+var/100)
  )

# Annual average index
ipc_annual <- ipc_monthly %>%
  group_by(year) %>%
  summarise(ipc = mean(ipc_idx, na.rm = TRUE), .groups = "drop") %>%
  filter(year >= 2012, year <= 2024)

# Set base year
base_year <- 2018
base_ipc  <- ipc_annual$ipc[ipc_annual$year == base_year]

cat("====== IPC OFICIAL ======\n")
cat("Base year:", base_year, "= index", round(base_ipc, 2), "\n")
ipc_annual %>%
  mutate(ipc_rel = round(ipc / base_ipc, 4)) %>%
  print(n = 15)

prices_wide <- prices_sy_nominal %>%
  left_join(ipc_annual, by = "year") %>%
  mutate(price_real = price_nominal * (base_ipc / ipc)) %>%
  select(year, NM_RECURSO, price_real) %>%
  pivot_wider(names_from = NM_RECURSO, values_from = price_real) %>%
  rename(price_jurel = JUREL, price_sardina = `SARDINA COMUN`,
         price_anchov = ANCHOVETA) %>%
  mutate(year = as.integer(year)) %>%
  # Rescale from pesos/ton to thousands of pesos/ton for numerical stability
  mutate(across(starts_with("price_"), ~ . / 1000))

cat("Prices: deflated to", base_year, "pesos, rescaled to 1000s pesos/ton (official IPC).\n")
cat("  Jurel coverage:", sum(!is.na(prices_wide$price_jurel)), "of",
    nrow(prices_wide), "years\n")

rm(prices_cs, prices_sy_nominal)


# =========================================================================
# 7. COG: CENTER OF GRAVITY PER VESSEL
# =========================================================================
# Catch-weighted centroid over full sample — time-invariant.
# sd_lat diagnostic flags vessels with unstable fishing locations.

log_spf <- log_spf %>%
  mutate(
    lat_deg = -(floor(LATITUD / 10000) + (LATITUD %% 10000) / 6000),
    lon_deg = -(floor(LONGITUD / 10000) + (LONGITUD %% 10000) / 6000)
  )

# Recalcular COG con grados decimales y filtrar outliers
cog_vessel <- log_spf %>%
  filter(
    !is.na(lat_deg), !is.na(lon_deg),
    lat_deg < -30, lat_deg > -46,       # Chile CS range
    lon_deg < -70, lon_deg > -80,       # coastal Chile
    !is.na(CAPTURA_RETENIDA), CAPTURA_RETENIDA > 0
  ) %>%
  group_by(COD_BARCO) %>%
  summarise(
    cog_lat = weighted.mean(lat_deg, w = CAPTURA_RETENIDA),
    cog_lon = weighted.mean(lon_deg, w = CAPTURA_RETENIDA),
    n_hauls = n(),
    sd_lat  = sd(lat_deg),
    .groups = "drop"
  ) %>%
  mutate(
    cog_stable = case_when(
      n_hauls == 1     ~ TRUE,
      sd_lat <= 0.5    ~ TRUE,
      TRUE             ~ FALSE
    ),
    reg_zone = if_else(cog_lat >= -38.4, "V_VIII", "IX_XIV")
  )

cat("COG vessels:", nrow(cog_vessel), "\n")
cat("Stable (sd_lat ≤ 0.5° or single haul):", sum(cog_vessel$cog_stable), "\n")
summary(cog_vessel$sd_lat)
cog_vessel %>% count(reg_zone)


# =========================================================================
# 8. COG → REGULATORY ZONE → days_closed_vy
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
# 9. COG → days_bad_weather_vy
# =========================================================================
# Wind speed > 10 m/s at nearest grid point to vessel COG.
# Threshold ≈ Beaufort 5-6, difficult conditions for purse seine.

env_dt <- readRDS(paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"))

wind_threshold <- 8  # m/s

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
            by = c("grid_lat" = "lat", "grid_lon" = "lon"),
            relationship = "many-to-many") %>%
  select(COD_BARCO, year, days_bad_weather)

cat("Bad weather days: ", nrow(days_bad_weather_vy), "vessel-years\n")
cat("  Mean:", round(mean(days_bad_weather_vy$days_bad_weather, na.rm = TRUE), 1),
    " Median:", median(days_bad_weather_vy$days_bad_weather, na.rm = TRUE), "\n")

rm(env_dt, env_grid, bad_weather_grid, cog_with_grid)



veda_by_zone <- expand_grid(
  year     = 2013:2024,
  reg_zone = c("V_VIII", "IX_XIV")
) %>%
  mutate(
    days_closed_vy = case_when(
      reg_zone == "V_VIII" ~ 151L,
      reg_zone == "IX_XIV" ~ 182L
    )
  )



# =========================================================================
# 10. DIESEL — CNE (precio nominal $/litro, por región → vessel-year, real)
# =========================================================================
# Serie: Precios observados a público, promedio nominal por región ($/litro)
# Fuente: CNE (ex-SERNAC hasta 2012)
#
# CSV columns (from header row):
#   V2  = fecha ("enero/24")
#   V3  = Región Metropolitana (13)
#   V4  = XV Arica (15)
#   V5  = I Iquique (1)
#   V6  = II Antofagasta (2)
#   V7  = III Copiapó (3)
#   V8  = IV La Serena (4)
#   V9  = V Valparaíso (5)
#   V10 = VI Rancagua (6)
#   V11 = VII Talca (7)
#   V12 = XVI Chillán (16)
#   V13 = VIII Concepción (8)
#   V14 = IX Temuco (9)
#   V15 = XIV Valdivia (14)
#   V16 = X Puerto Montt (10)
#   V17 = XI Coyhaique (11)
#   V18 = XII Punta Arenas (12)
#
# CS regions for SPF: V(5), VIII(8), IX(9), XIV(14), X(10), XVI(16)
# Corresponding columns: V9, V13, V14, V15, V16, V12

diesel_raw <- read.csv(
  paste0(dirdata, "CNE/precios_comb_liquidos_en_el_pais-2026-03-02(Petróleo Diesel).csv"),
  sep          = ";",
  fileEncoding = "Latin1",
  header       = FALSE,
  skip         = 9,
  stringsAsFactors = FALSE
)

month_map <- c(
  "enero" = 1, "febrero" = 2, "marzo" = 3, "abril" = 4,
  "mayo" = 5, "junio" = 6, "julio" = 7, "agosto" = 8,
  "septiembre" = 9, "octubre" = 10, "noviembre" = 11, "diciembre" = 12
)

# Helper: parse Chilean price format "1.050,5" → 1050.5
parse_clp <- function(x) {
  x <- str_trim(x)
  x <- str_replace_all(x, "\\.", "")   # remove thousands separator
  x <- str_replace(x, ",", ".")        # decimal comma → point
  as.numeric(x)
}

# Select CS region columns and reshape to long format
diesel_long <- diesel_raw %>%
  select(fecha = V2,
         reg_05 = V9,   # V Valparaíso
         reg_16 = V12,  # XVI Chillán
         reg_08 = V13,  # VIII Concepción
         reg_09 = V14,  # IX Temuco
         reg_14 = V15,  # XIV Valdivia
         reg_10 = V16   # X Puerto Montt
  ) %>%
  filter(!is.na(fecha), str_detect(fecha, "/")) %>%
  mutate(
    fecha   = str_trim(fecha),
    month_s = str_extract(fecha, "^[a-záéíóú]+"),
    year_s  = str_extract(fecha, "\\d+$"),
    month   = month_map[month_s],
    year    = as.integer(ifelse(nchar(year_s) == 2,
                                paste0(ifelse(as.integer(year_s) > 50, "19", "20"), year_s),
                                year_s))
  ) %>%
  filter(!is.na(month), !is.na(year), year >= 2012, year <= 2024) %>%
  mutate(across(starts_with("reg_"), parse_clp)) %>%
  select(year, month, starts_with("reg_")) %>%
  pivot_longer(cols = starts_with("reg_"),
               names_to = "region_code",
               values_to = "diesel_nominal",
               names_prefix = "reg_") %>%
  mutate(region_code = as.integer(region_code)) %>%
  filter(!is.na(diesel_nominal))


# Annual average by region (nominal)
diesel_region_year <- diesel_long %>%
  group_by(year, region_code) %>%
  summarise(diesel_nominal = mean(diesel_nominal, na.rm = TRUE),
            .groups = "drop") %>%
  left_join(ipc_annual, by = "year") %>%
  mutate(diesel_real = diesel_nominal * (base_ipc / ipc)) %>%
  select(year, region_code, diesel_real)

# Complete: ensure all region × year combinations exist
diesel_region_year <- diesel_region_year %>%
  complete(year = 2012:2024, region_code, fill = list(diesel_real = NA))

# Then backfill XVI with VIII
diesel_viii_fill <- diesel_region_year %>%
  filter(region_code == 8) %>%
  rename(diesel_fill = diesel_real) %>%
  select(year, diesel_fill)

diesel_region_year <- diesel_region_year %>%
  left_join(diesel_viii_fill, by = "year") %>%
  mutate(diesel_real = if_else(
    region_code == 16 & is.na(diesel_real),
    diesel_fill,
    diesel_real
  )) %>%
  select(-diesel_fill)

cat("XVI backfilled with VIII prices. Now:\n")
diesel_region_year %>%
  filter(region_code == 16) %>%
  print(n = 15)

# ---- Map vessel COG to nearest diesel region ----


# 1. Load port master table (adjust path to your file)
maestro_puertos <- read_excel(
  paste0(dirdata, "IFOP/1. BITACORA CENTRO SUR.xlsx"),
  sheet = "PESQUERIAS_MAESTRO_PUERTOS"
) %>%
  select(CODIGO_PUERTO, COD_REGION) %>%
  mutate(across(everything(), as.integer))


# 2. Modal departure port per vessel
puerto_modal <- log_spf %>%
  filter(!is.na(PUERTO_ZARPE)) %>%
  count(COD_BARCO, PUERTO_ZARPE) %>%
  group_by(COD_BARCO) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  left_join(maestro_puertos, by = c("PUERTO_ZARPE" = "CODIGO_PUERTO")) %>%
  select(COD_BARCO, PUERTO_ZARPE, diesel_region = COD_REGION)

cat("Vessels with modal port:", nrow(puerto_modal), "\n")
cat("By diesel region:\n")
puerto_modal %>% count(diesel_region, sort = TRUE) %>% print()



# 3. Build diesel vessel-year
diesel_vy <- puerto_modal %>%
  select(COD_BARCO, diesel_region) %>%
  left_join(diesel_region_year,
            by = c("diesel_region" = "region_code"),
            relationship = "many-to-many") %>%
  select(COD_BARCO, year, diesel_real)

cat("\nDiesel vessel-year obs:", nrow(diesel_vy), "\n")
# Rescale diesel from $/litro to 100s $/litro for readability
diesel_vy <- diesel_vy %>%
  mutate(diesel_real = diesel_real / 100)

cat("Mean real price:", round(mean(diesel_vy$diesel_real, na.rm = TRUE), 3), "(100s $/litro)\n")





# =========================================================================
# 11. MERGE ALL COMPONENTS
# =========================================================================

poisson_df <- trips_vy %>%
  left_join(vessel_chars,     by = "COD_BARCO") %>%
  left_join(harvest_vy_wide,  by = c("COD_BARCO", "year")) %>%
  left_join(halloc,           by = c("COD_BARCO", "year")) %>%
  left_join(diesel_vy, by = c("COD_BARCO", "year")) %>%
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
      diesel_real,
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


saveRDS(maestro_puertos, file = "data/trips/maestro_puertos.rds")
saveRDS(log_spf, file = "data/trips/log_spf.rds")
saveRDS(vessel_chars, file = "data/trips/vessel_chars.rds")
saveRDS(harvest_vys, file = "data/trips/harvest_vys.rds")

# =========================================================================
# 12. ESTIMATION: Negative Binomial, separate by fleet
# =========================================================================

library(MASS)
library(sandwich)
library(lmtest)

df_ind <- poisson_df %>% filter(TIPO_FLOTA == "IND")
df_art <- poisson_df %>% filter(TIPO_FLOTA == "ART")

nb_ind_sin_diesel <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB,
  data = df_ind
)

nb_art_sin_diesel <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB,
  data = df_art
)

nb_ind_con_diesel <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    diesel_real +
    days_bad_weather + days_closed_vy +
    TIPO_EMB,
  data = df_ind
)

nb_art_con_diesel <- glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    diesel_real +
    days_bad_weather + days_closed_vy +
    TIPO_EMB,
  data = df_art
)

cat("AIC comparison (lower = better):\n")
cat("  IND sin diesel:", AIC(nb_ind_sin_diesel), "\n")
cat("  IND con diesel:", AIC(nb_ind_con_diesel), "\n")
cat("  ART sin diesel:", AIC(nb_art_sin_diesel), "\n")
cat("  ART con diesel:", AIC(nb_art_con_diesel), "\n")


se_ind_cd <- coeftest(nb_ind_con_diesel, vcov = vcovCL(nb_ind_con_diesel, cluster = df_ind$COD_BARCO))
se_art_cd <- coeftest(nb_art_con_diesel, vcov = vcovCL(nb_art_con_diesel, cluster = df_art$COD_BARCO))

cat("\n====== INDUSTRIAL (con diesel) ======\n")
print(se_ind_cd)
cat("\n====== ARTISANAL (con diesel) ======\n")
print(se_art_cd)

cat("\nAIC comparison:\n")
cat("  IND sin diesel:", AIC(nb_ind_sin_diesel), "\n")
cat("  IND con diesel:", AIC(nb_ind_con_diesel), "\n")
cat("  ART sin diesel:", AIC(nb_art_sin_diesel), "\n")
cat("  ART con diesel:", AIC(nb_art_con_diesel), "\n")


# SEs for main spec (sin diesel)
se_ind <- coeftest(nb_ind_sin_diesel, vcov = vcovCL(nb_ind_sin_diesel, cluster = df_ind$COD_BARCO))
se_art <- coeftest(nb_art_sin_diesel, vcov = vcovCL(nb_art_sin_diesel, cluster = df_art$COD_BARCO))

cat("\n====== INDUSTRIAL (sin diesel) ======\n")
print(se_ind)
cat("\n====== ARTISANAL (sin diesel) ======\n")
print(se_art)

cat("\nTheta:\n")
cat("  IND:", round(nb_ind_sin_diesel$theta, 2), "(SE:", round(nb_ind_sin_diesel$SE.theta, 2), ")\n")
cat("  ART:", round(nb_art_sin_diesel$theta, 2), "(SE:", round(nb_art_sin_diesel$SE.theta, 2), ")\n")


# LR test: NB vs Poisson
pois_ind <- glm(T_vy ~ log_bodega + H_alloc_vy +
                  price_jurel + price_sardina + price_anchov +
                  days_bad_weather + days_closed_vy + TIPO_EMB,
                family = poisson, data = df_ind)
pois_art <- glm(T_vy ~ log_bodega + H_alloc_vy +
                  price_jurel + price_sardina + price_anchov +
                  days_bad_weather + days_closed_vy + TIPO_EMB,
                family = poisson, data = df_art)

lr_ind <- 2 * (logLik(nb_ind_sin_diesel) - logLik(pois_ind))
lr_art <- 2 * (logLik(nb_art_sin_diesel) - logLik(pois_art))

cat("LR test NB vs Poisson:\n")
cat("  IND:", round(as.numeric(lr_ind), 1),
    "p =", format.pval(pchisq(as.numeric(lr_ind), 1, lower.tail = FALSE)), "\n")
cat("  ART:", round(as.numeric(lr_art), 1),
    "p =", format.pval(pchisq(as.numeric(lr_art), 1, lower.tail = FALSE)), "\n")


### WIND ROBUTNESS 

library(dplyr)
select <- dplyr::select
env_dt <- readRDS(paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"))

# Recrear cog_with_grid desde cog_vessel + env_grid
env_grid <- env_dt %>%
  distinct(lat, lon) %>%
  filter(!is.na(lat), !is.na(lon))

cog_with_grid <- cog_vessel %>%
  rowwise() %>%
  mutate(nearest = list(find_nearest_grid(cog_lat, cog_lon, env_grid))) %>%
  unnest(nearest) %>%
  ungroup()

for (wt in c(8, 10, 12)) {
  
  bw <- env_dt %>%
    mutate(year = year(date)) %>%
    filter(year >= 2013, year <= 2024) %>%
    group_by(lat, lon, year) %>%
    summarise(days_bw = sum(speed_max > wt, na.rm = TRUE), .groups = "drop")
  
  dbw <- cog_with_grid %>%
    select(COD_BARCO, grid_lat, grid_lon) %>%
    left_join(bw, by = c("grid_lat" = "lat", "grid_lon" = "lon"),
              relationship = "many-to-many") %>%
    select(COD_BARCO, year, days_bw)
  
  assign(paste0("dbw_", wt), dbw)
  cat("Threshold", wt, "m/s: mean =", round(mean(dbw$days_bw, na.rm = TRUE), 1), "\n")
}

for (wt in c(8, 10, 12)) {
  
  df_tmp <- poisson_df %>%
    select(-days_bad_weather) %>%
    left_join(get(paste0("dbw_", wt)), by = c("COD_BARCO", "year"))
  
  nb_art_tmp <- glm.nb(
    T_vy ~ log_bodega + H_alloc_vy +
      price_jurel + price_sardina + price_anchov +
      days_bw + days_closed_vy + TIPO_EMB,
    data = df_tmp %>% filter(TIPO_FLOTA == "ART"))
  
  nb_ind_tmp <- glm.nb(
    T_vy ~ log_bodega + H_alloc_vy +
      price_jurel + price_sardina + price_anchov +
      days_bw + days_closed_vy + TIPO_EMB,
    data = df_tmp %>% filter(TIPO_FLOTA == "IND"))
  
  cat("\n=== Threshold:", wt, "m/s ===\n")
  cat("  ART days_bw coef:", round(coef(nb_art_tmp)["days_bw"], 6),
      " p =", round(summary(nb_art_tmp)$coefficients["days_bw", 4], 4), "\n")
  cat("  IND days_bw coef:", round(coef(nb_ind_tmp)["days_bw"], 6),
      " p =", round(summary(nb_ind_tmp)$coefficients["days_bw", 4], 4), "\n")
  cat("  ART AIC:", round(AIC(nb_art_tmp), 1), " IND AIC:", round(AIC(nb_ind_tmp), 1), "\n")
}


