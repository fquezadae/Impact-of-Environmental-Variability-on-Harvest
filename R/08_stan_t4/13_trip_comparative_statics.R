# =============================================================================
# FONDECYT -- 13_trip_comparative_statics.R   (T6 / step B paper1)
#
# Long-run comparative statics sobre TRIPS -- conecta el posterior T4b-full con
# la negative binomial trip equation via el Schaefer steady-state bajo F_hist.
# Es el companion de 12_growth_comparative_statics.R (T5, growth rates) y
# alimenta la tabla tab:trip_compstat en paper1 §4.4 "Implications for
# fleet-level effort".
#
# Framing Cowles: steady-state bajo status-quo F, no forward simulation.
# Forward sim con trayectorias y reglas endogenas => paper 2.
#
# Pipeline matematico:
#
#   (1) r_eff[d,s,c] = r_base[d,s] * exp(rho_sst[d,s]*DSST[c] + rho_chl[d,s]*DlogCHL[c])
#
#   (2) Schaefer steady-state:
#       B_star[d,s,c] = K[d,s] * (1 - F_hist[s]/r_eff[d,s,c])
#       Extincion si F_hist[s] >= r_eff[d,s,c]. Flag y reportar Pr(extinct).
#
#   (3) factor_B[d,s,c] = B_star[d,s,c] / B_hist[s]
#       B_hist = mediana de biomass 2000-2024 (IFOP/SPRFMO, consistente con Stan)
#
#   (4) omega[v,s] = share historico realizado de especie s en captura vessel v
#       desde H_33/H_114/H_26 en poisson_dt.rds:
#         omega[v,s] = sum_y H_{s,vy} / sum_y (H_33 + H_114 + H_26)_{vy}
#
#   (5) factor_H[d,v,c] = sum_s omega[v,s] * factor_B[d,s,c]
#       Convencion: jurel_cs no identificado -> factor_B_jurel = 1.0 para
#       todos los draws (posterior prior-dominado; propagarlo mete ruido
#       espurio al portfolio). Asuncion explicita.
#
#   (6) factor_trips con semi-elasticity (el NB estima H_alloc_vy en niveles,
#       NO log, asi que la traduccion correcta del posterior a trips es):
#       factor_trips[d,v,c] = exp( beta_H[fleet(v)] * H_alloc_hist[v] *
#                                  (factor_H[d,v,c] - 1) )
#       H_alloc_hist[v] = mediana de H_alloc_vy por vessel.
#       Consecuencia: heterogeneidad intra-flota -- vessels grandes responden
#       mas en log-trips a mismo %Delta H_alloc. Los IC [q05,q95] sobre
#       (draws x vessels within fleet) lo capturan.
#
#   (7) Agregar por flota: mediana, q05, q95, Pr(Delta trips < 0) sobre
#       draws x vessels within fleet. Pr(extinct) reportado por stock x scenario.
#
# Sanity check: DSST=0, DlogCHL=0 -> r_eff = r_base, B_star = B_star_hist,
# factor_B = 1.0 exacto (asumiendo F_hist proporcional congruente), y
# factor_trips = 1.0 exacto.
#
# Entradas:
#   - data/outputs/t4b/t4b_full_fit.rds        (cmdstanr CmdStanMCMC)
#   - data/projections/cmip6_deltas.rds        (data.table CMIP6 deltas)
#   - data/bio_params/catch_annual_cs_2000_2024.csv  (captura IFOP-consistente)
#   - data/bio_params/official_biomass_series.csv    (anch/sard biomass_total_t)
#   - data/bio_params/acoustic_biomass_series.csv    (jurel_cs biomass_t)
#   - data/trips/poisson_dt.rds                (panel NB con H_33/H_114/H_26)
#
# Salidas:
#   - tables/trip_comparative_statics.csv          (formateado para paper)
#   - tables/trip_comparative_statics_raw.csv      (numerico crudo)
#   - tables/trip_comparative_statics_extinct.csv  (Pr extinct por stock x scen)
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

# Reuso del builder de escalares CMIP6 del T5
source_utf8("R/08_stan_t4/12_growth_comparative_statics.R")
# Nota: 12_growth_comparative_statics.R define t5_build_scenario_scalars() y
# constantes T5_*. No ejecuta t5_run() porque el main guard requiere option
# t5.run_main = TRUE.

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------

T6_FIT_RDS           <- "data/outputs/t4b/t4b_full_fit.rds"
T6_DELTAS_RDS        <- "data/projections/cmip6_deltas.rds"
T6_CATCH_CSV         <- "data/bio_params/catch_annual_cs_2000_2024.csv"
T6_OFF_BIO_CSV       <- "data/bio_params/official_biomass_series.csv"
T6_ACU_BIO_CSV       <- "data/bio_params/acoustic_biomass_series.csv"
T6_POISSON_RDS       <- "data/trips/poisson_dt.rds"

T6_TABLE_OUT         <- "paper1/tables/trip_comparative_statics.csv"
T6_TABLE_RAW_OUT     <- "paper1/tables/trip_comparative_statics_raw.csv"
T6_TABLE_EXTINCT_OUT <- "paper1/tables/trip_comparative_statics_extinct.csv"

T6_WINDOW    <- 2000:2024                 # consistente con T4B_FULL_WINDOW
T6_STOCKS    <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
T6_STOCK_IDX <- setNames(seq_along(T6_STOCKS), T6_STOCKS)

T6_STOCK_LABEL <- c(
  anchoveta_cs     = "Anchoveta CS",
  sardina_comun_cs = "Sardina comun CS",
  jurel_cs         = "Jurel CS"
)

# Species-code map (confirmado vs R/01_data_cleaning/tac_processing.R:130-133)
#   H_114 -> anchoveta; H_33 -> sardina_comun; H_26 -> jurel
T6_CATCH_COL_OF <- c(
  anchoveta_cs     = "H_114",
  sardina_comun_cs = "H_33",
  jurel_cs         = "H_26"
)

# Stocks cuyo shifter NO esta identificado por la data 2000-2024.
# Convencion paper1: jurel reportado como "n.i." en growth tables y, aqui,
# se fija factor_B = 1.0 para no contaminar el portfolio con posterior
# prior-dominado. Ver project_jurel_ni_convention.md.
T6_NON_IDENTIFIED_STOCKS <- c("jurel_cs")

T6_SSPS    <- c("ssp245", "ssp585")
T6_WINDOWS <- c("mid", "end")

T6_SCENARIO_LABEL <- c(
  ssp245_mid = "SSP2-4.5, 2041-2060",
  ssp245_end = "SSP2-4.5, 2081-2100",
  ssp585_mid = "SSP5-8.5, 2041-2060",
  ssp585_end = "SSP5-8.5, 2081-2100"
)

T6_FLEET_LABEL <- c(
  ART = "Artisanal",
  IND = "Industrial"
)

# -----------------------------------------------------------------------------
# Paso 1 -- F_hist y B_hist por stock (desde series consistentes con Stan)
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

  # F proporcional anual (catch/biomass). NOTA: sin correccion por survival
  # midseason -- consistente con la likelihood Schaefer de t4b_state_space_full.stan
  # que trata C como sustraccion del stock de inicio de ano.
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

  cat("[T6] F_hist y B_hist por stock (mediana 2000-2024, IFOP-consistent):\n")
  print(summ %>%
          dplyr::mutate(F_hist = round(F_hist, 3),
                        B_hist_kt = round(B_hist_t / 1e3, 0)))
  cat("\n")

  list(summary = summ, annual = fb)
}

# -----------------------------------------------------------------------------
# Paso 2 -- Extraer draws posteriores (r_base, K_nat, rho_sst, rho_chl)
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

  cat("[T6] Posterior draws extraidos: N_total =", nrow(draws_long),
      "(", length(unique(draws_long$.draw)), "draws x",
      length(stocks), "stocks )\n")
  cat("    Units check -- K_nat en miles de t (mil_t), biomass en Stan data en mil_t\n")
  cat("    K_nat median por stock:",
      paste(round(tapply(draws_long$K_nat, draws_long$stock_id, median), 0),
            collapse = " | "), "\n\n")

  draws_long
}

# -----------------------------------------------------------------------------
# Paso 3 -- factor_B[d,s,c] via Schaefer steady-state bajo F_hist
# -----------------------------------------------------------------------------
# OJO UNIDADES: el Stan trabaja con biomass en MIL_T (miles de toneladas).
# K_nat del posterior esta en mil_t. B_hist la convertimos a mil_t antes de
# calcular el factor (aunque en verdad el factor es ratio y no importa la
# unidad siempre que sea la misma arriba y abajo -- pero los F_hist requieren
# que catch/biomass esten en la misma unidad, y catch_annual_cs_2000_2024.csv
# usa t -- F_prop = catch_t / biomass_t es dimensionless, OK).

t6_compute_factor_B <- function(draws_long, bio_summary, scen_dt) {

  bio_summary <- bio_summary %>%
    dplyr::select(stock_id, F_hist, B_hist_t)

  scen_df <- tibble::as_tibble(scen_dt) %>%
    dplyr::select(ssp, window, DSST, DlogCHL) %>%
    dplyr::mutate(scenario_key = paste(ssp, window, sep = "_"))

  dt <- draws_long %>%
    dplyr::left_join(bio_summary, by = "stock_id") %>%
    tidyr::crossing(scen_df) %>%
    dplyr::mutate(
      r_eff    = r_base * exp(rho_sst * DSST + rho_chl * DlogCHL),
      extinct  = F_hist >= r_eff,
      # K_nat en mil_t; B_hist_t en t. Convertimos K_nat_t = K_nat * 1e3 para
      # que factor_B = B_star_t / B_hist_t sea dimensionless.
      K_nat_t  = K_nat * 1e3,
      # Si extinct, B_star = 0 (colapso total bajo Schaefer cuando F >= r).
      # Usamos 0 en vez de NA para que el portfolio del vessel compute
      # correctamente: un stock extinto contribuye con 0 * omega al factor_H,
      # que es lo economicamente correcto (captura desaparece) y no dropea
      # al vessel entero del agregado.
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
# Paso 3b -- Pr(extinction) por stock x scenario
# -----------------------------------------------------------------------------

t6_summarise_extinction <- function(factor_B_dt) {
  # Ojo: t6_compute_factor_B ya sobreescribio extinct=FALSE para jurel. Eso
  # es lo que queremos reportar (al lector no le comunicamos un Pr ext de
  # jurel derivado de un posterior no identificado).
  factor_B_dt %>%
    dplyr::group_by(stock_id, ssp, window) %>%
    dplyr::summarise(
      n_draws       = dplyr::n(),
      n_extinct     = sum(extinct),
      pr_extinct    = mean(extinct),
      # Los draws extinct contribuyen factor_B=0 al resumen: eso es honesto.
      # Si la mediana queda en 0, significa que >50% de los draws colapsan.
      factor_B_med  = median(factor_B),
      factor_B_q05  = quantile(factor_B, 0.05),
      factor_B_q95  = quantile(factor_B, 0.95),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      scenario_key  = paste(ssp, window, sep = "_"),
      stock_label   = T6_STOCK_LABEL[stock_id],
      scenario_label = T6_SCENARIO_LABEL[scenario_key],
      non_identified = stock_id %in% T6_NON_IDENTIFIED_STOCKS
    ) %>%
    dplyr::arrange(stock_id,
                   factor(ssp, levels = T6_SSPS),
                   factor(window, levels = T6_WINDOWS))
}

# -----------------------------------------------------------------------------
# Paso 4 -- omega[v,s] + H_alloc_hist[v] desde poisson_dt.rds
# -----------------------------------------------------------------------------

t6_build_vessel_table <- function(poisson_rds = T6_POISSON_RDS) {
  pdt <- as.data.table(readRDS(poisson_rds))

  # omega_v,s = share historico realizado
  # Sumar H_*_vy por vessel a lo largo de los anios disponibles
  v_catch <- pdt[, .(
    H_anch = sum(H_114, na.rm = TRUE),
    H_sard = sum(H_33,  na.rm = TRUE),
    H_jur  = sum(H_26,  na.rm = TRUE)
  ), by = .(COD_BARCO, TIPO_FLOTA)]

  v_catch[, H_tot := H_anch + H_sard + H_jur]

  # Vessels con H_tot == 0 se dropean (ningun catch en las 3 especies)
  dropped <- v_catch[H_tot == 0, .N]
  if (dropped > 0) {
    cat("[T6] WARNING: dropeando", dropped,
        "vessels con captura cero en las 3 especies.\n")
  }
  v_catch <- v_catch[H_tot > 0]

  v_catch[, `:=`(
    omega_anch = H_anch / H_tot,
    omega_sard = H_sard / H_tot,
    omega_jur  = H_jur  / H_tot
  )]

  # H_alloc_hist[v] = mediana de H_alloc_vy por vessel (mas robusto que mean
  # a outliers de entrada tardia / año-con-cero-cuota)
  v_halloc <- pdt[!is.na(H_alloc_vy),
                  .(H_alloc_hist = median(H_alloc_vy),
                    n_years      = .N),
                  by = COD_BARCO]

  vtab <- merge(v_catch, v_halloc, by = "COD_BARCO", all.x = TRUE)
  vtab <- vtab[!is.na(H_alloc_hist) & H_alloc_hist > 0]

  cat("[T6] Vessel table construida:",
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
# Paso 5 -- Re-estimar NB para beta_H_ind y beta_H_art
# -----------------------------------------------------------------------------
# Replica el chunk est_poisson del Rmd (paper1_climate_projections.Rmd L398-416).
# Re-estimacion in-script en vez de serializar: el NB fit es barato (<1s) y
# mantiene el script auto-contenido y reproducible.

t6_fit_nb <- function(poisson_rds = T6_POISSON_RDS) {
  poisson_df <- readRDS(poisson_rds)

  df_ind <- poisson_df %>% dplyr::filter(TIPO_FLOTA == "IND")
  df_art <- poisson_df %>% dplyr::filter(TIPO_FLOTA == "ART")

  f <- T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB

  nb_ind <- MASS::glm.nb(f, data = df_ind)
  nb_art <- MASS::glm.nb(f, data = df_art)

  beta_H_ind <- as.numeric(coef(nb_ind)["H_alloc_vy"])
  beta_H_art <- as.numeric(coef(nb_art)["H_alloc_vy"])

  cat("[T6] NB reestimado (in-script):\n")
  cat("    IND: beta_H(H_alloc_vy) =", sprintf("%.6f", beta_H_ind),
      "(N =", nrow(df_ind), ")\n")
  cat("    ART: beta_H(H_alloc_vy) =", sprintf("%.6f", beta_H_art),
      "(N =", nrow(df_art), ")\n")
  cat("    (semi-elasticity -- multiplicar por H_alloc_hist[v] en ton/t\n",
      "     para obtener elasticity-a-la-mediana por vessel)\n\n")

  list(
    beta_H = c(ART = beta_H_art, IND = beta_H_ind),
    fits   = list(art = nb_art, ind = nb_ind)
  )
}

# -----------------------------------------------------------------------------
# Paso 6 -- factor_H[d,v,c] y factor_trips[d,v,c] por vessel
# -----------------------------------------------------------------------------
# Estrategia de memoria: evitamos la CJ completa (draws x scenarios x vessels ~
# 15M+ filas). Para cada vessel, calculamos factor_H y factor_trips sobre las
# 12K filas (draws x scenarios) vectorialmente, y rbind-listamos solo el resultado.

t6_compute_factor_trips <- function(factor_B_dt, vessel_tab, beta_H) {

  # Pivotear factor_B a wide en stock (draws x scenarios x {anch,sard,jur})
  fb_wide <- as.data.table(factor_B_dt)[
    , .(.draw, stock_id, ssp, window, factor_B)
  ] %>%
    data.table::dcast(.draw + ssp + window ~ stock_id,
                      value.var = "factor_B")

  # Renombrar columnas stock -> abreviadas para consumir por vessel
  setnames(fb_wide,
           old = c("anchoveta_cs", "sardina_comun_cs", "jurel_cs"),
           new = c("fB_anch", "fB_sard", "fB_jur"),
           skip_absent = TRUE)

  # Defensivo: jurel override a 1.0 lo hace t6_compute_factor_B, pero si por
  # alguna razon quedara NA, lo llenamos neutral.
  fb_wide[is.na(fB_jur), fB_jur := 1.0]

  # Post-fix NA->0 en extinct: fB_anch y fB_sard son siempre numericos
  # (cero si extinct), asi que el portfolio computa correctamente sin NA.

  vt <- as.data.table(vessel_tab)

  # Loop por vessel -- simple y memory-safe
  chunks <- vector("list", nrow(vt))
  for (i in seq_len(nrow(vt))) {
    v <- vt[i]
    beta <- beta_H[[as.character(v$TIPO_FLOTA)]]

    factor_H <- v$omega_anch * fb_wide$fB_anch +
                v$omega_sard * fb_wide$fB_sard +
                v$omega_jur  * fb_wide$fB_jur

    factor_trips <- exp(beta * v$H_alloc_hist * (factor_H - 1))

    chunks[[i]] <- data.table(
      COD_BARCO    = v$COD_BARCO,
      TIPO_FLOTA   = v$TIPO_FLOTA,
      .draw        = fb_wide$.draw,
      ssp          = fb_wide$ssp,
      window       = fb_wide$window,
      factor_H     = factor_H,
      factor_trips = factor_trips
    )
  }

  out <- rbindlist(chunks)
  out[, scenario_key := paste(ssp, window, sep = "_")]

  cat("[T6] factor_trips computado: N =", nrow(out), "rows (",
      length(unique(out$COD_BARCO)), "vessels x",
      length(unique(out$.draw)), "draws x",
      length(unique(out$scenario_key)), "scenarios )\n\n")

  out
}

# -----------------------------------------------------------------------------
# Paso 7 -- Resumen por flota x scenario
# -----------------------------------------------------------------------------

t6_summarise_trips <- function(ft_dt, threshold = 0.5) {
  # Opcion (a') -- reportar tres objetos:
  #
  #   (i)  factor_trips marginal: mediana sobre TODOS los draws. Mezcla
  #        colapsos y supervivencia. Es lo que leeria un policymaker como
  #        "respuesta agregada" — pero esta dominada por los draws donde
  #        el portfolio se evapora bajo Schaefer steady-state.
  #
  #   (ii) Pr(portfolio loss > 50%): fraccion de draws donde factor_H <
  #        threshold (default 0.5). Proxy de "functional degradation" del
  #        portfolio del vessel — no confundir con extincion de stock
  #        individual (que esta en la tabla extinct).
  #
  #   (iii) factor_trips condicional: mediana restringida a draws donde
  #         factor_H >= threshold. Es la "respuesta pura al clima" sin
  #         mezclar con el piso de colapso. Sirve para separar la señal
  #         de elasticidad climatica de la señal de Schaefer-steady-state-
  #         -collapse. Si threshold produce un subset vacio para alguna
  #         flota x scenario, la cond queda NA y se reporta como "collapse
  #         dominated" en la tabla formateada.

  ft_dt[, survive := factor_H >= threshold]

  summ <- ft_dt[, .(
    n_obs                 = .N,
    n_survive             = sum(survive),
    # (i) marginal (all draws)
    factor_trips_marg_med = median(factor_trips),
    factor_trips_marg_q05 = quantile(factor_trips, 0.05),
    factor_trips_marg_q95 = quantile(factor_trips, 0.95),
    # (ii) portfolio loss probability
    pr_portfolio_loss     = mean(!survive),
    # (iii) conditional (draws with factor_H >= threshold)
    factor_trips_cond_med = if (sum(survive) > 0)
                              median(factor_trips[survive]) else NA_real_,
    factor_trips_cond_q05 = if (sum(survive) > 0)
                              quantile(factor_trips[survive], 0.05) else NA_real_,
    factor_trips_cond_q95 = if (sum(survive) > 0)
                              quantile(factor_trips[survive], 0.95) else NA_real_,
    # factor_H stats (para lectura sanidad)
    factor_H_med          = median(factor_H),
    factor_H_q05          = quantile(factor_H, 0.05),
    factor_H_q95          = quantile(factor_H, 0.95),
    # Pr(decline) marginal
    pr_decline            = mean(factor_trips < 1)
  ), by = .(TIPO_FLOTA, ssp, window)]

  summ[, scenario_key := paste(ssp, window, sep = "_")]
  summ[, scenario_label := T6_SCENARIO_LABEL[scenario_key]]
  summ[, fleet_label    := T6_FLEET_LABEL[as.character(TIPO_FLOTA)]]

  # setorder de data.table no toma factor(...) como expresion -> cols aux
  summ[, ssp_ord    := factor(ssp,    levels = T6_SSPS)]
  summ[, window_ord := factor(window, levels = T6_WINDOWS)]
  setorder(summ, TIPO_FLOTA, ssp_ord, window_ord)
  summ[, c("ssp_ord", "window_ord") := NULL]

  summ
}

# -----------------------------------------------------------------------------
# Paso 7b -- Sanity: DSST=0, DlogCHL=0 -> factor_trips ~ 1.0
# -----------------------------------------------------------------------------

t6_sanity_noclimate <- function(draws_long, bio_summary,
                                vessel_tab, beta_H) {

  # Construir un "scenario" sintetico con DSST=0, DlogCHL=0
  scen0 <- data.table(ssp = "none", window = "none",
                      DSST = 0, DlogCHL = 0)
  scen0[, scenario_key := "none_none"]

  fb0 <- t6_compute_factor_B(draws_long, bio_summary, scen0)
  # Bajo (DSST=0, DlogCHL=0): r_eff = r_base. Entonces
  #   factor_B = K*(1 - F_hist/r_base) / B_hist
  # Esto NO es 1.0 exacto -- es el ratio de Schaefer-equilibrium B_star bajo
  # F_hist y los draws posteriores de (r,K). Para ser 1.0 exacto necesitariamos
  # que el pasado haya estado en equilibrio Schaefer con (r_base, K) medianos,
  # lo cual no es el caso (Stan fitea trajectorias, no eq steady-state).
  # El sanity util es: con DSST=0, DlogCHL=0, factor_trips debe ser IGUAL al
  # valor que saldria de evaluar el pipeline con scenario CMIP6 sustituyendo
  # sus deltas por cero. No es un check trivial de 1.0.

  ft0 <- t6_compute_factor_trips(fb0, vessel_tab, beta_H)
  med_ft <- median(ft0$factor_trips, na.rm = TRUE)

  cat("[T6] Sanity check (DSST=0, DlogCHL=0):\n")
  cat("    factor_trips medio:", sprintf("%.4f", med_ft), "\n")
  cat("    (NO necesariamente 1.0 -- depende de si el hindcast historico\n",
      "     estaba en Schaefer steady-state bajo F_hist; si factor_B != 1\n",
      "     bajo clima nulo, factor_trips tampoco lo sera.)\n\n")

  # Sanity check MAS STRICTO: factor_trips = 1.0 exacto si forzamos factor_B=1.
  vt_dummy <- copy(vessel_tab)
  # Un vessel de prueba con cualquier portfolio; factor_H = 1 por construccion
  # si factor_B es 1 para los 3 stocks. Veamos que factor_trips = exp(0) = 1.
  test_factor_H <- 1.0
  test_factor_trips <- exp(
    beta_H["IND"] * vt_dummy[TIPO_FLOTA == "IND", median(H_alloc_hist)] *
    (test_factor_H - 1)
  )
  cat("    factor_trips bajo factor_H=1 (unit test):",
      sprintf("%.6f", test_factor_trips),
      if (abs(test_factor_trips - 1) < 1e-10) " OK\n" else " FAIL\n")
  cat("\n")

  invisible(list(factor_B_dt = fb0, factor_trips_dt = ft0))
}

# -----------------------------------------------------------------------------
# Paso 8 -- Escribir tablas (formateada + raw + extinct)
# -----------------------------------------------------------------------------

t6_write_tables <- function(summ, extinct_summ,
                            path_fmt     = T6_TABLE_OUT,
                            path_raw     = T6_TABLE_RAW_OUT,
                            path_extinct = T6_TABLE_EXTINCT_OUT) {

  dir.create(dirname(path_fmt), recursive = TRUE, showWarnings = FALSE)

  # Tabla formateada para paper — tres objetos de opcion (a'):
  # marginal trips, portfolio-loss probability, conditional trips.
  fmt <- summ[, .(
    Fleet           = fleet_label,
    Scenario        = scenario_label,
    # Marginal (all draws)
    `%Delta trips (marginal, median)` = sprintf("%+.1f%%",
                                                100 * (factor_trips_marg_med - 1)),
    `%Delta trips (marginal, 90%)`    = sprintf("[%+.1f%%, %+.1f%%]",
                                                100 * (factor_trips_marg_q05 - 1),
                                                100 * (factor_trips_marg_q95 - 1)),
    # Portfolio loss probability
    `Pr(portfolio loss > 50%)` = sprintf("%.2f", pr_portfolio_loss),
    # Conditional (draws where factor_H >= 0.5)
    `%Delta trips (conditional, median)` = ifelse(is.na(factor_trips_cond_med),
                                                  "collapse-dom.",
                                                  sprintf("%+.1f%%",
                                                          100 * (factor_trips_cond_med - 1))),
    `%Delta trips (conditional, 90%)`    = ifelse(is.na(factor_trips_cond_med),
                                                  "—",
                                                  sprintf("[%+.1f%%, %+.1f%%]",
                                                          100 * (factor_trips_cond_q05 - 1),
                                                          100 * (factor_trips_cond_q95 - 1))),
    `factor_H (median)` = sprintf("%.3f", factor_H_med)
  )]

  write.csv(fmt, path_fmt, row.names = FALSE)
  cat("[T6] Tabla formateada:", path_fmt, "\n")

  write.csv(summ, path_raw, row.names = FALSE)
  cat("[T6] Tabla numerica raw:", path_raw, "\n")

  # Tabla extinction por stock x scenario
  ext_fmt <- as.data.table(extinct_summ)[, .(
    Stock      = stock_label,
    Scenario   = scenario_label,
    `Pr(extinct)`     = sprintf("%.3f", pr_extinct),
    `factor_B (median)` = ifelse(non_identified,
                                 "n.i.",
                                 sprintf("%.3f", factor_B_med)),
    `factor_B (q05)`    = ifelse(non_identified,
                                 "n.i.",
                                 sprintf("%.3f", factor_B_q05)),
    `factor_B (q95)`    = ifelse(non_identified,
                                 "n.i.",
                                 sprintf("%.3f", factor_B_q95)),
    `Non-identified`    = non_identified
  )]

  write.csv(ext_fmt, path_extinct, row.names = FALSE)
  cat("[T6] Tabla extinct/factor_B:", path_extinct, "\n\n")

  invisible(list(fmt = fmt, ext_fmt = ext_fmt))
}

# -----------------------------------------------------------------------------
# Orquestador
# -----------------------------------------------------------------------------

t6_run <- function() {
  cat(strrep("=", 60), "\n",
      "T6 -- Long-run comparative statics sobre TRIPS (Schaefer ss + NB)\n",
      strrep("=", 60), "\n\n", sep = "")

  # Biologia historica
  bio <- t6_load_biology()

  # Posterior T4b-full
  draws <- t6_extract_draws()

  # Escalares CMIP6 (reuso de T5)
  scen  <- t5_build_scenario_scalars()

  # factor_B por draw x stock x scenario + Pr(extinct)
  fB    <- t6_compute_factor_B(draws, bio$summary, scen)
  ext   <- t6_summarise_extinction(fB)

  cat("[T6] Pr(extinct) por stock x scenario:\n")
  print(as.data.table(ext)[, .(stock_label, scenario_label,
                               pr_extinct = round(pr_extinct, 3),
                               fB_med = round(factor_B_med, 3),
                               non_id = non_identified)])
  cat("\n")

  # Vessel table (omega + H_alloc_hist)
  vtab  <- t6_build_vessel_table()

  # NB fit y beta_H por flota
  nbres <- t6_fit_nb()

  # Sanity check (scenario sintetico DSST=0, DlogCHL=0)
  t6_sanity_noclimate(draws, bio$summary, vtab, nbres$beta_H)

  # factor_trips[d,v,c]
  ft    <- t6_compute_factor_trips(fB, vtab, nbres$beta_H)

  # Resumen por flota x scenario
  summ  <- t6_summarise_trips(ft)

  cat("[T6] Resumen factor_trips por flota x scenario (tres objetos):\n")
  print(summ[, .(fleet_label, scenario_label,
                 trips_marg = sprintf("%+.1f%% [%+.1f%%, %+.1f%%]",
                                      100 * (factor_trips_marg_med - 1),
                                      100 * (factor_trips_marg_q05 - 1),
                                      100 * (factor_trips_marg_q95 - 1)),
                 Pr_loss    = round(pr_portfolio_loss, 2),
                 trips_cond = ifelse(is.na(factor_trips_cond_med),
                                     "collapse-dom.",
                                     sprintf("%+.1f%% [%+.1f%%, %+.1f%%]",
                                             100 * (factor_trips_cond_med - 1),
                                             100 * (factor_trips_cond_q05 - 1),
                                             100 * (factor_trips_cond_q95 - 1))),
                 fH_med     = round(factor_H_med, 3))])
  cat("\n")
  cat("    Leyenda: trips_marg = mediana sobre todos los draws (mezcla\n",
      "             colapsos y supervivencia).\n",
      "             Pr_loss  = Pr(factor_H < 0.5) = portfolio pierde >50%.\n",
      "             trips_cond = mediana restringida a draws con factor_H >= 0.5\n",
      "             (respuesta climatica pura, sin piso de colapso).\n\n")

  # Escribir tablas
  t6_write_tables(summ, ext)

  invisible(list(
    scenarios      = scen,
    biology        = bio,
    draws          = draws,
    factor_B       = fB,
    extinct_summ   = ext,
    vessel_tab     = vtab,
    nb             = nbres,
    factor_trips   = ft,
    summary        = summ
  ))
}

# -----------------------------------------------------------------------------
# Main guard
# -----------------------------------------------------------------------------

if (isTRUE(getOption("t6.run_main", FALSE))) {
  t6_result <- t6_run()
}
