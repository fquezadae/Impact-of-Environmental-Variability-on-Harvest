# =============================================================================
# FONDECYT -- 14_refit_t4b_full_appendix_e.R
#
# Apendice E del paper 1 -- robustez espacial de la NO-IDENTIFICACION de jurel.
#
# Refittea el T4b full (3 stocks + Omega + shifters SST/logCHL) sobre los TRES
# dominios anidados, manteniendo IDENTICOS:
#   - Stan model (paper1/stan/t4b_state_space_full.stan)
#   - Priors estructurales (r, K, B0, sigma_proc, sigma_obs, LKJ, rho)
#   - Datos de biomasa y captura (anch SCAA, sard SCAA, jur acustica)
#   - Ventana 2000-2024
#   - Sampler config (8 chains, warmup=2000, sampling=2000, adapt_delta=0.99,
#     max_treedepth=14)
#
# Lo UNICO que cambia entre fits es la serie SST_c y logCHL_c que entra como
# data al modelo. Las series vienen de
# data/bio_params/env_extended_3domains_2000_2024.csv (producido por
# R/06_projections/06_extended_env_anomalies.R).
#
# Outputs por dominio:
#   - data/outputs/t4b/t4b_full_appE_<domain>_fit.rds
#   - data/outputs/t4b/t4b_full_appE_<domain>_summary.csv
#   - data/outputs/t4b/t4b_full_appE_<domain>_stan_data.rds
#
# Notar que el dominio "centro_sur_eez" del archivo extended NO coincidira al
# decimal con el fit principal (que usa EnvCoastDaily diario, no monthly P1M-m,
# y unweighted spatial mean). Por eso el dominio centro_sur_eez aqui se etiqueta
# "centro_sur_eez_extended" en outputs y NO se publica como tabla principal --
# es la celda de comparacion para verificar que la diferencia es despreciable.
#
# Corre:
#   options(t4b.appE.run_main = TRUE)
#   source("R/08_stan_t4/14_refit_t4b_full_appendix_e.R")
#
# Para refittear solo un dominio (debug):
#   options(t4b.appE.run_main = TRUE,
#           t4b.appE.only = "se_pacific")
#   source("R/08_stan_t4/14_refit_t4b_full_appendix_e.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(yaml)
  library(lubridate)
  library(cmdstanr)
})

# Reusar el loader de inputs y la fabrica de stan_data del fit principal --
# no duplicamos logica. Lo unico que sobrescribimos es el bloque env.
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
source_utf8("R/08_stan_t4/08_fit_t4b_full.R")  # define load_t4b_full_inputs(),
                                                # build_t4b_full_stan_data(),
                                                # fit_t4b_full(), constantes

read_yaml_utf8 <- function(path) {
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  txt   <- rawToChar(bytes)
  Encoding(txt) <- "UTF-8"
  yaml::yaml.load(txt)
}

# -----------------------------------------------------------------------------
# Constantes propias de este script
# -----------------------------------------------------------------------------
APP_E_ENV_CSV  <- "data/bio_params/env_extended_3domains_2000_2024.csv"
APP_E_DOMAINS_ORDER <- c("centro_sur_eez", "offshore_ext", "se_pacific")
APP_E_OUT_DIR  <- T4B_FULL_OUT_DIR  # "data/outputs/t4b"

# -----------------------------------------------------------------------------
# Override env: en vez del bloque EnvCoastDaily, leer la serie de un dominio
# desde el CSV producido por 06_extended_env_anomalies.R
# -----------------------------------------------------------------------------
load_inputs_with_extended_env <- function(domain) {
  base <- load_t4b_full_inputs()  # carga scaa, ac_jurel, catch, env (EnvCoastDaily)

  ext <- readr::read_csv(APP_E_ENV_CSV, show_col_types = FALSE)
  if (!domain %in% unique(ext$domain)) {
    stop(sprintf("[appE-refit] Dominio '%s' no esta en %s. Disponibles: %s",
                 domain, APP_E_ENV_CSV,
                 paste(unique(ext$domain), collapse = ", ")))
  }
  env_d <- ext %>%
    dplyr::filter(domain == !!domain, year %in% T4B_FULL_WINDOW) %>%
    dplyr::arrange(year) %>%
    dplyr::transmute(year, sst, chl, SST_c, logCHL_c)

  if (nrow(env_d) != length(T4B_FULL_WINDOW)) {
    stop(sprintf("[appE-refit] Dominio %s: %d anios, esperaba %d",
                 domain, nrow(env_d), length(T4B_FULL_WINDOW)))
  }
  if (any(is.na(env_d$SST_c)) || any(is.na(env_d$logCHL_c))) {
    stop(sprintf("[appE-refit] Dominio %s: NA en SST_c/logCHL_c", domain))
  }

  base$env <- env_d
  base
}

# -----------------------------------------------------------------------------
# Fit por dominio
# -----------------------------------------------------------------------------
fit_one_domain <- function(domain, priors_yaml,
                           chains = 8, iter_warmup = 2000,
                           iter_sampling = 2000,
                           adapt_delta = 0.99, max_treedepth = 14,
                           seed = 2026L) {
  cat(strrep("-", 72), "\n", sep = "")
  cat(sprintf("[appE-refit] DOMINIO = %s\n", domain))
  cat(strrep("-", 72), "\n", sep = "")

  inputs    <- load_inputs_with_extended_env(domain)
  stan_data <- build_t4b_full_stan_data(inputs, priors_yaml)

  saveRDS(stan_data,
          file.path(APP_E_OUT_DIR,
                    sprintf("t4b_full_appE_%s_stan_data.rds", domain)))

  cat(sprintf("[appE-refit] Sampling %s -- chains=%d warmup=%d sampling=%d\n",
              domain, chains, iter_warmup, iter_sampling))
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
  fit$save_object(file.path(APP_E_OUT_DIR,
                            sprintf("t4b_full_appE_%s_fit.rds", domain)))

  smry <- fit$summary(variables = c("r_nat", "K_nat", "B0_nat",
                                    "sigma_proc", "sigma_obs",
                                    "rho_sst", "rho_chl", "Omega"))
  smry$domain <- domain
  readr::write_csv(smry,
                   file.path(APP_E_OUT_DIR,
                             sprintf("t4b_full_appE_%s_summary.csv", domain)))

  cat(sprintf("\n[appE-refit] %s -- diagnostico cmdstan:\n", domain))
  print(fit$cmdstan_diagnose())

  invisible(list(fit = fit, summary = smry))
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.appE.run_main", FALSE))) {
  cat(strrep("=", 72), "\n", sep = "")
  cat("T4b-FULL Apendice E -- refit espacial (3 dominios)\n")
  cat(strrep("=", 72), "\n\n", sep = "")

  if (!file.exists(APP_E_ENV_CSV)) {
    stop("Falta ", APP_E_ENV_CSV, ". Corre primero ",
         "R/06_projections/06_extended_env_anomalies.R")
  }

  priors <- read_yaml_utf8("data/bio_params/official_assessments.yaml")

  doms <- getOption("t4b.appE.only", APP_E_DOMAINS_ORDER)
  if (length(doms) == 1 && !doms %in% APP_E_DOMAINS_ORDER) {
    stop("t4b.appE.only debe ser uno de: ",
         paste(APP_E_DOMAINS_ORDER, collapse = ", "))
  }

  for (d in doms) {
    fit_one_domain(d, priors)
  }

  cat("\n[appE-refit] DONE. Siguiente: ",
      "R/08_stan_t4/15_appendix_e_sigma_ratios.R\n")
}
