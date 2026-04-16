
# ===== Limpieza bitácoras IFOP – definición robusta =====

# Viajes y lances (anti NUMERO_LANCE_EX pegado)


# --------------------------
# 0) Cargar datos
# --------------------------
logbooks <- readRDS("data/logbooks/logbooks.rds")

library(dplyr)
library(lubridate)
library(tidyr)
library(stringr)
library(geosphere)

# --------------------------
# 1) ddmmss -> decimal degrees
# --------------------------
ddmmss_to_dd <- function(x){
  x <- as.numeric(x)
  dd <- floor(x/10000)
  mm <- floor((x - dd*10000)/100)
  ss <- x - dd*10000 - mm*100
  dd + mm/60 + ss/3600
}

# --------------------------
# 2) Preparar lb con tiempos + coords + trip_id
# --------------------------
lb <- logbooks %>%
  mutate(
    fecha_zarpe = as.POSIXct(FECHA_HORA_ZARPE,    tz="America/Santiago"),
    fecha_recal = as.POSIXct(FECHA_HORA_RECALADA, tz="America/Santiago"),
    fecha_lance = as.POSIXct(FECHA_LANCE,         tz="America/Santiago"),
    
    lat_dd = ddmmss_to_dd(LATITUD),
    lon_dd = -abs(ddmmss_to_dd(LONGITUD)),  # Chile oeste
    
    trip_id = paste(COD_BARCO, fecha_zarpe, fecha_recal, sep="|")
  )

# --------------------------
# 3) Reconstruir lances dentro de viaje (robusto a lance_ex pegado)
# --------------------------
MAX_HOURS <- 6
MAX_KM    <- 20

lb_lance <- lb %>%
  arrange(COD_BARCO, trip_id, fecha_lance) %>%
  group_by(COD_BARCO, trip_id) %>%
  mutate(
    dt_hours = as.numeric(difftime(fecha_lance, lag(fecha_lance), units="hours")),
    dist_km = distHaversine(
      cbind(lag(lon_dd), lag(lat_dd)),
      cbind(lon_dd, lat_dd)
    ) / 1000,
    new_lance = ifelse(
      is.na(dt_hours) | dt_hours > MAX_HOURS | dist_km > MAX_KM,
      1, 0
    ),
    lance_seq = cumsum(new_lance),
    lance_id = paste(COD_BARCO, trip_id, lance_seq, sep="|")
  ) %>%
  ungroup()

# --------------------------
# 4) Centroide por viaje (usando 1 fila por lance)
# --------------------------
lance_unique <- lb_lance %>%
  group_by(trip_id, lance_id) %>%
  summarise(
    lat_dd = first(lat_dd),
    lon_dd = first(lon_dd),
    Q_lance = max(CAPTURA_RETENIDA_TOTAL, na.rm = TRUE),
    .groups = "drop"
  )

trip_centroid <- lance_unique %>%
  group_by(trip_id) %>%
  summarise(
    # conteos útiles para QC
    n_lances_total = n(),
    n_lances_geo   = sum(!is.na(lat_dd) & !is.na(lon_dd)),
    
    # centroide simple (ignora NA)
    lat_centroid = ifelse(
      n_lances_geo > 0,
      mean(lat_dd, na.rm = TRUE),
      NA_real_
    ),
    lon_centroid = ifelse(
      n_lances_geo > 0,
      mean(lon_dd, na.rm = TRUE),
      NA_real_
    ),
    
    # centroide ponderado (usa solo lances con coords y peso > 0)
    lat_centroid_w = ifelse(
      sum(!is.na(lat_dd) & !is.na(lon_dd) & Q_lance > 0) > 0,
      weighted.mean(
        lat_dd[!is.na(lat_dd) & !is.na(lon_dd)],
        w = pmax(Q_lance[!is.na(lat_dd) & !is.na(lon_dd)], 0),
        na.rm = TRUE
      ),
      NA_real_
    ),
    lon_centroid_w = ifelse(
      sum(!is.na(lat_dd) & !is.na(lon_dd) & Q_lance > 0) > 0,
      weighted.mean(
        lon_dd[!is.na(lat_dd) & !is.na(lon_dd)],
        w = pmax(Q_lance[!is.na(lat_dd) & !is.na(lon_dd)], 0),
        na.rm = TRUE
      ),
      NA_real_
    ),
    .groups = "drop"
  )

# --------------------------
# 5) Wide por viaje: captura por especie (Q por especie en columnas)
# --------------------------
trip_species_wide <- lb_lance %>%
  group_by(trip_id, NOMBRE_ESPECIE) %>%
  summarise(Q_kg = sum(CAPTURA_RETENIDA, na.rm=TRUE), .groups="drop") %>%
  mutate(spec = str_to_lower(str_replace_all(NOMBRE_ESPECIE, "\\s+", "_"))) %>%
  select(trip_id, spec, Q_kg) %>%
  pivot_wider(names_from = spec, values_from = Q_kg, values_fill = 0)

# --------------------------
# 6) Trip base final (1 fila por viaje)
#    Nota: para captura_total_trip es mejor usar sum(CAPTURA_RETENIDA)
#    (porque CAPTURA_RETENIDA_TOTAL se repite por especie)
# --------------------------
trip_base_wide <- lb_lance %>%
  group_by(trip_id) %>%
  summarise(
    COD_BARCO = first(COD_BARCO),
    fecha_zarpe = first(fecha_zarpe),
    fecha_recal = first(fecha_recal),
    PUERTO_ZARPE = first(PUERTO_ZARPE),
    PUERTO_RECALADA = first(PUERTO_RECALADA),
    PUERTO_ZARPE_NOMBRE = first(PUERTO_ZARPE_NOMBRE),
    PUERTO_RECALADA_NOMBRE = first(PUERTO_RECALADA_NOMBRE),
    CAPACIDAD_BODEGA = first(CAPACIDAD_BODEGA),
    TIPO_FLOTA = first(TIPO_FLOTA),
    TIPO_EMB = first(TIPO_EMB),
    COD_PESQUERIA = first(COD_PESQUERIA),
    REGION = first(REGION),
    year = first(year),
    month = first(month),
    captura_total_trip = sum(CAPTURA_RETENIDA, na.rm=TRUE),
    .groups="drop"
  ) %>%
  left_join(trip_centroid, by="trip_id") %>%
  left_join(trip_species_wide, by="trip_id") %>% drop_na(lat_centroid)

# 251,054 obs to 55,985

# listo:
# lb_lance: datos con lances reconstruidos
# trip_base_wide: 1 fila por viaje, con centroide y Q por especie en wide


install.packages("openxlsx")  # solo 1 vez
library(openxlsx)

out <- "data/outputs/trip_base_wide.xlsx"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)

write.xlsx(trip_base_wide, file = out, overwrite = TRUE)
message("Guardado en: ", normalizePath(out))


