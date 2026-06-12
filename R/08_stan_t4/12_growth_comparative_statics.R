# =============================================================================
# FONDECYT -- 12_growth_comparative_statics.R   (T5 ENSEMBLE 6 modelos)
#
# Comparative statics de la tasa de crecimiento efectiva r_eff[s] bajo los
# deltas climaticos CMIP6 -- ahora sobre el ENSEMBLE de 6 modelos (rewrite
# 2026-04-29 PM, ver project_cmip6_ensemble_deltas_executed.md). Reusa los
# draws posteriores de T4b-full sin refittear; el cambio es la integracion
# cross-model. Evalua:
#
#     r_eff[s, m] = r_base[s] * exp( rho_sst[s] * DSST_m + rho_chl[s] * DlogCHL_m )
#
# por draw posterior y por modelo CMIP6 m. Entrega:
#   - mediana cross-model + IQR cross-model (spread inter-modelo)
#   - posterior 90% CI dentro de un modelo tipico (within-model uncertainty)
#
# Las dos fuentes de incertidumbre se separan adrede: la primera es model
# uncertainty (epistemica, el ensemble representa lo que sabemos del clima),
# la segunda es la posterior dada un modelo (signal en T4b dado un forcing
# fijo). El Apendice F (Bloque 4 pendiente) hace la decomp formal de varianza.
#
# Entradas:
#   - data/outputs/t4b/t4b_full_fit.rds        (cmdstanr CmdStanMCMC)
#   - data/cmip6/deltas_ensemble.csv           (ensemble 6 modelos, long format)
#
# Salidas:
#   - tables/growth_comparative_statics.csv          (formato paper, n.i. para jurel)
#   - tables/growth_comparative_statics_raw.csv      (numerico, sin n.i.)
#   - tables/growth_comparative_statics_by_model.csv (modelo-nivel, debug + appendix)
#   - figs/t4b/growth_ridgeline_cmip6.png            (ridge por modelo, facet stock x ssp)
#
# Corre con:
#   options(t5.run_main = TRUE)
#   source("R/08_stan_t4/12_growth_comparative_statics.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(data.table)
  library(ggplot2)
  library(posterior)
  library(cmdstanr)
})

.HAS_GGRIDGES <- requireNamespace("ggridges", quietly = TRUE)

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
# Utilidades compartidas entre T5/T7/Apendice F. Define las constantes
# COMPSTAT_* y la funcion compstat_load_scenarios. Aliases T5_* abajo.
source_utf8("R/08_stan_t4/_compstat_utils.R")

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------

T5_FIT_RDS         <- "data/outputs/t4b/t4b_full_fit.rds"
T5_DELTAS_CSV      <- COMPSTAT_DELTAS_CSV
T5_TABLE_OUT       <- "tables/growth_comparative_statics.csv"
T5_TABLE_BYMODEL   <- "tables/growth_comparative_statics_by_model.csv"
T5_FIG_OUT         <- "figs/t4b/growth_ridgeline_cmip6.png"

# Aliases hacia los compstat shared (refactor 2026-04-29 PM, ver _compstat_utils.R)
T5_STOCKS                <- COMPSTAT_STOCKS
T5_STOCK_LABEL           <- COMPSTAT_STOCK_LABEL
T5_SSPS                  <- COMPSTAT_SSPS
T5_WINDOWS               <- COMPSTAT_WINDOWS
T5_SCENARIO_LABEL        <- COMPSTAT_SCENARIO_LABEL
T5_NON_IDENTIFIED_STOCKS <- COMPSTAT_NON_IDENTIFIED_STOCKS

# -----------------------------------------------------------------------------
# Paso 1 -- Cargar deltas del ensemble (per-model) -- alias a compstat_load_scenarios
# -----------------------------------------------------------------------------
t5_load_scenarios <- function(deltas_csv = T5_DELTAS_CSV) {
  compstat_load_scenarios(deltas_csv)
}

# -----------------------------------------------------------------------------
# Paso 2 -- Extraer draws posteriores de r_base, rho_sst, rho_chl (sin cambios)
# -----------------------------------------------------------------------------

t5_extract_draws <- function(fit_rds = T5_FIT_RDS,
                             stocks  = T5_STOCKS) {
  fit <- readRDS(fit_rds)
  vars <- c(sprintf("r_base[%d]", seq_along(stocks)),
            sprintf("rho_sst[%d]", seq_along(stocks)),
            sprintf("rho_chl[%d]", seq_along(stocks)))
  dr <- fit$draws(vars, format = "draws_df") %>% as_tibble()

  long_list <- lapply(seq_along(stocks), function(s) {
    tibble(
      .draw    = dr$.draw,
      stock_id = stocks[s],
      r_base   = dr[[sprintf("r_base[%d]", s)]],
      rho_sst  = dr[[sprintf("rho_sst[%d]", s)]],
      rho_chl  = dr[[sprintf("rho_chl[%d]", s)]]
    )
  })
  draws_long <- bind_rows(long_list)

  cat("[T5] Draws extraidos: N_total =", nrow(draws_long),
      "(", length(unique(draws_long$.draw)), "draws x",
      length(stocks), "stocks )\n\n")

  draws_long
}

# -----------------------------------------------------------------------------
# Paso 3 -- Cross-join (draws x scenarios) y computar r_eff por modelo
# -----------------------------------------------------------------------------
# Output: ~ N_draws x N_scenario_combos x 3 stocks filas. Ej: 8000 draws x 22
# combos (24 - 2 huecos CESM2/chlos/ssp245) x 3 = ~528K filas.

t5_compute_r_eff <- function(draws_long, scen_df) {
  draws_long %>%
    tidyr::crossing(scen_df) %>%
    mutate(
      r_eff      = r_base * exp(rho_sst * DSST + rho_chl * DlogCHL),
      pct_change = exp(rho_sst * DSST + rho_chl * DlogCHL) - 1
    )
}

# -----------------------------------------------------------------------------
# Paso 4a -- Resumen WITHIN-MODEL (mediana + 90% CI posterior dentro de m)
# -----------------------------------------------------------------------------

t5_summarise_within <- function(draws_scen) {
  draws_scen %>%
    group_by(stock_id, model, scenario, window) %>%
    summarise(
      DSST          = first(DSST),
      DlogCHL       = first(DlogCHL),
      r_eff_med     = median(r_eff),
      pct_med       = median(pct_change),
      pct_q05       = quantile(pct_change, 0.05),
      pct_q95       = quantile(pct_change, 0.95),
      prob_decline  = mean(pct_change < 0),
      .groups       = "drop"
    ) %>%
    mutate(scenario_key = paste(scenario, window, sep = "_"))
}

# -----------------------------------------------------------------------------
# Paso 4b -- Resumen CROSS-MODEL (mediana de medianas + IQR cross-model + CI within tipico)
# -----------------------------------------------------------------------------
# Convencion:
#   pct_cross_med = median across m del pct_med dentro de cada m
#   pct_cross_q25 = q25 across m del pct_med (IQR cross-model bajo)
#   pct_cross_q75 = q75 across m del pct_med (IQR cross-model alto)
#   pct_within_q05 = median across m del pct_q05 within m (posterior tipico bajo)
#   pct_within_q95 = median across m del pct_q95 within m (posterior tipico alto)
#   prob_decline_cross = median across m del prob_decline within m

t5_summarise_cross <- function(within_summ) {
  within_summ %>%
    group_by(stock_id, scenario, window) %>%
    summarise(
      n_models           = n(),
      DSST_cross_med     = median(DSST),
      DSST_cross_q25     = quantile(DSST, 0.25),
      DSST_cross_q75     = quantile(DSST, 0.75),
      DlogCHL_cross_med  = median(DlogCHL),
      DlogCHL_cross_q25  = quantile(DlogCHL, 0.25),
      DlogCHL_cross_q75  = quantile(DlogCHL, 0.75),
      r_eff_cross_med    = median(r_eff_med),
      pct_cross_med      = median(pct_med),
      pct_cross_q25      = quantile(pct_med, 0.25),
      pct_cross_q75      = quantile(pct_med, 0.75),
      pct_within_q05     = median(pct_q05),
      pct_within_q95     = median(pct_q95),
      prob_decline_cross = median(prob_decline),
      .groups = "drop"
    ) %>%
    mutate(
      stock_label    = T5_STOCK_LABEL[stock_id],
      scenario_key   = paste(scenario, window, sep = "_"),
      scenario_label = T5_SCENARIO_LABEL[scenario_key]
    ) %>%
    arrange(factor(stock_id, levels = T5_STOCKS),
            factor(scenario, levels = T5_SSPS),
            factor(window,   levels = T5_WINDOWS))
}

# -----------------------------------------------------------------------------
# Paso 4c -- Sanity check: shock hipotetico +1 C sin cambio en CHL
# -----------------------------------------------------------------------------

t5_sanity_plus1c <- function(draws_long) {
  check <- draws_long %>%
    mutate(pct_change_plus1C = exp(rho_sst * 1 + rho_chl * 0) - 1) %>%
    group_by(stock_id) %>%
    summarise(
      pct_median = median(pct_change_plus1C),
      pct_q05    = quantile(pct_change_plus1C, 0.05),
      pct_q95    = quantile(pct_change_plus1C, 0.95),
      .groups    = "drop"
    )

  cat("[T5] Sanity -- shock +1 C SST (CHL constante)\n")
  cat("    (debe dar ~ -65% anch, -94% sard segun paper1)\n")
  print(check %>%
          mutate(across(c(pct_median, pct_q05, pct_q95),
                        ~ sprintf("%+.1f%%", 100 * .x))))
  cat("\n")
  invisible(check)
}

# -----------------------------------------------------------------------------
# Paso 5 -- Tablas (cross-model formateada + raw + by-model)
# -----------------------------------------------------------------------------

t5_write_table <- function(cross_summ, within_summ,
                           path_main = T5_TABLE_OUT,
                           path_bymodel = T5_TABLE_BYMODEL) {

  dir.create(dirname(path_main), recursive = TRUE, showWarnings = FALSE)

  ni <- cross_summ$stock_id %in% T5_NON_IDENTIFIED_STOCKS

  fmt_pct <- function(x) ifelse(is.na(x), "n.i.", sprintf("%+.1f%%", 100 * x))
  fmt_band <- function(lo, hi) ifelse(is.na(lo) | is.na(hi),
                                       "n.i.",
                                       sprintf("[%+.1f%%, %+.1f%%]",
                                               100 * lo, 100 * hi))

  # Para stocks no identificados reemplazamos pct y r_eff por "n.i.";
  # DSST y DlogCHL son inputs exogenos y se conservan.
  out <- cross_summ %>%
    transmute(
      Stock              = stock_label,
      Scenario           = scenario_label,
      n_models           = n_models,
      `DSST (C)`         = sprintf("%+.2f", DSST_cross_med),
      `DlogCHL`          = sprintf("%+.3f", DlogCHL_cross_med),
      `r_eff (cross median)`     = ifelse(ni, "n.i.",
                                          sprintf("%.3f", r_eff_cross_med)),
      `%Delta cross median`      = ifelse(ni, "n.i.", fmt_pct(pct_cross_med)),
      `%Delta cross IQR`         = ifelse(ni, "n.i.",
                                          fmt_band(pct_cross_q25, pct_cross_q75)),
      `%Delta within posterior CI` = ifelse(ni, "n.i.",
                                            fmt_band(pct_within_q05, pct_within_q95)),
      `Pr(Delta<0) cross median` = ifelse(ni, "n.i.",
                                          sprintf("%.2f", prob_decline_cross))
    )

  if (any(ni)) {
    cat("[T5] Stocks reportados como n.i.: ",
        paste(unique(cross_summ$stock_label[ni]), collapse = ", "),
        " (ver _raw.csv y _by_model.csv)\n")
  }

  write.csv(out, path_main, row.names = FALSE)
  cat("[T5] Tabla principal:", path_main, "\n")

  # Raw numerico cross-model
  num_path <- sub("\\.csv$", "_raw.csv", path_main)
  write.csv(cross_summ, num_path, row.names = FALSE)
  cat("[T5] Tabla cross-model raw:", num_path, "\n")

  # By-model (long): cada (stock, model, ssp, window) en una fila
  by_model_out <- within_summ %>%
    transmute(
      stock_id, model, scenario, window,
      DSST  = round(DSST, 3),
      DlogCHL = round(DlogCHL, 4),
      r_eff_med = round(r_eff_med, 4),
      pct_med   = round(pct_med, 4),
      pct_q05   = round(pct_q05, 4),
      pct_q95   = round(pct_q95, 4),
      prob_decline = round(prob_decline, 3)
    )
  write.csv(by_model_out, path_bymodel, row.names = FALSE)
  cat("[T5] Tabla by-model:", path_bymodel, "\n\n")

  invisible(out)
}

# -----------------------------------------------------------------------------
# Paso 6 -- Ridgeline: 1 ridge por modelo, facet stock x scenario
# -----------------------------------------------------------------------------

t5_plot_ridgeline <- function(draws_scen, path = T5_FIG_OUT) {

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  plot_df <- draws_scen %>%
    filter(!stock_id %in% T5_NON_IDENTIFIED_STOCKS) %>%
    mutate(
      stock_label    = factor(T5_STOCK_LABEL[stock_id],
                              levels = unname(T5_STOCK_LABEL[
                                setdiff(names(T5_STOCK_LABEL),
                                        T5_NON_IDENTIFIED_STOCKS)])),
      scenario_label = factor(T5_SCENARIO_LABEL[scenario_key],
                              levels = unname(T5_SCENARIO_LABEL))
    ) %>%
    mutate(pct_clip = pmin(pmax(pct_change, -1), 3))

  excluded <- setdiff(unique(draws_scen$stock_id), unique(plot_df$stock_id))
  has_cesm2_gap <- "CESM2" %in% plot_df$model &&
                   !any(plot_df$model == "CESM2" & plot_df$scenario == "ssp245")
  subtitle_lines <- c(
    sprintf("CMIP6 ensemble (%d models); one ridge per model.",
            length(unique(plot_df$model))),
    if (length(excluded) > 0)
      sprintf("Non-identified stocks excluded (%s).",
              paste(T5_STOCK_LABEL[excluded], collapse = ", "))
    else NULL,
    if (has_cesm2_gap)
      "CESM2 absent from SSP2-4.5 panels: chl ssp245 not published in NCAR CMIP6 catalog."
    else NULL
  )
  subtitle_note <- paste(subtitle_lines, collapse = "\n")

  x_breaks <- c(-1, -0.75, -0.5, -0.25, 0, 0.25, 0.5)

  if (.HAS_GGRIDGES) {
    p <- ggplot(plot_df,
                ggplot2::aes(x = pct_clip, y = model, fill = model)) +
      ggridges::geom_density_ridges(alpha = 0.6, scale = 1.0,
                                    rel_min_height = 0.01,
                                    color = "white", linewidth = 0.2) +
      facet_grid(stock_label ~ scenario_label, scales = "free_y") +
      scale_x_continuous(labels = scales::percent_format(accuracy = 1),
                         breaks = x_breaks) +
      coord_cartesian(xlim = c(-1, 0.5)) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "grey30") +
      scale_fill_brewer(palette = "Set2", guide = "none") +
      labs(x = "% change in r_eff vs historical baseline (2000-2024)",
           y = NULL,
           title = "Growth comparative statics under CMIP6 ensemble",
           subtitle = subtitle_note) +
      theme_minimal(base_size = 10) +
      theme(strip.text = element_text(face = "bold", size = 9),
            plot.title = element_text(face = "bold"),
            plot.subtitle = element_text(size = 8.5, color = "grey25"),
            axis.text.y = element_text(size = 9),
            axis.text.x = element_text(size = 8))
  } else {
    message("[T5] ggridges not available -- falling back to violin")
    p <- ggplot(plot_df,
                ggplot2::aes(x = model, y = pct_clip, fill = model)) +
      geom_violin(alpha = 0.6, color = "white", scale = "width") +
      facet_grid(stock_label ~ scenario_label, scales = "free_y") +
      scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                         breaks = x_breaks) +
      coord_flip(ylim = c(-1, 0.5)) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "grey30") +
      scale_fill_brewer(palette = "Set2", guide = "none") +
      labs(y = "% change in r_eff vs historical baseline (2000-2024)",
           x = NULL,
           title = "Growth comparative statics under CMIP6 ensemble",
           subtitle = subtitle_note) +
      theme_minimal(base_size = 10)
  }

  ggsave(path, p, width = 11, height = 7, dpi = 150)
  cat("[T5] Figura guardada:", path, "\n\n")

  invisible(p)
}

# -----------------------------------------------------------------------------
# Orquestador
# -----------------------------------------------------------------------------

t5_run <- function() {
  cat(strrep("=", 70), "\n",
      "T5 ENSEMBLE -- Comparative statics bajo CMIP6 6-modelo ensemble\n",
      strrep("=", 70), "\n\n", sep = "")

  scen   <- t5_load_scenarios()
  draws  <- t5_extract_draws()

  t5_sanity_plus1c(draws)

  ds_raw <- t5_compute_r_eff(draws, scen)
  within <- t5_summarise_within(ds_raw)
  cross  <- t5_summarise_cross(within)

  cat("[T5] Resumen cross-model (mediana cross-model + IQR + CI within):\n")
  print(cross %>%
          transmute(stock_label, scenario_label, n_models,
                    DSST    = round(DSST_cross_med, 2),
                    DlogCHL = round(DlogCHL_cross_med, 3),
                    pct_med = sprintf("%+.1f%%", 100 * pct_cross_med),
                    cross_IQR = sprintf("[%+.1f%%, %+.1f%%]",
                                        100 * pct_cross_q25,
                                        100 * pct_cross_q75),
                    within_CI = sprintf("[%+.1f%%, %+.1f%%]",
                                        100 * pct_within_q05,
                                        100 * pct_within_q95),
                    Pr_dec  = round(prob_decline_cross, 2)))
  cat("\n")

  t5_write_table(cross, within)
  t5_plot_ridgeline(ds_raw)

  invisible(list(scenarios = scen,
                 cross     = cross,
                 within    = within,
                 draws_scen = ds_raw))
}

# -----------------------------------------------------------------------------
# Main guard (default-TRUE para source(), legacy option soportada)
# -----------------------------------------------------------------------------

if (isTRUE(getOption("t5.run_main", TRUE))) {
  t5_result <- t5_run()
}
