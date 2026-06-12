# =============================================================================
# FONDECYT -- 01b_cmip6_enso_deltas.R   (ENSEMBLE 6 modelos, ENSO Nino 3.4)
#
# Sister-script de 01_cmip6_deltas.R, especializado para el indice ENSO Nino 3.4
# del pivote 2026-05-04 (project_paper1_enso_pivot). Reusa las utilidades
# robustas del padre (cmip6_dates, read_cmip6_var, agg_year_mean) y solo cambia
# las constantes input/output:
#
#   - Input dir : D:/GitHub/climate_projections/CMIP6_NINO34
#   - Filename  : CMIP6_<model>_tos_<exp>_monthly_nino34.nc
#   - Bbox      : lat [-5, +5] x lon [-170, -120]   (Nino 3.4)
#   - Variables : solo tos (ENSO es por definicion un indice SST)
#   - Splice    : igual que padre (hist 2000-2014 + ssp245 2015-2024); CESM2
#                 cae a ssp585 si el catalogo Pangeo no le tiene tos/ssp245.
#                 Override registrado al final.
#
# Convencion de delta: igual que el padre. Crudo en C, NO z-scored. La
# semielasticidad rho_enso del Stan ENSO se calibra a esta escala (sd ~0.55 C
# en el historico OISST/ERSSTv5, similar en escala a SST_D1 sd 0.26 C).
#
# Entradas:
#   D:/GitHub/climate_projections/CMIP6_NINO34/CMIP6_<model>_tos_<exp>_monthly_nino34.nc
#
# Salidas:
#   data/cmip6/enso_deltas_ensemble.csv     (long format, 1 var = ENSO)
#       columnas: model, scenario, window, var, delta, baseline_mean,
#                 future_mean, n_years_baseline, n_years_future, splice_exp
#   data/cmip6/enso_deltas_ensemble_log.csv (registro de combos saltados)
#
# Corre con:
#   source("R/06_projections/01b_cmip6_enso_deltas.R")
#
# Dependencia: el padre 01_cmip6_deltas.R debe estar accesible (lo source-amos
# con cmip6.deltas.run_main = FALSE para no disparar el run completo costero).
# =============================================================================

suppressPackageStartupMessages({
  library(ncdf4)
  library(data.table)
})

source("R/00_config/config.R")

# Cargar helpers del padre SIN ejecutar su main loop costero
old_opt <- getOption("cmip6.deltas.run_main", TRUE)
options(cmip6.deltas.run_main = FALSE)
source("R/06_projections/01_cmip6_deltas.R")
options(cmip6.deltas.run_main = old_opt)

# =============================================================================
# CONFIGURACION ENSO (override de los globals del padre cuando aplica)
# =============================================================================

ENSO_CMIP6_DIR  <- "D:/GitHub/climate_projections/CMIP6_NINO34"
ENSO_OUTPUT_DIR <- "data/cmip6"
dir.create(ENSO_OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

ENSO_OUTPUT_CSV     <- file.path(ENSO_OUTPUT_DIR, "enso_deltas_ensemble.csv")
ENSO_OUTPUT_LOG_CSV <- file.path(ENSO_OUTPUT_DIR, "enso_deltas_ensemble_log.csv")

# Nino 3.4 bbox (mismo que en download_cmip6_nino34.py)
ENSO_BBOX <- list(lon_min = -170, lon_max = -120,
                  lat_min = -5,   lat_max =  5)

# Modelos (mismos del padre; reuso ENSO_MODELS por simetria)
ENSO_MODELS <- MODELS  # del padre

# Solo tos
ENSO_VAR <- "tos"

# Override de splice (paralelo al padre).
# Si en algun caso CESM2/tos/ssp245 falla, caemos a ssp585 (defendible:
# ssp245 ~ ssp585 en near-term <2040).
ENSO_SPLICE_OVERRIDE <- list(
  `CESM2.tos` = "ssp585"
)

# =============================================================================
# UTILIDADES ENSO (override de filepath; reusa cmip6_dates/read_cmip6_var/agg_year_mean)
# =============================================================================

filepath_cmip6_nino34 <- function(model, var, exp) {
  file.path(ENSO_CMIP6_DIR,
            sprintf("CMIP6_%s_%s_%s_monthly_nino34.nc",
                    model_token(model), var, exp))
}

splice_exp_for_enso <- function(model, var) {
  key <- paste(model, var, sep = ".")
  if (!is.null(ENSO_SPLICE_OVERRIDE[[key]])) return(ENSO_SPLICE_OVERRIDE[[key]])
  "ssp245"
}

# Carga baseline 2000-2024 spliced para (model, tos) sobre Nino 3.4.
load_baseline_spliced_enso <- function(model) {
  hist_dt <- read_cmip6_var(filepath_cmip6_nino34(model, ENSO_VAR, "historical"),
                            ENSO_VAR, BASELINE_HIST, ENSO_BBOX)
  if (is.null(hist_dt)) return(NULL)

  splice_exp <- splice_exp_for_enso(model, ENSO_VAR)
  splice_dt <- read_cmip6_var(filepath_cmip6_nino34(model, ENSO_VAR, splice_exp),
                              ENSO_VAR, BASELINE_SPLICE, ENSO_BBOX)
  if (is.null(splice_dt)) return(NULL)

  list(dt = rbind(hist_dt, splice_dt), splice_exp = splice_exp)
}

# Procesa ENSO/tos para un modelo: baseline + 4 deltas (ssp x window).
process_enso_one <- function(model) {
  base <- load_baseline_spliced_enso(model)
  if (is.null(base)) {
    return(list(rows = NULL,
                log = data.table(model = model, var = "enso",
                                 stage = "baseline",
                                 reason = "archivo hist o splice missing")))
  }
  base_agg <- agg_year_mean(base$dt, ENSO_VAR)

  rows <- list(); skipped <- list()
  for (ssp in SSPS) {
    for (wname in names(WINDOWS_FUT)) {
      fut_file <- filepath_cmip6_nino34(model, ENSO_VAR, ssp)
      fut_dt <- read_cmip6_var(fut_file, ENSO_VAR, WINDOWS_FUT[[wname]], ENSO_BBOX)
      if (is.null(fut_dt)) {
        skipped[[length(skipped) + 1L]] <- data.table(
          model = model, var = "enso",
          stage = sprintf("future/%s/%s", ssp, wname),
          reason = "archivo missing o sin meses en rango")
        next
      }
      fut_agg <- agg_year_mean(fut_dt, ENSO_VAR)
      rows[[length(rows) + 1L]] <- data.table(
        model              = model,
        scenario           = ssp,
        window             = wname,
        var                = "enso",
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

# =============================================================================
# ORQUESTADOR
# =============================================================================

compute_enso_ensemble_deltas <- function() {

  cat(strrep("=", 70), "\n", sep = "")
  cat("CMIP6 ENSO deltas -- 6 modelos, Nino 3.4 (lat [-5,+5] x lon [-170,-120])\n")
  cat(sprintf("Baseline splice 2000-2024 (hist 2000-2014 + ssp245 2015-2024).\n"))
  cat(sprintf("Output dir: %s\n", ENSO_CMIP6_DIR))
  cat(strrep("=", 70), "\n\n", sep = "")

  if (!dir.exists(ENSO_CMIP6_DIR)) {
    stop("[enso-deltas] no existe ", ENSO_CMIP6_DIR,
         ". Corre primero R/06_projections/download_cmip6_nino34.py")
  }

  all_rows <- list(); all_log <- list()

  for (model in ENSO_MODELS) {
    cat("---", model, "---\n")
    cat("  tos (Nino 3.4) ... ")
    res <- process_enso_one(model)
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

  out <- if (length(all_rows) > 0) rbindlist(all_rows, use.names = TRUE)
         else data.table()
  log <- if (length(all_log) > 0) rbindlist(all_log, use.names = TRUE)
         else data.table(model=character(), var=character(),
                         stage=character(), reason=character())

  if (nrow(out) > 0) setorder(out, scenario, window, model)

  fwrite(out, ENSO_OUTPUT_CSV)
  fwrite(log, ENSO_OUTPUT_LOG_CSV)

  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("Resumen ensemble ENSO (mean, sd cross-model):\n")
  if (nrow(out) > 0) {
    print(out[, .(n_models   = .N,
                  delta_mean = round(mean(delta), 4),
                  delta_sd   = round(sd(delta),   4),
                  delta_min  = round(min(delta),  4),
                  delta_max  = round(max(delta),  4)),
              by = .(scenario, window)])

    # Sanity: baseline ENSO del ensemble vs OISST. Esperado ~26.5-27.5 C.
    cat("\nBaseline mean por modelo (esperado ~26.5-27.5 C; OISST/ERSSTv5 = 27.08):\n")
    print(out[, .(baseline_C = round(mean(baseline_mean), 3)), by = model])

    # Sanity: signo del delta ENSO. CMIP6 mean response a SSP585 sobre Nino 3.4
    # es positivo (~+1 a +2 C end-of-century) por warming general.
    cat("\nDelta ssp585/end por modelo (esperado +1 a +3 C; warming general):\n")
    print(out[scenario == "ssp585" & window == "end",
              .(model, delta = round(delta, 3))])
  } else {
    cat("(sin filas; revisa enso_deltas_ensemble_log.csv)\n")
  }
  cat(sprintf("\nFilas escritas: %d -> %s\n", nrow(out), ENSO_OUTPUT_CSV))
  cat(sprintf("Combos saltados: %d -> %s\n", nrow(log), ENSO_OUTPUT_LOG_CSV))

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
# funciones sin correr el main:
#   options(cmip6.enso.run_main = FALSE); source(".../01b_cmip6_enso_deltas.R")

if (isTRUE(getOption("cmip6.enso.run_main", TRUE))) {
  enso_deltas_ensemble <- compute_enso_ensemble_deltas()
}
