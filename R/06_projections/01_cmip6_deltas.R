# =============================================================================
# FONDECYT -- 01_cmip6_deltas.R   (ENSEMBLE 6 modelos)
#
# Computa deltas CMIP6 sobre la caja Centro-Sur Chile, iterando sobre los 6
# modelos del ensemble descargado en 2026-04-28 PM:
#
#   IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, MPI-ESM1-2-HR
#
# Variables:
#   sst        (de tos, ORCA curvilinear) -- aditivo en C
#   logchl     (de chlos, ORCA curvilinear) -- aditivo en log-CHL adimensional
#   uas        (regular, atmospheric)        -- aditivo en m/s
#   vas        (regular, atmospheric)        -- aditivo en m/s
#   wind_speed (derivado: sqrt(uas^2+vas^2)) -- aditivo en m/s
#
# Convencion de baseline -- decidida 2026-04-29 PM:
#   Splice 2000-2024 = hist 2000-2014 + ssp245 2015-2024  (apples-to-apples
#   con el centering de T4b principal y appendix E, ver
#   project_cmip6_baseline_splice_decision.md). CMIP6 hist corta en 2014, por
#   eso requerimos splice; usar 1995-2014 como antes introducia sesgo de
#   ~0.15-0.25 C respecto al fit.
#
#   Override: CESM2/chlos no tiene ssp245 publicado (NCAR). Splice con ssp585
#   para 2015-2024 (defendible: ssp245 ~ ssp585 en near-term <2040). Esto
#   mantiene CESM2 en el ensemble para chlos/ssp585 future window. Para
#   chlos/ssp245 future, CESM2 se dropea.
#
# Convencion de delta:
#   Delta crudo en unidades fisicas, NO z-scored. T4b consume anomalias
#   centradas en C / log-CHL / m/s directamente (ver `08_fit_t4b_full.R`
#   lineas 128-131). Los priors rho estan calibrados a esa escala.
#
# CESM2 huecos conocidos (catalogo NCAR, ver `project_paper1_next_steps.md`):
#   - chlos/ssp245                        -> drop esa celda
#   - uas    x {hist, ssp245, ssp585}    -> drop CESM2 de uas, vas, wind_speed
#   - vas    x {hist, ssp245, ssp585}
#
# Entradas:
#   D:/GitHub/climate_projections/CMIP6/CMIP6_<model>_<var>_<exp>_monthly.nc
#
# Salidas:
#   data/cmip6/deltas_ensemble.csv   (long format)
#       columnas: model, scenario, window, var, delta,
#                 baseline_mean, future_mean,
#                 n_years_baseline, n_years_future, splice_exp
#   data/cmip6/deltas_ensemble_log.csv  (registro de combos saltados)
#
# Agregacion T4b-compatible:
#   1) Por anio: chl_year/sst_year/wind_year = mean sobre (lon, lat, mes-en-anio)
#   2) Para chlos: log(chl_year) (floor 0.01) -- igual que el fit
#   3) Mean a traves de anios en cada ventana
#   4) delta = mean_anios(future) - mean_anios(baseline_spliced)
#
# Importante: para chlos, mean(log(chl_year)) != log(mean(chl_year)) por
# Jensen, asi que el orden importa. T4b usa log al nivel de anio (ver
# `08_fit_t4b_full.R` linea 124-130). Esta convencion lo respeta.
#
# Corre con:
#   source("R/06_projections/01_cmip6_deltas.R")
# =============================================================================

suppressPackageStartupMessages({
  library(ncdf4)
  library(data.table)
})

source("R/00_config/config.R")

# =============================================================================
# CONFIGURACION
# =============================================================================

CMIP6_DIR  <- "D:/GitHub/climate_projections/CMIP6"
OUTPUT_DIR <- "data/cmip6"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

OUTPUT_CSV     <- file.path(OUTPUT_DIR, "deltas_ensemble.csv")
OUTPUT_LOG_CSV <- file.path(OUTPUT_DIR, "deltas_ensemble_log.csv")

# Caja Centro-Sur EEZ -- matchea con T4b (anch/sard CS) y con T5 actual.
BBOX <- list(lon_min = -80, lon_max = -70,
             lat_min = -42, lat_max = -30)

# 6 modelos del ensemble
MODELS <- c("IPSL-CM6A-LR", "GFDL-ESM4", "CESM2",
            "CNRM-ESM2-1",  "UKESM1-0-LL", "MPI-ESM1-2-HR")

# Variables principales (la quinta -- wind_speed -- es derivada de uas+vas)
VARS_BASE <- c("tos", "chlos", "uas", "vas")

# Experimentos
SSPS <- c("ssp245", "ssp585")

# Ventanas
BASELINE_HIST   <- c(as.Date("2000-01-01"), as.Date("2014-12-31"))
BASELINE_SPLICE <- c(as.Date("2015-01-01"), as.Date("2024-12-31"))
WINDOWS_FUT <- list(
  mid = c(as.Date("2041-01-01"), as.Date("2060-12-31")),
  end = c(as.Date("2081-01-01"), as.Date("2100-12-31"))
)

# Override de splice por (model, var). Default ssp245.
SPLICE_OVERRIDE <- list(
  `CESM2.chlos` = "ssp585"
)

# Mapa var-stan-name -> nombre del CSV largo. wind_speed se agrega al final.
VAR_OUT_NAME <- c(tos = "sst", chlos = "logchl",
                  uas = "uas", vas = "vas")

# =============================================================================
# UTILIDADES
# =============================================================================

model_token <- function(m) tolower(gsub("-", "_", m))

filepath_cmip6 <- function(model, var, exp) {
  file.path(CMIP6_DIR,
            sprintf("CMIP6_%s_%s_%s_monthly.nc",
                    model_token(model), var, exp))
}

# Agrega dt(lon, lat, date, value) a escala T4b-compatible:
#   1) Mean(value) por anio (sobre celdas y meses dentro del anio)
#   2) Si var == "chlos", aplica log(pmax(., 0.01)) al chl_year (igual que T4b:
#      logCHL_c = log(chl_year) - mean(log(chl_year)), no mean(log(.)) crudo)
#   3) Retorna mean a traves de anios + n_years + n_obs
#
# Para tos/uas/vas/wind_speed la aggregacion lineal cell-month vs year-level
# da el mismo numero (red balanceado), pero forzamos el camino year-first
# por consistencia y legibilidad.
agg_year_mean <- function(dt, var) {
  dtc <- copy(dt)
  dtc[, year := data.table::year(date)]
  per_year <- dtc[, .(value_year = mean(value, na.rm = TRUE)), by = year]
  if (var == "chlos") {
    per_year[, value_year := log(pmax(value_year, 0.01))]
  }
  list(mean    = mean(per_year$value_year, na.rm = TRUE),
       n_years = nrow(per_year),
       n_obs   = nrow(dtc))
}

# Convierte tiempo CMIP6 a Date Gregoriano respetando calendario.
#   - standard / gregorian / proleptic_gregorian / julian: aritmetica Gregoriana directa
#   - 360_day: convierte index de mes asumiendo 30-day months y sintetiza Date(YYYY-MM-15)
#   - noleap / 365_day / all_leap: drift ~0.06 dia/anio, aceptable para monthly
# UKESM1-0-LL es 360_day, el resto del ensemble es Gregoriano.
cmip6_dates <- function(t_var, t_units, calendar) {
  parts  <- strsplit(t_units, " since ", fixed = TRUE)[[1]]
  unit   <- tolower(trimws(parts[1]))
  origin_s <- trimws(sub(" .*", "", parts[2]))
  origin <- as.Date(origin_s)

  cal <- if (is.null(calendar) || identical(calendar, "")) "standard" else calendar

  if (cal %in% c("360_day", "360")) {
    if (unit != "days") stop("Calendario 360_day esperaba 'days since', no '", unit, "'")
    # Asume monthly mid-month stamps: 15, 45, 75, ... (independiente del 1er valor)
    month_idx <- round((as.numeric(t_var) - 15) / 30)
    y0 <- as.integer(format(origin, "%Y"))
    m0 <- as.integer(format(origin, "%m"))
    total_m  <- m0 + month_idx - 1L
    yr <- y0 + total_m %/% 12L
    mo <- (total_m %% 12L) + 1L
    return(as.Date(sprintf("%04d-%02d-15", yr, mo)))
  }

  mult <- switch(unit,
                 "seconds" = 1 / 86400,
                 "minutes" = 1 / 1440,
                 "hours"   = 1 / 24,
                 "days"    = 1,
                 stop("Unidad de tiempo no soportada: ", unit))
  as.Date(origin + as.numeric(t_var) * mult)
}

# Read CMIP6 netCDF, subsetting time + bbox. Maneja regular y curvilinear.
# Returns data.table(lon, lat, date, month, value) o NULL si vacio.
read_cmip6_var <- function(filepath, varname, date_range, bbox) {

  if (!file.exists(filepath)) return(NULL)

  nc <- nc_open(filepath)
  on.exit(nc_close(nc))

  t_var    <- ncvar_get(nc, "time")
  t_units  <- ncatt_get(nc, "time", "units")$value
  cal_attr <- ncatt_get(nc, "time", "calendar")
  t_calend <- if (isTRUE(cal_attr$hasatt)) cal_attr$value else "standard"
  dates    <- cmip6_dates(t_var, t_units, t_calend)

  t_idx <- which(dates >= date_range[1] & dates <= date_range[2])
  if (length(t_idx) == 0) return(NULL)

  # Deteccion de grid tolerante a varios naming conventions:
  #   - nav_lon/nav_lat                (IPSL, GFDL/Omon, CNRM, MPI ORCA)
  #   - lon/lat 2D                     (CESM2 POP)
  #   - longitude/latitude 2D          (UKESM1-0-LL ORCA)
  #   - lon/lat 1D (dim o var)         (atmospheric uas/vas regular)
  #   - longitude/latitude 1D          (algunos modelos atm)
  pick <- function(names_try) {
    for (n in names_try) {
      if (n %in% names(nc$var)) {
        v <- ncvar_get(nc, n)
        return(list(values = v, is_2d = !is.null(dim(v)) && length(dim(v)) == 2L))
      }
      if (n %in% names(nc$dim)) {
        return(list(values = nc$dim[[n]]$vals, is_2d = FALSE))
      }
    }
    NULL
  }
  lon_info <- pick(c("nav_lon", "lon", "longitude"))
  lat_info <- pick(c("nav_lat", "lat", "latitude"))
  if (is.null(lon_info) || is.null(lat_info)) {
    stop("Grid desconocido en ", basename(filepath),
         " -- vars=[", paste(names(nc$var), collapse = ","),
         "] dims=[", paste(names(nc$dim), collapse = ","), "]")
  }
  if (lon_info$is_2d || lat_info$is_2d) {
    lon2d <- lon_info$values
    lat2d <- lat_info$values
    grid_type <- "curvilinear"
    # POP / algunos ORCA publican lon en 0-360. Normalizar para bbox negativo.
    lon2d <- ifelse(lon2d > 180, lon2d - 360, lon2d)
  } else {
    lon1d <- lon_info$values
    lat1d <- lat_info$values
    grid_type <- "regular"
  }

  v <- nc$var[[varname]]
  dim_names <- sapply(v$dim, function(d) d$name)
  start_vec <- rep(1, length(dim_names))
  count_vec <- rep(-1, length(dim_names))
  time_pos <- which(dim_names == "time")
  start_vec[time_pos] <- min(t_idx)
  count_vec[time_pos] <- length(t_idx)
  arr <- ncvar_get(nc, varname, start = start_vec, count = count_vec)

  if (grid_type == "regular") {
    if (all(lon1d >= 0) && bbox$lon_min < 0) {
      lon_idx <- which(lon1d >= bbox$lon_min + 360 &
                         lon1d <= bbox$lon_max + 360)
    } else {
      lon_idx <- which(lon1d >= bbox$lon_min & lon1d <= bbox$lon_max)
    }
    lat_idx <- which(lat1d >= bbox$lat_min & lat1d <= bbox$lat_max)

    lon_sub <- lon1d[lon_idx]; lat_sub <- lat1d[lat_idx]
    arr_sub <- arr[lon_idx, lat_idx, , drop = FALSE]
    lon_sub <- ifelse(lon_sub > 180, lon_sub - 360, lon_sub)

    dt <- CJ(lon = lon_sub, lat = lat_sub, date = dates[t_idx])
    setorder(dt, lon, lat, date)
    dt[, value := as.vector(arr_sub)]
  } else {
    nt <- length(t_idx)
    dt_list <- vector("list", nt)
    for (i in seq_len(nt)) {
      slice <- arr[, , i]
      dt_i <- data.table(lon = as.vector(lon2d),
                         lat = as.vector(lat2d),
                         value = as.vector(slice))
      dt_i <- dt_i[lon >= bbox$lon_min & lon <= bbox$lon_max &
                     lat >= bbox$lat_min & lat <= bbox$lat_max &
                     !is.na(value)]
      dt_i[, date := dates[t_idx[i]]]
      dt_list[[i]] <- dt_i
    }
    dt <- rbindlist(dt_list)
  }

  if (nrow(dt) == 0L) return(NULL)
  dt[, month := data.table::month(date)]
  dt[]
}

# =============================================================================
# DELTAS POR (model, var) -- baseline spliced + 4 deltas (ssp x window)
# =============================================================================

splice_exp_for <- function(model, var) {
  key <- paste(model, var, sep = ".")
  if (!is.null(SPLICE_OVERRIDE[[key]])) return(SPLICE_OVERRIDE[[key]])
  "ssp245"
}

# Carga baseline 2000-2024 spliced para (model, var). Returns data.table o NULL.
load_baseline_spliced <- function(model, var) {
  hist_dt <- read_cmip6_var(filepath_cmip6(model, var, "historical"),
                            var, BASELINE_HIST, BBOX)
  if (is.null(hist_dt)) return(NULL)

  splice_exp <- splice_exp_for(model, var)
  splice_dt <- read_cmip6_var(filepath_cmip6(model, var, splice_exp),
                              var, BASELINE_SPLICE, BBOX)
  if (is.null(splice_dt)) return(NULL)

  list(dt = rbind(hist_dt, splice_dt), splice_exp = splice_exp)
}


# Procesa una variable simple (tos, chlos, uas, vas). Returns rows.
process_simple_var <- function(model, var) {
  base <- load_baseline_spliced(model, var)
  if (is.null(base)) {
    return(list(rows = NULL,
                log = data.table(model = model, var = var,
                                 stage = "baseline",
                                 reason = "archivo hist o splice missing")))
  }
  base_agg <- agg_year_mean(base$dt, var)

  rows <- list(); skipped <- list()
  for (ssp in SSPS) {
    for (wname in names(WINDOWS_FUT)) {
      fut_file <- filepath_cmip6(model, var, ssp)
      fut_dt <- read_cmip6_var(fut_file, var, WINDOWS_FUT[[wname]], BBOX)
      if (is.null(fut_dt)) {
        skipped[[length(skipped) + 1L]] <- data.table(
          model = model, var = var,
          stage = sprintf("future/%s/%s", ssp, wname),
          reason = "archivo missing o sin meses en rango")
        next
      }
      fut_agg <- agg_year_mean(fut_dt, var)
      rows[[length(rows) + 1L]] <- data.table(
        model              = model,
        scenario           = ssp,
        window             = wname,
        var                = VAR_OUT_NAME[[var]],
        delta              = fut_agg$mean - base_agg$mean,
        baseline_mean      = base_agg$mean,
        future_mean        = fut_agg$mean,
        n_years_baseline   = base_agg$n_years,
        n_years_future     = fut_agg$n_years,
        splice_exp         = base$splice_exp
      )
    }
  }
  list(rows = rbindlist(rows), log = rbindlist(skipped))
}

# Procesa wind_speed para un modelo. Necesita uas y vas en TODOS los exp.
#
# Convencion: spatial-aggregate por mes ANTES de combinar uas/vas. Esto evita
# problemas de grids divergentes entre uas y vas (UKESM publica uas en u-points
# y vas en v-points del C-grid, distinto numero de celdas en bbox), y reduce
# el merge a "date" 1D (robusto a float precision en lat/lon).
#
# Sesgo por Jensen: sqrt(<uas>^2 + <vas>^2) vs <sqrt(uas^2 + vas^2)> es chico
# (<2%) para bbox pequena con poca variabilidad direccional intra-mes.
# Trade-off explicito; consistente entre modelos.
process_wind_speed <- function(model) {
  exps <- c("historical", SSPS)
  uas_files <- setNames(sapply(exps, function(e) filepath_cmip6(model,"uas",e)), exps)
  vas_files <- setNames(sapply(exps, function(e) filepath_cmip6(model,"vas",e)), exps)

  if (any(!file.exists(uas_files)) || any(!file.exists(vas_files))) {
    return(list(rows = NULL,
                log = data.table(model = model, var = "wind_speed",
                                 stage = "all",
                                 reason = "uas/vas incompletos en algun exp")))
  }

  # Helper: read + spatial-mean per timestamp -> data.table(date, value)
  read_monthly_scalar <- function(file, var, drange) {
    dt <- read_cmip6_var(file, var, drange, BBOX)
    if (is.null(dt)) return(NULL)
    dt[, .(value = mean(value, na.rm = TRUE)), by = date]
  }

  # Combina uas+vas a wind_speed monthly (sqrt suma cuadrados) sobre date comun
  combine_uv_monthly <- function(u_dt, v_dt, tag = "") {
    if (is.null(u_dt) || is.null(v_dt)) return(NULL)
    m <- merge(u_dt, v_dt, by = "date", suffixes = c("_uas", "_vas"))
    if (nrow(m) == 0) {
      cat(sprintf("    [wind %s] merge by date -> 0 filas\n", tag))
      return(NULL)
    }
    if (nrow(m) != nrow(u_dt) || nrow(m) != nrow(v_dt)) {
      cat(sprintf("    [wind %s] partial date overlap: nrow uas=%d vas=%d merged=%d\n",
                  tag, nrow(u_dt), nrow(v_dt), nrow(m)))
    }
    m[, value := sqrt(value_uas^2 + value_vas^2)]
    m[, .(date, value)]
  }

  uas_hist <- read_monthly_scalar(uas_files["historical"], "uas", BASELINE_HIST)
  vas_hist <- read_monthly_scalar(vas_files["historical"], "vas", BASELINE_HIST)
  uas_sp   <- read_monthly_scalar(uas_files["ssp245"], "uas", BASELINE_SPLICE)
  vas_sp   <- read_monthly_scalar(vas_files["ssp245"], "vas", BASELINE_SPLICE)

  bh <- combine_uv_monthly(uas_hist, vas_hist, paste(model, "hist"))
  bs <- combine_uv_monthly(uas_sp,   vas_sp,   paste(model, "splice"))
  if (is.null(bh) || is.null(bs)) {
    return(list(rows = NULL,
                log = data.table(model = model, var = "wind_speed",
                                 stage = "baseline",
                                 reason = "no merge uas/vas baseline (ver consola)")))
  }
  base <- rbind(bh, bs)
  base_agg <- agg_year_mean(base, "wind_speed")

  rows <- list(); skipped <- list()
  for (ssp in SSPS) {
    for (wname in names(WINDOWS_FUT)) {
      uas_fut <- read_monthly_scalar(uas_files[ssp], "uas", WINDOWS_FUT[[wname]])
      vas_fut <- read_monthly_scalar(vas_files[ssp], "vas", WINDOWS_FUT[[wname]])
      fut <- combine_uv_monthly(uas_fut, vas_fut, paste(model, ssp, wname))
      if (is.null(fut)) {
        skipped[[length(skipped) + 1L]] <- data.table(
          model = model, var = "wind_speed",
          stage = sprintf("future/%s/%s", ssp, wname),
          reason = "no merge uas/vas (ver consola)")
        next
      }
      fut_agg <- agg_year_mean(fut, "wind_speed")
      rows[[length(rows) + 1L]] <- data.table(
        model              = model,
        scenario           = ssp,
        window             = wname,
        var                = "wind_speed",
        delta              = fut_agg$mean - base_agg$mean,
        baseline_mean      = base_agg$mean,
        future_mean        = fut_agg$mean,
        n_years_baseline   = base_agg$n_years,
        n_years_future     = fut_agg$n_years,
        splice_exp         = "ssp245"
      )
    }
  }
  list(rows = rbindlist(rows), log = rbindlist(skipped))
}

# =============================================================================
# ORQUESTADOR
# =============================================================================

compute_ensemble_deltas <- function() {

  cat(strrep("=", 70), "\n", sep = "")
  cat("CMIP6 ensemble deltas -- 6 modelos, baseline splice 2000-2024\n")
  cat(sprintf("Bbox: lon [%.0f, %.0f] x lat [%.0f, %.0f]\n",
              BBOX$lon_min, BBOX$lon_max, BBOX$lat_min, BBOX$lat_max))
  cat(strrep("=", 70), "\n\n", sep = "")

  all_rows <- list(); all_log <- list()

  for (model in MODELS) {
    cat("---", model, "---\n")
    for (var in VARS_BASE) {
      cat(sprintf("  %s ... ", var))
      res <- process_simple_var(model, var)
      if (!is.null(res$rows) && nrow(res$rows) > 0) {
        cat(sprintf("%d filas\n", nrow(res$rows)))
        all_rows[[length(all_rows) + 1L]] <- res$rows
      } else {
        cat("DROP\n")
      }
      if (!is.null(res$log) && nrow(res$log) > 0) {
        all_log[[length(all_log) + 1L]] <- res$log
      }
    }
    cat("  wind_speed ... ")
    res_w <- process_wind_speed(model)
    if (!is.null(res_w$rows) && nrow(res_w$rows) > 0) {
      cat(sprintf("%d filas\n", nrow(res_w$rows)))
      all_rows[[length(all_rows) + 1L]] <- res_w$rows
    } else {
      cat("DROP\n")
    }
    if (!is.null(res_w$log) && nrow(res_w$log) > 0) {
      all_log[[length(all_log) + 1L]] <- res_w$log
    }
  }

  out <- rbindlist(all_rows, use.names = TRUE)
  log <- if (length(all_log) > 0) rbindlist(all_log, use.names = TRUE)
         else data.table(model=character(), var=character(),
                         stage=character(), reason=character())

  setorder(out, var, scenario, window, model)

  fwrite(out, OUTPUT_CSV)
  fwrite(log, OUTPUT_LOG_CSV)

  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("Resumen ensemble (mean, sd cross-model):\n")
  print(out[, .(n_models   = .N,
                delta_mean = round(mean(delta), 4),
                delta_sd   = round(sd(delta),   4)),
            by = .(var, scenario, window)])
  cat(sprintf("\nFilas escritas: %d -> %s\n", nrow(out), OUTPUT_CSV))
  cat(sprintf("Combos saltados: %d -> %s\n", nrow(log), OUTPUT_LOG_CSV))

  if (nrow(log) > 0) {
    cat("\nDrop registry:\n")
    print(log)
  }

  invisible(out)
}

# =============================================================================
# RUN
# =============================================================================
# Default TRUE para que source() lo ejecute. Si solo queres cargar las
# funciones sin correr el main (e.g., tests, exploracion):
#   options(cmip6.deltas.run_main = FALSE); source(".../01_cmip6_deltas.R")

if (isTRUE(getOption("cmip6.deltas.run_main", TRUE))) {
  deltas_ensemble <- compute_ensemble_deltas()
}
