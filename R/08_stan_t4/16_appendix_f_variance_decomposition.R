# =============================================================================
# FONDECYT -- 16_appendix_f_variance_decomposition.R   (Apendice F)
#
# Decomposicion de la varianza de %Delta r_eff entre incertidumbre POSTERIOR
# (within-model, dada un forcing fijo) e incertidumbre CLIMATICA (cross-model,
# spread inter-modelo del ensemble CMIP6 sobre forcing).
#
# Ley de varianza total (decomposicion estandar):
#
#     Var_total( pct_change ) = E_m[ Var_d( pct_change | m ) ]
#                             + Var_m[ E_d( pct_change | m ) ]
#                             |--------- within ---------|
#                                                          |---- between ----|
#
# donde m indexa modelos CMIP6 y d indexa draws posteriores de T4b. La razon
# within/total dice cuanto del ruido viene de la posterior del shifter; la
# razon between/total dice cuanto viene del disagreement climatico.
#
# Reusa funciones de 12_growth_comparative_statics.R (cargado por source).
#
# Entradas:
#   - data/outputs/t4b/t4b_full_fit.rds
#   - data/cmip6/deltas_ensemble.csv
#
# Salidas:
#   - tables/appendix_f_variance_decomposition.csv
#   - figs/t4b/appendix_f_variance_decomposition.png
#
# Corre con:
#   options(t5.run_main = FALSE, appf.run_main = TRUE)
#   source("R/08_stan_t4/16_appendix_f_variance_decomposition.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

# Reusar t5_load_scenarios, t5_extract_draws, t5_compute_r_eff sin correr main.
# Restauramos t5.run_main al valor previo (default TRUE) para no contaminar la
# sesion: si despues el usuario hace source(.../12_growth_comparative_statics.R),
# el main debe correr.
.appf_t5_save <- getOption("t5.run_main", TRUE)
options(t5.run_main = FALSE)
source("R/08_stan_t4/12_growth_comparative_statics.R")
options(t5.run_main = .appf_t5_save)
rm(.appf_t5_save)

APPF_TABLE_OUT <- "tables/appendix_f_variance_decomposition.csv"
APPF_FIG_OUT   <- "figs/t4b/appendix_f_variance_decomposition.png"

# -----------------------------------------------------------------------------
# Decomposicion de la varianza por (stock, scenario, window)
# -----------------------------------------------------------------------------
# Usa draws_scen (ya con r_eff y pct_change calculados por t5_compute_r_eff).
# Filtra jurel (n.i.) -- la varianza posterior de jurel es prior-dominada y la
# decomposicion no tiene interpretacion estructural.

appf_decompose <- function(draws_scen,
                           drop_stocks = T5_NON_IDENTIFIED_STOCKS) {

  ds <- draws_scen %>% filter(!stock_id %in% drop_stocks)

  # Paso 1 -- por (stock, scenario, window, model): mean + var del pct_change
  by_model <- ds %>%
    group_by(stock_id, scenario, window, model) %>%
    summarise(
      e_d_given_m   = mean(pct_change),
      var_d_given_m = var(pct_change),
      n_draws       = dplyr::n(),
      .groups       = "drop"
    )

  # Paso 2 -- por (stock, scenario, window): aplicar la ley de varianza total
  decomp <- by_model %>%
    group_by(stock_id, scenario, window) %>%
    summarise(
      n_models             = dplyr::n(),
      mean_pct_change      = mean(e_d_given_m),
      var_within_avg       = mean(var_d_given_m),       # E_m[Var_d|m]
      var_between          = var(e_d_given_m),          # Var_m[E_d|m]
      .groups              = "drop"
    ) %>%
    mutate(
      var_total            = var_within_avg + var_between,
      pct_within           = var_within_avg / var_total,
      pct_between          = var_between    / var_total,
      sd_within            = sqrt(var_within_avg),
      sd_between           = sqrt(var_between),
      sd_total             = sqrt(var_total),
      stock_label          = T5_STOCK_LABEL[stock_id],
      scenario_key         = paste(scenario, window, sep = "_"),
      scenario_label       = T5_SCENARIO_LABEL[scenario_key]
    ) %>%
    arrange(factor(stock_id, levels = T5_STOCKS),
            factor(scenario, levels = T5_SSPS),
            factor(window,   levels = T5_WINDOWS))

  list(decomp = decomp, by_model = by_model)
}

# -----------------------------------------------------------------------------
# Tabla del Apendice F
# -----------------------------------------------------------------------------

appf_write_table <- function(decomp, path = APPF_TABLE_OUT) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  out <- decomp %>%
    transmute(
      Stock                          = stock_label,
      Scenario                       = scenario_label,
      n_models                       = n_models,
      `Mean %change`                 = sprintf("%+.1f%%", 100 * mean_pct_change),
      `SD total`                     = sprintf("%.3f", sd_total),
      `SD within (posterior)`        = sprintf("%.3f", sd_within),
      `SD between (cross-model)`     = sprintf("%.3f", sd_between),
      `% var within (posterior)`     = sprintf("%.0f%%", 100 * pct_within),
      `% var between (cross-model)`  = sprintf("%.0f%%", 100 * pct_between)
    )

  write.csv(out, path, row.names = FALSE)
  cat("[App F] Tabla:", path, "\n")

  num_path <- sub("\\.csv$", "_raw.csv", path)
  write.csv(decomp, num_path, row.names = FALSE)
  cat("[App F] Tabla numerica:", num_path, "\n\n")

  invisible(out)
}

# -----------------------------------------------------------------------------
# Figura: stacked bars con la descomposicion %within vs %between
# -----------------------------------------------------------------------------

appf_plot <- function(decomp, path = APPF_FIG_OUT) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  long <- decomp %>%
    select(stock_label, scenario_label, pct_within, pct_between) %>%
    pivot_longer(c(pct_within, pct_between),
                 names_to = "component", values_to = "share") %>%
    mutate(component = factor(component,
                              levels = c("pct_within", "pct_between"),
                              labels = c("Within-model (posterior)",
                                         "Between-model (CMIP6 spread)")))

  p <- ggplot(long,
              aes(x = scenario_label, y = share, fill = component)) +
    geom_col(position = "stack", width = 0.7, color = "white", linewidth = 0.3) +
    facet_wrap(~ stock_label, ncol = 1) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                       breaks = seq(0, 1, 0.25)) +
    scale_fill_manual(values = c("Within-model (posterior)"      = "#5b9bd5",
                                 "Between-model (CMIP6 spread)" = "#ed7d31"),
                      name = NULL) +
    labs(x = NULL,
         y = "Share of total variance",
         title = "Variance decomposition of growth comparative statics",
         subtitle = paste0("Total variance of % change in r_eff partitioned ",
                           "into posterior (within-model) and climate ",
                           "(cross-model) sources.")) +
    theme_minimal(base_size = 11) +
    theme(strip.text       = element_text(face = "bold"),
          plot.title       = element_text(face = "bold"),
          plot.subtitle    = element_text(size = 9, color = "grey25"),
          legend.position  = "top",
          axis.text.x      = element_text(size = 9))

  ggsave(path, p, width = 9, height = 6.5, dpi = 150)
  cat("[App F] Figura guardada:", path, "\n\n")
  invisible(p)
}

# -----------------------------------------------------------------------------
# Orquestador
# -----------------------------------------------------------------------------

appf_run <- function() {
  cat(strrep("=", 70), "\n",
      "Appendix F -- Variance decomposition of growth compstat\n",
      strrep("=", 70), "\n\n", sep = "")

  scen   <- t5_load_scenarios()
  draws  <- t5_extract_draws()
  ds_raw <- t5_compute_r_eff(draws, scen)

  res <- appf_decompose(ds_raw)

  cat("[App F] Decomposicion:\n")
  print(res$decomp %>%
          transmute(stock_label, scenario_label,
                    n_models,
                    mean_pct = sprintf("%+.1f%%", 100 * mean_pct_change),
                    sd_total = round(sd_total, 3),
                    pct_within  = sprintf("%.0f%%", 100 * pct_within),
                    pct_between = sprintf("%.0f%%", 100 * pct_between)))
  cat("\n")

  appf_write_table(res$decomp)
  appf_plot(res$decomp)

  invisible(res)
}

# -----------------------------------------------------------------------------
# Main guard
# -----------------------------------------------------------------------------

if (isTRUE(getOption("appf.run_main", TRUE))) {
  appf_result <- appf_run()
}
