# =============================================================================
# FONDECYT -- 04_fit_t4b_ind.R
#
# T4b paso 6(b) -- Ajusta Schaefer state-space INDEPENDIENTE a los 3 stocks
# SPF centro-sur: anchoveta_cs, sardina_comun_cs, jurel_cs. Omega = I (sin
# correlacion cruzada de ruido de proceso); sin shifters ambientales.
#
# Escalado incremental desde T4b single-species (anchoveta_cs) validado en
# 2026-04-23 (paso 6a). Si este fit converge limpio, procede 6(c) (agregar
# Omega con LKJ_corr_cholesky).
#
# Entradas:
#   - data/bio_params/official_biomass_series.csv    (biomass_total_t anch+sard)
#   - data/bio_params/acoustic_biomass_series.csv    (biomasa acustica jurel)
#   - data/bio_params/catch_annual_paper1.csv        (captura SERNAPESCA V-X)
#   - data/bio_params/official_assessments.yaml      (r_prior_mean, K_prior_mean)
#
# Salidas:
#   - data/outputs/t4b/t4b_ind_fit.rds
#   - data/outputs/t4b/t4b_ind_summary.csv
#   - data/outputs/t4b/t4b_ind_stan_data.rds
#
# Corre con:
#   options(t4b.ind.run_main = TRUE)
#   source("R/08_stan_t4/04_fit_t4b_ind.R")
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
    stop(sprintf("[t4b-ind] Prior invalido: %s = %s", name, deparse(x)),
         call. = FALSE)
  }
  as.numeric(x)
}

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
T4B_IND_STOCKS       <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
T4B_IND_WINDOW       <- 2000:2024
T4B_IND_CENSOR_JUREL <- 3.0             # mil t; obs <= 3 mil t -> censored

T4B_IND_STAN_FILE <- "paper1/stan/t4b_state_space_ind.stan"
T4B_IND_OUT_DIR   <- "data/outputs/t4b"

# PRIORS APRETADOS (orden: anch, sard, jur)
# - log_r_sd: 0.25 para los 3. Conservador; r esta levemente identificado.
# - log_K_sd: 0.15 anch y sard (anclados IFOP V-X con BD0 primario verificado),
#             0.25 jurel (K re-escalado desde range-wide, menos preciso).
# - log_B0_sd: 0.10 anch y sard (B_2000 observado IFOP), 0.15 jurel (gaps
#              MAR en serie acustica).
T4B_IND_LOG_R_SD  <- c(0.25, 0.25, 0.25)
T4B_IND_LOG_K_SD  <- c(0.15, 0.15, 0.25)
T4B_IND_LOG_B0_SD <- c(0.10, 0.10, 0.15)

# sigma_obs: anch/sard (SCAA suavizado) ~ 0.12; jurel (acustico snapshot) ~ 0.30
T4B_IND_SIGMA_OBS_MEAN <- c(0.12, 0.12, 0.30)
T4B_IND_SIGMA_OBS_SD   <- c(0.05, 0.05, 0.10)

# sigma_proc: lognormal(log(0.10), logsd). Jurel con logsd mayor porque la
# observacion acustica (con gaps) permite mas variabilidad latente aparente.
T4B_IND_SIGMA_PROC_LOGMEAN <- rep(log(0.10), 3)
T4B_IND_SIGMA_PROC_LOGSD   <- c(0.40, 0.40, 0.60)

dir.create(T4B_IND_OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Cargar insumos
# -----------------------------------------------------------------------------
load_t4b_ind_inputs <- function() {
  # Anchoveta + sardina: biomass_total_t (NO ssb_t, ver fix 2026-04-23)
  scaa <- readr::read_csv("data/bio_params/official_biomass_series.csv",
                          show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% c("anchoveta_cs", "sardina_comun_cs"),
                  year %in% T4B_IND_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     biomass_mil_t = biomass_total_t / 1e3)

  # Jurel: acustico (biomass_t es ya biomasa total, no SSB)
  ac <- readr::read_csv("data/bio_params/acoustic_biomass_series.csv",
                        show_col_types = FALSE) %>%
    dplyr::filter(species == "jurel_cs", year %in% T4B_IND_WINDOW) %>%
    dplyr::transmute(stock_id = "jurel_cs", year,
                     biomass_mil_t = biomass_t / 1e3)

  # Captura: todos los stocks
  catch <- readr::read_csv("data/bio_params/catch_annual_paper1.csv",
                           show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% T4B_IND_STOCKS, year %in% T4B_IND_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     catch_mil_t = catch_t / 1e3)

  list(scaa = scaa, ac_jurel = ac, catch = catch)
}

# -----------------------------------------------------------------------------
# 2. Armar stan_data
# -----------------------------------------------------------------------------
build_t4b_ind_stan_data <- function(inputs, priors_yaml) {
  # --- Priors estructurales: valores centrales del YAML ---
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

  # --- Captura en matriz T x S (orden: anch, sard, jur) ---
  catch_wide <- inputs$catch %>%
    dplyr::right_join(
      tidyr::crossing(stock_id = T4B_IND_STOCKS, year = T4B_IND_WINDOW),
      by = c("stock_id", "year")
    ) %>%
    dplyr::mutate(catch_mil_t = tidyr::replace_na(catch_mil_t, 0)) %>%
    tidyr::pivot_wider(id_cols = year, names_from = stock_id,
                       values_from = catch_mil_t) %>%
    dplyr::arrange(year)
  C_mat <- as.matrix(catch_wide[, T4B_IND_STOCKS])

  # --- Observaciones por stock ---
  anch <- inputs$scaa %>%
    dplyr::filter(stock_id == "anchoveta_cs") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_IND_WINDOW))
  sard <- inputs$scaa %>%
    dplyr::filter(stock_id == "sardina_comun_cs") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_IND_WINDOW))
  jur <- inputs$ac_jurel %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_IND_WINDOW),
                  is_censored = biomass_mil_t <= T4B_IND_CENSOR_JUREL)
  jur_unc <- jur %>% dplyr::filter(!is_censored)
  jur_cen <- jur %>% dplyr::filter(is_censored)

  # --- B0 por stock: primer valor observado ---
  B0_mean <- c(anch$biomass_mil_t[1],
               sard$biomass_mil_t[1],
               jur_unc$biomass_mil_t[1])

  cat(sprintf("[t4b-ind] T=%d  S=3\n", length(T4B_IND_WINDOW)))
  cat(sprintf("[t4b-ind] N_obs: anch=%d  sard=%d  jur_unc=%d  jur_cen=%d (anios: %s)\n",
              nrow(anch), nrow(sard), nrow(jur_unc), nrow(jur_cen),
              paste(jur_cen$year, collapse = ", ")))
  cat(sprintf("[t4b-ind] r_prior_mean: anch=%.2f  sard=%.2f  jur=%.2f\n",
              r_mean[1], r_mean[2], r_mean[3]))
  cat(sprintf("[t4b-ind] K_prior_mean (mil t): anch=%.0f  sard=%.0f  jur=%.0f\n",
              K_mean[1], K_mean[2], K_mean[3]))
  cat(sprintf("[t4b-ind] B0 (primer obs): anch=%.0f  sard=%.0f  jur=%.0f  mil t\n",
              B0_mean[1], B0_mean[2], B0_mean[3]))

  list(
    S = 3L,
    T = length(T4B_IND_WINDOW),
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
    B_censor_limit_jurel = T4B_IND_CENSOR_JUREL,
    C = C_mat,

    log_r_prior_mean  = log(r_mean),
    log_r_prior_sd    = T4B_IND_LOG_R_SD,
    log_K_prior_mean  = log(K_mean),
    log_K_prior_sd    = T4B_IND_LOG_K_SD,
    log_B0_prior_mean = log(B0_mean),
    log_B0_prior_sd   = T4B_IND_LOG_B0_SD,

    sigma_obs_prior_mean = T4B_IND_SIGMA_OBS_MEAN,
    sigma_obs_prior_sd   = T4B_IND_SIGMA_OBS_SD,
    sigma_proc_prior_logmean = T4B_IND_SIGMA_PROC_LOGMEAN,
    sigma_proc_prior_logsd   = T4B_IND_SIGMA_PROC_LOGSD
  )
}

# -----------------------------------------------------------------------------
# 3. Fit
# -----------------------------------------------------------------------------
fit_t4b_ind <- function(stan_data,
                        chains = 8,
                        iter_warmup = 1500,
                        iter_sampling = 2000,
                        adapt_delta = 0.99,
                        max_treedepth = 14,
                        seed = 2026L) {
  cat(sprintf("[t4b-ind] Chains=%d  warmup=%d  sampling=%d  adapt_delta=%.2f  max_treedepth=%d\n",
              chains, iter_warmup, iter_sampling, adapt_delta, max_treedepth))
  mod <- cmdstanr::cmdstan_model(T4B_IND_STAN_FILE)
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
if (isTRUE(getOption("t4b.ind.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b IND (3 stocks independientes, Omega = I) -- paso 6(b)\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  inputs    <- load_t4b_ind_inputs()
  priors    <- read_yaml_utf8("data/bio_params/official_assessments.yaml")
  stan_data <- build_t4b_ind_stan_data(inputs, priors)

  saveRDS(stan_data, file.path(T4B_IND_OUT_DIR, "t4b_ind_stan_data.rds"))
  cat("\n[t4b-ind] stan_data guardado\n\n")

  fit <- fit_t4b_ind(stan_data)
  fit$save_object(file = file.path(T4B_IND_OUT_DIR, "t4b_ind_fit.rds"))

  smry <- fit$summary(variables = c("r_nat", "K_nat", "B0_nat",
                                    "sigma_proc", "sigma_obs"))
  readr::write_csv(smry, file.path(T4B_IND_OUT_DIR, "t4b_ind_summary.csv"))

  cat("\n[t4b-ind] Summary parametros clave (orden: anch, sard, jur):\n")
  print(smry)

  cat("\n[t4b-ind] Diagnosticos cmdstan:\n")
  print(fit$cmdstan_diagnose())

  cat("\n[t4b-ind] Criterios de validacion paso 6(b):\n")
  cat("  - R-hat maximo <= 1.01 en todos los top-level por stock\n")
  cat("  - ESS_bulk minimo >= 400 por stock\n")
  cat("  - 0 divergencias\n")
  cat("  - E-BFMI > 0.3 en las 8 chains\n")
  cat("Si todo OK: proceder a 6(c) -- agregar Omega con lkj_corr_cholesky(4).\n")

  invisible(fit)
}
