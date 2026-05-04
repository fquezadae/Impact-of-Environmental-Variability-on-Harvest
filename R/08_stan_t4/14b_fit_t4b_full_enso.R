# =============================================================================
# FONDECYT -- 14b_fit_t4b_full_enso.R
#
# Paper 1, pivote ENSO 2026-05-04 (project_paper1_enso_pivot).
#
# Refit del T4b-full-stockenv extendido con shifter ENSO basin-scale (Nino 3.4)
# sobre jurel. La narrativa estructural es REEMPLAZO, no adicion:
#
#   - anch (s=1): r_t = r0 * exp(rho_sst[1]*SST_D1[t-1] + rho_chl[1]*logCHL_D1[t-1])
#                 rho_enso[1] PINNED a 0 via prior N(0, 0.01).
#   - sard (s=2): r_t = r0 * exp(rho_sst[2]*SST_D1[t-1] + rho_chl[2]*logCHL_D1[t-1])
#                 rho_enso[2] PINNED a 0 via prior N(0, 0.01).
#   - jurel (s=3): r_t = r0 * exp(rho_enso[3]*ENSO_c[t-1])
#                 rho_sst[3] y rho_chl[3] PINNED a 0 via priors N(0, 0.01).
#                 Ademas, SST_c[,3] y logCHL_c[,3] forzados a vector de ceros
#                 (doblemente seguro contra leakage).
#
# Pinning via prior tight (sd=0.01) en lugar de mascara binaria mantiene la
# geometria del modelo identica al stockenv original (un solo Stan code para
# auditar). El rho_*[3] que nos importa en el output es rho_enso[3] -- los
# rho_sst[3] y rho_chl[3] del summary aparecen colapsados a ~0 con sd ~0.01.
#
# Spec principal: lag 1 (ENSO_c[t-1] consume 24 observaciones de la ventana
# 2000-2024 -- mismo lag que SST/CHL costeros). Spec sensibilidad lag 2
# disponible via option(t4b.enso.lag = 2).
#
# Outputs (en data/outputs/t4b/):
#   - t4b_full_enso_lag1_fit.rds          (cmdstanr fit object)
#   - t4b_full_enso_lag1_summary.csv      (posterior summary, incluye rho_enso)
#   - t4b_full_enso_lag1_stan_data.rds    (input data preservado)
#
# Uso:
#   options(t4b.enso.run_main = TRUE)
#   options(t4b.enso.lag      = 1L)        # 1 (principal) o 2 (sensibilidad)
#   source("R/00_config/config.R")
#   source("R/08_stan_t4/14b_fit_t4b_full_enso.R")
#
# Bloqueado por:
#   - data/bio_params/enso_nino34_annual_2000_2024.csv (extract_oisst_nino34.R, listo)
#   - data/bio_params/env_extended_3domains_2000_2024.csv (06_extended_env_anomalies.R, listo)
#   - paper1/stan/t4b_state_space_full_stockenv_enso.stan (este pivote, listo)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(yaml)
  library(cmdstanr)
})

# Helper UTF-8 safe source -- igual que 14_refit_t4b_full_appendix_e.R
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
source_utf8("R/08_stan_t4/08_fit_t4b_full.R")
# 08_fit_t4b_full.R define load_t4b_full_inputs(), build_t4b_full_stan_data(),
# y constantes T4B_FULL_*. Reusamos la fabrica de stan_data y solo
# sobrescribimos los slots SST/CHL/ENSO + priors rho_*.

# YAML loader UTF-8 safe -- igual que 14_refit_t4b_full_appendix_e.R
read_yaml_utf8 <- function(path) {
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  txt   <- rawToChar(bytes)
  Encoding(txt) <- "UTF-8"
  yaml::yaml.load(txt)
}

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
ENSO_STAN_FILE   <- "paper1/stan/t4b_state_space_full_stockenv_enso.stan"
ENSO_OUT_DIR     <- T4B_FULL_OUT_DIR  # "data/outputs/t4b"
ENSO_ENV_CSV     <- "data/bio_params/env_extended_3domains_2000_2024.csv"
ENSO_NINO34_CSV  <- "data/bio_params/enso_nino34_annual_2000_2024.csv"
ENSO_BIO_DOMAIN_ANCHSARD <- "centro_sur_eez"

# Indices stock-specific
ENSO_IDX_ANCH <- 1L
ENSO_IDX_SARD <- 2L
ENSO_IDX_JUR  <- 3L

# Lag default = 1 (matchea con SST_D1 del fit principal)
ENSO_LAG_DEFAULT <- 1L

# -----------------------------------------------------------------------------
# Priors stock-specific para los 3 shifters bajo la convencion de REEMPLAZO
# -----------------------------------------------------------------------------
# Anch y sard: identicos al fit principal (T4B_FULL_RHO_SST_*/T4B_FULL_RHO_CHL_*).
# rho_enso pinned a 0 con sd=0.01.
# Jurel: rho_sst y rho_chl pinned a 0 con sd=0.01; rho_enso recibe N(0, 0.5)
#        (decidido 2026-05-04 -- ver project_paper1_enso_pivot.md).
ENSO_RHO_SST_MEAN <- c(T4B_FULL_RHO_SST_MEAN[1],
                       T4B_FULL_RHO_SST_MEAN[2],
                       0.0)
ENSO_RHO_SST_SD   <- c(T4B_FULL_RHO_SST_SD[1],
                       T4B_FULL_RHO_SST_SD[2],
                       0.01)        # jurel SST pinned

ENSO_RHO_CHL_MEAN <- c(T4B_FULL_RHO_CHL_MEAN[1],
                       T4B_FULL_RHO_CHL_MEAN[2],
                       0.0)
ENSO_RHO_CHL_SD   <- c(T4B_FULL_RHO_CHL_SD[1],
                       T4B_FULL_RHO_CHL_SD[2],
                       0.01)        # jurel CHL pinned

# anch, sard pinned a 0 en ENSO; jurel activo con N(0, 0.5)
ENSO_RHO_ENSO_MEAN <- c(0.0, 0.0, 0.0)
ENSO_RHO_ENSO_SD   <- c(0.01, 0.01, 0.5)

# -----------------------------------------------------------------------------
# Helper: cargar serie ENSO anual + aplicar lag
# -----------------------------------------------------------------------------
load_enso_centered_lag <- function(lag = ENSO_LAG_DEFAULT) {
  if (!file.exists(ENSO_NINO34_CSV)) {
    stop("[t4b-enso] no encontre ", ENSO_NINO34_CSV,
         ". Corre primero R/01_data/extract_oisst_nino34.R")
  }
  enso <- readr::read_csv(ENSO_NINO34_CSV, show_col_types = FALSE) %>%
    dplyr::filter(year %in% T4B_FULL_WINDOW) %>%
    dplyr::arrange(year)
  if (nrow(enso) != length(T4B_FULL_WINDOW)) {
    stop(sprintf("[t4b-enso] esperaba %d anios en %s, obtuve %d",
                 length(T4B_FULL_WINDOW), ENSO_NINO34_CSV, nrow(enso)))
  }
  if (any(is.na(enso$ENSO_c))) {
    stop("[t4b-enso] NA en ENSO_c -- revisar extract_oisst_nino34.R")
  }
  cat(sprintf("[t4b-enso] ENSO_c: sd=%.3f, mean=%.4f, range=[%.2f, %.2f]\n",
              sd(enso$ENSO_c), mean(enso$ENSO_c),
              min(enso$ENSO_c), max(enso$ENSO_c)))
  cat(sprintf("[t4b-enso] aplicando lag %d (Stan ya hace t-1; lag>1 = pre-shift)\n",
              lag))
  if (lag <= 0) stop("[t4b-enso] lag debe ser >= 1")
  if (lag == 1L) return(enso$ENSO_c)
  # Lag 2: shift por 1 mas en R-side. Y_t respondera a ENSO_{t-2}.
  # Stan ya consume ENSO_c[t-1], asi que para "lag 2" pasamos un vector
  # donde la posicion t es ENSO en year (year[t] - 1). Eso compone con el
  # t-1 del Stan a Y_t respondiendo a ENSO_{t-2}.
  # Anios: [yr1, yr2, ..., yrT]. ENSO_c original esta sobre yr1..yrT.
  # Vector lag-1 (R-side) sobre los mismos T anios = [NA, ENSO_c[1..T-1]].
  # Reemplazamos NA por la media muestral (centrado, asi 0).
  shifted <- c(rep(0, lag - 1L), head(enso$ENSO_c, -(lag - 1L)))
  shifted
}

# -----------------------------------------------------------------------------
# Build stan_data ENSO: extiende build_t4b_full_stan_data anadiendo
# matrix[T,S] SST_c, matrix[T,S] logCHL_c stock-specific (igual al apendice E),
# vector[T] ENSO_c basin-scale, y los 3 priors rho_*.
# -----------------------------------------------------------------------------
build_stan_data_enso <- function(lag = ENSO_LAG_DEFAULT) {
  # Reusar inputs y stan_data base (anch+sard env = D1 = centro_sur_eez)
  inputs <- load_t4b_full_inputs()

  # Cargar D1 para anch/sard (idem appE-D1)
  ext <- readr::read_csv(ENSO_ENV_CSV, show_col_types = FALSE) %>%
    dplyr::filter(domain == ENSO_BIO_DOMAIN_ANCHSARD,
                  year %in% T4B_FULL_WINDOW) %>%
    dplyr::arrange(year) %>%
    dplyr::select(year, sst, chl, SST_c, logCHL_c)
  if (nrow(ext) != length(T4B_FULL_WINDOW)) {
    stop("[t4b-enso] D1 env no completo")
  }

  inputs$env <- ext  # placeholder; sobrescribiremos

  # Cargar priors estructurales del YAML official_assessments (igual que
  # 14_refit_t4b_full_appendix_e.R). build_t4b_full_stan_data los necesita
  # para r_prior, K_prior, M_prior, sigma_obs_prior, etc.
  priors <- read_yaml_utf8("data/bio_params/official_assessments.yaml")
  stan_data  <- build_t4b_full_stan_data(inputs, priors)

  T_ <- stan_data$T
  S_ <- stan_data$S
  stopifnot(S_ == 3L, length(ext$SST_c) == T_)

  # Matrices SST_c y logCHL_c stock-specific
  SST_mat <- matrix(0, nrow = T_, ncol = S_)
  CHL_mat <- matrix(0, nrow = T_, ncol = S_)

  # anch, sard: usan D1 (su habitat real)
  SST_mat[, ENSO_IDX_ANCH] <- ext$SST_c
  SST_mat[, ENSO_IDX_SARD] <- ext$SST_c
  CHL_mat[, ENSO_IDX_ANCH] <- ext$logCHL_c
  CHL_mat[, ENSO_IDX_SARD] <- ext$logCHL_c

  # jurel: forzado a cero en SST/CHL (REEMPLAZO total). Doblemente seguro
  # con los priors tight rho_sst[3]=N(0,0.01), rho_chl[3]=N(0,0.01).
  # SST_mat[, ENSO_IDX_JUR] = 0 ya inicializado.
  # CHL_mat[, ENSO_IDX_JUR] = 0 ya inicializado.

  # ENSO_c basin-scale (1 sola serie, no stock-specific)
  ENSO_vec <- load_enso_centered_lag(lag)
  stopifnot(length(ENSO_vec) == T_)

  # Inyectar al stan_data y sobreescribir los priors rho_*
  stan_data$SST_c              <- SST_mat
  stan_data$logCHL_c           <- CHL_mat
  stan_data$ENSO_c             <- ENSO_vec
  stan_data$rho_sst_prior_mean <- ENSO_RHO_SST_MEAN
  stan_data$rho_sst_prior_sd   <- ENSO_RHO_SST_SD
  stan_data$rho_chl_prior_mean <- ENSO_RHO_CHL_MEAN
  stan_data$rho_chl_prior_sd   <- ENSO_RHO_CHL_SD
  stan_data$rho_enso_prior_mean <- ENSO_RHO_ENSO_MEAN
  stan_data$rho_enso_prior_sd   <- ENSO_RHO_ENSO_SD

  # Diagnostico
  cat("\n[t4b-enso] stan_data ENSO listo:\n")
  cat(sprintf("  T = %d, S = %d\n", T_, S_))
  cat(sprintf("  anch/sard SST_D1 sd = %.3f, logCHL_D1 sd = %.3f\n",
              sd(ext$SST_c), sd(ext$logCHL_c)))
  cat(sprintf("  jurel SST_c[,3] = 0 (REEMPLAZADO por ENSO via priors tight)\n"))
  cat(sprintf("  ENSO_c sd = %.3f, lag = %d\n", sd(ENSO_vec), lag))
  cat("\n  Priors rho stock-specific:\n")
  for (s in seq_len(S_)) {
    cat(sprintf("    s=%d: rho_sst ~N(%+.2f, %.2f), rho_chl ~N(%+.2f, %.2f), rho_enso ~N(%+.2f, %.2f)\n",
                s,
                ENSO_RHO_SST_MEAN[s],  ENSO_RHO_SST_SD[s],
                ENSO_RHO_CHL_MEAN[s],  ENSO_RHO_CHL_SD[s],
                ENSO_RHO_ENSO_MEAN[s], ENSO_RHO_ENSO_SD[s]))
  }

  stan_data
}

# -----------------------------------------------------------------------------
# Fit
# -----------------------------------------------------------------------------
fit_t4b_enso <- function(lag = ENSO_LAG_DEFAULT,
                         chains = 8, iter_warmup = 2000,
                         iter_sampling = 2000,
                         adapt_delta = 0.99, max_treedepth = 14,
                         seed = 2026L) {
  cat(strrep("=", 72), "\n", sep = "")
  cat(sprintf("T4b-FULL ENSO refit -- lag %d (Nino 3.4 basin-scale)\n", lag))
  cat("Replazo: jurel ve solo ENSO; anch/sard sin cambios (SST_D1 + logCHL_D1)\n")
  cat(strrep("=", 72), "\n\n", sep = "")

  if (!file.exists(ENSO_STAN_FILE)) stop("Falta ", ENSO_STAN_FILE)

  stan_data <- build_stan_data_enso(lag)

  out_tag <- sprintf("t4b_full_enso_lag%d", lag)
  saveRDS(stan_data,
          file.path(ENSO_OUT_DIR, sprintf("%s_stan_data.rds", out_tag)))

  cat(sprintf("\n[t4b-enso] sampling -- chains=%d warmup=%d sampling=%d adapt_delta=%.2f\n",
              chains, iter_warmup, iter_sampling, adapt_delta))
  mod <- cmdstanr::cmdstan_model(ENSO_STAN_FILE)
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
  fit$save_object(file.path(ENSO_OUT_DIR, sprintf("%s_fit.rds", out_tag)))

  smry <- fit$summary(
    variables = c("r_nat", "K_nat", "B0_nat",
                  "sigma_proc", "sigma_obs",
                  "rho_sst", "rho_chl", "rho_enso", "Omega")
  )
  smry$lag <- lag
  readr::write_csv(smry,
                   file.path(ENSO_OUT_DIR, sprintf("%s_summary.csv", out_tag)))

  cat(sprintf("\n[t4b-enso] %s -- diagnostico cmdstan:\n", out_tag))
  print(fit$cmdstan_diagnose())

  # Headline: rho_enso[3] sigma_post / sigma_prior
  rho_enso_jurel <- smry %>%
    dplyr::filter(variable == "rho_enso[3]")
  if (nrow(rho_enso_jurel) == 1L) {
    sigma_prior <- ENSO_RHO_ENSO_SD[ENSO_IDX_JUR]
    sigma_post  <- rho_enso_jurel$sd
    ratio       <- sigma_post / sigma_prior
    cat(sprintf("\n[t4b-enso] HEADLINE: rho_enso[3] = %.3f (90%% CI [%.2f, %.2f]); sigma_post=%.3f / sigma_prior=%.3f -> ratio=%.3f\n",
                rho_enso_jurel$median,
                rho_enso_jurel$q5, rho_enso_jurel$q95,
                sigma_post, sigma_prior, ratio))
    if (ratio <= 0.7) {
      cat("[t4b-enso] => ESCENARIO A: ENSO IDENTIFICA jurel (ratio <= 0.7)\n")
    } else if (ratio <= 0.85) {
      cat("[t4b-enso] => Marginal: ratio en (0.7, 0.85] -- discutir como evidencia parcial\n")
    } else {
      cat("[t4b-enso] => ESCENARIO B: ENSO no identifica (ratio > 0.85). Null cuarta evidencia.\n")
    }
  }

  invisible(list(fit = fit, summary = smry))
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.enso.run_main", FALSE))) {
  lag <- as.integer(getOption("t4b.enso.lag", ENSO_LAG_DEFAULT))
  fit_t4b_enso(lag = lag)
  cat(sprintf("\n[t4b-enso] DONE lag %d.\n", lag))
  cat("Para sensibilidad lag 2:\n")
  cat("  options(t4b.enso.run_main = TRUE, t4b.enso.lag = 2L)\n")
  cat("  source('R/08_stan_t4/14b_fit_t4b_full_enso.R')\n")
}
