# =============================================================================
# FONDECYT -- 01_fit_t4.R
#
# Ajusta el modelo T4 state-space Bayesiano (paper1/stan/t4_state_space.stan)
# a las tres SPF centro-sur: anchoveta_cs, sardina_comun_cs, jurel_cs.
#
# Entradas:
#   - data/bio_params/official_biomass_series.csv    (SSB SCAA IFOP)
#   - data/bio_params/acoustic_biomass_series.csv    (biomasa acustica jurel_cs)
#   - data/bio_params/catch_annual_paper1.csv        (captura SERNAPESCA V-X)
#   - data/Environmental/env/EnvCoastDaily_*.rds     (SST, CHL anualizados)
#   - data/bio_params/official_assessments.yaml      (priors estructurales)
#
# Salidas:
#   - data/outputs/t4/t4_fit.rds       (objeto cmdstanr draws)
#   - data/outputs/t4/t4_summary.csv   (tabla summary de parametros)
#   - data/outputs/t4/t4_stan_data.rds (lista stan_data usada)
#
# Corre con:
#   options(t4.run_main = TRUE)
#   source("R/08_stan_t4/01_fit_t4.R")
#
# REQUISITOS (una sola vez):
#   install.packages("cmdstanr",
#     repos = c("https://stan-dev.r-universe.dev",
#               "https://cloud.r-project.org"))
#   cmdstanr::install_cmdstan()
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

# Lector YAML que evita el bug de readLines en locale CP1252 (Windows).
# Lee el archivo como raw bytes, declara UTF-8 explicito y pasa a yaml.load.
read_yaml_utf8 <- function(path) {
  bytes <- readBin(path, "raw", n = file.info(path)$size)
  txt   <- rawToChar(bytes)
  Encoding(txt) <- "UTF-8"
  yaml::yaml.load(txt)
}

# Valida que un prior sea numerico escalar; aborta ruidoso si NULL/NA/string.
assert_scalar_numeric <- function(x, name) {
  if (is.null(x) || length(x) != 1 || !is.numeric(x) || is.na(x)) {
    stop(sprintf("[t4] Prior invalido: %s = %s (type=%s, length=%d)",
                 name, deparse(x), class(x)[1], length(x %||% 0)),
         call. = FALSE)
  }
  as.numeric(x)
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
T4_STOCKS <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
T4_WINDOW <- 2000:2024                       # ventana comun (25 anios)
T4_CENSOR_LIMIT_JUREL <- 3.0                 # mil t; obs <= 3 mil t => censored
T4_STAN_FILE <- "paper1/stan/t4_state_space.stan"
T4_OUT_DIR   <- "data/outputs/t4"

dir.create(T4_OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Cargar series (biomasa, captura, ambiente)
# -----------------------------------------------------------------------------
load_t4_inputs <- function() {
  # --- Biomasa total SCAA para anchoveta y sardina ---
  # FIX 2026-04-23: usar biomass_total_t, NO ssb_t. El prior K del YAML
  # esta calibrado para biomasa total (K_fuente: "K_total estimado 1.5-2x BD0").
  # Usar SSB aqui producia una inconsistencia estructural entre obs y dinamica
  # que causo fallo de mixing en T4 v1. Validado en T4b single-species
  # anchoveta (iter 3, 2026-04-23): R-hat 1.00, 0 divergencias, PPC limpio.
  # Ver project_t4_v1_failure_and_t4b_plan.md.
  ssb_scaa <- readr::read_csv("data/bio_params/official_biomass_series.csv",
                              show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% c("anchoveta_cs", "sardina_comun_cs"),
                  year %in% T4_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     biomass_mil_t = biomass_total_t / 1e3)

  # --- Biomasa acustica para jurel ---
  ac_raw <- readr::read_csv("data/bio_params/acoustic_biomass_series.csv",
                            show_col_types = FALSE) %>%
    dplyr::filter(species == "jurel_cs", year %in% T4_WINDOW) %>%
    dplyr::transmute(stock_id = "jurel_cs", year,
                     biomass_mil_t = biomass_t / 1e3)

  # --- Captura ---
  catch <- readr::read_csv("data/bio_params/catch_annual_paper1.csv",
                           show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% T4_STOCKS, year %in% T4_WINDOW) %>%
    dplyr::transmute(stock_id, year,
                     catch_mil_t = catch_t / 1e3)

  # --- Ambiente SST/CHL (anualizado) ---
  env1 <- readRDS(file.path(dirdata, "Environmental/env", "2000-2011",
                            "EnvCoastDaily_2000_2011_0.25deg.rds"))
  env2 <- readRDS(file.path(dirdata, "Environmental/env",
                            "EnvCoastDaily_2012_2025_0.125deg.rds"))
  env_year <- dplyr::bind_rows(
    dplyr::mutate(env1, year = lubridate::year(date)),
    dplyr::mutate(env2, year = lubridate::year(date))
  ) %>%
    dplyr::filter(year %in% T4_WINDOW) %>%
    dplyr::group_by(year) %>%
    dplyr::summarise(sst = mean(sst, na.rm = TRUE),
                     chl = mean(chl, na.rm = TRUE),
                     .groups = "drop") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(
      SST_c    = sst - mean(sst, na.rm = TRUE),
      logCHL_c = log(chl) - mean(log(chl), na.rm = TRUE)
    )

  list(ssb_scaa = ssb_scaa, ac_jurel = ac_raw, catch = catch, env = env_year)
}

# -----------------------------------------------------------------------------
# 2. Armar la lista stan_data
# -----------------------------------------------------------------------------
build_stan_data <- function(inputs, priors) {
  env <- inputs$env
  stopifnot(nrow(env) == length(T4_WINDOW))

  # --- Captura como matriz TxS (orden columnas: 1=anch, 2=sard, 3=jur) ---
  catch_wide <- inputs$catch %>%
    dplyr::right_join(
      tidyr::crossing(stock_id = T4_STOCKS, year = T4_WINDOW),
      by = c("stock_id", "year")
    ) %>%
    dplyr::mutate(catch_mil_t = tidyr::replace_na(catch_mil_t, 0)) %>%
    tidyr::pivot_wider(id_cols = year, names_from = stock_id,
                       values_from = catch_mil_t) %>%
    dplyr::arrange(year)

  C_mat <- as.matrix(catch_wide[, T4_STOCKS])

  # --- Observaciones por stock ---
  anch_df <- inputs$ssb_scaa %>%
    dplyr::filter(stock_id == "anchoveta_cs") %>%
    dplyr::mutate(t = match(year, T4_WINDOW))
  sard_df <- inputs$ssb_scaa %>%
    dplyr::filter(stock_id == "sardina_comun_cs") %>%
    dplyr::mutate(t = match(year, T4_WINDOW))
  # jurel: split en uncensored y censored
  jur_df <- inputs$ac_jurel %>%
    dplyr::mutate(t = match(year, T4_WINDOW),
                  is_censored = biomass_mil_t <= T4_CENSOR_LIMIT_JUREL)
  jur_unc <- jur_df %>% dplyr::filter(!is_censored)
  jur_cen <- jur_df %>% dplyr::filter(is_censored)

  cat(sprintf("[t4] N obs anchoveta = %d\n", nrow(anch_df)))
  cat(sprintf("[t4] N obs sardina   = %d\n", nrow(sard_df)))
  cat(sprintf("[t4] N obs jurel uncensored = %d\n", nrow(jur_unc)))
  cat(sprintf("[t4] N obs jurel censored   = %d (anios: %s)\n",
              nrow(jur_cen), paste(jur_cen$year, collapse = ", ")))

  # --- Vectores de priors stock-especificos (orden: anch, sard, jur) ---
  P <- priors
  pick <- function(stock, key) {
    val <- P[[stock]]$priors_biologicos[[key]]
    assert_scalar_numeric(val, sprintf("%s.priors_biologicos.%s", stock, key))
  }
  r_prior_mean <- c(pick("anchoveta_cs",     "r_prior_mean"),
                    pick("sardina_comun_cs", "r_prior_mean"),
                    pick("jurel_cs",         "r_prior_mean"))
  r_prior_sd   <- c(pick("anchoveta_cs",     "r_prior_sd"),
                    pick("sardina_comun_cs", "r_prior_sd"),
                    pick("jurel_cs",         "r_prior_sd"))
  K_prior_mean <- c(pick("anchoveta_cs",     "K_prior_mean_mil_t"),
                    pick("sardina_comun_cs", "K_prior_mean_mil_t"),
                    pick("jurel_cs",         "K_prior_mean_mil_t"))
  K_prior_sd   <- c(pick("anchoveta_cs",     "K_prior_sd_mil_t"),
                    pick("sardina_comun_cs", "K_prior_sd_mil_t"),
                    pick("jurel_cs",         "K_prior_sd_mil_t"))
  cat(sprintf("[t4] r_prior_mean: %s\n", paste(r_prior_mean, collapse = ", ")))
  cat(sprintf("[t4] K_prior_mean (mil t): %s\n", paste(K_prior_mean, collapse = ", ")))

  # B0: primer valor observado de la serie por stock
  B0_prior_mean <- c(
    anch_df$biomass_mil_t[1],
    sard_df$biomass_mil_t[1],
    jur_unc$biomass_mil_t[1]
  )
  B0_prior_sd <- 0.3 * B0_prior_mean    # CV ~ 30%

  # Shifters: del bloque priors_informativos_derivados_para_T4_stan_v2 del YAML.
  # Hardcoded aqui para evitar parsear strings "normal(mu, sd)".
  rho_sst_prior_mean <- c(-2.3, -2.0,  0.0)
  rho_sst_prior_sd   <- c( 1.0,  1.0,  1.0)
  rho_chl_prior_mean <- c(-2.3,  2.1,  0.0)
  rho_chl_prior_sd   <- c( 1.0,  1.0,  1.0)

  # sigma_obs stock-especifico:
  #   anch, sard: SSB SCAA es resumen suavizado -> sigma ~ 0.12 (CV 12% en log)
  #   jurel: acustico snapshot -> sigma ~ 0.30
  sigma_obs_prior_mean <- c(0.12, 0.12, 0.30)
  sigma_obs_prior_sd   <- c(0.05, 0.05, 0.10)

  list(
    S = 3L,
    T = length(T4_WINDOW),
    N_obs_anchoveta = nrow(anch_df),
    N_obs_sardina   = nrow(sard_df),
    N_obs_jurel_uncensored = nrow(jur_unc),
    N_obs_jurel_censored   = nrow(jur_cen),
    t_anchoveta   = anch_df$t,
    t_sardina     = sard_df$t,
    t_jurel_unc   = jur_unc$t,
    t_jurel_cen   = jur_cen$t,
    B_obs_anchoveta = anch_df$biomass_mil_t,
    B_obs_sardina   = sard_df$biomass_mil_t,
    B_obs_jurel     = jur_unc$biomass_mil_t,
    B_censor_limit_jurel = T4_CENSOR_LIMIT_JUREL,
    C = C_mat,
    SST_c    = env$SST_c,
    logCHL_c = env$logCHL_c,
    r_prior_mean = r_prior_mean,
    r_prior_sd   = r_prior_sd,
    K_prior_mean = K_prior_mean,
    K_prior_sd   = K_prior_sd,
    rho_sst_prior_mean = rho_sst_prior_mean,
    rho_sst_prior_sd   = rho_sst_prior_sd,
    rho_chl_prior_mean = rho_chl_prior_mean,
    rho_chl_prior_sd   = rho_chl_prior_sd,
    B0_prior_mean = B0_prior_mean,
    B0_prior_sd   = B0_prior_sd,
    sigma_obs_prior_mean = sigma_obs_prior_mean,
    sigma_obs_prior_sd   = sigma_obs_prior_sd,
    sigma_proc_prior_mean = 0.15,
    sigma_proc_prior_sd   = 0.10
  )
}

# -----------------------------------------------------------------------------
# 3. Compilar y ajustar
# -----------------------------------------------------------------------------
fit_t4 <- function(stan_data,
                   chains = max(8, min(16, parallel::detectCores() - 4)),
                   iter_warmup = 1000, iter_sampling = 1500,
                   parallel_chains = chains,
                   adapt_delta = 0.95, max_treedepth = 12,
                   seed = 2026L) {
  cat(sprintf("[t4] Usando %d chains en paralelo (detectCores=%d)\n",
              chains, parallel::detectCores()))
  mod <- cmdstanr::cmdstan_model(T4_STAN_FILE)
  fit <- mod$sample(
    data            = stan_data,
    chains          = chains,
    parallel_chains = parallel_chains,
    iter_warmup     = iter_warmup,
    iter_sampling   = iter_sampling,
    adapt_delta     = adapt_delta,
    max_treedepth   = max_treedepth,
    seed            = seed,
    refresh         = 100
  )
  fit
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4 -- Bayesian state-space fit (cmdstanr)\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  inputs <- load_t4_inputs()
  priors <- read_yaml_utf8("data/bio_params/official_assessments.yaml")
  stan_data <- build_stan_data(inputs, priors)

  saveRDS(stan_data, file.path(T4_OUT_DIR, "t4_stan_data.rds"))
  cat("\n[t4] stan_data guardado en ", T4_OUT_DIR, "/t4_stan_data.rds\n", sep = "")

  fit <- fit_t4(stan_data)

  fit$save_object(file = file.path(T4_OUT_DIR, "t4_fit.rds"))

  smry <- fit$summary(variables = c("r_nat", "K_nat", "rho_sst", "rho_chl",
                                    "sigma_proc", "sigma_obs", "Omega"))
  readr::write_csv(smry, file.path(T4_OUT_DIR, "t4_summary.csv"))

  cat("\n[t4] Summary (parametros clave):\n")
  print(smry)

  cat("\n[t4] Diagnosticos:\n")
  print(fit$cmdstan_diagnose())

  invisible(fit)
}
