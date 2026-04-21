# =============================================================================
# FONDECYT -- 09_stress_test_sst.R
#
# STRESS TEST T3-bis (PEND-11 del YAML): hindcast Schaefer AUMENTADO con
# shifter SST exogeno. Propositi: ver si el error baja por debajo del umbral
# 20% cuando r depende de SST, antes de invertir en el T4 Stan.
#
# Ley de movimiento aumentada:
#
#   r_t    = r_0 * exp( rho_SST * (SST_t - mean(SST)) )
#   B_{t+1} = B_t + r_t * B_t * (1 - B_t / K) - C_t         con floor 0.01 * K
#
# Estimacion: maxima verosimilitud Gaussiana log-error (i.e., minimiza
# sum((log(B_hat) - log(B_obs))^2)), sobre (log_r_0, log_K, rho_SST) con
# optim() BFGS. B_0 se fija en obs[1] del overlap (igual que el hindcast
# baseline T3).
#
# OUTPUT:
#   - consola: tabla comparativa baseline (02_hindcast_check.R) vs aumentado
#              por especie, con posteriors puntuales y median|err%|.
#   - data/bio_params/qa/hindcast_sst_trajectories.png  trayectorias
#   - data/bio_params/qa/hindcast_sst_comparison.csv    summary table
#
# LECTURA DEL RESULTADO:
#   - Si median|err%| del aumentado cruza el 20% en los tres stocks ->
#     evidencia fuerte de que el clima es la diferencia, T4 justificado
#     sin reservas.
#   - Si baja pero no cruza (p.ej. 30%) -> T4 con shifters multiples
#     (SST + CHL) probablemente cierra el gap; escribir el Stan.
#   - Si no baja materialmente -> hay un problema mas profundo (p.ej.
#     error de observacion no gaussiano, o dinamica no-Schaefer).
#
# CAVEATS:
#   - SST anualizada agregada sobre toda la grilla env (misma que usa el
#     Rmd principal, ver chunk `load_env_vars` de paper1_climate_projections.Rmd).
#   - La optimizacion es maxima verosimilitud puntual, NO Bayesiana. Sirve
#     como stress test, no reemplaza T4.
#   - No se agrega CHL en este paso para mantenerlo simple; si baja parcial,
#     re-correr con CHL tambien.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(tibble)
  library(readr)
  library(ggplot2)
  library(lubridate)
})

# Wrapper UTF-8 (ver comentario en 02_hindcast_check.R)
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
source_utf8("R/07_structural_bio/01_load_official_params.R")
source_utf8("R/07_structural_bio/05_load_official_biomass.R")
source_utf8("R/07_structural_bio/06_load_catch_series.R")
source_utf8("R/07_structural_bio/02_hindcast_check.R")

# -----------------------------------------------------------------------------
# Carga SST anual CS-wide (misma logica que chunk `load_env_vars` del Rmd)
# -----------------------------------------------------------------------------
load_env_annual <- function(
    path_recent = file.path(dirdata, "Environmental/env",
                            "EnvCoastDaily_2012_2025_0.125deg.rds"),
    path_early  = file.path(dirdata, "Environmental/env", "2000-2011",
                            "EnvCoastDaily_2000_2011_0.25deg.rds")
) {
  stopifnot(file.exists(path_recent), file.exists(path_early))

  env1 <- readRDS(path_early)
  env2 <- readRDS(path_recent)

  annualize <- function(dt) {
    dt %>%
      dplyr::mutate(year = lubridate::year(date)) %>%
      dplyr::group_by(year) %>%
      dplyr::summarise(
        sst = mean(sst, na.rm = TRUE),
        chl = mean(chl, na.rm = TRUE),
        .groups = "drop"
      )
  }
  dplyr::bind_rows(annualize(env1), annualize(env2)) %>%
    dplyr::arrange(year)
}

# -----------------------------------------------------------------------------
# Schaefer aumentado con shifter SST
# -----------------------------------------------------------------------------
simulate_schaefer_sst <- function(r_0, K, rho_sst, B0, catch_series, sst_c,
                                  floor_frac = 0.01) {
  Tn <- length(catch_series)
  stopifnot(length(sst_c) == Tn)
  B <- numeric(Tn); B[1] <- B0
  for (t in seq_len(Tn - 1)) {
    r_t <- r_0 * exp(rho_sst * sst_c[t])
    g   <- r_t * B[t] * (1 - B[t] / K)
    B[t + 1] <- max(floor_frac * K, B[t] + g - catch_series[t])
  }
  B
}

# -----------------------------------------------------------------------------
# Negative log-likelihood Gaussiana en log-error
# -----------------------------------------------------------------------------
nll_schaefer_sst <- function(par, C, obs, sst_c, B0, floor_frac = 0.01) {
  # par = (log_r0, log_K, rho_sst)
  r_0     <- exp(par[1])
  K       <- exp(par[2])
  rho_sst <- par[3]

  B_hat <- simulate_schaefer_sst(r_0, K, rho_sst, B0, C, sst_c, floor_frac)
  if (any(!is.finite(B_hat)) || any(B_hat <= 0)) return(1e12)

  log_err <- log(B_hat) - log(obs)
  sum(log_err^2)   # proporcional a -log-likelihood hasta factor constante
}

# -----------------------------------------------------------------------------
# Estimacion por optim() con multi-start (dos inicializaciones + la mejor)
# -----------------------------------------------------------------------------
fit_schaefer_sst <- function(inp, sst_by_year) {
  years <- inp$years

  # Merge SST al overlap
  sst_df <- sst_by_year %>% dplyr::filter(year %in% years) %>%
    dplyr::arrange(year)
  if (nrow(sst_df) != length(years)) {
    warning("SST missing for some years of stock ", inp$catch_id,
            "; dropping those obs. Cobertura: ",
            nrow(sst_df), "/", length(years))
    years_keep <- intersect(years, sst_df$year)
    keep_idx   <- match(years_keep, years)
    C    <- inp$C[keep_idx]
    obs  <- inp$obs[keep_idx]
    years <- years_keep
    sst_df <- sst_df %>% dplyr::filter(year %in% years)
  } else {
    C   <- inp$C
    obs <- inp$obs
  }
  sst_c <- sst_df$sst - mean(sst_df$sst)
  B0    <- obs[1]

  # Inicializacion 1: priors YAML
  par0_a <- c(log_r0 = log(inp$r), log_K = log(inp$K), rho_sst = 0)

  # Inicializacion 2: r pequeno, K = 2 * max(obs), rho = 0
  par0_b <- c(log_r0 = log(0.3), log_K = log(2 * max(obs)), rho_sst = 0)

  fit_a <- tryCatch(
    stats::optim(par0_a, nll_schaefer_sst,
                 C = C, obs = obs, sst_c = sst_c, B0 = B0,
                 method = "BFGS",
                 control = list(maxit = 500)),
    error = function(e) list(value = Inf, par = par0_a))

  fit_b <- tryCatch(
    stats::optim(par0_b, nll_schaefer_sst,
                 C = C, obs = obs, sst_c = sst_c, B0 = B0,
                 method = "BFGS",
                 control = list(maxit = 500)),
    error = function(e) list(value = Inf, par = par0_b))

  fit <- if (fit_a$value <= fit_b$value) fit_a else fit_b

  r_0     <- exp(fit$par[1])
  K       <- exp(fit$par[2])
  rho_sst <- unname(fit$par[3])
  B_hat   <- simulate_schaefer_sst(r_0, K, rho_sst, B0, C, sst_c)

  list(
    stock_id     = inp$catch_id,
    years        = years,
    C            = C,
    obs          = obs,
    B_hat        = B_hat,
    sst_c        = sst_c,
    r_0          = unname(r_0),
    K            = unname(K),
    rho_sst      = rho_sst,
    B0           = B0,
    nll          = fit$value,
    convergence  = fit$convergence,
    median_abs_err_pct = stats::median(abs(B_hat - obs) / obs * 100)
  )
}

# -----------------------------------------------------------------------------
# Runner: fit todos los stocks y compara con el baseline (T3)
# -----------------------------------------------------------------------------
run_stress_test <- function() {

  env_year <- load_env_annual()

  inputs   <- build_hindcast_inputs()       # hereda el STOCK_MAP de 02
  baseline <- run_hindcast_all(inputs)       # Schaefer sin SST
  summ_base <- summarise_hindcast(baseline)

  fits <- purrr::map(inputs, fit_schaefer_sst, sst_by_year = env_year)
  names(fits) <- names(inputs)

  aug_summary <- purrr::map_dfr(fits, function(f) {
    tibble::tibble(
      stock_id            = f$stock_id,
      n_years             = length(f$years),
      r0_fit              = f$r_0,
      K_fit_mil_t         = f$K / 1e3,
      rho_sst             = f$rho_sst,
      median_err_pct_aug  = f$median_abs_err_pct,
      nll                 = f$nll,
      converged           = (f$convergence == 0)
    )
  })

  comp <- dplyr::left_join(
    summ_base %>% dplyr::select(stock_id, median_err_pct_base = median_err_p),
    aug_summary,
    by = "stock_id"
  ) %>%
    dplyr::mutate(
      delta_err_pct = median_err_pct_aug - median_err_pct_base,
      pass_aug      = median_err_pct_aug < 20
    )

  list(fits = fits, comparison = comp)
}

# -----------------------------------------------------------------------------
# Plot trayectorias baseline vs aumentado
# -----------------------------------------------------------------------------
plot_sst_augmented <- function(fits, inputs, out_path = NULL) {

  rows <- purrr::map_dfr(names(fits), function(nm) {
    f   <- fits[[nm]]
    inp <- inputs[[nm]]
    B_base <- simulate_schaefer_hindcast(inp$r, inp$K, inp$B0, inp$C)

    # El baseline usa TODOS los anos del inp; el aumentado puede haber
    # dropeado algunos si faltaba SST. Nos quedamos con los anos del aug.
    keep <- match(f$years, inp$years)

    tibble::tibble(
      stock_id = nm,
      year     = f$years,
      B_obs    = f$obs,
      B_base   = B_base[keep],
      B_aug    = f$B_hat
    )
  })

  rows_long <- rows %>%
    tidyr::pivot_longer(c(B_obs, B_base, B_aug),
                        names_to = "series", values_to = "B") %>%
    dplyr::mutate(series = factor(series,
                                  levels = c("B_obs", "B_base", "B_aug"),
                                  labels = c("Observado",
                                             "Schaefer baseline (sin SST)",
                                             "Schaefer + shifter SST")))

  p <- ggplot(rows_long, aes(x = year, y = B / 1e3,
                             colour = series, linetype = series)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 1.7) +
    facet_wrap(~ stock_id, ncol = 1, scales = "free_y") +
    scale_colour_manual(values = c(
      "Observado"                    = "#0072B2",
      "Schaefer baseline (sin SST)"  = "#D55E00",
      "Schaefer + shifter SST"       = "#009E73"
    )) +
    labs(title    = "Stress test T3-bis: Schaefer baseline vs aumentado con SST",
         subtitle = "Si verde cruza el umbral 20% y azul no, T4 queda justificado",
         x = "Año", y = "Biomasa (mil t)", colour = NULL, linetype = NULL) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom")

  if (!is.null(out_path)) {
    dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
    ggsave(out_path, p, width = 9, height = 10, dpi = 150)
  }
  p
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("structural_bio.run_main", FALSE))) {

  QA_DIR <- file.path("data", "bio_params", "qa")
  dir.create(QA_DIR, showWarnings = FALSE, recursive = TRUE)

  cat(strrep("=", 70), "\n", sep = "")
  cat("T3-bis -- STRESS TEST Schaefer con shifter SST\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  out <- run_stress_test()

  cat("Comparativa baseline vs aumentado:\n")
  tbl <- out$comparison %>%
    dplyr::mutate(dplyr::across(
      c(median_err_pct_base, median_err_pct_aug, delta_err_pct,
        r0_fit, K_fit_mil_t, rho_sst),
      ~ round(.x, 2))) %>%
    as.data.frame()
  print(tbl, row.names = FALSE)

  n_pass <- sum(out$comparison$pass_aug, na.rm = TRUE)
  cat(sprintf("\n-> %d de %d stocks cruzan el umbral 20%% con shifter SST.\n",
              n_pass, nrow(out$comparison)))

  # Plot + save CSV
  inputs <- build_hindcast_inputs()
  plot_sst_augmented(out$fits, inputs,
                     file.path(QA_DIR, "hindcast_sst_trajectories.png"))
  readr::write_csv(out$comparison,
                   file.path(QA_DIR, "hindcast_sst_comparison.csv"))
  cat("QA plot: ", file.path(QA_DIR, "hindcast_sst_trajectories.png"), "\n",
      "CSV   : ", file.path(QA_DIR, "hindcast_sst_comparison.csv"),   "\n",
      sep = "")

  # Lectura diagnostica
  cat("\n--- Lectura ---\n")
  if (n_pass == nrow(out$comparison)) {
    cat("Los tres stocks cruzan el umbral con solo SST. T4 queda justificado\n",
        "sin reservas: el clima es la diferencia estructural entre un Schaefer\n",
        "determinista y la trayectoria observada.\n", sep = "")
  } else if (n_pass >= 1) {
    cat("Al menos un stock cruza. Para los otros, T4 con CHL ademas de SST\n",
        "probablemente cierra el gap. Revisar rho_sst posteriors: si signo y\n",
        "magnitud son biologicamente interpretables, adelante con T4.\n", sep = "")
  } else {
    cat("Ningun stock cruza con solo SST. Opciones: (a) probar SST^2 no\n",
        "lineal, (b) agregar CHL, (c) revisar si el error de observacion\n",
        "acustica tiene varianza mayor a la asumida. No arrancar T4 sin\n",
        "entender por que el shifter no ayuda.\n", sep = "")
  }

  cat(strrep("=", 70), "\n", sep = "")
  invisible(out)
}
