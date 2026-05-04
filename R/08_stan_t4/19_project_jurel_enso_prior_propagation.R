# =============================================================================
# FONDECYT -- 19_project_jurel_enso_prior_propagation.R
#
# Proyeccion del factor multiplicativo sobre r*_jurel bajo prior-propagation
# del posterior de rho_enso[3] x ensemble CMIP6 de delta ENSO Nino 3.4.
#
# Motivacion: el lag-1 fit (2026-05-04) confirmo Escenario B sobre rho_enso[3]
# (sigma_post/sigma_prior = 0.979; 90% CI [-0.81, +0.80]). El plan original
# (plan_enso_jurel.md, sugerencia 1) eleva esta sensibilidad de "opcional" a
# "importante" dado el null:
#
#   "Si no identifica, se vuelve importante como unica via para mostrar que
#    el '0.7-1.1% industrial' es punto estimado bajo asuncion fuerte."
#
# Mecanica: para cada celda (modelo CMIP6 m, escenario s, ventana w, draw d
# del posterior) computamos
#
#   factor_r*[m, s, w, d] = exp( rho_enso_draw[d] * delta_ENSO[m, s, w] )
#
# y agregamos cross-draw + cross-model para producir el envelope. El median va
# a ser cercano a 1 (porque median del posterior ~ 0), pero los cuantiles 5/95
# van a abrir un rango de 2-3 ordenes de magnitud, reflejando la incertidumbre
# bayesiana directa de un shifter no identificado bajo prior N(0, 0.5)
# extrapolado a delta SSP585 end +3.65 C (6.6 sd historicos).
#
# Cuenta rapida del rango esperado bajo SSP5-8.5 end-of-century:
#   exp(-0.81 * 3.65) = 0.05   -> factor q5  ~ 5% del baseline
#   exp(+0.80 * 3.65) = 18.7   -> factor q95 ~ 19x del baseline
# Median del factor ~ exp(-0.022 * 3.65) = 0.92 (cercano a 1 pero ligeramente
# debajo por el median negativo del posterior).
#
# Outputs:
#   - data/outputs/t4b/jurel_enso_prior_envelope.csv
#       columnas: scenario, window, factor_q5, factor_q25, factor_q50,
#                 factor_q75, factor_q95, factor_iqr_width, n_draws_total,
#                 n_models
#   - data/outputs/t4b/jurel_enso_prior_envelope_by_model.csv
#       breakdown por modelo (cross-draw within each model fixed)
#
# Uso:
#   source("R/00_config/config.R")
#   source("R/08_stan_t4/19_project_jurel_enso_prior_propagation.R")
#
# Bloqueado por:
#   - data/outputs/t4b/t4b_full_enso_lag1_fit.rds       (lag-1 fit listo)
#   - data/cmip6/enso_deltas_ensemble.csv               (deltas CMIP6 listos)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(posterior)
})

source_utf8 <- function(file, envir = globalenv()) {
  con <- file(file, "rb")
  on.exit(close(con), add = TRUE)
  bytes <- readBin(con, what = "raw", n = file.info(file)$size)
  txt <- rawToChar(bytes)
  Encoding(txt) <- "UTF-8"
  eval(parse(text = txt, encoding = "UTF-8"), envir = envir)
  invisible(NULL)
}

source_utf8("R/00_config/config.R")

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
PROJ_FIT_RDS    <- "data/outputs/t4b/t4b_full_enso_lag1_fit.rds"
PROJ_DELTAS_CSV <- "data/cmip6/enso_deltas_ensemble.csv"
PROJ_OUT_DIR    <- "data/outputs/t4b"
dir.create(PROJ_OUT_DIR, recursive = TRUE, showWarnings = FALSE)

PROJ_OUT_CSV          <- file.path(PROJ_OUT_DIR, "jurel_enso_prior_envelope.csv")
PROJ_OUT_BY_MODEL_CSV <- file.path(PROJ_OUT_DIR, "jurel_enso_prior_envelope_by_model.csv")

PROJ_RHO_VAR <- "rho_enso[3]"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
load_rho_enso_draws <- function(fit_path = PROJ_FIT_RDS) {
  if (!file.exists(fit_path)) {
    stop("[proj] no encontre ", fit_path,
         ". Corre primero R/08_stan_t4/14b_fit_t4b_full_enso.R")
  }
  fit <- readRDS(fit_path)
  draws_obj <- fit$draws(variables = PROJ_RHO_VAR, format = "draws_array")
  drv <- as.numeric(posterior::as_draws_matrix(draws_obj))
  if (length(drv) < 1000L) {
    warning("[proj] solo ", length(drv), " draws. Esperaba >=8000.")
  }
  cat(sprintf("[proj] cargados %d draws de %s\n", length(drv), PROJ_RHO_VAR))
  cat(sprintf("[proj]   posterior median=%.4f sd=%.4f q5=%.3f q95=%.3f\n",
              median(drv), sd(drv), quantile(drv, 0.05), quantile(drv, 0.95)))
  drv
}

load_enso_deltas <- function(csv_path = PROJ_DELTAS_CSV) {
  if (!file.exists(csv_path)) {
    stop("[proj] no encontre ", csv_path,
         ". Corre primero R/06_projections/01b_cmip6_enso_deltas.R")
  }
  d <- readr::read_csv(csv_path, show_col_types = FALSE)
  cat(sprintf("[proj] cargados %d deltas ENSO (modelos x escenarios x ventanas)\n",
              nrow(d)))
  d
}

# -----------------------------------------------------------------------------
# Compute envelope: factor_r*[m, s, w] cross-draw distribution
# -----------------------------------------------------------------------------
compute_envelope <- function(rho_draws, deltas) {
  # Para cada fila de deltas (m, s, w), generamos un vector de factor con
  # length(rho_draws) entradas. Luego agregamos cross-model dentro de
  # (s, w) para producir el envelope global.
  rows_global <- list()
  rows_by_model <- list()

  for (i in seq_len(nrow(deltas))) {
    row <- deltas[i, ]
    factor_vec <- exp(rho_draws * row$delta)

    # Stats per (model x scenario x window)
    rows_by_model[[i]] <- tibble::tibble(
      model            = row$model,
      scenario         = row$scenario,
      window           = row$window,
      delta_ENSO       = row$delta,
      factor_q5        = quantile(factor_vec, 0.05),
      factor_q25       = quantile(factor_vec, 0.25),
      factor_q50       = quantile(factor_vec, 0.50),
      factor_q75       = quantile(factor_vec, 0.75),
      factor_q95       = quantile(factor_vec, 0.95),
      n_draws          = length(factor_vec)
    )
  }
  by_model <- dplyr::bind_rows(rows_by_model)

  # Global envelope: pool across models within (scenario x window).
  # Concatenamos draws de los 6 modelos (cross-model x cross-draw).
  global_rows <- list()
  for (sw in unique(paste(deltas$scenario, deltas$window, sep = "/"))) {
    parts <- strsplit(sw, "/")[[1]]
    sc <- parts[1]; wn <- parts[2]
    sub <- deltas[deltas$scenario == sc & deltas$window == wn, ]
    pooled <- numeric(0)
    for (i in seq_len(nrow(sub))) {
      pooled <- c(pooled, exp(rho_draws * sub$delta[i]))
    }
    global_rows[[length(global_rows) + 1L]] <- tibble::tibble(
      scenario           = sc,
      window             = wn,
      delta_ENSO_median  = median(sub$delta),
      delta_ENSO_min     = min(sub$delta),
      delta_ENSO_max     = max(sub$delta),
      factor_q5          = quantile(pooled, 0.05),
      factor_q25         = quantile(pooled, 0.25),
      factor_q50         = quantile(pooled, 0.50),
      factor_q75         = quantile(pooled, 0.75),
      factor_q95         = quantile(pooled, 0.95),
      factor_iqr_width   = quantile(pooled, 0.75) - quantile(pooled, 0.25),
      log_factor_sd      = sd(log(pooled)),
      n_draws_total      = length(pooled),
      n_models           = nrow(sub)
    )
  }
  global <- dplyr::bind_rows(global_rows) %>%
    dplyr::arrange(scenario, window)

  list(global = global, by_model = by_model)
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("proj.run_main", TRUE))) {

  cat(strrep("=", 72), "\n", sep = "")
  cat("Paper 1 -- prior-propagation envelope para r*_jurel bajo CMIP6 ENSO\n")
  cat("Sensibilidad obligatoria dado Escenario B en lag-1 (ratio 0.979)\n")
  cat(strrep("=", 72), "\n\n", sep = "")

  rho_draws <- load_rho_enso_draws()
  deltas    <- load_enso_deltas()

  res <- compute_envelope(rho_draws, deltas)

  readr::write_csv(res$global,   PROJ_OUT_CSV)
  readr::write_csv(res$by_model, PROJ_OUT_BY_MODEL_CSV)

  cat(sprintf("\n[proj] envelope global escrito: %s\n", PROJ_OUT_CSV))
  cat(sprintf("[proj] breakdown por modelo:    %s\n", PROJ_OUT_BY_MODEL_CSV))

  # ---- Print headline table -------------------------------------------------
  cat("\n[proj] FACTOR sobre r*_jurel -- envelope global (cross-model x cross-draw):\n\n")
  fmt2 <- function(x) formatC(x, digits = 3, format = "g")
  hdr <- sprintf("%-9s %-6s %12s %10s %10s %10s %10s %10s %12s\n",
                 "scenario", "window",
                 "delta_med", "q5", "q25", "q50", "q75", "q95",
                 "log_fac_sd")
  cat(hdr); cat(strrep("-", nchar(hdr)), "\n", sep = "")
  for (i in seq_len(nrow(res$global))) {
    r <- res$global[i, ]
    cat(sprintf("%-9s %-6s %12s %10s %10s %10s %10s %10s %12s\n",
                r$scenario, r$window,
                fmt2(r$delta_ENSO_median),
                fmt2(r$factor_q5),
                fmt2(r$factor_q25),
                fmt2(r$factor_q50),
                fmt2(r$factor_q75),
                fmt2(r$factor_q95),
                fmt2(r$log_factor_sd)))
  }

  cat("\n[proj] LECTURA:\n")
  cat("  - factor_q50 (mediana) cercano a 1 -> el median del posterior es ~0,\n")
  cat("    asi que el efecto centrico es cero\n")
  cat("  - factor_q5/q95 abren 2-3 ordenes de magnitud -> esto ES el resultado:\n")
  cat("    bajo prior-propagation, la incertidumbre de r*_jurel sobre SSP5-8.5\n")
  cat("    end abarca [factor_q5, factor_q95] del baseline. Esto justifica\n")
  cat("    fijar factor_B_jurel = 1 como spec principal: el envelope ridiculo\n")
  cat("    no es informativo para policy.\n")
  cat("  - log_factor_sd creciente con extrapolacion -> el rango aumenta con\n")
  cat("    delta_ENSO (mas extremo SSP585 end > SSP585 mid > SSP245 end > SSP245 mid).\n")

  cat(sprintf("\n[proj] DONE. Drop el envelope como fila adicional en Tabla 5\n"))
  cat("       y mencionar en seccion 5 caveats que jurel n.i. queda fijo en r*=1\n")
  cat("       precisamente porque la prior-propagation arroja envelope no informativo.\n")
}
