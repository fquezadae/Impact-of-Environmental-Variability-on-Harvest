# =============================================================================
# FONDECYT -- 06_fit_t4b_omega.R
#
# T4b paso 6(c) -- Ajusta Schaefer state-space con CORRELACION CRUZADA Omega
# (LKJ_corr_cholesky(4)) a los 3 stocks SPF centro-sur. Extiende T4b-ind
# (paso 6b) agregando la matriz de correlacion de ruido de proceso.
#
# Si converge limpio con R-hat<=1.01 y 0 divergencias -> paso 6(d) agregar
# shifters SST/CHL.
#
# Entradas: idem 04_fit_t4b_ind.R.
#
# Salidas:
#   - data/outputs/t4b/t4b_omega_fit.rds
#   - data/outputs/t4b/t4b_omega_summary.csv
#   - data/outputs/t4b/t4b_omega_stan_data.rds
#
# Corre con:
#   options(t4b.omega.run_main = TRUE)
#   source("R/08_stan_t4/06_fit_t4b_omega.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(yaml)
  library(cmdstanr)
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

read_yaml_utf8 <- function(path) {
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  txt   <- rawToChar(bytes)
  Encoding(txt) <- "UTF-8"
  yaml::yaml.load(txt)
}

assert_scalar_numeric <- function(x, name) {
  if (is.null(x) || length(x) != 1 || !is.numeric(x) || is.na(x)) {
    stop(sprintf("[t4b-omega] Prior invalido: %s = %s", name, deparse(x)),
         call. = FALSE)
  }
  as.numeric(x)
}

# -----------------------------------------------------------------------------
# Constantes -- identicas a 04_fit_t4b_ind.R excepto STAN_FILE y OUT_DIR
# -----------------------------------------------------------------------------
T4B_OMEGA_STOCKS       <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
T4B_OMEGA_WINDOW       <- 2000:2024
# CSV HIBRIDO: SERNAPESCA 2000-2023 (todas las artes) + IFOP 2024 (cerco).
# Ver comentario en 04_fit_t4b_ind.R y memoria project_catch_data_sources.md.
T4B_OMEGA_CATCH_CSV    <- "data/bio_params/catch_annual_cs_2000_2024.csv"
T4B_OMEGA_CENSOR_JUREL <- 3.0

T4B_OMEGA_STAN_FILE <- "paper1/stan/t4b_state_space_omega.stan"
T4B_OMEGA_OUT_DIR   <- "data/outputs/t4b"

# Priors idem T4b-ind (validados en 6b)
T4B_OMEGA_LOG_R_SD  <- c(0.25, 0.25, 0.25)
T4B_OMEGA_LOG_K_SD  <- c(0.15, 0.15, 0.25)
T4B_OMEGA_LOG_B0_SD <- c(0.10, 0.10, 0.15)
T4B_OMEGA_SIGMA_OBS_MEAN <- c(0.12, 0.12, 0.30)
T4B_OMEGA_SIGMA_OBS_SD   <- c(0.05, 0.05, 0.10)
T4B_OMEGA_SIGMA_PROC_LOGMEAN <- rep(log(0.10), 3)
T4B_OMEGA_SIGMA_PROC_LOGSD   <- c(0.40, 0.40, 0.60)

dir.create(T4B_OMEGA_OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Insumos (idem T4b-ind)
# -----------------------------------------------------------------------------
load_t4b_omega_inputs <- function() {
  scaa <- readr::read_csv("data/bio_params/official_biomass_series.csv",
                          show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% c("anchoveta_cs", "sardina_comun_cs"),
                  year %in% T4B_OMEGA_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     biomass_mil_t = biomass_total_t / 1e3)

  ac <- readr::read_csv("data/bio_params/acoustic_biomass_series.csv",
                        show_col_types = FALSE) %>%
    dplyr::filter(species == "jurel_cs", year %in% T4B_OMEGA_WINDOW) %>%
    dplyr::transmute(stock_id = "jurel_cs", year,
                     biomass_mil_t = biomass_t / 1e3)

  catch <- readr::read_csv(T4B_OMEGA_CATCH_CSV, show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% T4B_OMEGA_STOCKS, year %in% T4B_OMEGA_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     catch_mil_t = catch_t / 1e3)

  list(scaa = scaa, ac_jurel = ac, catch = catch)
}

# -----------------------------------------------------------------------------
# Build stan_data (idem T4b-ind)
# -----------------------------------------------------------------------------
build_t4b_omega_stan_data <- function(inputs, priors_yaml) {
  pick <- function(stock, key) {
    val <- priors_yaml[[stock]]$priors_biologicos[[key]]
    assert_scalar_numeric(val, sprintf("%s.%s", stock, key))
  }
  r_mean <- c(pick("anchoveta_cs",     "r_prior_mean"),
              pick("sardina_comun_cs", "r_prior_mean"),
              pick("jurel_cs",         "r_prior_mean"))
  K_mean <- c(pick("anchoveta_cs",     "K_prior_mean_mil_t"),
              pick("sardina_comun_cs", "K_prior_mean_mil_t"),
              pick("jurel_cs",         "K_prior_mean_mil_t"))

  catch_wide <- inputs$catch %>%
    dplyr::right_join(
      tidyr::crossing(stock_id = T4B_OMEGA_STOCKS, year = T4B_OMEGA_WINDOW),
      by = c("stock_id", "year")
    ) %>%
    dplyr::mutate(catch_mil_t = tidyr::replace_na(catch_mil_t, 0)) %>%
    tidyr::pivot_wider(id_cols = year, names_from = stock_id,
                       values_from = catch_mil_t) %>%
    dplyr::arrange(year)
  C_mat <- as.matrix(catch_wide[, T4B_OMEGA_STOCKS])

  anch <- inputs$scaa %>%
    dplyr::filter(stock_id == "anchoveta_cs") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_OMEGA_WINDOW))
  sard <- inputs$scaa %>%
    dplyr::filter(stock_id == "sardina_comun_cs") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_OMEGA_WINDOW))
  jur <- inputs$ac_jurel %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_OMEGA_WINDOW),
                  is_censored = biomass_mil_t <= T4B_OMEGA_CENSOR_JUREL)
  jur_unc <- jur %>% dplyr::filter(!is_censored)
  jur_cen <- jur %>% dplyr::filter(is_censored)

  B0_mean <- c(anch$biomass_mil_t[1],
               sard$biomass_mil_t[1],
               jur_unc$biomass_mil_t[1])

  cat(sprintf("[t4b-omega] T=%d  S=3  (ventana %d-%d)\n",
              length(T4B_OMEGA_WINDOW), min(T4B_OMEGA_WINDOW), max(T4B_OMEGA_WINDOW)))
  cat(sprintf("[t4b-omega] N_obs: anch=%d  sard=%d  jur_unc=%d  jur_cen=%d\n",
              nrow(anch), nrow(sard), nrow(jur_unc), nrow(jur_cen)))
  cat(sprintf("[t4b-omega] Priors r: %.2f, %.2f, %.2f  K: %.0f, %.0f, %.0f\n",
              r_mean[1], r_mean[2], r_mean[3],
              K_mean[1], K_mean[2], K_mean[3]))

  list(
    S = 3L,
    T = length(T4B_OMEGA_WINDOW),
    N_obs_anch    = nrow(anch),
    N_obs_sard    = nrow(sard),
    N_obs_jur_unc = nrow(jur_unc),
    N_obs_jur_cen = nrow(jur_cen),
    t_anch    = anch$t,
    t_sard    = sard$t,
    t_jur_unc = jur_unc$t,
    t_jur_cen = jur_cen$t,
    B_obs_anch = anch$biomass_mil_t,
    B_obs_sard = sard$biomass_mil_t,
    B_obs_jur  = jur_unc$biomass_mil_t,
    B_censor_limit_jurel = T4B_OMEGA_CENSOR_JUREL,
    C = C_mat,

    log_r_prior_mean  = log(r_mean),
    log_r_prior_sd    = T4B_OMEGA_LOG_R_SD,
    log_K_prior_mean  = log(K_mean),
    log_K_prior_sd    = T4B_OMEGA_LOG_K_SD,
    log_B0_prior_mean = log(B0_mean),
    log_B0_prior_sd   = T4B_OMEGA_LOG_B0_SD,

    sigma_obs_prior_mean = T4B_OMEGA_SIGMA_OBS_MEAN,
    sigma_obs_prior_sd   = T4B_OMEGA_SIGMA_OBS_SD,
    sigma_proc_prior_logmean = T4B_OMEGA_SIGMA_PROC_LOGMEAN,
    sigma_proc_prior_logsd   = T4B_OMEGA_SIGMA_PROC_LOGSD
  )
}

# -----------------------------------------------------------------------------
# Fit -- iter_warmup subido a 2000 (vs 1500 en T4b-ind) por Omega mas exigente
# -----------------------------------------------------------------------------
fit_t4b_omega <- function(stan_data,
                          chains = 8,
                          iter_warmup = 2000,
                          iter_sampling = 2000,
                          adapt_delta = 0.99,
                          max_treedepth = 14,
                          seed = 2026L) {
  cat(sprintf("[t4b-omega] Chains=%d  warmup=%d  sampling=%d  adapt_delta=%.2f  max_treedepth=%d\n",
              chains, iter_warmup, iter_sampling, adapt_delta, max_treedepth))
  mod <- cmdstanr::cmdstan_model(T4B_OMEGA_STAN_FILE)
  fit <- mod$sample(
    data            = stan_data,
    chains          = chains,
    parallel_chains = chains,
    iter_warmup     = iter_warmup,
    iter_sampling   = iter_sampling,
    adapt_delta     = adapt_delta,
    max_treedepth   = max_treedepth,
    seed            = seed,
    refresh         = 200
  )
  fit
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.omega.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b-OMEGA (3 stocks + LKJ(4) cross-correlation) -- paso 6(c)\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  inputs    <- load_t4b_omega_inputs()
  priors    <- read_yaml_utf8("data/bio_params/official_assessments.yaml")
  stan_data <- build_t4b_omega_stan_data(inputs, priors)

  saveRDS(stan_data, file.path(T4B_OMEGA_OUT_DIR, "t4b_omega_stan_data.rds"))

  fit <- fit_t4b_omega(stan_data)
  fit$save_object(file = file.path(T4B_OMEGA_OUT_DIR, "t4b_omega_fit.rds"))

  smry <- fit$summary(variables = c("r_nat", "K_nat", "B0_nat",
                                    "sigma_proc", "sigma_obs", "Omega"))
  readr::write_csv(smry, file.path(T4B_OMEGA_OUT_DIR, "t4b_omega_summary.csv"))

  cat("\n[t4b-omega] Summary parametros clave:\n")
  print(smry)

  cat("\n[t4b-omega] Diagnosticos cmdstan:\n")
  print(fit$cmdstan_diagnose())

  cat("\n[t4b-omega] Criterios de validacion paso 6(c):\n")
  cat("  - R-hat top-level <= 1.01 (incluyendo los 3 Omega off-diagonal)\n")
  cat("  - ESS_bulk >= 400\n")
  cat("  - 0 divergencias, 0 treedepth saturation\n")
  cat("  - Omega[1,2] (anch-sard): correlacion esperada posterior con CI interpretable\n")
  cat("  - Omega[*,3] (con jurel): esperado cercano a 0 con CI amplio\n")
  cat("Si OK -> proceder a 6(d): agregar shifters SST/CHL.\n")

  invisible(fit)
}
