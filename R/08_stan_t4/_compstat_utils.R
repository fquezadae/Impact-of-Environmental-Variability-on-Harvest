# =============================================================================
# FONDECYT -- _compstat_utils.R
#
# Utilidades compartidas entre los scripts de comparative statics:
#   - 12_growth_comparative_statics.R   (T5)
#   - 13_trip_comparative_statics.R     (T7)
#   - 16_appendix_f_variance_decomposition.R (Apendice F)
#
# Antes (pre-2026-04-29 PM) T5 exponia las constantes y funciones publicas
# de facto a T7 via `source(T5)`. Esa importacion gatillaba el main guard de
# T5 con default-TRUE -> efecto colateral indeseado (corre T5 entero) cuando
# T7 solo necesitaba reusar las funciones. Este archivo separa lo "shared"
# del "main", permitiendo que cualquiera de los downstream scripts llame
#   source_utf8("R/08_stan_t4/_compstat_utils.R")
# sin gatillar runs.
#
# Contenido:
#   - Constantes: COMPSTAT_STOCKS, COMPSTAT_SSPS, COMPSTAT_WINDOWS,
#                 COMPSTAT_NON_IDENTIFIED_STOCKS, COMPSTAT_STOCK_LABEL,
#                 COMPSTAT_SCENARIO_LABEL, COMPSTAT_DELTAS_CSV
#   - Funcion:   compstat_load_scenarios()
#                  Devuelve tibble(model, scenario, window, scenario_key,
#                                  DSST, DlogCHL) per-model.
#
# Convencion: los nombres T5_*/T6_* en cada script downstream siguen siendo
# los exportados localmente (alias) por compatibilidad con los scripts
# previos y por uniformidad estilistica entre archivos. Este modulo es la
# fuente unica de verdad para los valores.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(data.table)
})

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------

COMPSTAT_DELTAS_CSV <- "data/cmip6/deltas_ensemble.csv"

COMPSTAT_STOCKS <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")

COMPSTAT_STOCK_LABEL <- c(
  anchoveta_cs     = "Anchoveta CS",
  sardina_comun_cs = "Sardine CS",
  jurel_cs         = "Jack mackerel CS"
)

COMPSTAT_SSPS    <- c("ssp245", "ssp585")
COMPSTAT_WINDOWS <- c("mid", "end")

COMPSTAT_SCENARIO_LABEL <- c(
  ssp245_mid = "SSP2-4.5, 2041-2060",
  ssp245_end = "SSP2-4.5, 2081-2100",
  ssp585_mid = "SSP5-8.5, 2041-2060",
  ssp585_end = "SSP5-8.5, 2081-2100"
)

# Stocks no identificados estructuralmente -- jurel es n.i. en los 3 dominios
# del Apendice E. Reportar como "n.i." en tablas formateadas; conservar numeros
# en *_raw.csv y *_by_model.csv para trazabilidad.
COMPSTAT_NON_IDENTIFIED_STOCKS <- c("jurel_cs")

# -----------------------------------------------------------------------------
# Carga de escenarios CMIP6 (per-model)
# -----------------------------------------------------------------------------
# Output: tibble con columnas (model, scenario, window, scenario_key,
# DSST, DlogCHL). Los pares (model, ssp, window) sin ambos delta (e.g.,
# CESM2/chlos/ssp245) quedan filtrados.

compstat_load_scenarios <- function(deltas_csv = COMPSTAT_DELTAS_CSV,
                                    verbose = TRUE) {

  d <- data.table::fread(deltas_csv)

  # Solo SST y log-CHL son inputs para T4b. uas/vas/wind_speed son para T7
  # (no usados ahi tampoco al dia de hoy: T7 solo entra por el canal r_eff).
  scen_long <- d[var %in% c("sst", "logchl"),
                 .(model, scenario, window, var, delta)]

  scen_wide <- as_tibble(scen_long) %>%
    pivot_wider(names_from = var, values_from = delta) %>%
    rename(DSST = sst, DlogCHL = logchl) %>%
    filter(!is.na(DSST), !is.na(DlogCHL)) %>%
    mutate(scenario_key = paste(scenario, window, sep = "_")) %>%
    arrange(model, scenario, window)

  if (verbose) {
    cat("[compstat_utils] Escenarios CMIP6 cargados:\n")
    cat(sprintf("    n_filas=%d (combos model x ssp x window con SST+CHL)\n",
                nrow(scen_wide)))
    cat(sprintf("    modelos: %s\n",
                paste(unique(scen_wide$model), collapse = ", ")))
    summ <- scen_wide %>%
      group_by(scenario, window) %>%
      summarise(n_models = n(),
                DSST_mean    = round(mean(DSST), 3),
                DSST_sd      = round(sd(DSST), 3),
                DlogCHL_mean = round(mean(DlogCHL), 4),
                DlogCHL_sd   = round(sd(DlogCHL), 4),
                .groups = "drop")
    print(summ)
    cat("\n")
  }

  scen_wide
}
