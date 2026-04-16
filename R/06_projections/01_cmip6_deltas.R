# =============================================================================
# FONDECYT -- 01_cmip6_deltas.R
# Compute climate change deltas from CMIP6 IPSL-CM6A-LR for the
# Centro-Sur Chile study area.
#
# Adapted from: INCAR2-RL8 01_delta_method_INCAR.R
#
# Variables:
#   Wind speed (from uas, vas):  additive delta
#   SST (tos):                   additive delta  (for SUR module, future use)
#   CHL (chlos):                 multiplicative   (for SUR module, future use)
#
# Time windows:
#   Baseline (CMIP6 historical): 1995--2014  (20 yrs)
#   Mid-century:                 2041--2060
#   End-century:                 2081--2100
#
# Output: data/projections/cmip6_deltas.rds
#   data.table with (lon, lat, month, variable, ssp, window, delta)
# =============================================================================

library(ncdf4)
library(data.table)
library(terra)

source("R/00_config/config.R")

# =============================================================================
# CONFIGURATION
# =============================================================================

CMIP6_DIR <- "D:/GitHub/climate_projections/CMIP6"

OUTPUT_DIR <- "data/projections"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# FONDECYT study area bounding box (Centro-Sur: Valparaiso to Los Rios)
BBOX <- list(
  lon_min = -80, lon_max = -70,
  lat_min = -42, lat_max = -30
)

# Baseline and future windows
BASELINE <- c(as.Date("1995-01-01"), as.Date("2014-12-31"))

WINDOWS <- list(
  mid = c(as.Date("2041-01-01"), as.Date("2060-12-31")),
  end = c(as.Date("2081-01-01"), as.Date("2100-12-31"))
)

SSPS <- c("ssp245", "ssp585")

# CMIP6 file paths
CMIP6_FILES <- list(
  # Wind (atmospheric grid, regular lon-lat)
  uas = list(
    historical = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_eastward_near_surface_wind_historical_monthly.nc"),
    ssp245     = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_eastward_near_surface_wind_ssp2_4_5_monthly.nc"),
    ssp585     = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_eastward_near_surface_wind_ssp5_8_5_monthly.nc")
  ),
  vas = list(
    historical = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_northward_near_surface_wind_historical_monthly.nc"),
    ssp245     = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_northward_near_surface_wind_ssp2_4_5_monthly.nc"),
    ssp585     = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_northward_near_surface_wind_ssp5_8_5_monthly.nc")
  ),
  # SST (ORCA curvilinear grid)
  tos = list(
    historical = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_sea_surface_temperature_historical_monthly.nc"),
    ssp245     = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_sea_surface_temperature_ssp2_4_5_monthly.nc"),
    ssp585     = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_sea_surface_temperature_ssp5_8_5_monthly.nc")
  ),
  # CHL (ORCA curvilinear grid)
  chlos = list(
    historical = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_chlos_historical_monthly.nc"),
    ssp245     = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_chlos_ssp245_monthly.nc"),
    ssp585     = file.path(CMIP6_DIR, "CMIP6_ipsl_cm6a_lr_chlos_ssp585_monthly.nc")
  )
)


# =============================================================================
# UTILITY: Read CMIP6 variable, subset to bbox, return data.table
# =============================================================================

read_cmip6_var <- function(filepath, varname, date_range, bbox) {

  nc <- nc_open(filepath)
  on.exit(nc_close(nc))

  # Time axis
  t_var   <- ncvar_get(nc, "time")
  t_units <- ncatt_get(nc, "time", "units")$value
  t_origin <- sub(".*since ", "", t_units)

  dates <- if (grepl("^hours",   t_units)) as.Date(t_origin) + t_var / 24
  else if (grepl("^seconds", t_units)) as.Date(t_origin) + t_var / 86400
  else if (grepl("^days",    t_units)) as.Date(t_origin) + t_var
  else stop("Unknown time units: ", t_units)

  t_idx <- which(dates >= date_range[1] & dates <= date_range[2])
  if (length(t_idx) == 0) stop("No dates in range for ", basename(filepath))

  # Detect grid type
  if ("nav_lon" %in% names(nc$var)) {
    # ORCA curvilinear grid (oceanic vars)
    lon2d <- ncvar_get(nc, "nav_lon")
    lat2d <- ncvar_get(nc, "nav_lat")
    grid_type <- "curvilinear"
  } else if (all(c("lon", "lat") %in% names(nc$dim))) {
    # Regular grid (atmospheric vars like uas, vas)
    lon1d <- ncvar_get(nc, "lon")
    lat1d <- ncvar_get(nc, "lat")
    grid_type <- "regular"
  } else {
    stop("Unknown grid structure in ", basename(filepath))
  }

  # Read data for selected time range
  v <- nc$var[[varname]]
  dim_names <- sapply(v$dim, function(d) d$name)
  n_dims <- length(dim_names)

  start_vec <- rep(1, n_dims)
  count_vec <- rep(-1, n_dims)
  time_pos <- which(dim_names == "time")
  start_vec[time_pos] <- min(t_idx)
  count_vec[time_pos] <- length(t_idx)

  arr <- ncvar_get(nc, varname, start = start_vec, count = count_vec)

  cat("  Read", basename(filepath), ":", length(t_idx), "months,",
      "grid:", grid_type, "\n")

  # Build data.table with (lon, lat, date, value)
  if (grid_type == "regular") {
    # Handle 0-360 longitude convention (e.g., IPSL atmospheric grid)
    if (all(lon1d >= 0) && bbox$lon_min < 0) {
      # Convert bbox to 0-360 for subsetting
      lon_min_360 <- bbox$lon_min + 360
      lon_max_360 <- bbox$lon_max + 360
      lon_idx <- which(lon1d >= lon_min_360 & lon1d <= lon_max_360)
    } else {
      lon_idx <- which(lon1d >= bbox$lon_min & lon1d <= bbox$lon_max)
    }
    lat_idx <- which(lat1d >= bbox$lat_min & lat1d <= bbox$lat_max)

    lon_sub <- lon1d[lon_idx]
    lat_sub <- lat1d[lat_idx]
    arr_sub <- arr[lon_idx, lat_idx, ]

    # Convert longitudes back to -180/180 if needed
    lon_sub <- ifelse(lon_sub > 180, lon_sub - 360, lon_sub)

    dt <- CJ(lon = lon_sub, lat = lat_sub, date = dates[t_idx])
    setorder(dt, lon, lat, date)
    dt[, value := as.vector(arr_sub)]

  } else {
    # Curvilinear: melt full array, then filter to bbox
    nx <- dim(arr)[1]
    ny <- dim(arr)[2]
    nt <- length(t_idx)

    dt_list <- vector("list", nt)
    for (i in seq_len(nt)) {
      slice <- arr[, , i]
      dt_i <- data.table(
        lon   = as.vector(lon2d),
        lat   = as.vector(lat2d),
        value = as.vector(slice)
      )
      dt_i <- dt_i[lon >= bbox$lon_min & lon <= bbox$lon_max &
                      lat >= bbox$lat_min & lat <= bbox$lat_max &
                      !is.na(value)]
      dt_i[, date := dates[t_idx[i]]]
      dt_list[[i]] <- dt_i
    }
    dt <- rbindlist(dt_list)
  }

  dt[, month := month(date)]
  dt
}


# =============================================================================
# COMPUTE MONTHLY CLIMATOLOGY from data.table
# =============================================================================

compute_climatology <- function(dt) {
  # Returns (lon, lat, month, clim_value)
  dt[, .(clim_value = mean(value, na.rm = TRUE)),
     by = .(lon, lat, month)]
}


# =============================================================================
# MAIN: Compute deltas for all variables x SSPs x windows
# =============================================================================

compute_all_deltas <- function() {

  cat("\n", strrep("=", 60), "\n")
  cat("FONDECYT: CMIP6 delta-method computation\n")
  cat(strrep("=", 60), "\n")

  # --- 1. WIND SPEED DELTAS ---
  # Read uas and vas separately, compute speed, then climatology
  cat("\n--- Wind speed ---\n")

  cat("  Historical:\n")
  uas_hist <- read_cmip6_var(CMIP6_FILES$uas$historical, "uas", BASELINE, BBOX)
  vas_hist <- read_cmip6_var(CMIP6_FILES$vas$historical, "vas", BASELINE, BBOX)

  # Merge uas + vas, compute speed
  wind_hist <- merge(uas_hist, vas_hist,
                     by = c("lon", "lat", "date", "month"),
                     suffixes = c("_uas", "_vas"))
  wind_hist[, value := sqrt(value_uas^2 + value_vas^2)]
  wind_hist[, c("value_uas", "value_vas") := NULL]

  clim_wind_hist <- compute_climatology(wind_hist)
  rm(uas_hist, vas_hist, wind_hist); gc()

  # Future wind by SSP x window
  wind_deltas <- list()

  for (ssp in SSPS) {
    for (wname in names(WINDOWS)) {
      win <- WINDOWS[[wname]]
      key <- paste(ssp, wname, sep = "_")

      cat(sprintf("\n  Wind | %s | %s:\n", ssp, wname))
      uas_fut <- read_cmip6_var(CMIP6_FILES$uas[[ssp]], "uas", win, BBOX)
      vas_fut <- read_cmip6_var(CMIP6_FILES$vas[[ssp]], "vas", win, BBOX)

      wind_fut <- merge(uas_fut, vas_fut,
                        by = c("lon", "lat", "date", "month"),
                        suffixes = c("_uas", "_vas"))
      wind_fut[, value := sqrt(value_uas^2 + value_vas^2)]
      wind_fut[, c("value_uas", "value_vas") := NULL]

      clim_wind_fut <- compute_climatology(wind_fut)

      # Additive delta
      delta <- merge(clim_wind_fut, clim_wind_hist,
                     by = c("lon", "lat", "month"),
                     suffixes = c("_fut", "_hist"))
      delta[, delta := clim_value_fut - clim_value_hist]
      delta[, c("clim_value_fut", "clim_value_hist") := NULL]
      delta[, `:=`(variable = "wind_speed", ssp = ssp, window = wname,
                   delta_type = "additive")]

      wind_deltas[[key]] <- delta
      rm(uas_fut, vas_fut, wind_fut, clim_wind_fut, delta); gc()
    }
  }

  rm(clim_wind_hist); gc()

  # --- 2. SST DELTAS (for SUR module, future use) ---
  cat("\n--- SST ---\n")
  cat("  Historical:\n")
  sst_hist <- read_cmip6_var(CMIP6_FILES$tos$historical, "tos", BASELINE, BBOX)
  clim_sst_hist <- compute_climatology(sst_hist)
  rm(sst_hist); gc()

  sst_deltas <- list()
  for (ssp in SSPS) {
    for (wname in names(WINDOWS)) {
      win <- WINDOWS[[wname]]
      key <- paste(ssp, wname, sep = "_")

      cat(sprintf("\n  SST | %s | %s:\n", ssp, wname))
      sst_fut <- read_cmip6_var(CMIP6_FILES$tos[[ssp]], "tos", win, BBOX)
      clim_sst_fut <- compute_climatology(sst_fut)

      delta <- merge(clim_sst_fut, clim_sst_hist,
                     by = c("lon", "lat", "month"),
                     suffixes = c("_fut", "_hist"))
      delta[, delta := clim_value_fut - clim_value_hist]
      delta[, c("clim_value_fut", "clim_value_hist") := NULL]
      delta[, `:=`(variable = "sst", ssp = ssp, window = wname,
                   delta_type = "additive")]

      sst_deltas[[key]] <- delta
      rm(sst_fut, clim_sst_fut, delta); gc()
    }
  }
  rm(clim_sst_hist); gc()

  # --- 3. CHL DELTAS (for SUR module, future use) ---
  cat("\n--- CHL ---\n")
  cat("  Historical:\n")
  chl_hist <- read_cmip6_var(CMIP6_FILES$chlos$historical, "chlos", BASELINE, BBOX)
  clim_chl_hist <- compute_climatology(chl_hist)
  rm(chl_hist); gc()

  chl_deltas <- list()
  for (ssp in SSPS) {
    for (wname in names(WINDOWS)) {
      win <- WINDOWS[[wname]]
      key <- paste(ssp, wname, sep = "_")

      cat(sprintf("\n  CHL | %s | %s:\n", ssp, wname))
      chl_fut <- read_cmip6_var(CMIP6_FILES$chlos[[ssp]], "chlos", win, BBOX)
      clim_chl_fut <- compute_climatology(chl_fut)

      # Multiplicative delta (ratio)
      delta <- merge(clim_chl_fut, clim_chl_hist,
                     by = c("lon", "lat", "month"),
                     suffixes = c("_fut", "_hist"))
      delta[, clim_value_hist := fifelse(clim_value_hist < 0.01, 0.01, clim_value_hist)]
      delta[, delta := clim_value_fut / clim_value_hist]
      delta[, c("clim_value_fut", "clim_value_hist") := NULL]
      delta[, `:=`(variable = "chl", ssp = ssp, window = wname,
                   delta_type = "multiplicative")]

      chl_deltas[[key]] <- delta
      rm(chl_fut, clim_chl_fut, delta); gc()
    }
  }
  rm(clim_chl_hist); gc()

  # --- Combine and save ---
  all_deltas <- rbindlist(c(wind_deltas, sst_deltas, chl_deltas), use.names = TRUE)

  cat("\n", strrep("=", 60), "\n")
  cat("Delta summary:\n")
  print(all_deltas[, .(
    mean_delta = round(mean(delta, na.rm = TRUE), 4),
    sd_delta   = round(sd(delta, na.rm = TRUE), 4),
    n_cells    = .N
  ), by = .(variable, ssp, window, delta_type)])

  saveRDS(all_deltas, file = file.path(OUTPUT_DIR, "cmip6_deltas.rds"))
  cat("\nSaved:", file.path(OUTPUT_DIR, "cmip6_deltas.rds"), "\n")
  cat(strrep("=", 60), "\n")

  invisible(all_deltas)
}


# =============================================================================
# RUN
# =============================================================================

if (sys.nframe() == 0) {
  deltas <- compute_all_deltas()
}
