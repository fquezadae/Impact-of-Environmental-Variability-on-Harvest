library(data.table)
library(sf)
library(ggplot2)

#------------------------------------------------------------
# 0) Datos
#------------------------------------------------------------
# Asumo que tu data.table grande se llama dt y tiene:
# lon, lat, date (Date) + variables numéricas

rm(list = ls())
gc()

dirdata <- "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
dt <- readRDS(paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"))

# Asegura data.table y key
setDT(dt)
setkey(dt, lon, lat, date)

#------------------------------------------------------------
# 1) Puertos (corrige tu data.frame)
#------------------------------------------------------------
puertos_db <- data.frame(
  Puerto = c(
    "San Antonio",
    "Talcahuano (San Vicente)",
    "Coronel",
    "Calbuco",
    "Lota",
    "Corral",
    "Puerto Montt",
    "Region 7 (puerto)",   # nombre placeholder
    "Region 9 (puerto)"    # nombre placeholder
  ),
  Region_Num = c(5, 8, 8, 10, 8, 14, 10, 7, 9),
  Latitud = c(-33.5804, -36.7248, -37.0315, -41.7709, -37.0913, -39.8829, -41.4717, -35.3732, -39.3879),
  Longitud = c(-71.6186, -73.1311, -73.1596, -73.1301, -73.1601, -73.4294, -72.9367, -72.4337, -73.2135)
)

#------------------------------------------------------------
# 2) Convertir a sf (CRS WGS84) y preparar celdas únicas
#------------------------------------------------------------
# Celdas únicas lon/lat (MUY importante por performance)
cells <- unique(dt[, .(lon, lat)])
cells[, cell_id := .I]

cells_sf <- st_as_sf(cells, coords = c("lon","lat"), crs = 4326, remove = FALSE)
ports_sf <- st_as_sf(puertos_db, coords = c("Longitud","Latitud"), crs = 4326, remove = FALSE)

# Para buffers en metros: proyecta a un CRS métrico local (Chile: EPSG:32719 o 32718 según zona).
# Como tienes puertos desde ~33S a ~42S, 32719 (UTM 19S) funciona razonable.
cells_m <- st_transform(cells_sf, 32719)
ports_m <- st_transform(ports_sf, 32719)

#------------------------------------------------------------
# 3) Buffers y anillos
#------------------------------------------------------------
radii_km <- c(30, 60, 90, 120)
radii_m  <- radii_km * 1000

# Buffers acumulados
buf_list <- lapply(seq_along(radii_m), function(i){
  b <- st_buffer(ports_m, dist = radii_m[i])
  b$zone <- paste0("0_", radii_km[i], "km")
  b
})
buffers <- do.call(rbind, buf_list)
buffers <- st_make_valid(buffers)
buffers <- buffers[!st_is_empty(buffers), ]


# Anillos: 30-60, 60-90, 90-120 (diferencia de buffers)
make_ring <- function(r_in_m, r_out_m, label){
  outer <- st_buffer(ports_m, dist = r_out_m)
  inner <- st_buffer(ports_m, dist = r_in_m)
  
  ring <- st_difference(st_make_valid(outer), st_make_valid(inner))
  ring <- st_collection_extract(ring, "POLYGON")  # saca GEOMETRYCOLLECTION si aparece
  ring <- st_cast(ring, "MULTIPOLYGON", warn = FALSE)
  ring$zone <- label
  
  ring <- ring[!st_is_empty(ring), ]
  ring
}

rings <- rbind(
  make_ring(30e3, 60e3,  "30_60km"),
  make_ring(60e3, 90e3,  "60_90km"),
  make_ring(90e3, 120e3, "90_120km")
)
rings <- st_make_valid(rings)
rings <- rings[!st_is_empty(rings), ]


# Quédate solo con las columnas necesarias
buffers2 <- buffers[, c("Puerto", "zone")]
rings2   <- rings[,   c("Puerto", "zone")]

# Ahora sí se pueden unir
zones <- rbind(buffers2, rings2)
zones <- st_make_valid(zones)
zones <- zones[!st_is_empty(zones) & !is.na(zones$Puerto) & !is.na(zones$zone), ]




# Te quedan zonas: 0_30km, 0_60km, 0_90km, 0_120km + 30_60km, 60_90km, 90_120km

#------------------------------------------------------------
# 4) Mapear cell_id -> (Puerto, zone) con join espacial (una sola vez)
#------------------------------------------------------------
# st_join devuelve todas las combinaciones donde el punto cae dentro del polígono
# (puede ser MANY-TO-MANY)
m <- st_join(cells_m, zones[, c("Puerto","zone")], join = st_within, left = FALSE)
table(is.na(m$Puerto), is.na(m$zone))

map_cells <- as.data.table(st_drop_geometry(m))[, .(cell_id, Puerto, zone)]
setkey(map_cells, cell_id)

#------------------------------------------------------------
# 5) Promedios por Puerto/fecha/zona
#------------------------------------------------------------
# Une cell_id al dt grande sin geometría
dt2 <- dt[cells[, .(lon, lat, cell_id)], on = .(lon, lat)]

# Une zonas (puede replicar filas si una celda cae en varias zonas/puertos)
dt3 <- map_cells[dt2, on = "cell_id", allow.cartesian = TRUE, nomatch = 0L]

# Define qué variables promediar (todas menos lon/lat/date/cell_id/Puerto/zone)
vars_num <- setdiff(names(dt3), c("lon","lat","date","cell_id","Puerto","zone"))

# Promedios
mean_na <- function(x){
  if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
}

port_means <- dt3[, lapply(.SD, mean_na),
                  by = .(Puerto, zone, date),
                  .SDcols = vars_num]

# Resultado final
port_means[]


# MAPA!

library(sf)
library(ggplot2)

# Si tienes rnaturalearth:
# install.packages("rnaturalearth")
# install.packages("rnaturalearthdata")
library(rnaturalearth)

# 1) Costa / land
land <- ne_download(scale = 10, type = "land", category = "physical", returnclass = "sf")

# 2) Objetos a WGS84
buffers_wgs <- st_transform(buffers2, 4326)   # solo buffers acumulados (más limpio para el mapa)
ports_wgs   <- st_transform(ports_m, 4326)

# (Opcional) Puntos que efectivamente entraron a zonas (m viene del st_join con left=FALSE)
# m_wgs <- st_transform(m, 4326)
# set.seed(1)
# m_samp <- m_wgs[sample.int(nrow(m_wgs), min(30000, nrow(m_wgs))), ]

# 3) Caja del mapa (un poquito de margen)
bb <- st_bbox(st_union(ports_wgs))
bb_exp <- bb
bb_exp[c("xmin","xmax")] <- bb[c("xmin","xmax")] + c(-2, 2)
bb_exp[c("ymin","ymax")] <- bb[c("ymin","ymax")] + c(-2, 2)

ggplot() +
  geom_sf(data = land, linewidth = 0.2) +
  geom_sf(data = buffers_wgs, fill = NA, linewidth = 0.6) +
  geom_sf(data = ports_wgs, size = 2.4) +
  geom_text(data = puertos_db,
            aes(x = Longitud, y = Latitud, label = Puerto),
            size = 3.6, nudge_y = 0.15) +
  # Opcional: puntos usados
  # geom_sf(data = m_samp, size = 0.15, alpha = 0.15) +
  coord_sf(xlim = c(bb_exp["xmin"], bb_exp["xmax"]),
           ylim = c(bb_exp["ymin"], bb_exp["ymax"])) +
  theme_minimal(base_size = 12) +
  labs(title = "Radios alrededor de puertos",
       subtitle = "Buffers 0–30 / 0–60 / 0–90 / 0–120 km")


### LONG TO WIDE


library(data.table)
setDT(port_means)

# Variables numéricas a expandir (ajusta si quieres menos)
vars_num <- setdiff(names(port_means), c("Puerto","zone","date"))

wide <- dcast(
  port_means,
  Puerto + date ~ zone,
  value.var = vars_num
)

# Queda con nombres tipo: sst_0_30km, sst_30_60km, etc (data.table lo hace solo)
wide[]
saveRDS(wide, "data_ambiental_por_puerto.RDS")



