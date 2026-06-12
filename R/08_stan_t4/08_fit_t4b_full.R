# =============================================================================
# FONDECYT -- 08_fit_t4b_full.R
#
# T4b paso 6(d) -- MODELO COMPLETO: 3 stocks + Omega (LKJ 4) + shifters
# ambientales SST y log(CHL) con lag t-1, stock-especificos.
#
# Extiende 06_fit_t4b_omega.R agregando:
#   - Carga de serie ambiental SST/CHL anualizada desde los RDS EnvCoastDaily
#   - Priors rho_SST y rho_CHL por stock (del stress test T3-bis 2026-04-22)
#
# Entradas:
#   - data/bio_params/official_biomass_series.csv    (biomass_total_t anch+sard)
#   - data/bio_params/acoustic_biomass_series.csv    (biomasa acustica jurel)
#   - data/bio_params/catch_annual_cs_2000_2024.csv  (captura HIBRIDA)
#   - data/bio_params/official_assessments.yaml      (priors r/K)
#   - <dirdata>/Environmental/env/.../EnvCoastDaily_*.rds (SST+CHL diarios)
#
# Salidas:
#   - data/outputs/t4b/t4b_full_fit.rds
#   - data/outputs/t4b/t4b_full_summary.csv
#   - data/outputs/t4b/t4b_full_stan_data.rds
#
# Corre con:
#   options(t4b.full.run_main = TRUE)
#   source("R/08_stan_t4/08_fit_t4b_full.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(yaml)
  library(lubridate)
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
    stop(sprintf("[t4b-full] Prior invalido: %s = %s", name, deparse(x)),
         call. = FALSE)
  }
  as.numeric(x)
}

# -----------------------------------------------------------------------------
# Constantes -- heredadas de 06 excepto STAN_FILE/OUT y nuevos priors rho
# -----------------------------------------------------------------------------
T4B_FULL_STOCKS       <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
T4B_FULL_WINDOW       <- 2000:2024
T4B_FULL_CATCH_CSV    <- "data/bio_params/catch_annual_cs_2000_2024.csv"
T4B_FULL_CENSOR_JUREL <- 3.0

T4B_FULL_STAN_FILE <- "paper1/stan/t4b_state_space_full.stan"
T4B_FULL_OUT_DIR   <- "data/outputs/t4b"

# Priors estructurales idem T4b-omega
T4B_FULL_LOG_R_SD  <- c(0.25, 0.25, 0.25)
T4B_FULL_LOG_K_SD  <- c(0.15, 0.15, 0.25)
T4B_FULL_LOG_B0_SD <- c(0.10, 0.10, 0.15)
T4B_FULL_SIGMA_OBS_MEAN <- c(0.12, 0.12, 0.30)
T4B_FULL_SIGMA_OBS_SD   <- c(0.05, 0.05, 0.10)
T4B_FULL_SIGMA_PROC_LOGMEAN <- rep(log(0.10), 3)
T4B_FULL_SIGMA_PROC_LOGSD   <- c(0.40, 0.40, 0.60)

# Priors shifters (orden: anch, sard, jur) -- del stress test T3-bis 2026-04-22
T4B_FULL_RHO_SST_MEAN <- c(-2.3, -2.0,  0.0)
T4B_FULL_RHO_SST_SD   <- c( 1.0,  1.0,  1.0)
T4B_FULL_RHO_CHL_MEAN <- c(-2.3,  2.1,  0.0)
T4B_FULL_RHO_CHL_SD   <- c( 1.0,  1.0,  1.0)

dir.create(T4B_FULL_OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Cargar insumos
# -----------------------------------------------------------------------------
load_t4b_full_inputs <- function() {
  scaa <- readr::read_csv("data/bio_params/official_biomass_series.csv",
                          show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% c("anchoveta_cs", "sardina_comun_cs"),
                  year %in% T4B_FULL_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     biomass_mil_t = biomass_total_t / 1e3)

  ac <- readr::read_csv("data/bio_params/acoustic_biomass_series.csv",
                        show_col_types = FALSE) %>%
    dplyr::filter(species == "jurel_cs", year %in% T4B_FULL_WINDOW) %>%
    dplyr::transmute(stock_id = "jurel_cs", year,
                     biomass_mil_t = biomass_t / 1e3)

  catch <- readr::read_csv(T4B_FULL_CATCH_CSV, show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% T4B_FULL_STOCKS, year %in% T4B_FULL_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     catch_mil_t = catch_t / 1e3)

  # --- Ambiental anualizado ---
  env1 <- readRDS(file.path(dirdata, "Environmental/env", "2000-2011",
                            "EnvCoastDaily_2000_2011_0.25deg.rds"))
  env2 <- readRDS(file.path(dirdata, "Environmental/env",
                            "EnvCoastDaily_2012_2025_0.125deg.rds"))
  env_year <- dplyr::bind_rows(
    dplyr::mutate(env1, year = lubridate::year(date)),
    dplyr::mutate(env2, year = lubridate::year(date))
  ) %>%
    dplyr::filter(year %in% T4B_FULL_WINDOW) %>%
    dplyr::group_by(year) %>%
    dplyr::summarise(sst = mean(sst, na.rm = TRUE),
                     chl = mean(chl, na.rm = TRUE),
                     .groups = "drop") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(
      SST_c    = sst - mean(sst, na.rm = TRUE),
      logCHL_c = log(chl) - mean(log(chl), na.rm = TRUE)
    )
  stopifnot(nrow(env_year) == length(T4B_FULL_WINDOW))

  list(scaa = scaa, ac_jurel = ac, catch = catch, env = env_year)
}

# -----------------------------------------------------------------------------
# 2. Build stan_data (agrega SST_c, logCHL_c, priors rho respecto a 06)
# -----------------------------------------------------------------------------
build_t4b_full_stan_data <- function(inputs, priors_yaml) {
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
      tidyr::crossing(stock_id = T4B_FULL_STOCKS, year = T4B_FULL_WINDOW),
      by = c("stock_id", "year")
    ) %>%
    dplyr::mutate(catch_mil_t = tidyr::replace_na(catch_mil_t, 0)) %>%
    tidyr::pivot_wider(id_cols = year, names_from = stock_id,
                       values_from = catch_mil_t) %>%
    dplyr::arrange(year)
  C_mat <- as.matrix(catch_wide[, T4B_FULL_STOCKS])

  anch <- inputs$scaa %>%
    dplyr::filter(stock_id == "anchoveta_cs") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_FULL_WINDOW))
  sard <- inputs$scaa %>%
    dplyr::filter(stock_id == "sardina_comun_cs") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_FULL_WINDOW))
  jur <- inputs$ac_jurel %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_FULL_WINDOW),
                  is_censored = biomass_mil_t <= T4B_FULL_CENSOR_JUREL)
  jur_unc <- jur %>% dplyr::filter(!is_censored)
  jur_cen <- jur %>% dplyr::filter(is_censored)

  B0_mean <- c(anch$biomass_mil_t[1],
               sard$biomass_mil_t[1],
               jur_unc$biomass_mil_t[1])

  cat(sprintf("[t4b-full] T=%d  S=3  ventana %d-%d\n",
              length(T4B_FULL_WINDOW), min(T4B_FULL_WINDOW), max(T4B_FULL_WINDOW)))
  cat(sprintf("[t4b-full] N_obs: anch=%d  sard=%d  jur_unc=%d  jur_cen=%d\n",
              nrow(anch), nrow(sard), nrow(jur_unc), nrow(jur_cen)))
  cat(sprintf("[t4b-full] Env rango: SST_c [%.2f, %.2f]  logCHL_c [%.2f, %.2f]\n",
              min(inputs$env$SST_c), max(inputs$env$SST_c),
              min(inputs$env$logCHL_c), max(inputs$env$logCHL_c)))
  cat(sprintf("[t4b-full] Priors rho_SST: anch=N(%.1f, %.1f)  sard=N(%.1f, %.1f)  jur=N(%.1f, %.1f)\n",
              T4B_FULL_RHO_SST_MEAN[1], T4B_FULL_RHO_SST_SD[1],
              T4B_FULL_RHO_SST_MEAN[2], T4B_FULL_RHO_SST_SD[2],
              T4B_FULL_RHO_SST_MEAN[3], T4B_FULL_RHO_SST_SD[3]))
  cat(sprintf("[t4b-full] Priors rho_CHL: anch=N(%.1f, %.1f)  sard=N(%.1f, %.1f)  jur=N(%.1f, %.1f)\n",
              T4B_FULL_RHO_CHL_MEAN[1], T4B_FULL_RHO_CHL_SD[1],
              T4B_FULL_RHO_CHL_MEAN[2], T4B_FULL_RHO_CHL_SD[2],
              T4B_FULL_RHO_CHL_MEAN[3], T4B_FULL_RHO_CHL_SD[3]))

  list(
    S = 3L,
    T = length(T4B_FULL_WINDOW),
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
    B_censor_limit_jurel = T4B_FULL_CENSOR_JUREL,
    C = C_mat,

    SST_c    = inputs$env$SST_c,
    logCHL_c = inputs$env$logCHL_c,

    log_r_prior_mean  = log(r_mean),
    log_r_prior_sd    = T4B_FULL_LOG_R_SD,
    log_K_prior_mean  = log(K_mean),
    log_K_prior_sd    = T4B_FULL_LOG_K_SD,
    log_B0_prior_mean = log(B0_mean),
    log_B0_prior_sd   = T4B_FULL_LOG_B0_SD,

    sigma_obs_prior_mean = T4B_FULL_SIGMA_OBS_MEAN,
    sigma_obs_prior_sd   = T4B_FULL_SIGMA_OBS_SD,
    sigma_proc_prior_logmean = T4B_FULL_SIGMA_PROC_LOGMEAN,
    sigma_proc_prior_logsd   = T4B_FULL_SIGMA_PROC_LOGSD,

    rho_sst_prior_mean = T4B_FULL_RHO_SST_MEAN,
    rho_sst_prior_sd   = T4B_FULL_RHO_SST_SD,
    rho_chl_prior_mean = T4B_FULL_RHO_CHL_MEAN,
    rho_chl_prior_sd   = T4B_FULL_RHO_CHL_SD
  )
}

# -----------------------------------------------------------------------------
# 3. Fit
# -----------------------------------------------------------------------------
fit_t4b_full <- function(stan_data,
                         chains = 8,
                         iter_warmup = 2000,
                         iter_sampling = 2000,
                         adapt_delta = 0.99,
                         max_treedepth = 14,
                         seed = 2026L) {
  cat(sprintf("[t4b-full] Chains=%d  warmup=%d  sampling=%d  adapt_delta=%.2f  max_treedepth=%d\n",
              chains, iter_warmup, iter_sampling, adapt_delta, max_treedepth))
  mod <- cmdstanr::cmdstan_model(T4B_FULL_STAN_FILE)
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
if (isTRUE(getOption("t4b.full.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b-FULL -- 3 stocks + Omega + shifters SST/CHL (paso 6(d))\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  inputs    <- load_t4b_full_inputs()
  priors    <- read_yaml_utf8("data/bio_params/official_assessments.yaml")
  stan_data <- build_t4b_full_stan_data(inputs, priors)

  saveRDS(stan_data, file.path(T4B_FULL_OUT_DIR, "t4b_full_stan_data.rds"))

  fit <- fit_t4b_full(stan_data)
  fit$save_object(file = file.path(T4B_FULL_OUT_DIR, "t4b_full_fit.rds"))

  smry <- fit$summary(variables = c("r_nat", "K_nat", "B0_nat",
                                    "sigma_proc", "sigma_obs",
                                    "rho_sst", "rho_chl", "Omega"))
  readr::write_csv(smry, file.path(T4B_FULL_OUT_DIR, "t4b_full_summary.csv"))

  cat("\n[t4b-full] Summary parametros clave:\n")
  print(smry)

  cat("\n[t4b-full] Diagnosticos cmdstan:\n")
  print(fit$cmdstan_diagnose())

  cat("\n[t4b-full] Criterios de validacion paso 6(d):\n")
  cat("  - R-hat <= 1.01 en todos los top-level (incluyendo rho_sst/rho_chl)\n")
  cat("  - ESS_bulk >= 400\n")
  cat("  - 0 divergencias\n")
  cat("  - Comparar Omega[anch,sard] vs 6(c): si se aplana hacia 0, las\n")
  cat("    correlaciones cruzadas de 6(c) eran mediadas por forzamiento\n")
  cat("    ambiental comun (no competencia biologica directa).\n")

  invisible(fit)
}
