# =============================================================================
# FONDECYT -- 14c_fit_t4b_full_enso_joint.R
#
# Paper 1, pivote ENSO 2026-05-04 -- VARIANTE JOINT.
#
# Sensibilidad estandar del referee: en lugar de la convencion de REEMPLAZO
# del 14b (jurel ve solo ENSO; SST/CHL costeros pinned a 0), aqui dejamos los
# TRES shifters activos para jurel y dejamos que los datos hablen.
#
# Diferencia con 14b (que es el principal):
#
#   14b   "REEMPLAZO":  jurel ve solo ENSO
#         rho_sst[3]  ~ N(0, 0.01)   <- pinned a 0
#         rho_chl[3]  ~ N(0, 0.01)   <- pinned a 0
#         rho_enso[3] ~ N(0, 0.5)    <- activo
#         SST_c[,3]    = 0           <- doblemente seguro
#         logCHL_c[,3] = 0
#
#   14c   "JOINT" (este script): jurel ve los tres
#         rho_sst[3]  ~ N(0, 1.5)    <- activo (igual al fit principal)
#         rho_chl[3]  ~ N(0, 1.5)    <- activo
#         rho_enso[3] ~ N(0, 0.5)    <- activo
#         SST_c[,3]    = SST_D1 real <- usa la serie costera D1
#         logCHL_c[,3] = logCHL_D1 real
#
# Justificacion econometrica para hacer este test:
#   - Con N=24 obs y K=5 regresores efectivos (intercept + B/K + 3 shifters)
#     hay df=19, suficiente para no sobreajustar.
#   - cor(SST_D1, logCHL_D1) = 0.03 (raw, stress test 2026-04-21).
#   - cor lag-1(ENSO, SST_D1) = 0.09 (verificado en extract_oisst_nino34.R).
#   - cor lag-1(ENSO, logCHL_D1) = 0.18.
#   Las 3 covariates son aproximadamente ortogonales al lag relevante para la
#   identificacion dinamica. Sin colinearidad seria.
#
# Lectura esperada (dado Escenario B en lag-1 14b):
#   - rho_enso[3] esperado: median ~ -0.022 (igual al 14b porque lag-1 dio
#     null y aqui solo agregamos covariates ortogonales).
#   - rho_sst[3] esperado: ratio ~ 0.85-0.95 (similar al fit principal).
#   - rho_chl[3] esperado: ratio ~ 0.95-1.0 (similar al fit principal).
#   - Anch/sard sin cambios materiales (son los mismos datos D1).
#
# Si los tres ratios de jurel exceden 0.85 -> evidencia REFORZADA del null:
# tres covariates simultaneas, todas no-identificadas, con minima correlacion
# entre ellas. El referee no puede pedir "y si los pones todos juntos"
# despues de esto.
#
# Outputs en data/outputs/t4b/:
#   - t4b_full_enso_joint_lag1_fit.rds
#   - t4b_full_enso_joint_lag1_summary.csv
#   - t4b_full_enso_joint_lag1_stan_data.rds
#
# Uso:
#   options(t4b.enso.joint.run_main = TRUE)
#   options(t4b.enso.joint.lag      = 1L)         # 1 default; 2 sensibilidad
#   source("R/00_config/config.R")
#   source("R/08_stan_t4/14c_fit_t4b_full_enso_joint.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
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
source_utf8("R/08_stan_t4/08_fit_t4b_full.R")
# 08_fit_t4b_full.R define load_t4b_full_inputs(), build_t4b_full_stan_data(),
# T4B_FULL_*, T4B_FULL_RHO_SST_*, T4B_FULL_RHO_CHL_*.

read_yaml_utf8 <- function(path) {
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  txt   <- rawToChar(bytes)
  Encoding(txt) <- "UTF-8"
  yaml::yaml.load(txt)
}

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
ENSO_J_STAN_FILE   <- "paper1/stan/t4b_state_space_full_stockenv_enso.stan"
ENSO_J_OUT_DIR     <- T4B_FULL_OUT_DIR
ENSO_J_ENV_CSV     <- "data/bio_params/env_extended_3domains_2000_2024.csv"
ENSO_J_NINO34_CSV  <- "data/bio_params/enso_nino34_annual_2000_2024.csv"
ENSO_J_BIO_DOMAIN  <- "centro_sur_eez"

ENSO_J_IDX_ANCH <- 1L
ENSO_J_IDX_SARD <- 2L
ENSO_J_IDX_JUR  <- 3L

ENSO_J_LAG_DEFAULT <- 1L

# -----------------------------------------------------------------------------
# Priors stock-specific bajo convencion JOINT (jurel ve los TRES shifters)
# -----------------------------------------------------------------------------
# anch y sard: identicos al fit principal y al 14b -- no se mueven.
# jurel: SST y CHL retoman los priors del fit principal del paper (N(0, 1.5)),
#        ENSO usa el N(0, 0.5) decidido 2026-05-04.
ENSO_J_RHO_SST_MEAN <- T4B_FULL_RHO_SST_MEAN
ENSO_J_RHO_SST_SD   <- T4B_FULL_RHO_SST_SD          # c(1.0, 1.0, 1.0) en el fit principal

ENSO_J_RHO_CHL_MEAN <- T4B_FULL_RHO_CHL_MEAN
ENSO_J_RHO_CHL_SD   <- T4B_FULL_RHO_CHL_SD          # idem

# anch, sard pinned en ENSO; jurel activo
ENSO_J_RHO_ENSO_MEAN <- c(0.0, 0.0, 0.0)
ENSO_J_RHO_ENSO_SD   <- c(0.01, 0.01, 0.5)

# -----------------------------------------------------------------------------
# Helper: cargar serie ENSO anual con lag (idem 14b)
# -----------------------------------------------------------------------------
load_enso_centered_lag_joint <- function(lag = ENSO_J_LAG_DEFAULT) {
  if (!file.exists(ENSO_J_NINO34_CSV)) {
    stop("[t4b-enso-joint] no encontre ", ENSO_J_NINO34_CSV)
  }
  enso <- readr::read_csv(ENSO_J_NINO34_CSV, show_col_types = FALSE) %>%
    dplyr::filter(year %in% T4B_FULL_WINDOW) %>%
    dplyr::arrange(year)
  if (nrow(enso) != length(T4B_FULL_WINDOW)) {
    stop("[t4b-enso-joint] ENSO csv incompleto")
  }
  if (lag <= 0) stop("[t4b-enso-joint] lag debe ser >= 1")
  if (lag == 1L) return(enso$ENSO_c)
  shifted <- c(rep(0, lag - 1L), head(enso$ENSO_c, -(lag - 1L)))
  shifted
}

# -----------------------------------------------------------------------------
# Build stan_data JOINT: jurel ve SST_D1 + logCHL_D1 + ENSO simultaneamente.
# -----------------------------------------------------------------------------
build_stan_data_enso_joint <- function(lag = ENSO_J_LAG_DEFAULT) {
  inputs <- load_t4b_full_inputs()

  ext <- readr::read_csv(ENSO_J_ENV_CSV, show_col_types = FALSE) %>%
    dplyr::filter(domain == ENSO_J_BIO_DOMAIN, year %in% T4B_FULL_WINDOW) %>%
    dplyr::arrange(year) %>%
    dplyr::select(year, sst, chl, SST_c, logCHL_c)
  if (nrow(ext) != length(T4B_FULL_WINDOW)) {
    stop("[t4b-enso-joint] D1 env no completo")
  }

  inputs$env <- ext
  priors <- read_yaml_utf8("data/bio_params/official_assessments.yaml")
  stan_data <- build_t4b_full_stan_data(inputs, priors)

  T_ <- stan_data$T
  S_ <- stan_data$S
  stopifnot(S_ == 3L, length(ext$SST_c) == T_)

  # JOINT: TODAS las columnas usan la serie real D1 (anch=sard=jurel comparten habitat).
  # Diferencia clave con 14b: jurel NO se zero-outea en SST/CHL.
  SST_mat <- matrix(0, nrow = T_, ncol = S_)
  CHL_mat <- matrix(0, nrow = T_, ncol = S_)
  for (s in seq_len(S_)) {
    SST_mat[, s] <- ext$SST_c
    CHL_mat[, s] <- ext$logCHL_c
  }

  ENSO_vec <- load_enso_centered_lag_joint(lag)
  stopifnot(length(ENSO_vec) == T_)

  stan_data$SST_c              <- SST_mat
  stan_data$logCHL_c           <- CHL_mat
  stan_data$ENSO_c             <- ENSO_vec
  stan_data$rho_sst_prior_mean <- ENSO_J_RHO_SST_MEAN
  stan_data$rho_sst_prior_sd   <- ENSO_J_RHO_SST_SD
  stan_data$rho_chl_prior_mean <- ENSO_J_RHO_CHL_MEAN
  stan_data$rho_chl_prior_sd   <- ENSO_J_RHO_CHL_SD
  stan_data$rho_enso_prior_mean <- ENSO_J_RHO_ENSO_MEAN
  stan_data$rho_enso_prior_sd   <- ENSO_J_RHO_ENSO_SD

  cat("\n[t4b-enso-joint] stan_data JOINT listo:\n")
  cat(sprintf("  T = %d, S = %d\n", T_, S_))
  cat(sprintf("  TODOS los stocks (anch/sard/jurel) ven D1 en SST y logCHL\n"))
  cat(sprintf("  jurel ADEMAS ve ENSO basin-scale\n"))
  cat(sprintf("  ENSO_c sd = %.3f, lag = %d\n", sd(ENSO_vec), lag))
  cat("\n  Priors rho stock-specific (JOINT):\n")
  for (s in seq_len(S_)) {
    cat(sprintf("    s=%d: rho_sst ~N(%+.2f, %.2f), rho_chl ~N(%+.2f, %.2f), rho_enso ~N(%+.2f, %.2f)\n",
                s,
                ENSO_J_RHO_SST_MEAN[s],  ENSO_J_RHO_SST_SD[s],
                ENSO_J_RHO_CHL_MEAN[s],  ENSO_J_RHO_CHL_SD[s],
                ENSO_J_RHO_ENSO_MEAN[s], ENSO_J_RHO_ENSO_SD[s]))
  }

  stan_data
}

# -----------------------------------------------------------------------------
# Fit
# -----------------------------------------------------------------------------
fit_t4b_enso_joint <- function(lag = ENSO_J_LAG_DEFAULT,
                               chains = 8, iter_warmup = 2000,
                               iter_sampling = 2000,
                               adapt_delta = 0.99, max_treedepth = 14,
                               seed = 2026L) {
  cat(strrep("=", 72), "\n", sep = "")
  cat(sprintf("T4b-FULL ENSO JOINT refit -- lag %d (jurel ve SST_D1 + logCHL_D1 + ENSO)\n", lag))
  cat("Sensibilidad referee: deja los 3 shifters libres simultaneamente para jurel\n")
  cat(strrep("=", 72), "\n\n", sep = "")

  if (!file.exists(ENSO_J_STAN_FILE)) stop("Falta ", ENSO_J_STAN_FILE)

  stan_data <- build_stan_data_enso_joint(lag)

  out_tag <- sprintf("t4b_full_enso_joint_lag%d", lag)
  saveRDS(stan_data,
          file.path(ENSO_J_OUT_DIR, sprintf("%s_stan_data.rds", out_tag)))

  cat(sprintf("\n[t4b-enso-joint] sampling -- chains=%d warmup=%d sampling=%d\n",
              chains, iter_warmup, iter_sampling))
  mod <- cmdstanr::cmdstan_model(ENSO_J_STAN_FILE)
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
  fit$save_object(file.path(ENSO_J_OUT_DIR, sprintf("%s_fit.rds", out_tag)))

  smry <- fit$summary(
    variables = c("r_nat", "K_nat", "B0_nat",
                  "sigma_proc", "sigma_obs",
                  "rho_sst", "rho_chl", "rho_enso", "Omega")
  )
  smry$lag <- lag
  smry$spec <- "joint"
  readr::write_csv(smry,
                   file.path(ENSO_J_OUT_DIR, sprintf("%s_summary.csv", out_tag)))

  cat(sprintf("\n[t4b-enso-joint] %s -- diagnostico cmdstan:\n", out_tag))
  print(fit$cmdstan_diagnose())

  # Headline: sigma_post / sigma_prior para los 3 shifters de jurel
  cat("\n[t4b-enso-joint] HEADLINE jurel (s=3) bajo JOINT:\n")
  for (var in c("rho_sst[3]", "rho_chl[3]", "rho_enso[3]")) {
    row <- smry %>% dplyr::filter(variable == var)
    if (nrow(row) == 1L) {
      sigma_prior <- if (var == "rho_enso[3]") ENSO_J_RHO_ENSO_SD[3] else
                     if (var == "rho_sst[3]")  ENSO_J_RHO_SST_SD[3] else
                                                ENSO_J_RHO_CHL_SD[3]
      sigma_post <- row$sd
      ratio      <- sigma_post / sigma_prior
      cat(sprintf("  %s: median=%+.3f  90%% CI [%+.2f, %+.2f]  sigma_post=%.3f / sigma_prior=%.2f -> ratio=%.3f\n",
                  var, row$median, row$q5, row$q95,
                  sigma_post, sigma_prior, ratio))
    }
  }
  cat("\n[t4b-enso-joint] Lectura: si los tres ratios de jurel > 0.85 -> null reforzado\n")
  cat("                              (3 shifters ortogonales no identifican simultaneamente)\n")
  cat("                          si alguno <= 0.70 -> ese shifter identifica condicional\n")
  cat("                              en los otros dos -- importante para la narrativa\n")

  invisible(list(fit = fit, summary = smry))
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.enso.joint.run_main", FALSE))) {
  lag <- as.integer(getOption("t4b.enso.joint.lag", ENSO_J_LAG_DEFAULT))
  fit_t4b_enso_joint(lag = lag)
  cat(sprintf("\n[t4b-enso-joint] DONE lag %d.\n", lag))
}
