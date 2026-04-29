# =============================================================================
# FONDECYT -- 06_extended_env_anomalies.R
#
# Apendice E del paper 1: lee SST (GLORYS12 monthly, thetao) y CHL (Ocean Colour
# L4 multi-sensor) sobre la bbox extended (lon [-90,-65] x lat [-56,-20]) y
# construye series anuales SST y log(CHL) sobre TRES dominios anidados:
#
#   D1 "centro_sur_eez" : lat [-42, -32] x lon [-75, -70]   (main results 4.1)
#   D2 "offshore_ext"   : lat [-41, -32] x lon [-85, -65]   (Apendice E var 1)
#   D3 "se_pacific"     : lat [-45, -20] x lon [-90, -65]   (Apendice E var 2)
#
# Convencion de centering -- decidida 2026-04-29 con Felipe:
#   Cada serie anual se centra por su media 2000-2024, IGUAL que el fit principal
#   (08_fit_t4b_full.R). Esto deja Apendice E como un test puro de robustez
#   ESPACIAL (la unica cosa que cambia entre dominios es la bbox de promediado;
#   el baseline temporal no se mueve).
#
# Promedio espacial: ponderado por cos(latitud) en los 3 dominios. Para D1
# (10 deg de latitud) es practicamente equivalente al unweighted del fit
# principal (<0.05 degC en SST, <2% en CHL); en D3 (25 deg) corrige el sesgo
# hacia el sur por densidad de grid.
#
# Convencion de logCHL (idem fit principal):
#   chl_year = mean over (cell, month) within year (cos-lat weighted)
#   logCHL_c = log(chl_year) - mean(log(chl_year)) over 2000-2024
#
# Entradas:
#   - <dirdata>raw/climate_extended/paper1_SST_monthly_2000_2024_extended.nc
#   - <dirdata>raw/climate_extended/paper1_CHL_monthly_1998_2024_extended.nc
#
# Salidas:
#   - data/bio_params/env_extended_3domains_2000_2024.csv
#       columnas: domain, year, sst, chl, SST_c, logCHL_c, n_cells, n_months_yr
#   - data/bio_params/env_extended_3domains_diagnostics.csv
#       columnas: domain, lat_min, lat_max, lon_min, lon_max, n_cells_sst,
#                 n_cells_chl, sst_mean, sst_sd, chl_mean, chl_sd
#
# Corre:
#   source("R/00_config/config.R")
#   source("R/06_projections/06_extended_env_anomalies.R")
# =============================================================================

suppressPackageStartupMessages({
  library(ncdf4)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(lubridate)
})

if (!exists("dirdata")) source("R/00_config/config.R")

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
APP_E_WINDOW <- 2000:2024

APP_E_NC_SST <- file.path(dirdata, "raw", "climate_extended",
                          "paper1_SST_monthly_2000_2024_extended.nc")
APP_E_NC_CHL <- file.path(dirdata, "raw", "climate_extended",
                          "paper1_CHL_monthly_1998_2024_extended.nc")

APP_E_DOMAINS <- list(
  centro_sur_eez = list(lat = c(-42, -32), lon = c(-75, -70)),
  offshore_ext   = list(lat = c(-41, -32), lon = c(-85, -65)),
  se_pacific     = list(lat = c(-45, -20), lon = c(-90, -65))
)

APP_E_OUT_DIR <- "data/bio_params"
dir.create(APP_E_OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Helper: parse "<unit> since YYYY-MM-DD[ HH:MM:SS]"  ->  date vector
# -----------------------------------------------------------------------------
parse_nc_time <- function(time_vals, units_str) {
  parts <- strsplit(units_str, " since ", fixed = TRUE)[[1]]
  unit  <- tolower(trimws(parts[1]))
  origin <- as.POSIXct(trimws(parts[2]), tz = "UTC",
                       tryFormats = c("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"))
  mult <- switch(unit,
                 "seconds" = 1,
                 "minutes" = 60,
                 "hours"   = 3600,
                 "days"    = 86400,
                 stop("Unidad de tiempo no soportada: ", unit))
  as.Date(origin + as.numeric(time_vals) * mult)
}

# -----------------------------------------------------------------------------
# Helper: cos(lat) weights -> matrix [lon x lat] broadcast
# Returns a matrix of weights (sum to 1 over cells inside domain mask).
# -----------------------------------------------------------------------------
cos_lat_weights <- function(lon, lat, lat_range, lon_range) {
  in_lon <- lon >= lon_range[1] & lon <= lon_range[2]
  in_lat <- lat >= lat_range[1] & lat <= lat_range[2]
  w_lat  <- cos(lat * pi / 180)
  W <- outer(as.numeric(in_lon), w_lat * as.numeric(in_lat), `*`)
  s <- sum(W)
  if (s <= 0) {
    return(list(W = W, n_cells = 0L))
  }
  list(W = W / s, n_cells = sum(in_lon) * sum(in_lat))
}

# -----------------------------------------------------------------------------
# 1. SST: leer thetao (lon, lat, [depth], time) -> mensual por dominio
# -----------------------------------------------------------------------------
load_sst_monthly_by_domain <- function(nc_path, domains) {
  cat(sprintf("[appE-env] Abriendo SST nc: %s\n", basename(nc_path)))
  if (!file.exists(nc_path)) stop("No existe: ", nc_path)

  nc <- nc_open(nc_path)
  on.exit(nc_close(nc), add = TRUE)

  lon_name <- if ("longitude" %in% names(nc$dim)) "longitude" else "lon"
  lat_name <- if ("latitude"  %in% names(nc$dim)) "latitude"  else "lat"
  lon <- ncvar_get(nc, lon_name)
  lat <- ncvar_get(nc, lat_name)
  tim <- ncvar_get(nc, "time")
  units_t <- ncatt_get(nc, "time", "units")$value
  date_v  <- parse_nc_time(tim, units_t)

  thetao <- ncvar_get(nc, "thetao")  # dims: lon, lat, [depth,] time
  d <- dim(thetao)
  cat(sprintf("[appE-env] thetao dims = (%s)  ->  lon=%d lat=%d time=%d\n",
              paste(d, collapse = "x"), length(lon), length(lat), length(tim)))
  # Si tiene dim depth, colapsar (depth slice 0.49-1.55 m -> 1-2 capas surface)
  if (length(d) == 4) {
    thetao <- apply(thetao, c(1, 2, 4), mean, na.rm = TRUE)
  }
  stopifnot(dim(thetao)[1] == length(lon),
            dim(thetao)[2] == length(lat),
            dim(thetao)[3] == length(tim))

  out <- list()
  for (dn in names(domains)) {
    rng <- domains[[dn]]
    w   <- cos_lat_weights(lon, lat, rng$lat, rng$lon)
    if (w$n_cells == 0) stop("Dominio ", dn, " sin celdas en SST grid")
    # Para cada mes: SST_mes = sum_{i,j} w_ij * thetao_ijm  (NA-safe)
    mon_mean <- apply(thetao, 3, function(slice) {
      ok <- !is.na(slice) & w$W > 0
      if (!any(ok)) return(NA_real_)
      sum(slice[ok] * w$W[ok]) / sum(w$W[ok])
    })
    out[[dn]] <- data.frame(
      domain = dn,
      date   = date_v,
      sst    = as.numeric(mon_mean)
    )
    cat(sprintf("[appE-env]  D=%s  n_cells=%d  SST mensual rango [%.2f, %.2f]\n",
                dn, w$n_cells, min(out[[dn]]$sst, na.rm = TRUE),
                max(out[[dn]]$sst, na.rm = TRUE)))
  }
  bind_rows(out)
}

# -----------------------------------------------------------------------------
# 2. CHL: leer CHL (lon, lat, time) -> mensual por dominio
# -----------------------------------------------------------------------------
load_chl_monthly_by_domain <- function(nc_path, domains) {
  cat(sprintf("[appE-env] Abriendo CHL nc: %s\n", basename(nc_path)))
  if (!file.exists(nc_path)) stop("No existe: ", nc_path)

  nc <- nc_open(nc_path)
  on.exit(nc_close(nc), add = TRUE)

  lon_name <- if ("longitude" %in% names(nc$dim)) "longitude" else "lon"
  lat_name <- if ("latitude"  %in% names(nc$dim)) "latitude"  else "lat"
  lon <- ncvar_get(nc, lon_name)
  lat <- ncvar_get(nc, lat_name)
  tim <- ncvar_get(nc, "time")
  units_t <- ncatt_get(nc, "time", "units")$value
  date_v  <- parse_nc_time(tim, units_t)

  chl_var <- if ("CHL" %in% names(nc$var)) "CHL" else
             if ("chl" %in% names(nc$var)) "chl" else
             stop("No encontre variable CHL en ", nc_path)
  chl <- ncvar_get(nc, chl_var)
  d <- dim(chl)
  cat(sprintf("[appE-env] CHL dims = (%s)\n", paste(d, collapse = "x")))
  stopifnot(dim(chl)[1] == length(lon),
            dim(chl)[2] == length(lat),
            dim(chl)[3] == length(tim))

  out <- list()
  for (dn in names(domains)) {
    rng <- domains[[dn]]
    w   <- cos_lat_weights(lon, lat, rng$lat, rng$lon)
    if (w$n_cells == 0) stop("Dominio ", dn, " sin celdas en CHL grid")
    mon_mean <- apply(chl, 3, function(slice) {
      ok <- !is.na(slice) & w$W > 0
      if (!any(ok)) return(NA_real_)
      sum(slice[ok] * w$W[ok]) / sum(w$W[ok])
    })
    out[[dn]] <- data.frame(
      domain = dn,
      date   = date_v,
      chl    = as.numeric(mon_mean)
    )
    cat(sprintf("[appE-env]  D=%s  n_cells=%d  CHL mensual rango [%.3f, %.3f]\n",
                dn, w$n_cells, min(out[[dn]]$chl, na.rm = TRUE),
                max(out[[dn]]$chl, na.rm = TRUE)))
  }
  bind_rows(out)
}

# -----------------------------------------------------------------------------
# 3. Agregar a anual + center por media 2000-2024 (idem fit principal)
# -----------------------------------------------------------------------------
build_annual_env <- function(sst_mon, chl_mon, window) {
  sst_yr <- sst_mon %>%
    mutate(year = lubridate::year(date)) %>%
    filter(year %in% window) %>%
    group_by(domain, year) %>%
    summarise(n_months_sst = sum(!is.na(sst)),         # contar ANTES de reasignar
              sst          = mean(sst, na.rm = TRUE),
              .groups = "drop")

  chl_yr <- chl_mon %>%
    mutate(year = lubridate::year(date)) %>%
    filter(year %in% window) %>%
    group_by(domain, year) %>%
    summarise(n_months_chl = sum(!is.na(chl)),         # idem
              chl          = mean(chl, na.rm = TRUE),
              .groups = "drop")

  env <- full_join(sst_yr, chl_yr, by = c("domain", "year")) %>%
    arrange(domain, year) %>%
    group_by(domain) %>%
    mutate(
      SST_c    = sst       - mean(sst,       na.rm = TRUE),
      logCHL_c = log(chl)  - mean(log(chl),  na.rm = TRUE)
    ) %>%
    ungroup()

  # Diagnostico de cobertura
  cov <- env %>%
    group_by(domain) %>%
    summarise(
      n_years        = n(),
      n_full_sst     = sum(n_months_sst == 12, na.rm = TRUE),
      n_full_chl     = sum(n_months_chl == 12, na.rm = TRUE),
      sst_mean       = mean(sst, na.rm = TRUE),
      sst_sd         = sd(sst, na.rm = TRUE),
      chl_mean       = mean(chl, na.rm = TRUE),
      chl_sd         = sd(chl, na.rm = TRUE),
      .groups = "drop"
    )
  cat("\n[appE-env] Cobertura mensual por dominio (de 12 meses esperados/anio):\n")
  print(cov)
  list(env = env, cov = cov)
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("appE.env.run_main", TRUE))) {

  cat(strrep("=", 72), "\n", sep = "")
  cat("Apendice E -- env anomalies sobre 3 dominios anidados\n")
  cat("Centering: media 2000-2024 (idem 08_fit_t4b_full.R)\n")
  cat(strrep("=", 72), "\n\n", sep = "")

  sst_mon <- load_sst_monthly_by_domain(APP_E_NC_SST, APP_E_DOMAINS)
  chl_mon <- load_chl_monthly_by_domain(APP_E_NC_CHL, APP_E_DOMAINS)

  res <- build_annual_env(sst_mon, chl_mon, APP_E_WINDOW)

  out_csv <- file.path(APP_E_OUT_DIR, "env_extended_3domains_2000_2024.csv")
  readr::write_csv(res$env, out_csv)
  cat(sprintf("\n[appE-env] Escribi: %s  (%d filas)\n",
              out_csv, nrow(res$env)))

  diag_csv <- file.path(APP_E_OUT_DIR, "env_extended_3domains_diagnostics.csv")
  readr::write_csv(res$cov, diag_csv)
  cat(sprintf("[appE-env] Escribi: %s\n", diag_csv))

  # Sanity: correlaciones cross-dominio (deberia haber correlacion alta en SST,
  # menor en logCHL).
  wide_sst <- res$env %>%
    select(domain, year, SST_c) %>%
    tidyr::pivot_wider(names_from = domain, values_from = SST_c)
  wide_chl <- res$env %>%
    select(domain, year, logCHL_c) %>%
    tidyr::pivot_wider(names_from = domain, values_from = logCHL_c)
  cat("\n[appE-env] Correlaciones SST_c entre dominios:\n")
  print(round(cor(wide_sst[, names(APP_E_DOMAINS)], use = "complete.obs"), 3))
  cat("\n[appE-env] Correlaciones logCHL_c entre dominios:\n")
  print(round(cor(wide_chl[, names(APP_E_DOMAINS)], use = "complete.obs"), 3))

  invisible(res)
}
