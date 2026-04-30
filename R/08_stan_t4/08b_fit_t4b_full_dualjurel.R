# =============================================================================
# FONDECYT -- 08b_fit_t4b_full_dualjurel.R
#
# T4b paso 6(d) -- VARIANTE DUAL-JUREL (item #10, 2026-04-30 PM tarde).
#
# Carga las mismas series CS que 08_fit_t4b_full.R (anch/sard/jurel_cs) y
# AGREGA la serie acustica jurel Norte chileno (RECLAS Norte, IFOP) + el
# env del bbox Norte (dominio "norte_chile_eez" agregado a env_extended_
# 3domains_2000_2024.csv via 06_extended_env_anomalies.R).
#
# Llama a paper1/stan/t4b_state_space_full_dualjurel.stan que define un
# segundo state jurel_norte compartiendo rho_sst[IDX_JUR] y rho_chl[IDX_JUR]
# con el state CS. Si la identificacion de rho_jur mejora respecto al fit
# primary (sigma_post/sigma_prior baja material), promovemos a primary; si
# no, archivamos como Apendice de robustness.
#
# IMPORTANTE: la proyeccion del paper sigue usando el state CS
# (data/outputs/t4b/t4b_full_fit.rds del primary). Este script SOLO testea
# si rho_jur identifica con la info adicional del Norte chileno.
#
# Entradas:
#   - data/bio_params/official_biomass_series.csv    (anch + sard CS)
#   - data/bio_params/acoustic_biomass_series.csv    (jurel_cs + jurel_norte)
#   - data/bio_params/catch_annual_cs_2000_2024.csv  (captura CS hibrida)
#   - data/bio_params/env_extended_3domains_2000_2024.csv (4 dominios: D1+norte)
#   - data/bio_params/official_assessments.yaml      (priors r/K)
#   - <dirdata>/Environmental/env/.../EnvCoastDaily_*.rds (SST+CHL CS, primary)
#   - C_jur_norte_path (opcional, default 0 con caveat) -- captura jurel zona
#     Norte chilena (regiones III-XV) si se tiene; sin esto el state Norte
#     evoluciona sin extraccion (F=0) lo cual sesga r y K_norte hacia abajo
#     y arriba respectivamente. Sin embargo, sigue identificando rho_jur si
#     la dinamica climatica es lo suficientemente fuerte.
#
# Salidas:
#   - data/outputs/t4b/t4b_full_dualjurel_fit.rds
#   - data/outputs/t4b/t4b_full_dualjurel_summary.csv
#   - data/outputs/t4b/t4b_full_dualjurel_stan_data.rds
#
# Corre con:
#   options(t4b.full.dualjurel.run_main = TRUE)
#   source("R/08_stan_t4/08b_fit_t4b_full_dualjurel.R")
#
# Comparacion sigma_post/sigma_prior con el primary (post-fit):
#   primary_summary <- readr::read_csv("data/outputs/t4b/t4b_full_summary.csv")
#   dual_summary    <- readr::read_csv("data/outputs/t4b/t4b_full_dualjurel_summary.csv")
#   # Compare rho_sst[3] y rho_chl[3] sd entre los dos.
#   # Si dual sd < primary sd materialmente -> identificacion rescatada.
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
    stop(sprintf("[t4b-full-dual] Prior invalido: %s = %s", name, deparse(x)),
         call. = FALSE)
  }
  as.numeric(x)
}

# -----------------------------------------------------------------------------
# Constantes -- heredadas de 08 + nuevas para Norte
# -----------------------------------------------------------------------------
T4B_FULL_STOCKS       <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
T4B_FULL_WINDOW       <- 2000:2024
T4B_FULL_CATCH_CSV    <- "data/bio_params/catch_annual_cs_2000_2024.csv"
T4B_FULL_CENSOR_JUREL <- 3.0

T4B_DUAL_STAN_FILE <- "paper1/stan/t4b_state_space_full_dualjurel.stan"
T4B_DUAL_OUT_DIR   <- "data/outputs/t4b"
T4B_ENV_4DOM_CSV   <- "data/bio_params/env_extended_3domains_2000_2024.csv"
# (mismo archivo, ahora con 4 dominios incluyendo norte_chile_eez)

# Priors estructurales idem 08
T4B_FULL_LOG_R_SD  <- c(0.25, 0.25, 0.25)
T4B_FULL_LOG_K_SD  <- c(0.15, 0.15, 0.25)
T4B_FULL_LOG_B0_SD <- c(0.10, 0.10, 0.15)
T4B_FULL_SIGMA_OBS_MEAN <- c(0.12, 0.12, 0.30)
T4B_FULL_SIGMA_OBS_SD   <- c(0.05, 0.05, 0.10)
T4B_FULL_SIGMA_PROC_LOGMEAN <- rep(log(0.10), 3)
T4B_FULL_SIGMA_PROC_LOGSD   <- c(0.40, 0.40, 0.60)

T4B_FULL_RHO_SST_MEAN <- c(-2.3, -2.0,  0.0)
T4B_FULL_RHO_SST_SD   <- c( 1.0,  1.0,  1.0)
T4B_FULL_RHO_CHL_MEAN <- c(-2.3,  2.1,  0.0)
T4B_FULL_RHO_CHL_SD   <- c( 1.0,  1.0,  1.0)

# Priors NORTE jurel: usamos los mismos r_prior_mean del jurel CS del YAML;
# K y B0 calibrados a los datos observados de la serie Norte (mediana y
# primer observacion respectivamente, ambos en mil_t).
T4B_DUAL_LOG_R_NORTE_SD  <- 0.25  # mismo SD que CS
T4B_DUAL_LOG_K_NORTE_SD  <- 0.30  # algo mas amplio (incertidumbre extra Norte)
T4B_DUAL_LOG_B0_NORTE_SD <- 0.20

T4B_DUAL_SIGMA_OBS_NORTE_MEAN <- 0.30  # acustico, mismo orden que jurel CS
T4B_DUAL_SIGMA_OBS_NORTE_SD   <- 0.10
T4B_DUAL_SIGMA_PROC_NORTE_LOGMEAN <- log(0.10)
T4B_DUAL_SIGMA_PROC_NORTE_LOGSD   <- 0.60  # idem jurel CS

dir.create(T4B_DUAL_OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Cargar insumos
# -----------------------------------------------------------------------------
load_t4b_dualjurel_inputs <- function(C_jur_norte_path = NULL) {
  scaa <- readr::read_csv("data/bio_params/official_biomass_series.csv",
                          show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% c("anchoveta_cs", "sardina_comun_cs"),
                  year %in% T4B_FULL_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     biomass_mil_t = biomass_total_t / 1e3)

  ac_all <- readr::read_csv("data/bio_params/acoustic_biomass_series.csv",
                             show_col_types = FALSE)
  ac_cs <- ac_all %>%
    dplyr::filter(species == "jurel_cs", year %in% T4B_FULL_WINDOW) %>%
    dplyr::transmute(stock_id = "jurel_cs", year,
                     biomass_mil_t = biomass_t / 1e3)
  ac_norte <- ac_all %>%
    dplyr::filter(species == "jurel_norte", year %in% T4B_FULL_WINDOW,
                  !is.na(biomass_t)) %>%
    dplyr::transmute(stock_id = "jurel_norte", year,
                     biomass_mil_t = biomass_t / 1e3)

  catch <- readr::read_csv(T4B_FULL_CATCH_CSV, show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% T4B_FULL_STOCKS, year %in% T4B_FULL_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     catch_mil_t = catch_t / 1e3)

  # Captura jurel Norte chileno: si se pasa path a CSV con (year, catch_t),
  # se usa; si no, placeholder = 0 con WARNING. NOTA: sin captura, F_norte=0
  # y K_norte tiende al posterior maximo del ajuste (sesgo). Sigue siendo
  # informativo para identificar rho_jur mientras la dinamica climatica
  # imprima signal en logB_norte.
  if (!is.null(C_jur_norte_path) && file.exists(C_jur_norte_path)) {
    catch_norte <- readr::read_csv(C_jur_norte_path, show_col_types = FALSE) %>%
      dplyr::filter(year %in% T4B_FULL_WINDOW) %>%
      dplyr::transmute(year, catch_mil_t = catch_t / 1e3)
    cat(sprintf("[t4b-dual] Captura jurel Norte cargada: %s (%d obs)\n",
                C_jur_norte_path, nrow(catch_norte)))
  } else {
    catch_norte <- tibble::tibble(year = T4B_FULL_WINDOW, catch_mil_t = 0)
    warning("[t4b-dual] Captura jurel Norte = 0 (placeholder). Sesga r,K_norte; ",
            "rho_jur sigue identificable si la senal climatica es fuerte. ",
            "Pasar C_jur_norte_path a CSV con captura real para fit definitivo.",
            call. = FALSE)
  }

  # Env: 4 dominios desde env_extended_3domains_2000_2024.csv
  env_4dom <- readr::read_csv(T4B_ENV_4DOM_CSV, show_col_types = FALSE)
  required_domains <- c("centro_sur_eez", "norte_chile_eez")
  missing_dom <- setdiff(required_domains, unique(env_4dom$domain))
  if (length(missing_dom) > 0) {
    stop(sprintf("[t4b-dual] Dominios faltantes en env_extended: %s. ",
                 paste(missing_dom, collapse = ", ")),
         "Re-ejecutar R/06_projections/06_extended_env_anomalies.R con el ",
         "dominio norte_chile_eez agregado (edit 2026-04-30 PM tarde).",
         call. = FALSE)
  }

  env_cs <- env_4dom %>%
    dplyr::filter(domain == "centro_sur_eez", year %in% T4B_FULL_WINDOW) %>%
    dplyr::arrange(year)
  env_norte <- env_4dom %>%
    dplyr::filter(domain == "norte_chile_eez", year %in% T4B_FULL_WINDOW) %>%
    dplyr::arrange(year)
  stopifnot(nrow(env_cs)    == length(T4B_FULL_WINDOW))
  stopifnot(nrow(env_norte) == length(T4B_FULL_WINDOW))

  list(scaa = scaa, ac_jurel_cs = ac_cs, ac_jurel_norte = ac_norte,
       catch = catch, catch_norte = catch_norte,
       env_cs = env_cs, env_norte = env_norte)
}

# -----------------------------------------------------------------------------
# 2. Build stan_data
# -----------------------------------------------------------------------------
build_t4b_dualjurel_stan_data <- function(inputs, priors_yaml) {
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

  catch_norte_full <- inputs$catch_norte %>%
    dplyr::right_join(tibble::tibble(year = T4B_FULL_WINDOW), by = "year") %>%
    dplyr::mutate(catch_mil_t = tidyr::replace_na(catch_mil_t, 0)) %>%
    dplyr::arrange(year)

  anch <- inputs$scaa %>%
    dplyr::filter(stock_id == "anchoveta_cs") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_FULL_WINDOW))
  sard <- inputs$scaa %>%
    dplyr::filter(stock_id == "sardina_comun_cs") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_FULL_WINDOW))
  jur <- inputs$ac_jurel_cs %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_FULL_WINDOW),
                  is_censored = biomass_mil_t <= T4B_FULL_CENSOR_JUREL)
  jur_unc <- jur %>% dplyr::filter(!is_censored)
  jur_cen <- jur %>% dplyr::filter(is_censored)

  jur_norte <- inputs$ac_jurel_norte %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(t = match(year, T4B_FULL_WINDOW))

  B0_mean_cs <- c(anch$biomass_mil_t[1],
                   sard$biomass_mil_t[1],
                   jur_unc$biomass_mil_t[1])

  # Priors Norte calibrados a los datos
  log_r_norte_mean  <- log(r_mean[3])  # mismo r_prior que jurel CS
  log_K_norte_mean  <- log(median(jur_norte$biomass_mil_t) * 2.0)  # K ~ 2x median(B_obs)
  log_B0_norte_mean <- log(jur_norte$biomass_mil_t[1])

  cat(sprintf("[t4b-dual] T=%d  S=3  ventana %d-%d\n",
              length(T4B_FULL_WINDOW), min(T4B_FULL_WINDOW), max(T4B_FULL_WINDOW)))
  cat(sprintf("[t4b-dual] N_obs CS:    anch=%d  sard=%d  jur_unc=%d  jur_cen=%d\n",
              nrow(anch), nrow(sard), nrow(jur_unc), nrow(jur_cen)))
  cat(sprintf("[t4b-dual] N_obs NORTE: jurel_norte=%d (anios: %s)\n",
              nrow(jur_norte), paste(jur_norte$year, collapse = ", ")))
  cat(sprintf("[t4b-dual] Env CS    SST_c [%.2f, %.2f]  logCHL_c [%.2f, %.2f]\n",
              min(inputs$env_cs$SST_c), max(inputs$env_cs$SST_c),
              min(inputs$env_cs$logCHL_c), max(inputs$env_cs$logCHL_c)))
  cat(sprintf("[t4b-dual] Env NORTE SST_c [%.2f, %.2f]  logCHL_c [%.2f, %.2f]\n",
              min(inputs$env_norte$SST_c), max(inputs$env_norte$SST_c),
              min(inputs$env_norte$logCHL_c), max(inputs$env_norte$logCHL_c)))
  cat(sprintf("[t4b-dual] Priors Norte: log_r=%.2f  log_K=%.2f  log_B0=%.2f\n",
              log_r_norte_mean, log_K_norte_mean, log_B0_norte_mean))
  cat(sprintf("[t4b-dual] Captura Norte: total=%.1f mil_t (sum 2000-2024); ",
              sum(catch_norte_full$catch_mil_t)))
  if (sum(catch_norte_full$catch_mil_t) == 0) {
    cat("PLACEHOLDER 0 (caveat: sesga r,K Norte)\n")
  } else {
    cat("usando captura real\n")
  }

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

    SST_c    = inputs$env_cs$SST_c,
    logCHL_c = inputs$env_cs$logCHL_c,

    # ---------- DUAL JUREL ----------
    N_obs_jur_norte = nrow(jur_norte),
    t_jur_norte     = jur_norte$t,
    B_obs_jur_norte = jur_norte$biomass_mil_t,
    C_jur_norte     = catch_norte_full$catch_mil_t,
    SST_c_norte     = inputs$env_norte$SST_c,
    logCHL_c_norte  = inputs$env_norte$logCHL_c,

    log_r_jur_norte_prior_mean  = log_r_norte_mean,
    log_r_jur_norte_prior_sd    = T4B_DUAL_LOG_R_NORTE_SD,
    log_K_jur_norte_prior_mean  = log_K_norte_mean,
    log_K_jur_norte_prior_sd    = T4B_DUAL_LOG_K_NORTE_SD,
    log_B0_jur_norte_prior_mean = log_B0_norte_mean,
    log_B0_jur_norte_prior_sd   = T4B_DUAL_LOG_B0_NORTE_SD,

    sigma_obs_jur_norte_prior_mean = T4B_DUAL_SIGMA_OBS_NORTE_MEAN,
    sigma_obs_jur_norte_prior_sd   = T4B_DUAL_SIGMA_OBS_NORTE_SD,
    sigma_proc_jur_norte_prior_logmean = T4B_DUAL_SIGMA_PROC_NORTE_LOGMEAN,
    sigma_proc_jur_norte_prior_logsd   = T4B_DUAL_SIGMA_PROC_NORTE_LOGSD,
    # ---------- /DUAL JUREL ----------

    log_r_prior_mean  = log(r_mean),
    log_r_prior_sd    = T4B_FULL_LOG_R_SD,
    log_K_prior_mean  = log(K_mean),
    log_K_prior_sd    = T4B_FULL_LOG_K_SD,
    log_B0_prior_mean = log(B0_mean_cs),
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
fit_t4b_dualjurel <- function(stan_data,
                               chains = 8,
                               iter_warmup = 2000,
                               iter_sampling = 2000,
                               adapt_delta = 0.99,
                               max_treedepth = 14,
                               seed = 2026L) {
  cat(sprintf("[t4b-dual] Chains=%d  warmup=%d  sampling=%d  adapt_delta=%.2f  max_treedepth=%d\n",
              chains, iter_warmup, iter_sampling, adapt_delta, max_treedepth))
  mod <- cmdstanr::cmdstan_model(T4B_DUAL_STAN_FILE)
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
# 4. Sanity check sigma_post/sigma_prior post-fit
# -----------------------------------------------------------------------------
sanity_rho_jur_identification <- function(fit) {
  smry <- fit$summary(variables = c("rho_sst", "rho_chl"))
  prior_sd_jur <- T4B_FULL_RHO_SST_SD[3]  # 1.0 por construccion (=CHL tambien)

  rho_jur_rows <- smry %>%
    dplyr::filter(grepl("\\[3\\]$", variable))
  cat("\n[t4b-dual] Sanity rho_jur identification:\n")
  for (i in seq_len(nrow(rho_jur_rows))) {
    v   <- rho_jur_rows$variable[i]
    sd_post <- rho_jur_rows$sd[i]
    ratio   <- sd_post / prior_sd_jur
    flag    <- if (ratio < 0.7) "*** IDENTIFICADO ***" else
               if (ratio < 0.9) "marginal" else "no-id"
    cat(sprintf("    %-12s  sigma_post=%.3f  ratio=%.3f  %s\n",
                v, sd_post, ratio, flag))
  }
  cat("    (prior SD = 1.0 por construccion en T4B_FULL_RHO_*_SD)\n")
  cat("    Comparar con primary fit (data/outputs/t4b/t4b_full_summary.csv)\n")
  cat("    para ver si el ratio bajo respecto al primary.\n\n")
  invisible(rho_jur_rows)
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.full.dualjurel.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b-FULL-DUALJUREL -- 3 stocks CS + state Norte jurel (item #10)\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  C_jur_norte_path <- getOption("t4b.dual.C_jur_norte_path", NULL)
  inputs    <- load_t4b_dualjurel_inputs(C_jur_norte_path = C_jur_norte_path)
  priors    <- read_yaml_utf8("data/bio_params/official_assessments.yaml")
  stan_data <- build_t4b_dualjurel_stan_data(inputs, priors)

  saveRDS(stan_data, file.path(T4B_DUAL_OUT_DIR, "t4b_full_dualjurel_stan_data.rds"))

  fit <- fit_t4b_dualjurel(stan_data)
  fit$save_object(file = file.path(T4B_DUAL_OUT_DIR, "t4b_full_dualjurel_fit.rds"))

  smry <- fit$summary(variables = c("r_nat", "K_nat", "B0_nat",
                                     "r_nat_jur_norte", "K_nat_jur_norte",
                                     "B0_nat_jur_norte",
                                     "sigma_proc", "sigma_obs",
                                     "sigma_proc_jur_norte", "sigma_obs_jur_norte",
                                     "rho_sst", "rho_chl", "Omega"))
  readr::write_csv(smry, file.path(T4B_DUAL_OUT_DIR,
                                    "t4b_full_dualjurel_summary.csv"))

  cat("\n[t4b-dual] Summary parametros clave:\n")
  print(smry)

  cat("\n[t4b-dual] Diagnosticos cmdstan:\n")
  print(fit$cmdstan_diagnose())

  sanity_rho_jur_identification(fit)

  cat("[t4b-dual] Criterios de validacion paso 6(d) dual:\n")
  cat("  - R-hat <= 1.01 en todos los top-level (incluyendo rho_jur)\n")
  cat("  - ESS_bulk >= 400\n")
  cat("  - 0 divergencias\n")
  cat("  - sigma_post(rho_jur) / sigma_prior(rho_jur) idealmente < 0.7\n")
  cat("    (vs primary ~ 1.0). Si baja material -> identificacion rescatada.\n")
  cat("    Si sigue ~ 1.0 -> archivar como Apendice de robustness.\n")

  invisible(fit)
}
