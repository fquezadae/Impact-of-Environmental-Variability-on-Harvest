# =============================================================================
# FONDECYT -- 17_appendix_g_trips_variance_decomposition.R   (Apendice G)
#
# Decomposicion de la varianza de %Delta trips entre incertidumbre WITHIN-MODEL
# (posterior + vessel heterogeneity within fleet, pooled) y CROSS-MODEL
# (CMIP6 ensemble spread). Es el companion de Apendice F (que descompone
# %Delta r_eff a nivel stock); mientras F descompone variabilidad estructural
# de la elasticidad climatica al nivel del recurso, G descompone la
# variabilidad de la respuesta economica agregada al nivel de flota.
#
# Ley de varianza total (analoga a F.eq):
#
#   Var_total( pct_trips ) = E_m[ Var_{d,v}( pct_trips | m, fleet ) ]
#                          + Var_m[ E_{d,v}( pct_trips | m, fleet ) ]
#                          |--------- within ---------|
#                                                       |---- between ----|
#
# donde m indexa modelos CMIP6, d posterior draws T4b, y v vessels within fleet.
# El "within-model" pool de G agrega DOS sources que F mantiene separadas en
# el (stock, m, d): posterior uncertainty + heterogeneity inter-vessel within
# fleet (composition omega y H_alloc_hist son vessel-specific). Mantenemos el
# pool por dos razones: (1) paralelismo estructural con F, (2) la
# heterogeneity inter-vessel es una source identificada (no estructural) que
# no se reduce con mas data climatica ni con mas modelos. Una decomposicion
# 3-way (model / vessel / posterior) es directa con el mismo factor_trips_dt
# y queda anotada en el codigo para reviewer 3-way si lo pide.
#
# Lectura para paper:
#   - Si %within domina cross-fleet (caso plateau) -> climate ensemble
#     contribuye poco margin a la incertidumbre total una vez que el regimen
#     de collapse se satura. Floor-effect-like analogo a sard SSP585 end del F.
#   - Si %between domina (escenarios moderados, regimen no saturado) -> climate
#     ensemble es informativo en la transicion, posterior y vessel heterogeneity
#     son secundarias.
#
# Reusa funciones de 13_trip_comparative_statics.R (cargado por source con
# t6.run_main=FALSE para no gatillar el main; luego llamamos t6_run() inline
# para construir el factor_trips_dt completo).
#
# Entradas:
#   - data/outputs/t4b/t4b_full_fit.rds
#   - data/cmip6/deltas_ensemble.csv
#   - data/bio_params/catch_annual_cs_2000_2024.csv
#   - data/bio_params/official_biomass_series.csv
#   - data/bio_params/acoustic_biomass_series.csv
#   - data/trips/poisson_dt.rds
#
# Salidas:
#   - tables/appendix_g_trips_variance_decomposition.csv
#   - tables/appendix_g_trips_variance_decomposition_raw.csv
#   - figs/t4b/appendix_g_trips_variance_decomposition.png
#
# Corre con:
#   options(t6.run_main = FALSE, appg.run_main = TRUE)
#   source("R/08_stan_t4/17_appendix_g_trips_variance_decomposition.R")
#
# Si querés saltarte el t6_run() largo (51s) y solo cargar funciones (test):
#   options(appg.run_main = FALSE)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(data.table)
  library(ggplot2)
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

# Reusar t6_run() y constantes T6_*. El main guard de 13 es default-FALSE, asi
# que sourcear NO gatilla nada por accidente; pero forzamos FALSE para ser
# explicitos. Restauramos al valor previo despues por hygiene.
.appg_t6_save <- getOption("t6.run_main", FALSE)
options(t6.run_main = FALSE)
source_utf8("R/08_stan_t4/13_trip_comparative_statics.R")
options(t6.run_main = .appg_t6_save)
rm(.appg_t6_save)

APPG_TABLE_OUT <- "tables/appendix_g_trips_variance_decomposition.csv"
APPG_FIG_OUT   <- "figs/t4b/appendix_g_trips_variance_decomposition.png"

# -----------------------------------------------------------------------------
# Decomposicion 2-way (within-model pool / between-model)
# -----------------------------------------------------------------------------
# factor_trips_dt es ~292M filas (830 vessels x 22 model-scen x 16K draws).
# data.table aggregation por (TIPO_FLOTA, model, scenario, window) en 48 grupos.
# Costo: ~3-5s.

appg_decompose <- function(ft_dt) {

  ft <- as.data.table(ft_dt)
  ft[, pct_change := factor_trips - 1]

  # Paso 1 -- by_model: E_(d,v) y Var_(d,v) within (fleet, model, ssp, window)
  # El pool (d,v) es la "within-model variance" de la decomp 2-way.
  by_model <- ft[, .(
    e_dv_given_m   = mean(pct_change),
    var_dv_given_m = var(pct_change),
    n_obs          = .N
  ), by = .(TIPO_FLOTA, model, scenario, window)]

  # Paso 2 -- cross-model: ley de varianza total
  decomp <- by_model[, .(
    n_models        = .N,
    mean_pct_change = mean(e_dv_given_m),
    var_within_avg  = mean(var_dv_given_m),   # E_m[Var_(d,v)|m]
    var_between     = var(e_dv_given_m)        # Var_m[E_(d,v)|m]
  ), by = .(TIPO_FLOTA, scenario, window)]

  decomp[, var_total      := var_within_avg + var_between]
  decomp[, pct_within     := var_within_avg / var_total]
  decomp[, pct_between    := var_between    / var_total]
  decomp[, sd_within      := sqrt(var_within_avg)]
  decomp[, sd_between     := sqrt(var_between)]
  decomp[, sd_total       := sqrt(var_total)]
  decomp[, fleet_label    := T6_FLEET_LABEL[as.character(TIPO_FLOTA)]]
  decomp[, scenario_key   := paste(scenario, window, sep = "_")]
  decomp[, scenario_label := T6_SCENARIO_LABEL[scenario_key]]

  decomp[, ssp_ord    := factor(scenario, levels = T6_SSPS)]
  decomp[, window_ord := factor(window,   levels = T6_WINDOWS)]
  setorder(decomp, TIPO_FLOTA, ssp_ord, window_ord)
  decomp[, c("ssp_ord", "window_ord") := NULL]

  list(decomp = decomp, by_model = by_model)
}

# -----------------------------------------------------------------------------
# Tabla del Apendice G (formato paralelo a F)
# -----------------------------------------------------------------------------

appg_write_table <- function(decomp, path = APPG_TABLE_OUT) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  out <- as.data.table(decomp)[, .(
    Fleet                          = fleet_label,
    Scenario                       = scenario_label,
    n_models                       = n_models,
    `Mean %change`                 = sprintf("%+.1f%%", 100 * mean_pct_change),
    `SD total`                     = sprintf("%.4f", sd_total),
    `SD within (pool)`             = sprintf("%.4f", sd_within),
    `SD between (cross-model)`     = sprintf("%.4f", sd_between),
    `% var within (pool)`          = sprintf("%.0f%%", 100 * pct_within),
    `% var between (cross-model)`  = sprintf("%.0f%%", 100 * pct_between)
  )]

  write.csv(out, path, row.names = FALSE)
  cat("[App G] Tabla:", path, "\n")

  num_path <- sub("\\.csv$", "_raw.csv", path)
  write.csv(decomp, num_path, row.names = FALSE)
  cat("[App G] Tabla numerica:", num_path, "\n\n")

  invisible(out)
}

# -----------------------------------------------------------------------------
# Figura: stacked bars con la descomposicion %within vs %between por flota
# -----------------------------------------------------------------------------

appg_plot <- function(decomp, path = APPG_FIG_OUT) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  long <- as.data.frame(decomp) %>%
    dplyr::select(fleet_label, scenario_label, pct_within, pct_between) %>%
    tidyr::pivot_longer(c(pct_within, pct_between),
                        names_to = "component", values_to = "share") %>%
    dplyr::mutate(component = factor(component,
                                     levels = c("pct_within", "pct_between"),
                                     labels = c("Within-model (posterior + vessel heterogeneity)",
                                                "Between-model (CMIP6 spread)")),
                  scenario_label = factor(scenario_label,
                                          levels = unname(T6_SCENARIO_LABEL)))

  p <- ggplot(long,
              aes(x = scenario_label, y = share, fill = component)) +
    geom_col(position = "stack", width = 0.7,
             color = "white", linewidth = 0.3) +
    facet_wrap(~ fleet_label, ncol = 1) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1),
                       breaks = seq(0, 1, 0.25)) +
    scale_fill_manual(values = c(
        "Within-model (posterior + vessel heterogeneity)" = "#5b9bd5",
        "Between-model (CMIP6 spread)"                    = "#ed7d31"),
      name = NULL) +
    labs(x = NULL,
         y = "Share of total variance",
         title = "Variance decomposition of fleet-level trip comparative statics",
         subtitle = paste0("Total variance of %change in fleet-level trips ",
                           "partitioned into within-model (posterior plus ",
                           "vessel heterogeneity) and between-model ",
                           "(CMIP6 ensemble) sources.")) +
    theme_minimal(base_size = 11) +
    theme(strip.text       = element_text(face = "bold"),
          plot.title       = element_text(face = "bold"),
          plot.subtitle    = element_text(size = 9, color = "grey25"),
          legend.position  = "top",
          axis.text.x      = element_text(size = 9))

  ggsave(path, p, width = 9, height = 6.5, dpi = 150)
  cat("[App G] Figura guardada:", path, "\n\n")
  invisible(p)
}

# -----------------------------------------------------------------------------
# Orquestador
# -----------------------------------------------------------------------------

appg_run <- function() {
  cat(strrep("=", 70), "\n",
      "Appendix G -- Variance decomposition of trip comparative statics\n",
      strrep("=", 70), "\n\n", sep = "")

  # Reconstruir factor_trips_dt completo via t6_run().
  # Costo: ~51s (loop por vessel x 22 model-scen x 16K draws -> 292M filas).
  # Si Felipe ya tiene t6_result en globalenv (e.g., hizo source con
  # t6.run_main=TRUE recientemente), reusarlo es ~30s saved -- skip el run.
  if (exists("t6_result", envir = globalenv()) &&
      !is.null(globalenv()$t6_result$factor_trips)) {
    cat("[App G] Reusando t6_result$factor_trips desde globalenv (skip t6_run).\n\n")
    res_t6 <- globalenv()$t6_result
  } else {
    cat("[App G] Construyendo factor_trips_dt via t6_run() (~51s)...\n\n")
    res_t6 <- t6_run()
  }

  cat(strrep("-", 70), "\n",
      "[App G] Decomposicion 2-way de %Delta trips:\n",
      strrep("-", 70), "\n", sep = "")

  res_g <- appg_decompose(res_t6$factor_trips)

  print(res_g$decomp[, .(fleet_label, scenario_label, n_models,
                          mean_pct = sprintf("%+.1f%%", 100 * mean_pct_change),
                          sd_total = round(sd_total, 4),
                          pct_within  = sprintf("%.0f%%", 100 * pct_within),
                          pct_between = sprintf("%.0f%%", 100 * pct_between))])
  cat("\n")

  appg_write_table(res_g$decomp)
  appg_plot(res_g$decomp)

  invisible(res_g)
}

# -----------------------------------------------------------------------------
# Main guard
# -----------------------------------------------------------------------------

if (isTRUE(getOption("appg.run_main", TRUE))) {
  appg_result <- appg_run()
}
