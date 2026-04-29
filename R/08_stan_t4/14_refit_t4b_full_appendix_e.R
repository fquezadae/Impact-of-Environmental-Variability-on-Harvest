# =============================================================================
# FONDECYT -- 14_refit_t4b_full_appendix_e.R
#
# Apendice E del paper 1 -- robustez espacial de la NO-IDENTIFICACION de jurel.
#
# Refittea el T4b full con covariados ambientales STOCK-ESPECIFICOS
# (paper1/stan/t4b_state_space_full_stockenv.stan).
#
# En los 3 fits del Apendice:
#   - anch y sard usan SIEMPRE la serie centro_sur_eez (D1) -- es su habitat.
#   - jurel usa la serie del dominio de test:
#       * fit 1: jurel ve D1 (centro_sur_eez)        -> sanity, ~equivalente al fit principal
#       * fit 2: jurel ve D2 (offshore_ext)          -> primer test espacial
#       * fit 3: jurel ve D3 (se_pacific)            -> habitat regional pleno
#
# Identico al fit principal en TODO lo demas:
#   - Priors estructurales (r, K, B0, sigma_proc, sigma_obs, LKJ, rho)
#   - Datos de biomasa y captura (anch SCAA, sard SCAA, jur acustica)
#   - Ventana 2000-2024
#   - Sampler config (8 chains, warmup=2000, sampling=2000, adapt_delta=0.99,
#     max_treedepth=14)
#
# Lo UNICO que cambia entre fits es la columna 3 (jurel) de las matrices SST_c
# y logCHL_c. Anch y sard ven el mismo covariado en los 3 fits, asi que sus
# posteriors deberian ser ~estables (la unica fuente de movimiento es el
# coupling Omega contra jurel, que es chico).
#
# Outputs por dominio:
#   - data/outputs/t4b/t4b_full_appE_<domain>_fit.rds
#   - data/outputs/t4b/t4b_full_appE_<domain>_summary.csv
#   - data/outputs/t4b/t4b_full_appE_<domain>_stan_data.rds
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

# Reusar el loader y la fabrica de stan_data del fit principal -- no duplicamos
# logica. Lo unico que sobrescribimos al final es el bloque env (vector -> matrix).
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
                                                # constantes T4B_FULL_*

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

APP_E_STAN_FILE <- "paper1/stan/t4b_state_space_full_stockenv.stan"

# Idx de stocks en el modelo (debe coincidir con T4B_FULL_STOCKS y con la
# convencion IDX_* del Stan: anch=1, sard=2, jur=3)
APP_E_IDX_ANCH <- 1L
APP_E_IDX_SARD <- 2L
APP_E_IDX_JUR  <- 3L

# Dominio que ven anch y sard SIEMPRE (su habitat)
APP_E_BIO_DOMAIN_ANCHSARD <- "centro_sur_eez"

# -----------------------------------------------------------------------------
# Helper: leer una serie de un dominio en formato (sst, chl, SST_c, logCHL_c)
# ordenada por anio
# -----------------------------------------------------------------------------
load_extended_env_for_domain <- function(domain) {
  ext <- readr::read_csv(APP_E_ENV_CSV, show_col_types = FALSE)
  if (!domain %in% unique(ext$domain)) {
    stop(sprintf("[appE-refit] Dominio '%s' no esta en %s. Disponibles: %s",
                 domain, APP_E_ENV_CSV,
                 paste(unique(ext$domain), collapse = ", ")))
  }
  env_d <- ext %>%
    dplyr::filter(domain == !!domain, year %in% T4B_FULL_WINDOW) %>%
    dplyr::arrange(year) %>%
    dplyr::select(year, sst, chl, SST_c, logCHL_c)

  if (nrow(env_d) != length(T4B_FULL_WINDOW)) {
    stop(sprintf("[appE-refit] Dominio %s: %d anios, esperaba %d",
                 domain, nrow(env_d), length(T4B_FULL_WINDOW)))
  }
  if (any(is.na(env_d$SST_c)) || any(is.na(env_d$logCHL_c))) {
    stop(sprintf("[appE-refit] Dominio %s: NA en SST_c/logCHL_c", domain))
  }
  env_d
}

# -----------------------------------------------------------------------------
# Build stan_data para el modelo stockenv: matrix[T, S] de SST_c y logCHL_c
#
# anch (idx 1) y sard (idx 2) usan la serie de APP_E_BIO_DOMAIN_ANCHSARD
# jurel (idx 3) usa la serie de jurel_test_domain
# -----------------------------------------------------------------------------
build_stan_data_stockenv <- function(jurel_test_domain, priors_yaml) {
  inputs <- load_t4b_full_inputs()

  env_anchsard <- load_extended_env_for_domain(APP_E_BIO_DOMAIN_ANCHSARD)
  env_jurel    <- load_extended_env_for_domain(jurel_test_domain)

  # build_t4b_full_stan_data espera env como tibble con columnas SST_c/logCHL_c.
  # Le pasamos la serie de anch/sard como placeholder; despues sobrescribimos
  # SST_c y logCHL_c con matrices [T, S].
  inputs$env <- env_anchsard
  stan_data  <- build_t4b_full_stan_data(inputs, priors_yaml)

  T_  <- stan_data$T
  S_  <- stan_data$S
  stopifnot(S_ == 3L,
            length(env_anchsard$SST_c) == T_,
            length(env_jurel$SST_c)    == T_)

  SST_mat <- matrix(0, nrow = T_, ncol = S_)
  CHL_mat <- matrix(0, nrow = T_, ncol = S_)
  SST_mat[, APP_E_IDX_ANCH] <- env_anchsard$SST_c
  SST_mat[, APP_E_IDX_SARD] <- env_anchsard$SST_c
  SST_mat[, APP_E_IDX_JUR ] <- env_jurel$SST_c
  CHL_mat[, APP_E_IDX_ANCH] <- env_anchsard$logCHL_c
  CHL_mat[, APP_E_IDX_SARD] <- env_anchsard$logCHL_c
  CHL_mat[, APP_E_IDX_JUR ] <- env_jurel$logCHL_c

  stan_data$SST_c    <- SST_mat
  stan_data$logCHL_c <- CHL_mat

  cat(sprintf("[appE-refit] stockenv data:\n"))
  cat(sprintf("  anch/sard env   = %s (sd SST_c=%.3f, sd logCHL_c=%.3f)\n",
              APP_E_BIO_DOMAIN_ANCHSARD,
              sd(env_anchsard$SST_c), sd(env_anchsard$logCHL_c)))
  cat(sprintf("  jurel env       = %s (sd SST_c=%.3f, sd logCHL_c=%.3f)\n",
              jurel_test_domain,
              sd(env_jurel$SST_c), sd(env_jurel$logCHL_c)))
  cat(sprintf("  cor SST(anchsard, jurel) = %.3f\n",
              cor(env_anchsard$SST_c, env_jurel$SST_c)))
  cat(sprintf("  cor logCHL(anchsard, jurel) = %.3f\n",
              cor(env_anchsard$logCHL_c, env_jurel$logCHL_c)))

  stan_data
}

# -----------------------------------------------------------------------------
# Fit por dominio (jurel ve <jurel_test_domain>; anch y sard ven D1)
# -----------------------------------------------------------------------------
fit_one_domain <- function(jurel_test_domain, priors_yaml,
                           chains = 8, iter_warmup = 2000,
                           iter_sampling = 2000,
                           adapt_delta = 0.99, max_treedepth = 14,
                           seed = 2026L) {
  cat(strrep("-", 72), "\n", sep = "")
  cat(sprintf("[appE-refit] JUREL DOMAIN = %s   (anch/sard fijo en %s)\n",
              jurel_test_domain, APP_E_BIO_DOMAIN_ANCHSARD))
  cat(strrep("-", 72), "\n", sep = "")

  stan_data <- build_stan_data_stockenv(jurel_test_domain, priors_yaml)

  saveRDS(stan_data,
          file.path(APP_E_OUT_DIR,
                    sprintf("t4b_full_appE_%s_stan_data.rds",
                            jurel_test_domain)))

  cat(sprintf("[appE-refit] Sampling -- chains=%d warmup=%d sampling=%d\n",
              chains, iter_warmup, iter_sampling))
  mod <- cmdstanr::cmdstan_model(APP_E_STAN_FILE)
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
                            sprintf("t4b_full_appE_%s_fit.rds",
                                    jurel_test_domain)))

  smry <- fit$summary(variables = c("r_nat", "K_nat", "B0_nat",
                                    "sigma_proc", "sigma_obs",
                                    "rho_sst", "rho_chl", "Omega"))
  smry$jurel_domain <- jurel_test_domain
  readr::write_csv(smry,
                   file.path(APP_E_OUT_DIR,
                             sprintf("t4b_full_appE_%s_summary.csv",
                                     jurel_test_domain)))

  cat(sprintf("\n[appE-refit] %s -- diagnostico cmdstan:\n", jurel_test_domain))
  print(fit$cmdstan_diagnose())

  invisible(list(fit = fit, summary = smry))
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.appE.run_main", FALSE))) {
  cat(strrep("=", 72), "\n", sep = "")
  cat("T4b-FULL Apendice E -- refit con env STOCK-ESPECIFICO\n")
  cat("anch/sard fijo en centro_sur_eez | jurel itera sobre D1/D2/D3\n")
  cat(strrep("=", 72), "\n\n", sep = "")

  if (!file.exists(APP_E_ENV_CSV)) {
    stop("Falta ", APP_E_ENV_CSV, ". Corre primero ",
         "R/06_projections/06_extended_env_anomalies.R")
  }
  if (!file.exists(APP_E_STAN_FILE)) {
    stop("Falta ", APP_E_STAN_FILE)
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
