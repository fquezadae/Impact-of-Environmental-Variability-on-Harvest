# =============================================================================
# FONDECYT -- _weather_channel_utils.R
#
# Direct weather channel para T7 (13_trip_comparative_statics.R). Implementa
# la ruta vessel-specific A: para cada (vessel, model, scenario, window) toma
# la serie diaria de wind speed al COG del vessel, le suma el shift Deltawind del
# CMIP6, recuenta exceedances del threshold de 8 m/s y entrega Deltadays_bw
# (anual mediano) por vessel x escenario.
#
# Esto cierra la inconsistencia paper-codigo identificada 2026-04-30: el sec 3.4
# del manuscrito promete dos canales de proyeccion (direct weather + indirect
# biomass), pero el T7 pre-2026-04-30 solo propagaba el indirect a traves de
# r_eff. Aqui construimos el insumo para que `t6_compute_factor_trips()`
# agregue + beta_weather x Deltadays_bw al exponente del factor_trips, con beta_weather
# del NB fitteado in-script.
#
# Decisiones (ver chat 2026-04-30 con Felipe):
#   - VERSION A (vessel-specific) sobre A' (zonal): mantiene paralelismo con
#     el resto del pipeline (omega y H_alloc_hist son vessel-specific) y no
#     contamina la decomposicion within-vessel del Apendice G.
#   - Empirical CDF: shift directo sobre la serie diaria de speed_max al COG
#     y reconteo de exceedances. No asume distribucion parametrica del wind
#     diario (que tiene colas pesadas cerca del threshold).
#   - beta_weather literal del NB (incluido el IND no-significativo, beta=-0.0001):
#     no se impone beta_IND=0. Honesto y consistente con la prosa.
#
# Magnitudes esperadas (sanity, post-implementacion):
#   - ART: Deltalog(trips)_direct = beta_w x Deltadays_bw ~ -0.002 x 5-15 = -1 a -3%
#     extra -> tabla 5 SSP585 end aprox. -10 a -12% (vs -9.5% actual).
#   - IND: ~ 0 por beta_weather no-sig (-0.0001).
#   - Asimetria ART vs IND se refuerza: weather-limit afecta solo ART.
#
# Entradas:
#   - dirdata + "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"
#       Daily speed_max @ 0.125deg grid, 2012-2025 (mismo archivo que usa
#       poisson_model.R sec 9 para construir days_bad_weather del panel).
#   - data/trips/log_spf.rds  -> COG vessel via lat/lon weighted by catch
#   - data/cmip6/deltas_ensemble.csv (var = "wind_speed", per modelo CMIP6)
#
# Salida cacheada:
#   - data/cmip6/delta_days_bw_vessel.rds
#       data.table con (COD_BARCO, model, scenario, window, days_bw_hist,
#       days_bw_proj, delta_days_bw). El cache se invalida borrando el rds.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(data.table)
  library(lubridate)
})

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------

WC_WIND_THRESHOLD <- 8L          # m/s (identico a poisson_model.R sec 9)
WC_WINDOW_YEARS   <- 2013:2024   # alineado con panel NB (Ley 20.657)

WC_LOG_SPF_RDS    <- "data/trips/log_spf.rds"
WC_DELTAS_CSV     <- "data/cmip6/deltas_ensemble.csv"
WC_CACHE_RDS      <- "data/cmip6/delta_days_bw_vessel.rds"

# Path del rds diario de wind. Depende de dirdata (definido en config.R por
# usuario). Lo envolvemos como funcion para evaluarlo lazy y permitir que el
# script funcione si dirdata no esta cargado al sourcear este utils.
wc_wind_daily_path <- function() {
  if (!exists("dirdata", envir = globalenv())) {
    stop("dirdata no definido. Ejecutar source('R/00_config/config.R') antes.")
  }
  paste0(get("dirdata", envir = globalenv()),
         "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds")
}

# -----------------------------------------------------------------------------
# Helper: nearest grid cell por COG (replica poisson_model.R sec 9)
# -----------------------------------------------------------------------------

wc_find_nearest_grid <- function(target_lat, target_lon, grid_df) {
  dists <- sqrt((grid_df$lat - target_lat)^2 + (grid_df$lon - target_lon)^2)
  idx   <- which.min(dists)
  data.frame(grid_lat = grid_df$lat[idx], grid_lon = grid_df$lon[idx])
}

# -----------------------------------------------------------------------------
# COG por vessel (replica poisson_model.R sec 7-8 sin filtro cog_stable: lo
# unico que necesitamos es la asignacion al grid cell mas cercano, no la
# clasificacion zonal).
# -----------------------------------------------------------------------------

wc_build_cog_vessel <- function(log_spf_path = WC_LOG_SPF_RDS) {
  log_spf <- readRDS(log_spf_path)

  log_spf <- log_spf %>%
    dplyr::mutate(
      lat_deg = -(floor(LATITUD / 10000)  + (LATITUD  %% 10000) / 6000),
      lon_deg = -(floor(LONGITUD / 10000) + (LONGITUD %% 10000) / 6000)
    )

  cog_vessel <- log_spf %>%
    dplyr::filter(
      !is.na(lat_deg), !is.na(lon_deg),
      lat_deg < -30, lat_deg > -46,
      lon_deg < -70, lon_deg > -80,
      !is.na(CAPTURA_RETENIDA), CAPTURA_RETENIDA > 0
    ) %>%
    dplyr::group_by(COD_BARCO) %>%
    dplyr::summarise(
      cog_lat = stats::weighted.mean(lat_deg, w = CAPTURA_RETENIDA),
      cog_lon = stats::weighted.mean(lon_deg, w = CAPTURA_RETENIDA),
      n_hauls = dplyr::n(),
      .groups = "drop"
    )

  cog_vessel
}

# -----------------------------------------------------------------------------
# days_bw historico per (lat, lon): mediana cross-year de count(speed_max > 8)
# -----------------------------------------------------------------------------

wc_compute_grid_days_bw_hist <- function(env_dt,
                                          threshold = WC_WIND_THRESHOLD,
                                          years = WC_WINDOW_YEARS) {
  env <- as.data.table(env_dt)
  env <- env[, .(lat, lon, year = year(date), speed_max)]
  env <- env[year %in% years]

  bw_yr <- env[, .(days_bw = sum(speed_max > threshold, na.rm = TRUE)),
               by = .(lat, lon, year)]

  bw_yr[, .(days_bw_hist = median(days_bw, na.rm = TRUE)),
        by = .(lat, lon)]
}

# -----------------------------------------------------------------------------
# days_bw projected per (lat, lon, model, scenario, window): mediana cross-year
# de count((speed_max + Deltawind) > threshold). Equivalente a recontar contra un
# threshold ajustado (8 - Deltawind), pero mantenemos la formulacion shift-the-
# series por claridad y porque generaliza a metodos no-uniformes (e.g.
# Deltawind percentil-dependiente, no implementado aqui).
#
# Implementacion: data.table + crossing scenarios. Para evitar replicar env
# (~10M filas) por escenario, iteramos sobre scenarios. Cada pasada es ~1-2s.
# -----------------------------------------------------------------------------

wc_compute_grid_days_bw_proj <- function(env_dt, scen_wind,
                                          threshold = WC_WIND_THRESHOLD,
                                          years = WC_WINDOW_YEARS,
                                          verbose = TRUE) {
  env <- as.data.table(env_dt)
  env <- env[, .(lat, lon, year = year(date), speed_max)]
  env <- env[year %in% years]

  scen <- as.data.table(scen_wind)
  proj_list <- vector("list", nrow(scen))

  for (i in seq_len(nrow(scen))) {
    dw <- scen$delta_wind[i]
    bw_yr <- env[, .(days_bw = sum((speed_max + dw) > threshold,
                                    na.rm = TRUE)),
                  by = .(lat, lon, year)]
    bw_med <- bw_yr[, .(days_bw_proj = median(days_bw, na.rm = TRUE)),
                    by = .(lat, lon)]
    bw_med[, `:=`(model    = scen$model[i],
                  scenario = scen$scenario[i],
                  window   = scen$window[i],
                  delta_wind = dw)]
    proj_list[[i]] <- bw_med
    if (verbose && (i %% 5L == 0L || i == nrow(scen))) {
      cat(sprintf("  [weather_channel] grid days_bw proj: %d/%d scenarios\n",
                  i, nrow(scen)))
    }
  }

  rbindlist(proj_list)
}

# -----------------------------------------------------------------------------
# Deltadays_bw vessel-specific: pipeline completo end-to-end con cache en disco.
#
# use_cache = TRUE -> lee data/cmip6/delta_days_bw_vessel.rds si existe.
# force = TRUE     -> recomputa e ignora cache.
# -----------------------------------------------------------------------------

wc_compute_vessel_delta_days_bw <- function(use_cache = TRUE,
                                             force = FALSE,
                                             verbose = TRUE) {
  if (use_cache && !force && file.exists(WC_CACHE_RDS)) {
    if (verbose) cat("[weather_channel] Cache hit:", WC_CACHE_RDS, "\n")
    return(readRDS(WC_CACHE_RDS))
  }

  if (verbose) cat("[weather_channel] Recomputing Deltadays_bw vessel-specific\n")

  # 1. Cargar wind diario y construir grid
  env_dt <- readRDS(wc_wind_daily_path())
  if (verbose) cat(sprintf("  env_dt loaded: %s rows\n",
                            formatC(nrow(env_dt), format = "d",
                                    big.mark = ",")))

  env_grid <- as_tibble(env_dt) %>%
    dplyr::distinct(lat, lon) %>%
    dplyr::filter(!is.na(lat), !is.na(lon))

  # 2. days_bw historico per grid
  bw_hist <- wc_compute_grid_days_bw_hist(env_dt)
  if (verbose) cat(sprintf("  days_bw hist: %d grid cells, mean=%.1f d/y\n",
                            nrow(bw_hist),
                            mean(bw_hist$days_bw_hist, na.rm = TRUE)))

  # 3. Cargar Deltawind del CSV CMIP6
  scen_wind <- fread(WC_DELTAS_CSV)[var == "wind_speed",
                                     .(model, scenario, window,
                                       delta_wind = delta)]
  if (verbose) cat(sprintf("  CMIP6 wind scenarios: %d (model x ssp x window)\n",
                            nrow(scen_wind)))

  # 4. days_bw projected per grid x scenario
  bw_proj <- wc_compute_grid_days_bw_proj(env_dt, scen_wind, verbose = verbose)

  # 5. Deltadays_bw per grid x scenario
  delta_grid <- merge(bw_proj,
                      as.data.table(bw_hist),
                      by = c("lat", "lon"),
                      all.x = TRUE)
  delta_grid[, delta_days_bw := days_bw_proj - days_bw_hist]

  # 6. COG vessel + nearest grid
  cog_vessel <- wc_build_cog_vessel()
  if (verbose) cat(sprintf("  COG vessels: %d\n", nrow(cog_vessel)))

  cog_with_grid <- cog_vessel %>%
    dplyr::rowwise() %>%
    dplyr::mutate(.nearest = list(wc_find_nearest_grid(cog_lat, cog_lon,
                                                        env_grid))) %>%
    tidyr::unnest(.nearest) %>%
    dplyr::ungroup() %>%
    dplyr::select(COD_BARCO, grid_lat, grid_lon)

  # 7. Merge: vessel x scenario
  vessel_delta <- merge(as.data.table(cog_with_grid),
                         delta_grid,
                         by.x = c("grid_lat", "grid_lon"),
                         by.y = c("lat", "lon"),
                         allow.cartesian = TRUE)

  out <- vessel_delta[, .(COD_BARCO, model, scenario, window,
                          delta_wind, days_bw_hist, days_bw_proj,
                          delta_days_bw)]
  setkey(out, COD_BARCO, model, scenario, window)

  # 8. Cache
  dir.create(dirname(WC_CACHE_RDS), recursive = TRUE, showWarnings = FALSE)
  saveRDS(out, WC_CACHE_RDS)
  if (verbose) {
    cat(sprintf("[weather_channel] Cache saved: %s (%d rows)\n",
                WC_CACHE_RDS, nrow(out)))
    sanity <- out[, .(mean_delta_days = round(mean(delta_days_bw,
                                                    na.rm = TRUE), 2),
                      median_delta_days = round(median(delta_days_bw,
                                                        na.rm = TRUE), 2),
                      n_vessels = uniqueN(COD_BARCO)),
                   by = .(scenario, window)]
    cat("[weather_channel] Sanity Deltadays_bw cross-vessel mean/median:\n")
    print(sanity)
    cat("\n")
  }

  out
}
