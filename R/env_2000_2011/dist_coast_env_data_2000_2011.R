###----------------------------------------------###
###   Environmental data: distance to coast      ###
###----------------------------------------------###

rm(list = ls())
gc()

library(dplyr)
library(data.table)
library(lubridate)
library(sf)
library(rnaturalearth)

#---------------------------------
# Load dataset
#---------------------------------
usuario <- Sys.info()[["user"]]
dirdata <- paste0("C:/Users/", usuario,
                  "/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/")
env_dt <- readRDS("data/env/2000-2011/EnvMergedDaily_2000_2011_0.25deg.rds")

#---------------------------------
# Unique grid cells
#---------------------------------
grid_coords <- env_dt %>%
  select(lon, lat) %>%
  distinct()

grid_sf <- st_as_sf(grid_coords, coords = c("lon", "lat"), crs = 4326) %>%
  st_transform(32719)  # UTM 19S

#---------------------------------
# Chile continental (mainland only)
#---------------------------------
chile_mainland <- ne_countries(scale = "medium", returnclass = "sf") %>%
  filter(admin == "Chile") %>%
  st_union() %>%
  st_cast("POLYGON") %>%
  (\(x) x[which.max(st_area(x))])() %>%
  st_transform(32719)

#---------------------------------
# Buffer de 200 nm (~370.4 km)
#---------------------------------
nm200 <- 200 * 1852   # metros
chile_buffer <- st_buffer(chile_mainland, dist = nm200)

#---------------------------------
# Polígono de toda Sudamérica (para quitar tierra)
#---------------------------------
south_america <- ne_countries(scale = "medium", returnclass = "sf") %>%
  filter(continent == "South America") %>%
  st_union() %>%
  st_transform(32719)

#---------------------------------
# Zona de mar = buffer ∩ (no tierra)
#---------------------------------
sea_area <- st_difference(chile_buffer, south_america)

#---------------------------------
# Filtrar solo grilla en el mar
#---------------------------------
inside_sea <- st_intersects(grid_sf, sea_area, sparse = FALSE)[,1]
grid_filtered <- grid_sf[inside_sea, ]

#---------------------------------
# Distancias a la costa
#---------------------------------
grid_filtered$dist2coast_m  <- as.numeric(st_distance(grid_filtered, chile_mainland))
grid_filtered$dist2coast_km <- grid_filtered$dist2coast_m / 1000

#---------------------------------
# Extraer lon/lat de nuevo para merge
#---------------------------------
grid_filtered_lonlat <- st_transform(grid_filtered, 4326) %>%
  mutate(lon = st_coordinates(.)[,1],
         lat = st_coordinates(.)[,2]) %>%
  st_drop_geometry() %>%
  as.data.table()

#---------------------------------
# Merge con dataset original
#---------------------------------
keep_cells <- grid_filtered_lonlat %>%
  select(lon, lat, dist2coast_m, dist2coast_km)

env_coast_dt <- env_dt %>%
  semi_join(keep_cells, by = c("lon", "lat")) %>%
  left_join(keep_cells, by = c("lon", "lat"))

#---------------------------------
# Guardar dataset final
#---------------------------------
saveRDS(env_coast_dt,
        file = "data/env/2000-2011/EnvCoastDaily_2000_2011_0.25deg.rds")

#---------------------------------
# Chequeo rápido
#---------------------------------
cat("Celdas originales:", nrow(env_dt %>% distinct(lon, lat)), "\n")
cat("Celdas filtradas :", nrow(env_coast_dt %>% distinct(lon, lat)), "\n")


library(ggplot2)

# Pasar todo a lat/lon (EPSG:4326) para graficar
chile_plot   <- st_transform(chile_mainland, 4326)
buffer_plot  <- st_transform(chile_buffer, 4326)
sea_plot     <- st_transform(sea_area, 4326)
grid_plot    <- st_as_sf(grid_filtered, crs = 32719) %>%
  st_transform(4326)

p <- ggplot() +
  geom_sf(data = buffer_plot, fill = "lightblue", color = NA, alpha = 0.3) +
  geom_sf(data = sea_plot, fill = "lightblue", color = "blue", alpha = 0.2) +
  geom_sf(data = chile_plot, fill = "gray60", color = "black") +
  geom_sf(data = grid_plot, aes(color = dist2coast_km), size = 0.4) +
  scale_color_viridis_c(option = "plasma", name = "Distancia costa (km)") +
  coord_sf(xlim = c(-82, -70), ylim = c(-42, -30)) +
  theme_minimal() +
  labs(title = "Zona marítima chilena (≤ 200 nm, solo mar)",
       subtitle = "Grid ambiental 0.125° filtrado frente a Chile continental",
       x = "Longitud", y = "Latitud")

ggsave("figs/env_data_map.svg", p,
       device = svglite::svglite)