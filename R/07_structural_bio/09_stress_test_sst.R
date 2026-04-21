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
# Schaefer aumentado con shifters SST + CHL
#
#   r_t = r_0 * exp( rho_SST * (SST_t - mean(SST)) + rho_CHL * (CHL_t - mean(CHL)) )
#
# Con rho_SST o rho_CHL = 0 colapsa al caso univariado.
# -----------------------------------------------------------------------------
simulate_schaefer_env <- function(r_0, K, rho_sst, rho_chl, B0,
                                  catch_series, sst_c, chl_c,
                                  floor_frac = 0.01) {
  Tn <- length(catch_series)
  stopifnot(length(sst_c) == Tn, length(chl_c) == Tn)
  B <- numeric(Tn); B[1] <- B0
  for (t in seq_len(Tn - 1)) {
    r_t <- r_0 * exp(rho_sst * sst_c[t] + rho_chl * chl_c[t])
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
# FIT RESTRINGIDO: r_0 y K FIJOS en los priors del YAML; unico parametro libre
# es rho_sst. Version honesta del stress test.
#
# MOTIVACION: el fit 3D libre (fit_schaefer_sst) es estructuralmente no-
# identificable con MLE puntual -- optim se escapa inflando K (haciendo
# B/K ~ 0 y el termino de densodependencia aproximadamente lineal) y
# colapsando r_0, y rho_sst toma cualquier magnitud para absorber residuos.
# Resultado: K_fit de 30-40x el prior, rho_sst = -6.29 para sardina
# (biologicamente imposible). El fit 1D restringido elimina esa ruta de
# escape y da el test limpio que pide el paper: "bajo la bio asumida
# (r,K del YAML) cuanto margen gana el modelo si permitimos que r varie
# con SST?".
# -----------------------------------------------------------------------------
fit_schaefer_sst_restricted <- function(inp, sst_by_year,
                                        rho_lo = -3, rho_hi = 3) {
  years <- inp$years

  sst_df <- sst_by_year %>% dplyr::filter(year %in% years) %>%
    dplyr::arrange(year)
  if (nrow(sst_df) != length(years)) {
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

  r_0 <- inp$r   # prior YAML (r_prior_mean)
  K   <- inp$K   # prior YAML (K_prior_mean_mil_t * 1e3)

  nll_1d <- function(rho_sst) {
    B_hat <- simulate_schaefer_sst(r_0, K, rho_sst, B0, C, sst_c)
    if (any(!is.finite(B_hat)) || any(B_hat <= 0)) return(1e12)
    sum((log(B_hat) - log(obs))^2)
  }

  fit <- stats::optim(
    par    = 0,
    fn     = nll_1d,
    method = "Brent",
    lower  = rho_lo,
    upper  = rho_hi
  )

  rho_sst <- fit$par
  B_hat   <- simulate_schaefer_sst(r_0, K, rho_sst, B0, C, sst_c)

  list(
    stock_id     = inp$catch_id,
    years        = years,
    C            = C,
    obs          = obs,
    B_hat        = B_hat,
    sst_c        = sst_c,
    r_0          = r_0,          # FIJO
    K            = K,             # FIJO
    rho_sst      = rho_sst,
    B0           = B0,
    nll          = fit$value,
    convergence  = fit$convergence,
    median_abs_err_pct = stats::median(abs(B_hat - obs) / obs * 100)
  )
}

# -----------------------------------------------------------------------------
# FIT RESTRINGIDO -- solo CHL (rho_sst = 0); r_0 y K fijos en priors YAML.
# Ventana paralela al de SST para contraste: si un stock responde mas a CHL
# que a SST, lo vemos directo en el delta_err.
# -----------------------------------------------------------------------------
fit_schaefer_chl_restricted <- function(inp, env_by_year,
                                        rho_lo = -3, rho_hi = 3) {
  years <- inp$years

  env_df <- env_by_year %>%
    dplyr::filter(year %in% years, !is.na(chl), is.finite(chl)) %>%
    dplyr::arrange(year)
  if (nrow(env_df) != length(years)) {
    years_keep <- intersect(years, env_df$year)
    keep_idx   <- match(years_keep, years)
    C    <- inp$C[keep_idx]
    obs  <- inp$obs[keep_idx]
    years <- years_keep
  } else {
    C   <- inp$C
    obs <- inp$obs
  }
  chl_c <- env_df$chl - mean(env_df$chl)
  sst_c <- rep(0, length(chl_c))       # apagamos SST
  B0    <- obs[1]

  r_0 <- inp$r
  K   <- inp$K

  nll_1d <- function(rho_chl) {
    B_hat <- simulate_schaefer_env(r_0, K, 0, rho_chl, B0, C, sst_c, chl_c)
    if (any(!is.finite(B_hat)) || any(B_hat <= 0)) return(1e12)
    sum((log(B_hat) - log(obs))^2)
  }

  fit <- stats::optim(
    par    = 0, fn = nll_1d,
    method = "Brent", lower = rho_lo, upper = rho_hi
  )

  rho_chl <- fit$par
  B_hat   <- simulate_schaefer_env(r_0, K, 0, rho_chl, B0, C, sst_c, chl_c)

  list(
    stock_id     = inp$catch_id,
    years        = years,
    C            = C,
    obs          = obs,
    B_hat        = B_hat,
    chl_c        = chl_c,
    r_0          = r_0,
    K            = K,
    rho_chl      = rho_chl,
    B0           = B0,
    nll          = fit$value,
    convergence  = fit$convergence,
    median_abs_err_pct = stats::median(abs(B_hat - obs) / obs * 100)
  )
}

# -----------------------------------------------------------------------------
# FIT RESTRINGIDO 2D -- SST y CHL simultaneos; r_0 y K fijos en priors YAML.
# Version mas rica del stress test: permite que los dos shifters "compitan"
# por explicar el residuo. Si rho_CHL se va a cero cuando SST esta en el
# modelo, CHL no agrega informacion. Si se mantiene grande, es shifter
# independiente relevante.
# -----------------------------------------------------------------------------
fit_schaefer_sst_chl_restricted <- function(inp, env_by_year,
                                            rho_lo = -3, rho_hi = 3) {
  years <- inp$years

  env_df <- env_by_year %>%
    dplyr::filter(year %in% years,
                  !is.na(sst), is.finite(sst),
                  !is.na(chl), is.finite(chl)) %>%
    dplyr::arrange(year)
  if (nrow(env_df) != length(years)) {
    years_keep <- intersect(years, env_df$year)
    keep_idx   <- match(years_keep, years)
    C    <- inp$C[keep_idx]
    obs  <- inp$obs[keep_idx]
    years <- years_keep
  } else {
    C   <- inp$C
    obs <- inp$obs
  }
  sst_c <- env_df$sst - mean(env_df$sst)
  chl_c <- env_df$chl - mean(env_df$chl)
  B0    <- obs[1]

  r_0 <- inp$r
  K   <- inp$K

  nll_2d <- function(par) {
    rho_sst <- par[1]; rho_chl <- par[2]
    B_hat <- simulate_schaefer_env(r_0, K, rho_sst, rho_chl, B0, C,
                                    sst_c, chl_c)
    if (any(!is.finite(B_hat)) || any(B_hat <= 0)) return(1e12)
    sum((log(B_hat) - log(obs))^2)
  }

  fit <- stats::optim(
    par    = c(0, 0), fn = nll_2d,
    method = "L-BFGS-B",
    lower  = c(rho_lo, rho_lo),
    upper  = c(rho_hi, rho_hi),
    control = list(maxit = 500)
  )

  rho_sst <- unname(fit$par[1])
  rho_chl <- unname(fit$par[2])
  B_hat   <- simulate_schaefer_env(r_0, K, rho_sst, rho_chl, B0, C,
                                    sst_c, chl_c)

  list(
    stock_id     = inp$catch_id,
    years        = years,
    C            = C,
    obs          = obs,
    B_hat        = B_hat,
    sst_c        = sst_c,
    chl_c        = chl_c,
    r_0          = r_0,
    K            = K,
    rho_sst      = rho_sst,
    rho_chl      = rho_chl,
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

  # Fit 3D libre (diagnostico de no-identificabilidad)
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

  # Fit 1D restringido SST (r, K fijos en YAML)
  fits_r <- purrr::map(inputs, fit_schaefer_sst_restricted,
                       sst_by_year = env_year)
  names(fits_r) <- names(inputs)

  restr_summary <- purrr::map_dfr(fits_r, function(f) {
    tibble::tibble(
      stock_id                 = f$stock_id,
      n_years                  = length(f$years),
      r_fixed                  = f$r_0,
      K_fixed_mil_t            = f$K / 1e3,
      rho_sst_restricted       = f$rho_sst,
      median_err_pct_restricted = f$median_abs_err_pct,
      nll_restricted           = f$nll,
      converged_restricted     = (f$convergence == 0)
    )
  })

  # Fit 1D restringido CHL
  fits_chl <- purrr::map(inputs, fit_schaefer_chl_restricted,
                         env_by_year = env_year)
  names(fits_chl) <- names(inputs)

  chl_summary <- purrr::map_dfr(fits_chl, function(f) {
    tibble::tibble(
      stock_id                  = f$stock_id,
      n_years_chl               = length(f$years),
      rho_chl_restricted        = f$rho_chl,
      median_err_pct_chl        = f$median_abs_err_pct,
      nll_chl                   = f$nll,
      converged_chl             = (f$convergence == 0)
    )
  })

  # Fit 2D restringido SST + CHL conjuntos
  fits_both <- purrr::map(inputs, fit_schaefer_sst_chl_restricted,
                          env_by_year = env_year)
  names(fits_both) <- names(inputs)

  both_summary <- purrr::map_dfr(fits_both, function(f) {
    tibble::tibble(
      stock_id                   = f$stock_id,
      n_years_both               = length(f$years),
      rho_sst_both               = f$rho_sst,
      rho_chl_both               = f$rho_chl,
      median_err_pct_both        = f$median_abs_err_pct,
      nll_both                   = f$nll,
      converged_both             = (f$convergence == 0)
    )
  })

  comp <- dplyr::left_join(
    summ_base %>% dplyr::select(stock_id, median_err_pct_base = median_err_p),
    aug_summary,
    by = "stock_id"
  ) %>%
    dplyr::left_join(restr_summary, by = "stock_id") %>%
    dplyr::left_join(chl_summary,   by = "stock_id") %>%
    dplyr::left_join(both_summary,  by = "stock_id") %>%
    dplyr::mutate(
      delta_err_pct            = median_err_pct_aug - median_err_pct_base,
      delta_err_pct_restricted = median_err_pct_restricted - median_err_pct_base,
      delta_err_pct_chl        = median_err_pct_chl - median_err_pct_base,
      delta_err_pct_both       = median_err_pct_both - median_err_pct_base,
      pass_aug                 = median_err_pct_aug < 20,
      pass_restricted          = median_err_pct_restricted < 20,
      pass_chl                 = median_err_pct_chl < 20,
      pass_both                = median_err_pct_both < 20
    )

  list(fits            = fits,
       fits_restricted = fits_r,
       fits_chl        = fits_chl,
       fits_both       = fits_both,
       comparison      = comp)
}

# -----------------------------------------------------------------------------
# Plot trayectorias: baseline vs las 3 variantes restringidas
#   (dropeamos el fit 3D libre del plot porque es ruido confirmado; queda
#    en la tabla 1 de la consola como diagnostico de no-identificabilidad).
# -----------------------------------------------------------------------------
plot_sst_augmented <- function(fits_restricted, fits_chl, fits_both,
                               inputs, out_path = NULL) {

  rows <- purrr::map_dfr(names(fits_restricted), function(nm) {
    fr  <- fits_restricted[[nm]]
    fc  <- fits_chl[[nm]]
    fb  <- fits_both[[nm]]
    inp <- inputs[[nm]]
    B_base <- simulate_schaefer_hindcast(inp$r, inp$K, inp$B0, inp$C)

    # Cada fit puede haber dropeado anos distintos por missing env.
    # El plot usa la interseccion comun = years del fit 2D (el mas
    # restrictivo porque exige sst y chl no-NA simultaneos).
    keep_base <- match(fb$years, inp$years)
    keep_sst  <- match(fb$years, fr$years)
    keep_chl  <- match(fb$years, fc$years)

    tibble::tibble(
      stock_id = nm,
      year     = fb$years,
      B_obs    = fb$obs,
      B_base   = B_base[keep_base],
      B_sst    = fr$B_hat[keep_sst],
      B_chl    = fc$B_hat[keep_chl],
      B_both   = fb$B_hat
    )
  })

  rows_long <- rows %>%
    tidyr::pivot_longer(c(B_obs, B_base, B_sst, B_chl, B_both),
                        names_to = "series", values_to = "B") %>%
    dplyr::mutate(series = factor(series,
                                  levels = c("B_obs", "B_base",
                                             "B_sst", "B_chl", "B_both"),
                                  labels = c("Observado",
                                             "Baseline (sin env)",
                                             "+ SST restringido",
                                             "+ CHL restringido",
                                             "+ SST & CHL restringido")))

  p <- ggplot(rows_long, aes(x = year, y = B / 1e3,
                             colour = series, linetype = series)) +
    geom_line(linewidth = 0.85) +
    geom_point(size = 1.4) +
    facet_wrap(~ stock_id, ncol = 1, scales = "free_y") +
    scale_colour_manual(values = c(
      "Observado"               = "#0072B2",
      "Baseline (sin env)"      = "#D55E00",
      "+ SST restringido"       = "#009E73",
      "+ CHL restringido"       = "#E69F00",
      "+ SST & CHL restringido" = "#CC79A7"
    )) +
    scale_linetype_manual(values = c(
      "Observado"               = "solid",
      "Baseline (sin env)"      = "solid",
      "+ SST restringido"       = "solid",
      "+ CHL restringido"       = "solid",
      "+ SST & CHL restringido" = "longdash"
    )) +
    labs(title    = "Stress test T3-bis: Schaefer + shifters ambientales",
         subtitle = "Fits restringidos (r, K fijos en priors YAML); unico parametro libre es rho(s).",
         x = "Año", y = "Biomasa (mil t)", colour = NULL, linetype = NULL) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom",
          legend.text = element_text(size = 9))

  if (!is.null(out_path)) {
    dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
    ggsave(out_path, p, width = 10, height = 11, dpi = 150)
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
  cat("T3-bis -- STRESS TEST Schaefer con shifters ambientales (SST, CHL)\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  out <- run_stress_test()

  # --- Tabla 1: fit 3D libre SST (diagnostico de no-identificabilidad) ---
  cat("(1) Fit 3D LIBRE (r_0, K, rho_sst) -- diagnostico, NO interpretar r/K:\n")
  tbl_free <- out$comparison %>%
    dplyr::select(stock_id, median_err_pct_base, r0_fit, K_fit_mil_t,
                  rho_sst, median_err_pct_aug, delta_err_pct, pass_aug) %>%
    dplyr::mutate(dplyr::across(
      c(median_err_pct_base, median_err_pct_aug, delta_err_pct,
        r0_fit, K_fit_mil_t, rho_sst),
      ~ round(.x, 2))) %>%
    as.data.frame()
  print(tbl_free, row.names = FALSE)

  n_pass_free <- sum(out$comparison$pass_aug, na.rm = TRUE)
  cat(sprintf("-> %d de %d stocks cruzan 20%% con fit libre (sospechoso: K_fit muy lejos del prior).\n\n",
              n_pass_free, nrow(out$comparison)))

  # --- Tabla 2: fit RESTRINGIDO SOLO SST ---
  cat("(2) Fit RESTRINGIDO SST (r, K fijos en priors YAML; solo rho_sst libre):\n")
  tbl_restr <- out$comparison %>%
    dplyr::select(stock_id, median_err_pct_base,
                  r_fixed, K_fixed_mil_t, rho_sst_restricted,
                  median_err_pct_restricted, delta_err_pct_restricted,
                  pass_restricted) %>%
    dplyr::mutate(dplyr::across(
      c(median_err_pct_base, median_err_pct_restricted,
        delta_err_pct_restricted, r_fixed, K_fixed_mil_t,
        rho_sst_restricted),
      ~ round(.x, 3))) %>%
    as.data.frame()
  print(tbl_restr, row.names = FALSE)

  n_pass_restr <- sum(out$comparison$pass_restricted, na.rm = TRUE)
  cat(sprintf("-> %d de %d stocks cruzan 20%% con SST restringido.\n\n",
              n_pass_restr, nrow(out$comparison)))

  # --- Tabla 3: fit RESTRINGIDO SOLO CHL ---
  cat("(3) Fit RESTRINGIDO CHL (r, K fijos en priors YAML; solo rho_chl libre):\n")
  tbl_chl <- out$comparison %>%
    dplyr::select(stock_id, median_err_pct_base,
                  r_fixed, K_fixed_mil_t, rho_chl_restricted,
                  median_err_pct_chl, delta_err_pct_chl, pass_chl) %>%
    dplyr::mutate(dplyr::across(
      c(median_err_pct_base, median_err_pct_chl, delta_err_pct_chl,
        r_fixed, K_fixed_mil_t, rho_chl_restricted),
      ~ round(.x, 3))) %>%
    as.data.frame()
  print(tbl_chl, row.names = FALSE)

  n_pass_chl <- sum(out$comparison$pass_chl, na.rm = TRUE)
  cat(sprintf("-> %d de %d stocks cruzan 20%% con CHL restringido.\n\n",
              n_pass_chl, nrow(out$comparison)))

  # --- Tabla 4: fit RESTRINGIDO SST+CHL CONJUNTO ---
  cat("(4) Fit RESTRINGIDO SST + CHL (r,K fijos; rho_sst y rho_chl libres):\n")
  tbl_both <- out$comparison %>%
    dplyr::select(stock_id, median_err_pct_base,
                  rho_sst_both, rho_chl_both,
                  median_err_pct_both, delta_err_pct_both, pass_both) %>%
    dplyr::mutate(dplyr::across(
      c(median_err_pct_base, median_err_pct_both, delta_err_pct_both,
        rho_sst_both, rho_chl_both),
      ~ round(.x, 3))) %>%
    as.data.frame()
  print(tbl_both, row.names = FALSE)

  n_pass_both <- sum(out$comparison$pass_both, na.rm = TRUE)
  cat(sprintf("-> %d de %d stocks cruzan 20%% con SST+CHL restringido conjunto.\n",
              n_pass_both, nrow(out$comparison)))

  # Plot + save CSV
  inputs <- build_hindcast_inputs()
  plot_sst_augmented(out$fits_restricted, out$fits_chl, out$fits_both,
                     inputs,
                     file.path(QA_DIR, "hindcast_sst_trajectories.png"))
  readr::write_csv(out$comparison,
                   file.path(QA_DIR, "hindcast_sst_comparison.csv"))
  cat("\nQA plot: ", file.path(QA_DIR, "hindcast_sst_trajectories.png"), "\n",
      "CSV   : ", file.path(QA_DIR, "hindcast_sst_comparison.csv"),   "\n",
      sep = "")

  # --- Lectura diagnostica ---
  cat("\n--- Lectura ---\n")
  cat("Resumen comparativo por stock (mediana |err%|, todas las variantes):\n\n")
  cat(sprintf("  %-18s | %8s | %8s | %8s | %8s\n",
              "stock", "base", "+SST", "+CHL", "+ambos"))
  cat(sprintf("  %-18s-+-%8s-+-%8s-+-%8s-+-%8s\n",
              strrep("-", 18), strrep("-", 8), strrep("-", 8),
              strrep("-", 8), strrep("-", 8)))
  for (i in seq_len(nrow(out$comparison))) {
    r <- out$comparison[i, ]
    cat(sprintf("  %-18s | %7.1f%% | %7.1f%% | %7.1f%% | %7.1f%%\n",
                r$stock_id,
                r$median_err_pct_base,
                r$median_err_pct_restricted,
                r$median_err_pct_chl,
                r$median_err_pct_both))
  }
  cat("\nCoeficientes rho restringidos (r,K fijos en YAML):\n\n")
  cat(sprintf("  %-18s | %12s | %12s | %12s | %12s\n",
              "stock", "rho_SST solo", "rho_CHL solo",
              "rho_SST ambos", "rho_CHL ambos"))
  cat(sprintf("  %-18s-+-%12s-+-%12s-+-%12s-+-%12s\n",
              strrep("-", 18), strrep("-", 12), strrep("-", 12),
              strrep("-", 12), strrep("-", 12)))
  for (i in seq_len(nrow(out$comparison))) {
    r <- out$comparison[i, ]
    cat(sprintf("  %-18s | %+12.3f | %+12.3f | %+12.3f | %+12.3f\n",
                r$stock_id,
                r$rho_sst_restricted,
                r$rho_chl_restricted,
                r$rho_sst_both,
                r$rho_chl_both))
  }

  cat("\nNotas de lectura:\n",
      " - Si rho_SST cambia mucho entre '+SST solo' y '+ambos', es signal de\n",
      "   colinealidad SST-CHL (en este dominio son correlacionadas).\n",
      " - Si rho_CHL se va a cero cuando SST esta en el modelo, CHL no agrega\n",
      "   info marginal mas alla de SST.\n",
      " - Si '+ambos' baja el err% materialmente vs '+SST solo', justifica\n",
      "   incluir CHL como segundo driver en T4.\n",
      " - Coeficientes pegados a +/-3 son el bound; usar como indicio de que\n",
      "   el shifter lineal no es suficiente (probablemente no-lineal).\n", sep = "")

  cat(strrep("=", 70), "\n", sep = "")
  invisible(out)
}
