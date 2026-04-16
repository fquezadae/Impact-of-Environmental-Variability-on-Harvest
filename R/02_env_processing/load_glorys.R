###============================================================###
###   Load GLORYS reanalysis data (any time period)            ###
###============================================================###
#
#  Consolidated from: load_environmental_data_GLORYS1.R
#                     load_environmental_data_GLORYS2.R
#                     merge_GLORYS.R
#
#  Usage:
#    source("R/00_config/config.R")
#    source("R/02_env_processing/load_glorys.R")
#
#  The script reads ALL GLORYS netCDF files found in the
#  Environmental/ folder, processes each one identically,
#  and merges them into a single data.table.
###============================================================###

library(ncdf4)

# --- Helper: process a single GLORYS netCDF into a data.table ---
read_glorys_nc <- function(filepath) {

  nc <- nc_open(filepath)
  on.exit(nc_close(nc))

  lon <- ncvar_get(nc, "longitude")
  lat <- ncvar_get(nc, "latitude")
  tim <- ncvar_get(nc, "time")
  dep <- ncvar_get(nc, "depth")

  so  <- ncvar_get(nc, "so")
  sst <- ncvar_get(nc, "thetao")
  uo  <- ncvar_get(nc, "uo")
  vo  <- ncvar_get(nc, "vo")

  # Helper to melt 4D array -> data.table
  melt_var <- function(arr, varname) {
    dimnames(arr) <- list(lon = lon, lat = lat, dep = dep, time = tim)
    dt <- as.data.table(data.table::melt(arr, value.name = varname))
    setnames(dt, c("lon", "lat", "depth", "time", varname))
    # GLORYS time: hours since 1950-01-01
    dt[, date := as.Date("1950-01-01") + time / 24]
    dt[, time := NULL]
    dt
  }

  dt <- Reduce(
    function(x, y) merge(x, y, by = c("lon", "lat", "depth", "date")),
    list(melt_var(so, "so"), melt_var(sst, "sst"),
         melt_var(uo, "uo"), melt_var(vo, "vo"))
  )

  # Filter to surface layer, compute derived variables
  dt <- dt[depth < 1]
  dt[, `:=`(
    current_speed     = sqrt(uo^2 + vo^2),
    current_direction = fifelse(
      atan2(vo, uo) * 180 / pi < 0,
      atan2(vo, uo) * 180 / pi + 360,
      atan2(vo, uo) * 180 / pi
    )
  )]
  dt[, c("depth", "uo", "vo") := NULL]
  dt[, `:=`(year = year(date), month = month(date))]

  cat("  Loaded:", basename(filepath), "->", nrow(dt), "rows,",
      min(dt$date), "to", max(dt$date), "\n")
  dt
}

# --- Find and process all GLORYS files ---
glorys_files <- sort(Sys.glob(paste0(
  dirdata, "Environmental/cmems_mod_glo_phy_*_so-thetao-uo-vo_*.nc"
)))

if (length(glorys_files) == 0) {
  stop("No GLORYS netCDF files found in ", dirdata, "Environmental/")
}

cat("Found", length(glorys_files), "GLORYS file(s):\n")
glorys_list <- lapply(glorys_files, read_glorys_nc)
glorys_dt <- rbindlist(glorys_list, use.names = TRUE, fill = TRUE)

# Remove duplicates at boundaries between files
glorys_dt <- unique(glorys_dt, by = c("lon", "lat", "date"))
setorder(glorys_dt, lon, lat, date)

saveRDS(glorys_dt, file = "data/env/glorysDaily_2012_2025.rds")
cat("Saved: data/env/glorysDaily_2012_2025.rds ->", nrow(glorys_dt), "rows\n")

rm(glorys_list)
gc()
