###============================================================###
###   Load wind data from CMEMS netCDF (parallel version)      ###
###============================================================###
#
#  Consolidated from: load_environmental_data_Wind.R
#                     load_environmental_data_Wind_v2.R
#
#  Uses future.apply for parallel block processing to handle
#  large hourly netCDF files without exhausting memory.
#
#  Usage:
#    source("R/00_config/config.R")
#    source("R/02_env_processing/load_wind.R")
###============================================================###

library(ncdf4)
library(future.apply)

plan(multisession, workers = max(1, parallel::detectCores() - 2))

# --- Helper: daily wind aggregation for a netCDF file ---
read_wind_nc <- function(filepath, block_hours = 24 * 30) {

  nc <- nc_open(filepath)
  lon <- ncvar_get(nc, "longitude")
  lat <- ncvar_get(nc, "latitude")
  tim <- ncvar_get(nc, "time")
  time_units <- ncatt_get(nc, "time", "units")$value
  nc_close(nc)

  origin_str <- sub("seconds since ", "", time_units)
  dates <- as.Date(as.POSIXct(tim, origin = origin_str, tz = "UTC"))

  nT <- length(tim)
  block_size <- block_hours
  nBlocks <- ceiling(nT / block_size)

  process_block <- function(b) {
    nc <- nc_open(filepath)
    on.exit(nc_close(nc))

    start <- (b - 1) * block_size + 1
    count <- min(block_size, nT - start + 1)

    ua <- ncvar_get(nc, "eastward_wind",  start = c(1, 1, start), count = c(-1, -1, count))
    va <- ncvar_get(nc, "northward_wind", start = c(1, 1, start), count = c(-1, -1, count))

    spd <- sqrt(ua^2 + va^2)
    dir <- atan2(ua, va) * 180 / pi
    dir[dir < 0] <- dir[dir < 0] + 360

    dt <- data.table(
      lon       = rep(lon, each = length(lat) * count),
      lat       = rep(rep(lat, each = count), times = length(lon)),
      date      = rep(dates[start:(start + count - 1)], times = length(lon) * length(lat)),
      ua        = as.vector(ua),
      va        = as.vector(va),
      speed     = as.vector(spd),
      direction = as.vector(dir)
    )

    # Daily aggregation per pixel
    dt_daily <- dt[, .(
      ua_mean    = mean(ua, na.rm = TRUE),
      ua_min     = min(ua, na.rm = TRUE),
      ua_max     = max(ua, na.rm = TRUE),
      va_mean    = mean(va, na.rm = TRUE),
      va_min     = min(va, na.rm = TRUE),
      va_max     = max(va, na.rm = TRUE),
      speed_mean = mean(speed, na.rm = TRUE),
      speed_min  = min(speed, na.rm = TRUE),
      speed_max  = max(speed, na.rm = TRUE),
      dir_mean   = atan2(mean(sin(direction * pi / 180), na.rm = TRUE),
                         mean(cos(direction * pi / 180), na.rm = TRUE)) * 180 / pi,
      dir_min    = min(direction, na.rm = TRUE),
      dir_max    = max(direction, na.rm = TRUE)
    ), by = .(lon, lat, date)]

    dt_daily[dir_mean < 0, dir_mean := dir_mean + 360]
    dt_daily
  }

  cat("  Processing", nBlocks, "blocks from", basename(filepath), "...\n")
  wind_list <- future_lapply(seq_len(nBlocks), process_block)
  wind_dt <- rbindlist(wind_list)
  wind_dt[, `:=`(year = year(date), month = month(date))]

  cat("  Done:", nrow(wind_dt), "daily rows,",
      min(wind_dt$date), "to", max(wind_dt$date), "\n")
  wind_dt
}

# --- Find and process wind file(s) ---
wind_files <- sort(Sys.glob(paste0(
  dirdata, "Environmental/cmems_obs-wind_*_PT1H_*.nc"
)))

if (length(wind_files) == 0) {
  stop("No wind netCDF files found in ", dirdata, "Environmental/")
}

cat("Found", length(wind_files), "wind file(s):\n")
wind_list <- lapply(wind_files, read_wind_nc)
wind_dt <- rbindlist(wind_list, use.names = TRUE, fill = TRUE)
wind_dt <- unique(wind_dt, by = c("lon", "lat", "date"))
setorder(wind_dt, lon, lat, date)

saveRDS(wind_dt, file = "data/env/WindDaily_2012_2025.rds")
cat("Saved: data/env/WindDaily_2012_2025.rds ->", nrow(wind_dt), "rows\n")

plan(sequential)
rm(wind_list)
gc()
