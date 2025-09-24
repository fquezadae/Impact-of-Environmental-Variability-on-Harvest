
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
env_dt <- readRDS("data/env/EnvMergedDaily_2012_2025_0.125deg.rds")

#---------------------------------
# Unique grid cells
#---------------------------------
grid_coords <- env_dt %>%
  select(lon, lat) %>%
  distinct()

grid_sf <- st_as_sf(grid_coords, coords = c("lon", "lat"), crs = 4326) %>%
  st_transform(32719)  # UTM 19S, en metros

#---------------------------------
# Chile continental
#---------------------------------
chile_mainland <- ne_countries(scale = "medium", returnclass = "sf") %>%
  filter(admin == "Chile") %>%
  st_union() %>%
  st_cast("POLYGON") %>%
  (\(x) x[which.max(st_area(x))])() %>%
  st_transform(32719)

#---------------------------------
# Buffer de 200 nm (370.4 km)
#---------------------------------
nm200 <- 200 * 1852   # en metros
chile_buffer <- st_buffer(chile_mainland, dist = nm200)

#---------------------------------
# Quitar puntos en tierra
#---------------------------------
inside_land <- st_intersects(grid_sf, chile_mainland, sparse = FALSE)[,1]
grid_sf <- grid_sf[!inside_land, ]

#---------------------------------
# Filtrar solo dentro de buffer
#---------------------------------
inside_buffer <- st_intersects(grid_sf, chile_buffer, sparse = FALSE)[,1]
grid_filtered <- grid_sf[inside_buffer, ]

#---------------------------------
# Distancias a la costa
#---------------------------------
grid_filtered$dist2coast_m  <- as.numeric(st_distance(grid_filtered, chile_mainland))
grid_filtered$dist2coast_km <- grid_filtered$dist2coast_m / 1000

#---------------------------------
# Merge con dataset original
#---------------------------------
grid_filtered_dt <- as.data.table(st_drop_geometry(grid_filtered))

env_coast_dt <- env_dt %>%
  inner_join(grid_filtered_dt, by = c("lon", "lat"))

# Guardar
saveRDS(env_coast_dt,
        file="data/env/EnvCoastDaily_2012_2025_0.125deg.rds")



#---------------------------------
# Figura
#---------------------------------

library(ggplot2)

# Pasar a lat/lon para graficar bonito
grid_plot <- st_as_sf(grid_filtered, crs = 32719) %>%
  st_transform(4326)

chile_plot <- st_as_sf(chile_mainland, crs = 32719) %>%
  st_transform(4326)

buffer_plot <- st_as_sf(chile_buffer, crs = 32719) %>%
  st_transform(4326)

ggplot() +
  geom_sf(data = buffer_plot, fill = "lightblue", color = NA, alpha = 0.3) +
  geom_sf(data = chile_plot, fill = "gray60", color = "black") +
  geom_sf(data = grid_plot, aes(color = dist2coast_km), size = 0.3) +
  scale_color_viridis_c(option = "plasma", name = "Distancia costa (km)") +
  coord_sf(xlim = c(-82, -70), ylim = c(-42, -30)) +
  theme_minimal() +
  labs(title = "Distancia a la costa (≤ 200 nm)",
       subtitle = "Grid ambiental 0.125° filtrado a 200 nm de Chile continental",
       x = "Longitud", y = "Latitud")



#---------------------------------
# Maximum distance by latitude
#---------------------------------
grid_dt <- st_drop_geometry(grid_sf)

max_dist_by_lat <- grid_dt %>%
  group_by(lat) %>%
  summarise(max_dist = max(dist2coast, na.rm = TRUE)) %>%
  arrange(lat)

# Minimum of those maxima (narrowest width of ocean band)
min_maxdist <- min(max_dist_by_lat$max_dist, na.rm = TRUE)

cat("Minimum of the maximum distances (km):",
    round(min_maxdist / 1000, 2), "\n")
