###============================================================###
###   Extract environmental data by port buffers/rings         ###
###============================================================###
#
#  Consolidated from: obtain_env_data_by_ports.R
#                     obtain_env_data_by_ports_for_cost_module.R
#
#  This single script handles both use cases via a configurable
#  port list. Call with different port data.frames as needed.
#
#  Usage:
#    source("R/00_config/config.R")
#    source("R/03_env_spatial/obtain_env_by_ports.R")
#
#    # For the main model (9 ports):
#    result <- extract_env_by_ports(env_dt, ports_main)
#
#    # For the cost module (22 ports):
#    result <- extract_env_by_ports(env_dt, ports_cost)
###============================================================###

library(sf)
library(ggplot2)
library(rnaturalearth)

# --- Core function: extract env means by port buffer zones ---
extract_env_by_ports <- function(dt, puertos_db,
                                  radii_km = c(30, 60, 90, 120),
                                  crs_metric = 32719) {

  setDT(dt)
  setkey(dt, lon, lat, date)

  # --- Unique grid cells ---
  cells <- unique(dt[, .(lon, lat)])
  cells[, cell_id := .I]

  cells_sf <- st_as_sf(cells, coords = c("lon", "lat"), crs = 4326, remove = FALSE)
  ports_sf <- st_as_sf(puertos_db, coords = c("Longitud", "Latitud"),
                       crs = 4326, remove = FALSE)

  cells_m <- st_transform(cells_sf, crs_metric)
  ports_m <- st_transform(ports_sf, crs_metric)

  # --- Cumulative buffers ---
  radii_m <- radii_km * 1000
  buf_list <- lapply(seq_along(radii_m), function(i) {
    b <- st_buffer(ports_m, dist = radii_m[i])
    b$zone <- paste0("0_", radii_km[i], "km")
    b
  })
  buffers <- do.call(rbind, buf_list)
  buffers <- st_make_valid(buffers)
  buffers <- buffers[!st_is_empty(buffers), ]

  # --- Rings ---
  make_ring <- function(r_in_m, r_out_m, label) {
    outer <- st_buffer(ports_m, dist = r_out_m)
    inner <- st_buffer(ports_m, dist = r_in_m)
    ring  <- st_difference(st_make_valid(outer), st_make_valid(inner))
    ring  <- st_collection_extract(ring, "POLYGON")
    ring  <- st_cast(ring, "MULTIPOLYGON", warn = FALSE)
    ring$zone <- label
    ring[!st_is_empty(ring), ]
  }

  rings <- rbind(
    make_ring(radii_m[1], radii_m[2], paste0(radii_km[1], "_", radii_km[2], "km")),
    make_ring(radii_m[2], radii_m[3], paste0(radii_km[2], "_", radii_km[3], "km")),
    make_ring(radii_m[3], radii_m[4], paste0(radii_km[3], "_", radii_km[4], "km"))
  )
  rings <- st_make_valid(rings)
  rings <- rings[!st_is_empty(rings), ]

  # --- Combine zones ---
  buffers2 <- buffers[, c("Puerto", "zone")]
  rings2   <- rings[, c("Puerto", "zone")]
  zones    <- rbind(buffers2, rings2)
  zones    <- st_make_valid(zones)
  zones    <- zones[!st_is_empty(zones) & !is.na(zones$Puerto) & !is.na(zones$zone), ]

  # --- Spatial join: cell -> (Puerto, zone) ---
  m <- st_join(cells_m, zones[, c("Puerto", "zone")], join = st_within, left = FALSE)
  map_cells <- as.data.table(st_drop_geometry(m))[, .(cell_id, Puerto, zone)]
  setkey(map_cells, cell_id)

  # --- Merge and compute means ---
  dt2 <- dt[cells[, .(lon, lat, cell_id)], on = .(lon, lat)]
  dt3 <- map_cells[dt2, on = "cell_id", allow.cartesian = TRUE, nomatch = 0L]

  # Fix dist2coast for land cells
  if ("dist2coast_km" %in% names(dt3)) dt3[dist2coast_km <= 0, dist2coast_km := NA_real_]
  if ("dist2coast_m" %in% names(dt3))  dt3[dist2coast_m <= 0, dist2coast_m := NA_real_]

  vars_num <- setdiff(names(dt3), c("lon", "lat", "date", "cell_id", "Puerto", "zone"))

  mean_na <- function(x) {
    if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
  }

  port_means <- dt3[, lapply(.SD, mean_na),
                    by = .(Puerto, zone, date),
                    .SDcols = vars_num]

  cat("Extracted env data for", uniqueN(port_means$Puerto), "ports,",
      uniqueN(port_means$zone), "zones,",
      nrow(port_means), "total rows\n")

  list(
    port_means = port_means,
    buffers_sf = buffers2,
    ports_m    = ports_m,
    puertos_db = puertos_db
  )
}


# --- Plot helper ---
plot_port_buffers <- function(result, title = "Buffer radii around ports") {
  land <- ne_download(scale = 10, type = "land", category = "physical", returnclass = "sf")

  buffers_wgs <- st_transform(result$buffers_sf, 4326)
  ports_wgs   <- st_transform(result$ports_m, 4326)

  bb <- st_bbox(st_union(ports_wgs))
  bb_exp <- bb
  bb_exp[c("xmin", "xmax")] <- bb[c("xmin", "xmax")] + c(-2, 2)
  bb_exp[c("ymin", "ymax")] <- bb[c("ymin", "ymax")] + c(-2, 2)

  ggplot() +
    geom_sf(data = land, linewidth = 0.2) +
    geom_sf(data = buffers_wgs, fill = NA, linewidth = 0.6) +
    geom_sf(data = ports_wgs, size = 2.4) +
    geom_text(data = result$puertos_db,
              aes(x = Longitud, y = Latitud, label = Puerto),
              size = 2.8, nudge_y = 0.15) +
    coord_sf(xlim = c(bb_exp["xmin"], bb_exp["xmax"]),
             ylim = c(bb_exp["ymin"], bb_exp["ymax"])) +
    theme_minimal(base_size = 12) +
    labs(title = title,
         subtitle = "Cumulative: 0-30 / 0-60 / 0-90 / 0-120 km")
}


# --- Port definitions ---

# Main model ports (9 ports)
ports_main <- data.frame(
  Puerto     = c("San Antonio", "Talcahuano (San Vicente)", "Coronel",
                  "Calbuco", "Lota", "Corral", "Puerto Montt",
                  "Region 7 (puerto)", "Region 9 (puerto)"),
  Region_Num = c(5, 8, 8, 10, 8, 14, 10, 7, 9),
  Latitud    = c(-33.5804, -36.7248, -37.0315, -41.7709, -37.0913,
                 -39.8829, -41.4717, -35.3732, -39.3879),
  Longitud   = c(-71.6186, -73.1311, -73.1596, -73.1301, -73.1601,
                 -73.4294, -72.9367, -72.4337, -73.2135)
)

# Cost module ports (22 ports, with cod_puerto for cost database)
ports_cost <- data.frame(
  cod_puerto = c(830, 19, 28, 29, 30, 31, 39, 40, 43, 930,
                 890, 6023, 25, 26, 33, 36, 38, 41, 45, 944,
                 6040, 59),
  Puerto = c("Caleta Tumbes", "San Antonio", "Talcahuano", "San Vicente",
             "Coronel", "Lota", "Corral", "Valdivia", "Calbuco",
             "Caleta Niebla", "Caleta Coliumo", "Caleta Punta Chilen",
             "Tome", "Puerto Tumbes", "Caleta Santa Maria",
             "Caleta Isla Mocha", "Caleta Queule", "Puerto Montt",
             "Ancud", "Caleta Chinquihue", "Caleta San Rafael",
             "Puerto San Jose"),
  Latitud = c(-36.6401, -33.5885, -36.7133, -36.7259, -37.0276, -37.0980,
              -39.8781, -39.8405, -41.7773, -39.8752, -36.5375, -41.9006,
              -36.6194, -36.6386, -37.0248, -38.3329, -39.3977, -41.4849,
              -41.8665, -41.5154, -41.7672, -41.7863),
  Longitud = c(-73.0935, -71.6156, -73.1090, -73.1341, -73.1499, -73.1602,
               -73.4233, -73.2670, -73.1329, -73.3942, -72.9586, -73.4816,
               -72.9590, -73.0914, -73.1566, -73.9176, -73.2150, -72.9597,
               -73.8313, -73.0303, -73.1333, -73.1855)
)
