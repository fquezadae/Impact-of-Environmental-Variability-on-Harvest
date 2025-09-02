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
library(ggplot2)

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

# Convert to sf and keep lon/lat
grid_sf <- st_as_sf(grid_coords, coords = c("lon", "lat"), crs = 4326) %>%
  mutate(lon = st_coordinates(.)[,1],
         lat = st_coordinates(.)[,2])

# Transform to projected CRS (meters)
grid_sf <- st_transform(grid_sf, 6933)

#---------------------------------
# Coastline
#---------------------------------
land <- ne_countries(scale = "medium", returnclass = "sf")
coastline <- st_union(st_geometry(land)) |> st_transform(6933)

#---------------------------------
# Remove land points
#---------------------------------
inside_land <- st_intersects(grid_sf, coastline, sparse = FALSE)[,1]
grid_sf <- grid_sf[!inside_land, ]

#---------------------------------
# Distance to coast (m)
#---------------------------------
grid_sf$dist2coast <- st_distance(grid_sf, coastline) |> as.numeric()

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

#---------------------------------
# Filter to <= min_maxdist
#---------------------------------
grid_filtered <- grid_sf %>%
  filter(dist2coast <= min_maxdist)

grid_filtered_dt <- as.data.table(st_drop_geometry(grid_filtered))

# Merge with full dataset
env_coast_dt <- env_dt %>%
  inner_join(grid_filtered_dt, by = c("lon", "lat"))

saveRDS(env_coast_dt, file="data/env/EnvCoastDaily_2012_2025_0.125deg.rds")
