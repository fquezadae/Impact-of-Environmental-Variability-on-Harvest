# =============================================================================
# FONDECYT -- 02_fit_t4b_single_anchoveta.R
#
# T4b paso 6(a) -- Ajusta single-species Schaefer state-space a anchoveta_cs
# con priors apretados. SANITY CHECK: si esto no converge con R-hat<1.01, hay
# un problema conceptual mas profundo y no tiene sentido escalar a 3 stocks.
#
# Ver project_t4_v1_failure_and_t4b_plan.md para contexto del fallo T4 v1.
#
# Entradas:
#   - data/bio_params/official_biomass_series.csv   (SSB SCAA IFOP 1997-2024)
#   - data/bio_params/catch_annual_paper1.csv       (captura V-X SERNAPESCA)
#   - data/bio_params/official_assessments.yaml     (priors YAML -- se usan
#                                                    solo r/K_prior_mean; el
#                                                    *_sd del YAML se IGNORA
#                                                    y se sustituye por los
#                                                    sd APRETADOS de abajo.)
#
# Salidas:
#   - data/outputs/t4b/t4b_single_anch_fit.rds
#   - data/outputs/t4b/t4b_single_anch_summary.csv
#   - data/outputs/t4b/t4b_single_anch_stan_data.rds
#
# Corre con:
#   options(t4b.run_main = TRUE)
#   source("R/08_stan_t4/02_fit_t4b_single_anchoveta.R")
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

# -----------------------------------------------------------------------------
# Constantes T4b single-species
# -----------------------------------------------------------------------------
T4B_STOCK     <- "anchoveta_cs"
T4B_WINDOW    <- 2000:2024
T4B_STAN_FILE <- "paper1/stan/t4b_state_space_single.stan"
T4B_OUT_DIR   <- "data/outputs/t4b"

# PRIORS APRETADOS -- corazon del fix T4b (ver header del .stan).
# Todos en log-escala. NO tocar estos sin actualizar tambien la memoria
# project_t4_v1_failure_and_t4b_plan.md.
T4B_LOG_R_SD  <- 0.25    # +/-25% aprox en r-escala -- moderado
T4B_LOG_K_SD  <- 0.15    # +/-15% aprox en K-escala -- APRETADO, anclado a IFOP
T4B_LOG_B0_SD <- 0.10    # +/-10% aprox en B0-escala -- semi-fijo a B_t1_obs

T4B_SIGMA_OBS_MEAN <- 0.12   # SCAA es ya resumen suavizado; prior normal (truncado)
T4B_SIGMA_OBS_SD   <- 0.05

# sigma_proc: lognormal(log(0.10), 0.40). Corta la masa en sigma_proc=0 que
# activaba el funnel en la version non-centered anterior. Mediana ~0.10,
# q95 ~0.19, q99 ~0.25 -- permite ruido razonable sin colapsar a determinismo.
T4B_SIGMA_PROC_LOGMEAN <- log(0.10)
T4B_SIGMA_PROC_LOGSD   <- 0.40

dir.create(T4B_OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Cargar insumos
# -----------------------------------------------------------------------------
load_t4b_inputs <- function() {
  # NOTA (2026-04-23): se usa biomass_total_t, NO ssb_t. El prior K del YAML
  # (K_prior_mean_mil_t = 2200) esta calibrado para biomasa total (ver
  # K_fuente: "K_total estimado 1.5-2x BD0"). Usar SSB aqui producia una
  # inconsistencia estructural: el latente B se forzaba a ~SSB ( ~200-800 kt)
  # por la likelihood, pero la ecuacion dinamica con K=2200 asumia B_total.
  # Causa root del fallo de mixing en T4 v1 y T4b single v1.
  ssb <- readr::read_csv("data/bio_params/official_biomass_series.csv",
                         show_col_types = FALSE) %>%
    dplyr::filter(stock_id == T4B_STOCK, year %in% T4B_WINDOW) %>%
    dplyr::arrange(year) %>%
    dplyr::transmute(year, biomass_mil_t = biomass_total_t / 1e3)

  catch <- readr::read_csv("data/bio_params/catch_annual_paper1.csv",
                           show_col_types = FALSE) %>%
    dplyr::filter(stock_id == T4B_STOCK, year %in% T4B_WINDOW) %>%
    dplyr::right_join(tibble::tibble(year = T4B_WINDOW), by = "year") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(catch_mil_t = tidyr::replace_na(catch_t / 1e3, 0))

  stopifnot(nrow(catch) == length(T4B_WINDOW))

  list(ssb = ssb, catch = catch)
}

# -----------------------------------------------------------------------------
# 2. Armar stan_data
# -----------------------------------------------------------------------------
build_t4b_stan_data <- function(inputs, priors_yaml) {
  # Solo usamos r/K_prior_mean del YAML; los *_sd se reemplazan por los
  # apretados de arriba.
  p_anch <- priors_yaml[["anchoveta_cs"]]$priors_biologicos
  r_mean <- as.numeric(p_anch$r_prior_mean)
  K_mean <- as.numeric(p_anch$K_prior_mean_mil_t)
  stopifnot(!is.na(r_mean), !is.na(K_mean))

  t_obs <- match(inputs$ssb$year, T4B_WINDOW)
  stopifnot(!any(is.na(t_obs)))

  B0_mean <- inputs$ssb$biomass_mil_t[1]

  cat(sprintf("[t4b] Stock: %s  T=%d  N_obs=%d\n",
              T4B_STOCK, length(T4B_WINDOW), nrow(inputs$ssb)))
  cat(sprintf("[t4b] Priors: r ~ logN(log(%.2f), %.2f)  K ~ logN(log(%.0f), %.2f)  B0 ~ logN(log(%.1f), %.2f)\n",
              r_mean, T4B_LOG_R_SD, K_mean, T4B_LOG_K_SD, B0_mean, T4B_LOG_B0_SD))
  cat(sprintf("[t4b] sigma_obs ~ N(%.2f, %.2f)  sigma_proc ~ logN(log(%.2f), %.2f)\n",
              T4B_SIGMA_OBS_MEAN, T4B_SIGMA_OBS_SD,
              exp(T4B_SIGMA_PROC_LOGMEAN), T4B_SIGMA_PROC_LOGSD))

  list(
    T = length(T4B_WINDOW),
    N_obs = nrow(inputs$ssb),
    t_obs = t_obs,
    B_obs = inputs$ssb$biomass_mil_t,
    C     = inputs$catch$catch_mil_t,

    log_r_prior_mean  = log(r_mean),
    log_r_prior_sd    = T4B_LOG_R_SD,
    log_K_prior_mean  = log(K_mean),
    log_K_prior_sd    = T4B_LOG_K_SD,
    log_B0_prior_mean = log(B0_mean),
    log_B0_prior_sd   = T4B_LOG_B0_SD,

    sigma_obs_prior_mean = T4B_SIGMA_OBS_MEAN,
    sigma_obs_prior_sd   = T4B_SIGMA_OBS_SD,
    sigma_proc_prior_logmean = T4B_SIGMA_PROC_LOGMEAN,
    sigma_proc_prior_logsd   = T4B_SIGMA_PROC_LOGSD
  )
}

# -----------------------------------------------------------------------------
# 3. Fit
# -----------------------------------------------------------------------------
fit_t4b_single <- function(stan_data,
                           chains = 8,
                           iter_warmup = 1500,
                           iter_sampling = 2000,
                           adapt_delta = 0.99,        # subido desde 0.95 (centered
                                                      # puede tener funnels residuales)
                           max_treedepth = 14,        # subido desde 12
                           seed = 2026L) {
  cat(sprintf("[t4b] Chains=%d  warmup=%d  sampling=%d  adapt_delta=%.2f  max_treedepth=%d\n",
              chains, iter_warmup, iter_sampling, adapt_delta, max_treedepth))
  mod <- cmdstanr::cmdstan_model(T4B_STAN_FILE)
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
if (isTRUE(getOption("t4b.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b single-species (anchoveta_cs) -- sanity check\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  inputs    <- load_t4b_inputs()
  priors    <- read_yaml_utf8("data/bio_params/official_assessments.yaml")
  stan_data <- build_t4b_stan_data(inputs, priors)

  saveRDS(stan_data, file.path(T4B_OUT_DIR, "t4b_single_anch_stan_data.rds"))
  cat("[t4b] stan_data guardado\n\n")

  fit <- fit_t4b_single(stan_data)
  fit$save_object(file = file.path(T4B_OUT_DIR, "t4b_single_anch_fit.rds"))

  smry <- fit$summary(variables = c("r_nat", "K_nat", "B0_nat",
                                    "sigma_proc", "sigma_obs"))
  readr::write_csv(smry, file.path(T4B_OUT_DIR, "t4b_single_anch_summary.csv"))

  cat("\n[t4b] Summary parametros clave:\n")
  print(smry)

  cat("\n[t4b] Diagnosticos cmdstan:\n")
  print(fit$cmdstan_diagnose())

  cat("\n[t4b] CRITERIOS DE VALIDACION (paso 6a):\n")
  cat("  - R-hat maximo para r_nat, K_nat, B0_nat, sigma_*  <= 1.01\n")
  cat("  - ESS_bulk minimo para esos mismos parametros      >= 400\n")
  cat("  - 0 divergencias\n")
  cat("  - E-BFMI > 0.3 en las 8 chains\n")
  cat("  - Sin treedepth saturation (max_treedepth=12)\n")
  cat("Si todo OK: proceder a 6b (3 stocks independientes, Omega=I).\n")
  cat("Si falla: problema conceptual, NO seguir escalando.\n")

  invisible(fit)
}
