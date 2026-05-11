# =============================================================================
# FONDECYT -- 13_trip_comparative_statics.R   (T7 ENSEMBLE 6 modelos)
#
# Long-run comparative statics sobre TRIPS bajo el ensemble CMIP6 de 6 modelos
# (rewrite 2026-04-29 PM, ver project_cmip6_ensemble_deltas_executed.md).
# Connecta el posterior T4b-full con la negative binomial trip equation via el
# Schaefer steady-state bajo F_hist, ahora iterando sobre cada modelo del
# ensemble en vez de usar IPSL solo.
#
# Es el companion de 12_growth_comparative_statics.R (T5, growth rates) y
# alimenta la tabla tab:trip_compstat en paper1 sec 4.4 "Implications for
# fleet-level effort".
#
# 2026-04-30: agregado el DIRECT WEATHER CHANNEL (vessel-specific A) que el
# sec 3.4 promete. Para cada (vessel, model, scenario, window) tomamos la serie
# diaria de wind al COG, sumamos Deltawind del CMIP6 y recontamos exceedances de
# 8 m/s; el Deltadays_bw resultante entra al exponente del factor_trips con
# semi-elasticidad beta_weather del NB fitteado in-script. Implementacion en
# _weather_channel_utils.R con cache en data/cmip6/delta_days_bw_vessel.rds.
# beta_weather_IND = -0.0001 (ns), beta_weather_ART = -0.002*** -> el direct channel
# contribuye solo en ART y refuerza la asimetria ART/IND ya identificada.
#
# Framing Cowles: steady-state bajo status-quo F, no forward simulation.
# Forward sim con trayectorias y reglas endogenas => paper 2.
#
# Pipeline matematico:
#
#   (1) r_eff[d,s,m,c] = r_base[d,s] *
#                        exp(rho_sst[d,s]*DSST[m,c] + rho_chl[d,s]*DlogCHL[m,c])
#
#   (2) Schaefer steady-state:
#       B_star[d,s,m,c] = K[d,s] * (1 - F_hist[s] / r_eff[d,s,m,c])
#       Extincion si F_hist[s] >= r_eff[d,s,m,c]. Flag y reportar Pr(extinct).
#
#   (3) factor_B[d,s,m,c] = B_star[d,s,m,c] / B_hist[s]
#       B_hist = mediana de biomass 2000-2024 (IFOP/SPRFMO, consistente con Stan)
#
#   (4) omega[v,s] = share historico realizado de especie s en captura vessel v
#         omega[v,s] = sum_y H_{s,vy} / sum_y (H_33 + H_114 + H_26)_{vy}
#
#   (5) factor_H[d,v,m,c] = sum_s omega[v,s] * factor_B[d,s,m,c]
#       Convencion: jurel_cs no identificado -> factor_B_jurel = 1.0 para
#       todos los draws (posterior prior-dominado; propagarlo mete ruido
#       espurio al portfolio). Asuncion explicita.
#
#   (5b) Deltadays_bw[v,m,c] vessel-specific via _weather_channel_utils.R: shift
#        empirical CDF de speed_max al COG, recontar exceedances > 8 m/s.
#
#   (6) factor_trips con semi-elasticity y AMBOS canales:
#       factor_trips[d,v,m,c] = exp( beta_H[fleet(v)] * H_alloc_hist[v] *
#                                    (factor_H[d,v,m,c] - 1) +
#                                    beta_weather[fleet(v)] *
#                                    Deltadays_bw[v,m,c] )
#
#   (7) Resumen WITHIN-MODEL: para cada (fleet, m, ssp, window) agregar
#       sobre (draws x vessels within fleet) -> mediana, q05/q95, Pr_loss,
#       cond_med/q05/q95.
#
#   (8) Resumen CROSS-MODEL: para cada (fleet, ssp, window) agregar sobre
#       el axis m -> mediana de medianas (cross-model med), q25/q75 (cross-IQR),
#       y mediana de los q05/q95 within-model (within posterior CI tipico).
#       Paralelo exacto a t5_summarise_cross() en el growth compstat.
#
# Sanity check: DSST=0, DlogCHL=0 -> r_eff = r_base, factor_trips != 1.0
# (Schaefer-eq B_star bajo F_hist no es B_hist en general); pero el unit-test
# factor_H=1 -> factor_trips=1.0 exacto se chequea.
#
# Entradas:
#   - data/outputs/t4b/t4b_full_fit.rds        (cmdstanr CmdStanMCMC)
#   - data/cmip6/deltas_ensemble.csv           (long format ensemble)
#   - data/bio_params/catch_annual_cs_2000_2024.csv  (captura IFOP-consistente)
#   - data/bio_params/official_biomass_series.csv    (anch/sard biomass_total_t)
#   - data/bio_params/acoustic_biomass_series.csv    (jurel_cs biomass_t)
#   - data/trips/poisson_dt.rds                (panel NB con H_33/H_114/H_26)
#
# Salidas (paralelas a T5 ensemble):
#   - paper1/tables/trip_comparative_statics.csv
#         formato paper, fleet x scenario, cross-model + IQR + within-CI
#   - paper1/tables/trip_comparative_statics_raw.csv
#         numerico cross-model
#   - paper1/tables/trip_comparative_statics_by_model.csv
#         long, fila por (fleet x model x scenario x window) -- debug + Apendice
#   - paper1/tables/trip_comparative_statics_extinct.csv
#         Pr(extinct) cross-model + IQR por stock x scenario
#   - paper1/tables/trip_comparative_statics_extinct_by_model.csv
#         Pr(extinct) por stock x model x scenario (debug)
#
# Corre con:
#   options(t6.run_main = TRUE)
#   source("R/08_stan_t4/13_trip_comparative_statics.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(data.table)
  library(readr)
  library(posterior)
  library(cmdstanr)
  library(MASS)  # glm.nb
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
# Constantes y compstat_load_scenarios() compartidas con T5 y Apendice F.
# Antes T7 hacia source(T5) directo; eso traia el main guard default-TRUE de T5
# como side-effect. Refactor 2026-04-29 PM separa lo "shared" del "main".
source_utf8("R/08_stan_t4/_compstat_utils.R")
# Direct weather channel (2026-04-30): wc_compute_vessel_delta_days_bw().
source_utf8("R/08_stan_t4/_weather_channel_utils.R")

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------

T6_FIT_RDS           <- "data/outputs/t4b/t4b_full_fit.rds"
T6_DELTAS_CSV        <- COMPSTAT_DELTAS_CSV
T6_CATCH_CSV         <- "data/bio_params/catch_annual_cs_2000_2024.csv"
T6_OFF_BIO_CSV       <- "data/bio_params/official_biomass_series.csv"
T6_ACU_BIO_CSV       <- "data/bio_params/acoustic_biomass_series.csv"
T6_POISSON_RDS       <- "data/trips/poisson_dt.rds"

T6_TABLE_OUT             <- "paper1/tables/trip_comparative_statics.csv"
T6_TABLE_RAW_OUT         <- "paper1/tables/trip_comparative_statics_raw.csv"
T6_TABLE_BYMODEL_OUT     <- "paper1/tables/trip_comparative_statics_by_model.csv"
T6_TABLE_EXTINCT_OUT     <- "paper1/tables/trip_comparative_statics_extinct.csv"
T6_TABLE_EXTINCT_BYMODEL <- "paper1/tables/trip_comparative_statics_extinct_by_model.csv"

T6_WINDOW    <- 2000:2024                 # consistente con T4B_FULL_WINDOW

# Aliases hacia compstat shared (refactor 2026-04-29 PM)
T6_STOCKS                <- COMPSTAT_STOCKS
T6_STOCK_LABEL           <- COMPSTAT_STOCK_LABEL
T6_SSPS                  <- COMPSTAT_SSPS
T6_WINDOWS               <- COMPSTAT_WINDOWS
T6_SCENARIO_LABEL        <- COMPSTAT_SCENARIO_LABEL
T6_NON_IDENTIFIED_STOCKS <- COMPSTAT_NON_IDENTIFIED_STOCKS

T6_STOCK_IDX <- setNames(seq_along(T6_STOCKS), T6_STOCKS)

# Species-code map (confirmado vs R/01_data_cleaning/tac_processing.R:130-133)
#   H_114 -> anchoveta; H_33 -> sardina_comun; H_26 -> jurel
T6_CATCH_COL_OF <- c(
  anchoveta_cs     = "H_114",
  sardina_comun_cs = "H_33",
  jurel_cs         = "H_26"
)

T6_FLEET_LABEL <- c(
  ART = "Artisanal",
  IND = "Industrial"
)

# Threshold de portfolio loss (consistente con T7 single-IPSL pre-ensemble)
T6_LOSS_THRESHOLD <- 0.5

# -----------------------------------------------------------------------------
# Paso 1 -- F_hist y B_hist por stock (sin cambios, no depende de modelo CMIP6)
# -----------------------------------------------------------------------------

t6_load_biology <- function() {
  catch <- readr::read_csv(T6_CATCH_CSV, show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% T6_STOCKS, year %in% T6_WINDOW)

  off <- readr::read_csv(T6_OFF_BIO_CSV, show_col_types = FALSE) %>%
    dplyr::filter(stock_id %in% c("anchoveta_cs", "sardina_comun_cs"),
                  year %in% T6_WINDOW) %>%
    dplyr::transmute(stock_id, year, biomass_t = biomass_total_t)

  ac <- readr::read_csv(T6_ACU_BIO_CSV, show_col_types = FALSE) %>%
    dplyr::filter(species == "jurel_cs", year %in% T6_WINDOW) %>%
    dplyr::transmute(stock_id = "jurel_cs", year, biomass_t = biomass_t)

  bio <- dplyr::bind_rows(off, ac)

  fb <- dplyr::inner_join(catch, bio, by = c("stock_id", "year")) %>%
    dplyr::mutate(F_prop = catch_t / biomass_t)

  summ <- fb %>%
    dplyr::group_by(stock_id) %>%
    dplyr::summarise(
      F_hist      = median(F_prop, na.rm = TRUE),
      F_hist_q25  = quantile(F_prop, 0.25, na.rm = TRUE),
      F_hist_q75  = quantile(F_prop, 0.75, na.rm = TRUE),
      B_hist_t    = median(biomass_t, na.rm = TRUE),
      n_years     = sum(!is.na(F_prop)),
      .groups = "drop"
    )

  cat("[T7] F_hist y B_hist por stock (mediana 2000-2024, IFOP-consistent):\n")
  print(summ %>%
          dplyr::mutate(F_hist = round(F_hist, 3),
                        B_hist_kt = round(B_hist_t / 1e3, 0)))
  cat("\n")

  list(summary = summ, annual = fb)
}

# -----------------------------------------------------------------------------
# Paso 2 -- Extraer draws posteriores (sin cambios)
# -----------------------------------------------------------------------------

t6_extract_draws <- function(fit_rds = T6_FIT_RDS,
                             stocks  = T6_STOCKS) {

  fit <- readRDS(fit_rds)

  vars <- c(sprintf("r_base[%d]", seq_along(stocks)),
            sprintf("K_nat[%d]",  seq_along(stocks)),
            sprintf("rho_sst[%d]", seq_along(stocks)),
            sprintf("rho_chl[%d]", seq_along(stocks)))

  dr <- fit$draws(vars, format = "draws_df") %>% tibble::as_tibble()

  long_list <- lapply(seq_along(stocks), function(s) {
    tibble::tibble(
      .draw    = dr$.draw,
      stock_id = stocks[s],
      r_base   = dr[[sprintf("r_base[%d]",  s)]],
      K_nat    = dr[[sprintf("K_nat[%d]",   s)]],
      rho_sst  = dr[[sprintf("rho_sst[%d]", s)]],
      rho_chl  = dr[[sprintf("rho_chl[%d]", s)]]
    )
  })
  draws_long <- dplyr::bind_rows(long_list)

  cat("[T7] Posterior draws extraidos: N_total =", nrow(draws_long),
      "(", length(unique(draws_long$.draw)), "draws x",
      length(stocks), "stocks )\n\n")

  draws_long
}

# -----------------------------------------------------------------------------
# Paso 3 -- factor_B[d,s,m,c] via Schaefer steady-state bajo F_hist
# -----------------------------------------------------------------------------
# Cambio vs T7 viejo: scen_df ahora trae columna `model`. cross-join por
# (.draw x stock_id) x (model x ssp x window).

t6_compute_factor_B <- function(draws_long, bio_summary, scen_df) {

  bio_summary <- bio_summary %>%
    dplyr::select(stock_id, F_hist, B_hist_t)

  scen_keep <- scen_df %>%
    dplyr::select(model, scenario = scenario, window, DSST, DlogCHL,
                  scenario_key)

  dt <- draws_long %>%
    dplyr::left_join(bio_summary, by = "stock_id") %>%
    tidyr::crossing(scen_keep) %>%
    dplyr::mutate(
      r_eff    = r_base * exp(rho_sst * DSST + rho_chl * DlogCHL),
      extinct  = F_hist >= r_eff,
      # K_nat en mil_t; B_hist_t en t. Convertimos K_nat_t = K_nat * 1e3 para
      # que factor_B sea dimensionless.
      K_nat_t  = K_nat * 1e3,
      # Si extinct, B_star = 0 (colapso total bajo Schaefer cuando F >= r).
      B_star_t = dplyr::if_else(extinct,
                                0.0,
                                K_nat_t * (1 - F_hist / r_eff)),
      factor_B = dplyr::if_else(extinct,
                                0.0,
                                B_star_t / B_hist_t)
    )

  # Override jurel_cs -> factor_B = 1.0 (n.i. convention)
  dt <- dt %>%
    dplyr::mutate(
      factor_B = dplyr::if_else(stock_id %in% T6_NON_IDENTIFIED_STOCKS,
                                1.0, factor_B),
      extinct  = dplyr::if_else(stock_id %in% T6_NON_IDENTIFIED_STOCKS,
                                FALSE, extinct)
    )

  dt
}

# -----------------------------------------------------------------------------
# Paso 3b -- Pr(extinction) WITHIN-MODEL: por (stock, model, ssp, window)
# -----------------------------------------------------------------------------

t6_summarise_extinction_within <- function(factor_B_dt) {
  factor_B_dt %>%
    dplyr::group_by(stock_id, model, scenario, window) %>%
    dplyr::summarise(
      n_draws       = dplyr::n(),
      n_extinct     = sum(extinct),
      pr_extinct    = mean(extinct),
      factor_B_med  = median(factor_B),
      factor_B_q05  = quantile(factor_B, 0.05),
      factor_B_q95  = quantile(factor_B, 0.95),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      scenario_key   = paste(scenario, window, sep = "_"),
      stock_label    = T6_STOCK_LABEL[stock_id],
      scenario_label = T6_SCENARIO_LABEL[scenario_key],
      non_identified = stock_id %in% T6_NON_IDENTIFIED_STOCKS
    ) %>%
    dplyr::arrange(stock_id, model,
                   factor(scenario, levels = T6_SSPS),
                   factor(window,   levels = T6_WINDOWS))
}

# -----------------------------------------------------------------------------
# Paso 3c -- Pr(extinction) CROSS-MODEL: agregando sobre m
# -----------------------------------------------------------------------------
# Convencion (paralela a t5_summarise_cross):
#   pr_extinct_cross_med = median across m del pr_extinct within m
#   pr_extinct_cross_q25 = q25  across m del pr_extinct within m (IQR cross-model)
#   pr_extinct_cross_q75 = q75  across m del pr_extinct within m
#   factor_B_cross_med   = median across m del factor_B_med within m
#   factor_B_cross_q25/q75 = IQR cross-model de factor_B_med

t6_summarise_extinction_cross <- function(extinct_within) {
  extinct_within %>%
    dplyr::group_by(stock_id, scenario, window) %>%
    dplyr::summarise(
      n_models               = dplyr::n(),
      pr_extinct_cross_med   = median(pr_extinct),
      pr_extinct_cross_q25   = quantile(pr_extinct, 0.25),
      pr_extinct_cross_q75   = quantile(pr_extinct, 0.75),
      factor_B_cross_med     = median(factor_B_med),
      factor_B_cross_q25     = quantile(factor_B_med, 0.25),
      factor_B_cross_q75     = quantile(factor_B_med, 0.75),
      factor_B_within_q05    = median(factor_B_q05),
      factor_B_within_q95    = median(factor_B_q95),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      scenario_key   = paste(scenario, window, sep = "_"),
      stock_label    = T6_STOCK_LABEL[stock_id],
      scenario_label = T6_SCENARIO_LABEL[scenario_key],
      non_identified = stock_id %in% T6_NON_IDENTIFIED_STOCKS
    ) %>%
    dplyr::arrange(factor(stock_id, levels = T6_STOCKS),
                   factor(scenario, levels = T6_SSPS),
                   factor(window,   levels = T6_WINDOWS))
}

# -----------------------------------------------------------------------------
# Paso 4 -- omega[v,s] + H_alloc_hist[v] desde poisson_dt.rds (sin cambios)
# -----------------------------------------------------------------------------

t6_build_vessel_table <- function(poisson_rds = T6_POISSON_RDS) {
  pdt <- as.data.table(readRDS(poisson_rds))

  v_catch <- pdt[, .(
    H_anch = sum(H_114, na.rm = TRUE),
    H_sard = sum(H_33,  na.rm = TRUE),
    H_jur  = sum(H_26,  na.rm = TRUE)
  ), by = .(COD_BARCO, TIPO_FLOTA)]

  v_catch[, H_tot := H_anch + H_sard + H_jur]

  dropped <- v_catch[H_tot == 0, .N]
  if (dropped > 0) {
    cat("[T7] WARNING: dropeando", dropped,
        "vessels con captura cero en las 3 especies.\n")
  }
  v_catch <- v_catch[H_tot > 0]

  v_catch[, `:=`(
    omega_anch = H_anch / H_tot,
    omega_sard = H_sard / H_tot,
    omega_jur  = H_jur  / H_tot
  )]

  # 2026-05-11 Kasperski refactor: keep TIPO_EMB and species-specific
  # H_alloc_hist alongside the legacy scalar.
  v_halloc <- pdt[!is.na(H_alloc_vy),
                  .(H_alloc_hist           = median(H_alloc_vy),
                    H_alloc_anch_hist      = median(H_alloc_anchoveta,     na.rm = TRUE),
                    H_alloc_sard_hist      = median(H_alloc_sardina_comun, na.rm = TRUE),
                    H_alloc_jur_hist       = median(H_alloc_jurel,         na.rm = TRUE),
                    n_years                = .N,
                    TIPO_EMB               = data.table::first(TIPO_EMB)),
                  by = COD_BARCO]

  vtab <- merge(v_catch, v_halloc, by = "COD_BARCO", all.x = TRUE)
  vtab <- vtab[!is.na(H_alloc_hist) & H_alloc_hist > 0]

  cat("[T7] Vessel table construida:",
      nrow(vtab), "vessels (ART:",
      vtab[TIPO_FLOTA == "ART", .N], "| IND:",
      vtab[TIPO_FLOTA == "IND", .N], ").\n")
  cat("    omega medians (ART): anch",
      round(median(vtab[TIPO_FLOTA == "ART", omega_anch]), 2),
      "| sard", round(median(vtab[TIPO_FLOTA == "ART", omega_sard]), 2),
      "| jur", round(median(vtab[TIPO_FLOTA == "ART", omega_jur]), 2), "\n")
  cat("    omega medians (IND): anch",
      round(median(vtab[TIPO_FLOTA == "IND", omega_anch]), 2),
      "| sard", round(median(vtab[TIPO_FLOTA == "IND", omega_sard]), 2),
      "| jur", round(median(vtab[TIPO_FLOTA == "IND", omega_jur]), 2), "\n")
  cat("    H_alloc_hist median (ART):",
      round(median(vtab[TIPO_FLOTA == "ART", H_alloc_hist]), 1), "t | (IND):",
      round(median(vtab[TIPO_FLOTA == "IND", H_alloc_hist]), 1), "t\n\n")

  vtab
}

# -----------------------------------------------------------------------------
# Paso 5 -- Kasperski-aligned NB betas (2026-05-11 refactor)
# -----------------------------------------------------------------------------
# Loads the PRIMARY fits saved by poisson_model.R sec 14:
#   nb_ind_primary.rds: NB with 3 H_alloc_s + 3 prices + year FE
#   nb_art_primary.rds: NB with 3 H_alloc_s + 3 prices + year FE
#                       + H_alloc_anchoveta x TIPO_EMB interaction
#
# Returns nested betas per fleet:
#   beta_h_anch[fleet, TIPO_EMB]   - matrix-like, IND scalar, ART by TIPO_EMB
#   beta_h_sard[fleet]             - scalar per fleet
#   beta_h_jur[fleet]              - scalar per fleet
#   beta_weather[fleet]            - scalar per fleet
#
# Legacy fits also loaded for sensitivity comparison.

T6_PRIMARY_IND_RDS <- "data/outputs/nb_kasperski/nb_ind_primary.rds"
T6_PRIMARY_ART_RDS <- "data/outputs/nb_kasperski/nb_art_primary.rds"
T6_LEGACY_IND_RDS  <- "data/outputs/nb_kasperski/nb_ind_legacy_fe.rds"
T6_LEGACY_ART_RDS  <- "data/outputs/nb_kasperski/nb_art_legacy_fe.rds"

# TIPO_EMB categories with N >= 50 vessel-years in ART: BM, LM, UNK.
# Smaller categories (BR n=12, BRV n=3, L n=6) have unidentified
# interactions and are excluded from aggregate factor_trips with caveat
# in the manuscript (their effort+quota share is <0.1% of ART).
T6_TIPO_EMB_KEEP_ART <- c("BM", "LM", "UNK")

t6_fit_nb <- function(poisson_rds = T6_POISSON_RDS) {
  if (!file.exists(T6_PRIMARY_IND_RDS) || !file.exists(T6_PRIMARY_ART_RDS)) {
    stop(sprintf(
      "Primary fits not found at %s / %s. Run R/04_models/poisson_model.R first.",
      T6_PRIMARY_IND_RDS, T6_PRIMARY_ART_RDS))
  }

  nb_ind <- readRDS(T6_PRIMARY_IND_RDS)
  nb_art <- readRDS(T6_PRIMARY_ART_RDS)
  nb_ind_leg <- readRDS(T6_LEGACY_IND_RDS)
  nb_art_leg <- readRDS(T6_LEGACY_ART_RDS)

  cf_ind <- coef(nb_ind)
  cf_art <- coef(nb_art)

  # IND: scalar beta_h^s per species + scalar beta_weather
  beta_h_anch_ind <- as.numeric(cf_ind["H_alloc_anchoveta"])
  beta_h_sard_ind <- as.numeric(cf_ind["H_alloc_sardina_comun"])
  beta_h_jur_ind  <- as.numeric(cf_ind["H_alloc_jurel"])
  beta_W_ind      <- as.numeric(cf_ind["days_bad_weather"])

  # ART: beta_h_anch interacts with TIPO_EMB. Base = TIPO_EMB at reference
  # level (alphabetical: BM). Marginal beta for each TIPO_EMB is base +
  # interaction term. Keep only TIPO_EMB categories with N>=50.
  base_anch_art <- as.numeric(cf_art["H_alloc_anchoveta"])
  inter_names   <- grep("^H_alloc_anchoveta:TIPO_EMB", names(cf_art), value = TRUE)
  beta_h_anch_art_by_emb <- c(BM = base_anch_art)
  for (nm in inter_names) {
    em <- sub("H_alloc_anchoveta:TIPO_EMB", "", nm)
    beta_h_anch_art_by_emb[em] <- base_anch_art + as.numeric(cf_art[nm])
  }
  # Drop unidentified small-N categories from the lookup (caveat below).
  beta_h_anch_art_by_emb <- beta_h_anch_art_by_emb[
    names(beta_h_anch_art_by_emb) %in% T6_TIPO_EMB_KEEP_ART
  ]

  beta_h_sard_art <- as.numeric(cf_art["H_alloc_sardina_comun"])
  beta_h_jur_art  <- as.numeric(cf_art["H_alloc_jurel"])
  beta_W_art      <- as.numeric(cf_art["days_bad_weather"])

  # Legacy (scalar H_alloc) for sensitivity in the appendix
  cf_ind_leg <- coef(nb_ind_leg)
  cf_art_leg <- coef(nb_art_leg)
  beta_H_ind_leg <- as.numeric(cf_ind_leg["H_alloc_vy"])
  beta_H_art_leg <- as.numeric(cf_art_leg["H_alloc_vy"])
  beta_W_ind_leg <- as.numeric(cf_ind_leg["days_bad_weather"])
  beta_W_art_leg <- as.numeric(cf_art_leg["days_bad_weather"])

  cat("[T7] PRIMARY Kasperski-aligned betas loaded (year FE in all fits):\n")
  cat(sprintf("    IND: beta_h_anch=%.6f  beta_h_sard=%.6f  beta_h_jur=%.6f\n",
              beta_h_anch_ind, beta_h_sard_ind, beta_h_jur_ind))
  cat(sprintf("    IND: beta_weather=%.6f\n", beta_W_ind))
  cat(sprintf("    ART (TIPO_EMB-dependent for anchoveta):\n"))
  for (em in names(beta_h_anch_art_by_emb)) {
    cat(sprintf("       beta_h_anch[%s]=%.6f\n", em, beta_h_anch_art_by_emb[em]))
  }
  cat(sprintf("    ART: beta_h_sard=%.6f  beta_h_jur=%.6f  beta_weather=%.6f\n\n",
              beta_h_sard_art, beta_h_jur_art, beta_W_art))
  cat("[T7] Legacy (scalar) for appendix sensitivity:\n")
  cat(sprintf("    IND: beta_H=%.6f  beta_w=%.6f\n", beta_H_ind_leg, beta_W_ind_leg))
  cat(sprintf("    ART: beta_H=%.6f  beta_w=%.6f\n\n", beta_H_art_leg, beta_W_art_leg))

  list(
    # PRIMARY (Kasperski-aligned)
    beta_h_anch       = list(IND = beta_h_anch_ind, ART_by_emb = beta_h_anch_art_by_emb),
    beta_h_sard       = c(ART = beta_h_sard_art, IND = beta_h_sard_ind),
    beta_h_jur        = c(ART = beta_h_jur_art,  IND = beta_h_jur_ind),
    beta_weather      = c(ART = beta_W_art,      IND = beta_W_ind),
    # LEGACY (scalar H_alloc) for appendix sensitivity
    beta_H_legacy     = c(ART = beta_H_art_leg, IND = beta_H_ind_leg),
    beta_w_legacy     = c(ART = beta_W_art_leg, IND = beta_W_ind_leg),
    fits              = list(art = nb_art, ind = nb_ind,
                              art_legacy = nb_art_leg, ind_legacy = nb_ind_leg)
  )
}

# -----------------------------------------------------------------------------
# Paso 6 -- factor_H[d,v,m,c] y factor_trips[d,v,m,c] por vessel
# -----------------------------------------------------------------------------
# Memoria-safe: loop por vessel. Inner table ahora es (.draw x model x ssp
# x window) ~ 16K x 22 = 352K filas. Multiplied por ~hundreds de vessels =
# ~50-100M rows totales (manageable como rbindlist por vessel).

t6_compute_factor_trips <- function(factor_B_dt, vessel_tab, beta_pack,
                                     vessel_delta_dbw = NULL) {

  fb_wide <- as.data.table(factor_B_dt)[
    , .(.draw, stock_id, model, scenario, window, factor_B)
  ] %>%
    data.table::dcast(.draw + model + scenario + window ~ stock_id,
                      value.var = "factor_B")

  setnames(fb_wide,
           old = c("anchoveta_cs", "sardina_comun_cs", "jurel_cs"),
           new = c("fB_anch", "fB_sard", "fB_jur"),
           skip_absent = TRUE)

  fb_wide[is.na(fB_jur), fB_jur := 1.0]

  vt <- as.data.table(vessel_tab)

  # 2026-05-11 refactor: filter ART vessels to TIPO_EMB with N>=50 in fit.
  # Excluded BR/BRV/L: <0.1% of effort/quota in ART, documented caveat.
  before_n <- nrow(vt)
  vt <- vt[!(TIPO_FLOTA == "ART" & !(TIPO_EMB %in% T6_TIPO_EMB_KEEP_ART))]
  after_n <- nrow(vt)
  if (after_n < before_n) {
    cat(sprintf("[T7] Dropped %d ART vessels with TIPO_EMB outside {BM, LM, UNK}\n",
                before_n - after_n))
  }

  # Direct weather channel (vessel-specific Deltadays_bw)
  use_direct <- !is.null(beta_pack$beta_weather) && !is.null(vessel_delta_dbw)
  if (use_direct) {
    vd <- as.data.table(vessel_delta_dbw)[
      , .(COD_BARCO, model, scenario, window, delta_days_bw)
    ]
    fb_key <- paste(fb_wide$model, fb_wide$scenario, fb_wide$window, sep = "|")
    cat(sprintf("[T7] Direct weather channel ON: beta_weather ART=%.5f, IND=%.5f\n",
                beta_pack$beta_weather[["ART"]], beta_pack$beta_weather[["IND"]]))
  } else {
    cat("[T7] Direct weather channel OFF (legacy mode, indirect only)\n")
  }

  cat("[T7] Loop por vessel sobre", nrow(vt),
      "vessels x", nrow(fb_wide), "(.draw x model x scenario)\n",
      "    -> total filas factor_trips =",
      formatC(nrow(vt) * nrow(fb_wide), format = "d", big.mark = ","), "\n")
  t0 <- Sys.time()

  # Extract beta lookups (PRIMARY = Kasperski-aligned)
  beta_h_sard_v <- beta_pack$beta_h_sard
  beta_h_jur_v  <- beta_pack$beta_h_jur
  beta_w_v      <- if (use_direct) beta_pack$beta_weather else NULL

  chunks <- vector("list", nrow(vt))
  for (i in seq_len(nrow(vt))) {
    v       <- vt[i]
    fleet   <- as.character(v$TIPO_FLOTA)

    # beta_h_anch lookup: scalar for IND, TIPO_EMB-dependent for ART
    if (fleet == "IND") {
      beta_h_anch_v <- beta_pack$beta_h_anch$IND
    } else {  # ART
      emb <- as.character(v$TIPO_EMB)
      beta_h_anch_v <- beta_pack$beta_h_anch$ART_by_emb[emb]
      if (is.na(beta_h_anch_v)) {
        # Should not happen post-filter; safety belt.
        next
      }
    }

    # factor_H (legacy diagnostic, used in survive threshold)
    factor_H <- v$omega_anch * fb_wide$fB_anch +
                v$omega_sard * fb_wide$fB_sard +
                v$omega_jur  * fb_wide$fB_jur

    # PRIMARY indirect term: sum_s beta_h^s * H_alloc_s_hist * (fB_s - 1)
    indirect_term <- beta_h_anch_v * v$H_alloc_anch_hist * (fb_wide$fB_anch - 1) +
                     beta_h_sard_v[[fleet]] * v$H_alloc_sard_hist * (fb_wide$fB_sard - 1) +
                     beta_h_jur_v[[fleet]]  * v$H_alloc_jur_hist  * (fb_wide$fB_jur  - 1)

    if (use_direct) {
      vd_v <- vd[COD_BARCO == v$COD_BARCO]
      delta_lookup <- setNames(
        vd_v$delta_days_bw,
        paste(vd_v$model, vd_v$scenario, vd_v$window, sep = "|")
      )
      delta_days_bw <- unname(delta_lookup[fb_key])
      delta_days_bw[is.na(delta_days_bw)] <- 0

      beta_w <- beta_w_v[[fleet]]
      direct_term  <- beta_w * delta_days_bw
      factor_trips <- exp(indirect_term + direct_term)

      chunks[[i]] <- data.table(
        COD_BARCO        = v$COD_BARCO,
        TIPO_FLOTA       = v$TIPO_FLOTA,
        TIPO_EMB         = v$TIPO_EMB,
        .draw            = fb_wide$.draw,
        model            = fb_wide$model,
        scenario         = fb_wide$scenario,
        window           = fb_wide$window,
        factor_H         = factor_H,
        delta_days_bw    = delta_days_bw,
        factor_trips_ind = exp(indirect_term),
        factor_trips     = factor_trips
      )
    } else {
      factor_trips <- exp(indirect_term)
      chunks[[i]] <- data.table(
        COD_BARCO        = v$COD_BARCO,
        TIPO_FLOTA       = v$TIPO_FLOTA,
        TIPO_EMB         = v$TIPO_EMB,
        .draw            = fb_wide$.draw,
        model            = fb_wide$model,
        scenario         = fb_wide$scenario,
        window           = fb_wide$window,
        factor_H         = factor_H,
        delta_days_bw    = 0,
        factor_trips_ind = factor_trips,
        factor_trips     = factor_trips
      )
    }
  }

  out <- rbindlist(chunks)
  out[, scenario_key := paste(scenario, window, sep = "_")]

  cat(sprintf("    Done en %.1fs. N filas = %s\n\n",
              as.numeric(Sys.time() - t0, units = "secs"),
              formatC(nrow(out), format = "d", big.mark = ",")))

  out
}

# -----------------------------------------------------------------------------
# Paso 7a -- Resumen WITHIN-MODEL: (fleet x model x ssp x window)
# -----------------------------------------------------------------------------
# Aggregacion sobre (draws x vessels within fleet) -- pooling identico al T7
# viejo. La unica diferencia: ahora el agregado es por modelo CMIP6 m, no
# colapsando todo el ensemble a un solo punto.

t6_summarise_trips_within <- function(ft_dt, threshold = T6_LOSS_THRESHOLD) {
  ft_dt[, survive := factor_H >= threshold]

  summ <- ft_dt[, .(
    n_obs                 = .N,
    n_survive             = sum(survive),
    factor_trips_marg_med = median(factor_trips),
    factor_trips_marg_q05 = quantile(factor_trips, 0.05),
    factor_trips_marg_q95 = quantile(factor_trips, 0.95),
    pr_portfolio_loss     = mean(!survive),
    factor_trips_cond_med = if (sum(survive) > 0)
                              median(factor_trips[survive]) else NA_real_,
    factor_trips_cond_q05 = if (sum(survive) > 0)
                              quantile(factor_trips[survive], 0.05) else NA_real_,
    factor_trips_cond_q95 = if (sum(survive) > 0)
                              quantile(factor_trips[survive], 0.95) else NA_real_,
    factor_H_med          = median(factor_H),
    factor_H_q05          = quantile(factor_H, 0.05),
    factor_H_q95          = quantile(factor_H, 0.95),
    pr_decline            = mean(factor_trips < 1)
  ), by = .(TIPO_FLOTA, model, scenario, window)]

  summ[, scenario_key := paste(scenario, window, sep = "_")]
  summ[, scenario_label := T6_SCENARIO_LABEL[scenario_key]]
  summ[, fleet_label    := T6_FLEET_LABEL[as.character(TIPO_FLOTA)]]

  summ[, ssp_ord    := factor(scenario, levels = T6_SSPS)]
  summ[, window_ord := factor(window,   levels = T6_WINDOWS)]
  setorder(summ, TIPO_FLOTA, model, ssp_ord, window_ord)
  summ[, c("ssp_ord", "window_ord") := NULL]

  summ
}

# -----------------------------------------------------------------------------
# Paso 7b -- Resumen CROSS-MODEL: (fleet x ssp x window)
# -----------------------------------------------------------------------------
# Convencion exacta paralela a t5_summarise_cross():
#   *_cross_med   = median across m del *_med within m
#   *_cross_q25/q75 = IQR cross-model del *_med
#   *_within_q05/q95 = mediana across m del posterior q05/q95 within m
#                      (90% CI tipico dentro de un modelo)
#   pr_*_cross_med = median across m del pr_* within m

t6_summarise_trips_cross <- function(within_summ) {
  ws <- as.data.table(within_summ)
  ws[, .(
    n_models                = .N,
    # Marginal (all draws within model)
    factor_trips_marg_cross_med = median(factor_trips_marg_med),
    factor_trips_marg_cross_q25 = quantile(factor_trips_marg_med, 0.25),
    factor_trips_marg_cross_q75 = quantile(factor_trips_marg_med, 0.75),
    factor_trips_marg_within_q05 = median(factor_trips_marg_q05),
    factor_trips_marg_within_q95 = median(factor_trips_marg_q95),
    # Conditional (factor_H >= threshold within model)
    factor_trips_cond_cross_med = median(factor_trips_cond_med, na.rm = TRUE),
    factor_trips_cond_cross_q25 = quantile(factor_trips_cond_med, 0.25, na.rm = TRUE),
    factor_trips_cond_cross_q75 = quantile(factor_trips_cond_med, 0.75, na.rm = TRUE),
    factor_trips_cond_within_q05 = median(factor_trips_cond_q05, na.rm = TRUE),
    factor_trips_cond_within_q95 = median(factor_trips_cond_q95, na.rm = TRUE),
    n_models_cond_valid     = sum(!is.na(factor_trips_cond_med)),
    # Pr loss
    pr_portfolio_loss_cross_med = median(pr_portfolio_loss),
    pr_portfolio_loss_cross_q25 = quantile(pr_portfolio_loss, 0.25),
    pr_portfolio_loss_cross_q75 = quantile(pr_portfolio_loss, 0.75),
    # factor_H
    factor_H_cross_med      = median(factor_H_med),
    factor_H_cross_q25      = quantile(factor_H_med, 0.25),
    factor_H_cross_q75      = quantile(factor_H_med, 0.75),
    # Pr decline marginal
    pr_decline_cross_med    = median(pr_decline)
  ), by = .(TIPO_FLOTA, scenario, window)] -> cross

  cross[, scenario_key   := paste(scenario, window, sep = "_")]
  cross[, scenario_label := T6_SCENARIO_LABEL[scenario_key]]
  cross[, fleet_label    := T6_FLEET_LABEL[as.character(TIPO_FLOTA)]]

  cross[, ssp_ord    := factor(scenario, levels = T6_SSPS)]
  cross[, window_ord := factor(window,   levels = T6_WINDOWS)]
  setorder(cross, TIPO_FLOTA, ssp_ord, window_ord)
  cross[, c("ssp_ord", "window_ord") := NULL]

  cross
}

# -----------------------------------------------------------------------------
# Paso 7c -- Sanity unit-test: factor_H = 1 -> factor_trips = 1.0 exacto
# -----------------------------------------------------------------------------

t6_sanity_unit_test <- function(vessel_tab, beta_pack) {
  vt <- as.data.table(vessel_tab)
  # PRIMARY spec: indirect_term = sum_s beta_h^s * H_alloc_s_hist * (fB_s - 1).
  # When all fB_s = 1 (no climate change), every term is zero -> factor_trips = 1.
  # Build a median-IND vessel and check.
  vh_med_ind <- vt[TIPO_FLOTA == "IND",
                   .(H_anch = median(H_alloc_anch_hist, na.rm = TRUE),
                     H_sard = median(H_alloc_sard_hist, na.rm = TRUE),
                     H_jur  = median(H_alloc_jur_hist,  na.rm = TRUE))]
  beta_h_anch_ind <- beta_pack$beta_h_anch$IND
  beta_h_sard_ind <- beta_pack$beta_h_sard[["IND"]]
  beta_h_jur_ind  <- beta_pack$beta_h_jur[["IND"]]
  # factor_B = 1 for all species
  test_indirect <- beta_h_anch_ind * vh_med_ind$H_anch * 0 +
                   beta_h_sard_ind * vh_med_ind$H_sard * 0 +
                   beta_h_jur_ind  * vh_med_ind$H_jur  * 0
  test_factor_trips <- exp(test_indirect)
  ok <- abs(test_factor_trips - 1) < 1e-10
  cat(sprintf("[T7] Sanity unit-test factor_B_s=1 -> factor_trips_indirect = %.6f  %s\n",
              test_factor_trips, if (ok) "OK" else "FAIL"))
  cat("    (testea SOLO el canal indirect. factor_trips total incluye ademas\n",
      "     beta_weather*Deltadays_bw del direct channel; con Deltawind=0 ese termino\n",
      "     se anula y el sanity total = sanity indirect. Con DSST=0,\n",
      "     DlogCHL=0 NO da factor_trips=1 en general: historico no esta en\n",
      "     Schaefer steady-state bajo F_hist; r_eff=r_base pero factor_B =\n",
      "     K(1-F/r_base)/B_hist != 1.0 generico.)\n\n")
  invisible(ok)
}

# -----------------------------------------------------------------------------
# Paso 8 -- Escribir tablas (formateada cross + raw cross + by-model + extinct)
# -----------------------------------------------------------------------------

t6_write_tables <- function(cross_trips, within_trips, cross_ext, within_ext,
                            path_main      = T6_TABLE_OUT,
                            path_raw       = T6_TABLE_RAW_OUT,
                            path_bymodel   = T6_TABLE_BYMODEL_OUT,
                            path_extinct   = T6_TABLE_EXTINCT_OUT,
                            path_ext_bym   = T6_TABLE_EXTINCT_BYMODEL) {

  dir.create(dirname(path_main), recursive = TRUE, showWarnings = FALSE)

  # -- (i) Tabla formateada cross-model paper --------------------------------
  fmt_pct <- function(x) ifelse(is.na(x), "--",
                                sprintf("%+.1f%%", 100 * (x - 1)))
  fmt_band <- function(lo, hi) ifelse(is.na(lo) | is.na(hi),
                                       "--",
                                       sprintf("[%+.1f%%, %+.1f%%]",
                                               100 * (lo - 1), 100 * (hi - 1)))

  fmt <- as.data.table(cross_trips)[, .(
    Fleet                                = fleet_label,
    Scenario                             = scenario_label,
    n_models                             = n_models,
    # Marginal: cross-model + cross-IQR + within-CI
    `%Delta trips marg cross med`        = fmt_pct(factor_trips_marg_cross_med),
    `%Delta trips marg cross IQR`        = fmt_band(factor_trips_marg_cross_q25,
                                                    factor_trips_marg_cross_q75),
    `%Delta trips marg within posterior CI` = fmt_band(factor_trips_marg_within_q05,
                                                        factor_trips_marg_within_q95),
    # Pr portfolio loss
    `Pr loss cross med`                  = sprintf("%.2f", pr_portfolio_loss_cross_med),
    `Pr loss cross IQR`                  = sprintf("[%.2f, %.2f]",
                                                   pr_portfolio_loss_cross_q25,
                                                   pr_portfolio_loss_cross_q75),
    # Conditional (climate-pure response, draws with factor_H >= threshold)
    `%Delta trips cond cross med`        = ifelse(is.na(factor_trips_cond_cross_med),
                                                   "collapse-dom.",
                                                   fmt_pct(factor_trips_cond_cross_med)),
    `%Delta trips cond cross IQR`        = ifelse(is.na(factor_trips_cond_cross_q25) |
                                                   is.na(factor_trips_cond_cross_q75),
                                                   "--",
                                                   fmt_band(factor_trips_cond_cross_q25,
                                                            factor_trips_cond_cross_q75)),
    `factor_H cross med`                 = sprintf("%.3f", factor_H_cross_med),
    `factor_H cross IQR`                 = sprintf("[%.3f, %.3f]",
                                                   factor_H_cross_q25,
                                                   factor_H_cross_q75)
  )]
  write.csv(fmt, path_main, row.names = FALSE)
  cat("[T7] Tabla principal cross-model:", path_main, "\n")

  # -- (ii) Raw numerico cross-model -----------------------------------------
  write.csv(cross_trips, path_raw, row.names = FALSE)
  cat("[T7] Tabla cross-model raw:", path_raw, "\n")

  # -- (iii) By-model long --------------------------------------------------
  bym_out <- as.data.table(within_trips)[, .(
    Fleet         = fleet_label,
    model         = model,
    Scenario      = scenario_label,
    n_obs,
    pct_trips_marg_med = round(100 * (factor_trips_marg_med - 1), 2),
    pct_trips_marg_q05 = round(100 * (factor_trips_marg_q05 - 1), 2),
    pct_trips_marg_q95 = round(100 * (factor_trips_marg_q95 - 1), 2),
    pr_portfolio_loss  = round(pr_portfolio_loss, 3),
    pct_trips_cond_med = round(100 * (factor_trips_cond_med - 1), 2),
    pct_trips_cond_q05 = round(100 * (factor_trips_cond_q05 - 1), 2),
    pct_trips_cond_q95 = round(100 * (factor_trips_cond_q95 - 1), 2),
    factor_H_med       = round(factor_H_med, 4),
    factor_H_q05       = round(factor_H_q05, 4),
    factor_H_q95       = round(factor_H_q95, 4),
    pr_decline         = round(pr_decline, 3)
  )]
  write.csv(bym_out, path_bymodel, row.names = FALSE)
  cat("[T7] Tabla by-model:", path_bymodel, "\n")

  # -- (iv) Extinction cross-model formateada --------------------------------
  ext_fmt <- as.data.table(cross_ext)[, .(
    Stock              = stock_label,
    Scenario           = scenario_label,
    n_models           = n_models,
    `Pr(extinct) cross med`   = ifelse(non_identified, "n.i.",
                                       sprintf("%.3f", pr_extinct_cross_med)),
    `Pr(extinct) cross IQR`   = ifelse(non_identified, "n.i.",
                                       sprintf("[%.3f, %.3f]",
                                               pr_extinct_cross_q25,
                                               pr_extinct_cross_q75)),
    `factor_B cross med`      = ifelse(non_identified, "n.i.",
                                       sprintf("%.3f", factor_B_cross_med)),
    `factor_B cross IQR`      = ifelse(non_identified, "n.i.",
                                       sprintf("[%.3f, %.3f]",
                                               factor_B_cross_q25,
                                               factor_B_cross_q75)),
    `Non-identified`          = non_identified
  )]
  write.csv(ext_fmt, path_extinct, row.names = FALSE)
  cat("[T7] Tabla extinct cross-model:", path_extinct, "\n")

  # -- (v) Extinction by-model long -----------------------------------------
  ext_bym <- as.data.table(within_ext)[, .(
    Stock              = stock_label,
    model              = model,
    Scenario           = scenario_label,
    pr_extinct         = round(pr_extinct, 4),
    factor_B_med       = round(factor_B_med, 4),
    factor_B_q05       = round(factor_B_q05, 4),
    factor_B_q95       = round(factor_B_q95, 4),
    `Non-identified`   = non_identified
  )]
  write.csv(ext_bym, path_ext_bym, row.names = FALSE)
  cat("[T7] Tabla extinct by-model:", path_ext_bym, "\n\n")

  invisible(list(fmt = fmt, ext_fmt = ext_fmt))
}

# -----------------------------------------------------------------------------
# Orquestador
# -----------------------------------------------------------------------------

t6_run <- function() {
  cat(strrep("=", 70), "\n",
      "T7 ENSEMBLE -- Trip comparative statics (Schaefer ss + NB), 6 modelos\n",
      strrep("=", 70), "\n\n", sep = "")

  # Biologia historica
  bio    <- t6_load_biology()

  # Posterior T4b-full
  draws  <- t6_extract_draws()

  # Escenarios CMIP6 (per-model)
  scen   <- compstat_load_scenarios()

  # factor_B[d, s, m, c] + Pr(extinct) within / cross
  fB     <- t6_compute_factor_B(draws, bio$summary, scen)
  ext_w  <- t6_summarise_extinction_within(fB)
  ext_c  <- t6_summarise_extinction_cross(ext_w)

  cat("[T7] Pr(extinct) cross-model por stock x scenario:\n")
  print(as.data.table(ext_c)[, .(stock_label, scenario_label, n_models,
                                 pr_ext_cross_med  = round(pr_extinct_cross_med, 3),
                                 pr_ext_cross_IQR  = sprintf("[%.2f, %.2f]",
                                                             pr_extinct_cross_q25,
                                                             pr_extinct_cross_q75),
                                 fB_cross_med      = round(factor_B_cross_med, 3),
                                 non_id            = non_identified)])
  cat("\n")

  # Vessel table + Kasperski-aligned NB betas (loaded from primary fits)
  vtab   <- t6_build_vessel_table()
  nbres  <- t6_fit_nb()

  # Sanity unit-test sobre el termino indirect (no climate -> factor_trips=1)
  t6_sanity_unit_test(vtab, nbres)

  # Deltadays_bw vessel-specific (direct weather channel, via wc helper).
  vdbw <- wc_compute_vessel_delta_days_bw(use_cache = TRUE, force = FALSE)

  # factor_H[d,v,m,c] y factor_trips[d,v,m,c] con AMBOS canales
  # Pasa el beta_pack completo (PRIMARY Kasperski-aligned): 3 H_alloc_s per
  # fleet, with TIPO_EMB interaction on anchoveta in ART.
  ft     <- t6_compute_factor_trips(fB, vtab, nbres,
                                     vessel_delta_dbw = vdbw)

  # Resumenes within / cross
  trips_w <- t6_summarise_trips_within(ft, threshold = T6_LOSS_THRESHOLD)
  trips_c <- t6_summarise_trips_cross(trips_w)

  cat("[T7] Resumen factor_trips cross-model por flota x scenario:\n")
  print(trips_c[, .(fleet_label, scenario_label,
                    trips_marg = sprintf("%+.1f%% [%+.1f%%, %+.1f%%]",
                                         100 * (factor_trips_marg_cross_med - 1),
                                         100 * (factor_trips_marg_cross_q25 - 1),
                                         100 * (factor_trips_marg_cross_q75 - 1)),
                    Pr_loss    = sprintf("%.2f [%.2f, %.2f]",
                                          pr_portfolio_loss_cross_med,
                                          pr_portfolio_loss_cross_q25,
                                          pr_portfolio_loss_cross_q75),
                    trips_cond = ifelse(is.na(factor_trips_cond_cross_med),
                                        "collapse-dom.",
                                        sprintf("%+.1f%% [%+.1f%%, %+.1f%%]",
                                                100 * (factor_trips_cond_cross_med - 1),
                                                100 * (factor_trips_cond_cross_q25 - 1),
                                                100 * (factor_trips_cond_cross_q75 - 1))),
                    fH_med     = round(factor_H_cross_med, 3))])
  cat("\n")

  # Escribir tablas
  t6_write_tables(trips_c, trips_w, ext_c, ext_w)

  # -------------------------------------------------------------------------
  # 2026-05-11 refactor: ART within-fleet decomposition by TIPO_EMB.
  # New table for paper sec 4.4 (within-ART heterogeneity by vessel type).
  # -------------------------------------------------------------------------
  ft_art_emb <- ft[TIPO_FLOTA == "ART"]
  ft_art_emb[, survive := factor_H >= T6_LOSS_THRESHOLD]
  trips_w_emb <- ft_art_emb[, .(
    n_obs                 = .N,
    n_survive             = sum(survive),
    factor_trips_marg_med = median(factor_trips),
    factor_trips_marg_q05 = quantile(factor_trips, 0.05),
    factor_trips_marg_q95 = quantile(factor_trips, 0.95),
    pr_portfolio_loss     = mean(!survive),
    factor_trips_cond_med = if (sum(survive) > 0)
                              median(factor_trips[survive]) else NA_real_,
    factor_H_med          = median(factor_H),
    pr_decline            = mean(factor_trips < 1)
  ), by = .(TIPO_EMB, model, scenario, window)]
  trips_c_emb <- trips_w_emb[, .(
    n_models                       = .N,
    factor_trips_marg_cross_med    = median(factor_trips_marg_med),
    factor_trips_marg_cross_q25    = quantile(factor_trips_marg_med, 0.25),
    factor_trips_marg_cross_q75    = quantile(factor_trips_marg_med, 0.75),
    factor_trips_marg_within_q05   = median(factor_trips_marg_q05),
    factor_trips_marg_within_q95   = median(factor_trips_marg_q95),
    pr_portfolio_loss_cross_med    = median(pr_portfolio_loss),
    factor_trips_cond_cross_med    = median(factor_trips_cond_med, na.rm = TRUE),
    factor_H_cross_med             = median(factor_H_med)
  ), by = .(TIPO_EMB, scenario, window)]
  trips_c_emb[, scenario_key   := paste(scenario, window, sep = "_")]
  trips_c_emb[, scenario_label := T6_SCENARIO_LABEL[scenario_key]]
  trips_c_emb[, ssp_ord_emb := factor(scenario, levels = T6_SSPS)]
  trips_c_emb[, win_ord_emb := factor(window,   levels = T6_WINDOWS)]
  setorder(trips_c_emb, TIPO_EMB, ssp_ord_emb, win_ord_emb)
  trips_c_emb[, c("ssp_ord_emb", "win_ord_emb") := NULL]

  fmt_pct  <- function(x) ifelse(is.na(x), "--", sprintf("%+.1f%%", 100 * (x - 1)))
  fmt_band <- function(lo, hi) ifelse(is.na(lo) | is.na(hi), "--",
                                       sprintf("[%+.1f%%, %+.1f%%]",
                                               100 * (lo - 1), 100 * (hi - 1)))
  trips_emb_fmt <- trips_c_emb[, .(
    TIPO_EMB                              = TIPO_EMB,
    Scenario                              = scenario_label,
    n_models                              = n_models,
    `%Delta trips marg cross med`         = fmt_pct(factor_trips_marg_cross_med),
    `%Delta trips marg cross IQR`         = fmt_band(factor_trips_marg_cross_q25,
                                                      factor_trips_marg_cross_q75),
    `Pr loss cross med`                   = sprintf("%.2f", pr_portfolio_loss_cross_med),
    `%Delta trips cond cross med`         = ifelse(is.na(factor_trips_cond_cross_med),
                                                     "collapse-dom.",
                                                     fmt_pct(factor_trips_cond_cross_med)),
    `factor_H cross med`                  = sprintf("%.3f", factor_H_cross_med)
  )]

  path_emb     <- file.path(dirname(T6_TABLE_OUT), "trip_comparative_statics_by_tipo_emb.csv")
  path_emb_raw <- file.path(dirname(T6_TABLE_OUT), "trip_comparative_statics_by_tipo_emb_raw.csv")
  write.csv(trips_emb_fmt, path_emb,     row.names = FALSE)
  write.csv(trips_c_emb,   path_emb_raw, row.names = FALSE)
  cat("[T7] Wrote within-ART by TIPO_EMB:\n    ", path_emb, "\n    ", path_emb_raw, "\n\n")
  cat("[T7] Within-ART by TIPO_EMB headline (SSP5-8.5 end-of-century):\n")
  print(trips_emb_fmt[Scenario == "SSP5-8.5, 2081-2100"])
  cat("\n")

  invisible(list(
    scenarios          = scen,
    biology            = bio,
    draws              = draws,
    factor_B           = fB,
    extinct_within     = ext_w,
    extinct_cross      = ext_c,
    vessel_tab         = vtab,
    nb                 = nbres,
    factor_trips       = ft,
    trips_within       = trips_w,
    trips_cross        = trips_c,
    trips_within_emb   = trips_w_emb,
    trips_cross_emb    = trips_c_emb
  ))
}

# -----------------------------------------------------------------------------
# Main guard (default-FALSE: T7 es pesado, evitar trigger accidental)
# -----------------------------------------------------------------------------

if (isTRUE(getOption("t6.run_main", FALSE))) {
  t6_result <- t6_run()
}
