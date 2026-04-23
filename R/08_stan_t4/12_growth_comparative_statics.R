# =============================================================================
# FONDECYT -- 12_growth_comparative_statics.R   (T5 MINIMAL)
#
# Comparative statics de la tasa de crecimiento efectiva r_eff[s] bajo
# los deltas climaticos CMIP6 IPSL-CM6A-LR, usando los draws posteriores
# de T4b-full. Este script NO hace forward simulation de la dinamica
# poblacional -- solo evalua el shifter:
#
#     r_eff[s] = r_base[s] * exp( rho_sst[s] * DSST + rho_chl[s] * DlogCHL )
#
# evaluado en (SSP2-4.5, SSP5-8.5) x (mid 2041-2060, end 2081-2100), con
# DSST y DlogCHL promediados espacialmente sobre la caja Centro-Sur.
# Entrega soporte numerico a las magnitudes -65% anch / -94% sard citadas
# en paper1/sections/results_identification.Rmd para un shock hipotetico
# de +1 C sin cambio en CHL.
#
# Entradas:
#   - data/outputs/t4b/t4b_full_fit.rds        (cmdstanr CmdStanMCMC)
#   - data/projections/cmip6_deltas.rds        (data.table con deltas)
#
# Salidas:
#   - tables/growth_comparative_statics.csv
#   - figs/t4b/growth_ridgeline_cmip6.png
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

# ggridges es opcional -- si no esta, caemos a violin
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

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------

T5_FIT_RDS       <- "data/outputs/t4b/t4b_full_fit.rds"
T5_DELTAS_RDS    <- "data/projections/cmip6_deltas.rds"
T5_TABLE_OUT     <- "tables/growth_comparative_statics.csv"
T5_FIG_OUT       <- "figs/t4b/growth_ridgeline_cmip6.png"

# Indexacion de stocks segun Stan data (alineada con 08_fit_t4b_full.R)
T5_STOCKS <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
T5_STOCK_LABEL <- c(
  anchoveta_cs     = "Anchoveta CS",
  sardina_comun_cs = "Sardina comun CS",
  jurel_cs         = "Jurel CS"
)

# Bbox Centro-Sur -- el mismo que usa 01_cmip6_deltas.R
T5_BBOX <- list(lon_min = -80, lon_max = -70,
                lat_min = -42, lat_max = -30)

T5_SSPS     <- c("ssp245", "ssp585")
T5_WINDOWS  <- c("mid", "end")

T5_SCENARIO_LABEL <- c(
  ssp245_mid = "SSP2-4.5, 2041-2060",
  ssp245_end = "SSP2-4.5, 2081-2100",
  ssp585_mid = "SSP5-8.5, 2041-2060",
  ssp585_end = "SSP5-8.5, 2081-2100"
)

# Stocks cuyo shifter NO esta identificado por la data 2000-2024.
# Se reportan como "n.i." en la tabla formateada y se excluyen de la
# figura ridgeline -- su posterior esta prior-dominada y la mediana
# puntual es ruido (ver project_t4b_fits_completed + Pr_dec~0.34).
# El CSV *_raw.csv conserva los numeros completos para trazabilidad.
T5_NON_IDENTIFIED_STOCKS <- c("jurel_cs")

# -----------------------------------------------------------------------------
# Paso 1 -- Agregar deltas CMIP6 a escalares (DSST, DlogCHL) por escenario
# -----------------------------------------------------------------------------

t5_build_scenario_scalars <- function(deltas_rds = T5_DELTAS_RDS,
                                      bbox       = T5_BBOX) {

  d <- readRDS(deltas_rds)
  stopifnot(is.data.table(d))

  # Filtro a la caja Centro-Sur (defensivo; el RDS ya venia recortado).
  d <- d[lon >= bbox$lon_min & lon <= bbox$lon_max &
           lat >= bbox$lat_min & lat <= bbox$lat_max]

  # --- SST: delta aditivo en grados C ---
  dsst <- d[variable == "sst",
            .(DSST = mean(delta, na.rm = TRUE),
              DSST_sd_spatial = sd(delta, na.rm = TRUE),
              n_cells_months  = .N),
            by = .(ssp, window)]

  # --- CHL: delta es RATIO (fut/hist) -> convertir a log para empatar
  #     la parametrizacion del shifter (rho_chl sobre log(CHL) anomaly).
  #     Flooring defensivo: el ratio nunca deberia ser <= 0 porque 01_cmip6
  #     ya piso hist a 0.01, pero blindamos.
  chl <- d[variable == "chl"]
  chl[, log_ratio := log(pmax(delta, 1e-6))]

  dchl <- chl[, .(DlogCHL = mean(log_ratio, na.rm = TRUE),
                  DlogCHL_sd_spatial = sd(log_ratio, na.rm = TRUE),
                  n_cells_months     = .N),
              by = .(ssp, window)]

  # Merge en wide
  scen <- merge(dsst, dchl[, .(ssp, window, DlogCHL, DlogCHL_sd_spatial)],
                by = c("ssp", "window"))
  scen[, scenario_key := paste(ssp, window, sep = "_")]
  setorder(scen, ssp, window)

  cat("[T5] Escalares CMIP6 por escenario (caja Centro-Sur):\n")
  print(scen[, .(ssp, window,
                 DSST     = round(DSST, 3),
                 DlogCHL  = round(DlogCHL, 4),
                 pct_CHL  = sprintf("%+.1f%%", 100 * (exp(DlogCHL) - 1)))])
  cat("\n")

  scen[]
}

# -----------------------------------------------------------------------------
# Paso 2 -- Extraer draws posteriores de r_base, rho_sst, rho_chl
# -----------------------------------------------------------------------------

t5_extract_draws <- function(fit_rds = T5_FIT_RDS,
                             stocks  = T5_STOCKS) {

  fit <- readRDS(fit_rds)

  # El Stan model expone r_base (transformed parameter) y r_nat (generated
  # quantity = r_base). Usamos r_base para ser transparentes con la ecuacion.
  vars <- c(sprintf("r_base[%d]", seq_along(stocks)),
            sprintf("rho_sst[%d]", seq_along(stocks)),
            sprintf("rho_chl[%d]", seq_along(stocks)))

  dr <- fit$draws(vars, format = "draws_df") %>%
    as_tibble()

  # Reshape a long: (draw_id, stock_idx, r_base, rho_sst, rho_chl)
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
# Paso 3 -- Combinar draws x escenarios y computar r_eff, pct_change
# -----------------------------------------------------------------------------

t5_compute_r_eff <- function(draws_long, scen_dt) {

  # Cross join: cada draw x cada escenario
  scen_df <- as_tibble(scen_dt) %>%
    select(ssp, window, scenario_key, DSST, DlogCHL)

  out <- draws_long %>%
    # dplyr::cross_join cuando esta disponible; si no, by = character()
    tidyr::crossing(scen_df) %>%
    mutate(
      r_eff      = r_base * exp(rho_sst * DSST + rho_chl * DlogCHL),
      pct_change = exp(rho_sst * DSST + rho_chl * DlogCHL) - 1
    )

  out
}

# -----------------------------------------------------------------------------
# Paso 4 -- Resumen por stock x escenario (mediana + banda 90%)
# -----------------------------------------------------------------------------

t5_summarise <- function(draws_scen) {

  summ <- draws_scen %>%
    group_by(stock_id, ssp, window) %>%
    summarise(
      DSST            = first(DSST),
      DlogCHL         = first(DlogCHL),
      r_base_median   = median(r_base),
      r_base_q05      = quantile(r_base, 0.05),
      r_base_q95      = quantile(r_base, 0.95),
      r_eff_median    = median(r_eff),
      r_eff_q05       = quantile(r_eff, 0.05),
      r_eff_q95       = quantile(r_eff, 0.95),
      pct_median      = median(pct_change),
      pct_q05         = quantile(pct_change, 0.05),
      pct_q95         = quantile(pct_change, 0.95),
      prob_decline    = mean(pct_change < 0),
      .groups = "drop"
    ) %>%
    mutate(
      stock_label   = T5_STOCK_LABEL[stock_id],
      scenario_key  = paste(ssp, window, sep = "_"),
      scenario_label = T5_SCENARIO_LABEL[scenario_key]
    ) %>%
    arrange(stock_id,
            factor(ssp, levels = T5_SSPS),
            factor(window, levels = T5_WINDOWS))

  summ
}

# -----------------------------------------------------------------------------
# Paso 4b -- Sanity check: recuperar las cifras del paper (+1 C flat, DCHL=0)
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

  cat("[T5] Sanity check -- shock +1 C SST (CHL constante)\n")
  cat("    (debe dar approx -65% anch, -94% sard segun paper1)\n")
  print(check %>%
          mutate(across(c(pct_median, pct_q05, pct_q95),
                        ~ sprintf("%+.1f%%", 100 * .x))))
  cat("\n")

  invisible(check)
}

# -----------------------------------------------------------------------------
# Paso 5 -- Tabla final (CSV ancho y legible)
# -----------------------------------------------------------------------------

t5_write_table <- function(summ, path = T5_TABLE_OUT) {

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  # Formato pret-a-porter para paper: pct con signo + banda 90%.
  # Para stocks no identificados (jurel), reemplazamos r_eff y %Delta por
  # "n.i." -- la mediana puntual es ruido posterior, ver nota al pie del
  # script. DSST y DlogCHL se conservan porque son inputs exogenos.
  ni <- summ$stock_id %in% T5_NON_IDENTIFIED_STOCKS

  out <- summ %>%
    transmute(
      Stock    = stock_label,
      Scenario = scenario_label,
      `DSST (C)`        = sprintf("%+.2f", DSST),
      `DlogCHL`         = sprintf("%+.3f", DlogCHL),
      `r_base (median)` = sprintf("%.3f", r_base_median),
      `r_eff (median)`  = ifelse(ni, "n.i.", sprintf("%.3f", r_eff_median)),
      `r_eff (q05)`     = ifelse(ni, "n.i.", sprintf("%.3f", r_eff_q05)),
      `r_eff (q95)`     = ifelse(ni, "n.i.", sprintf("%.3f", r_eff_q95)),
      `%Delta (median)` = ifelse(ni, "n.i.", sprintf("%+.1f%%", 100 * pct_median)),
      `%Delta (q05)`    = ifelse(ni, "n.i.", sprintf("%+.1f%%", 100 * pct_q05)),
      `%Delta (q95)`    = ifelse(ni, "n.i.", sprintf("%+.1f%%", 100 * pct_q95)),
      `Pr(Delta<0)`     = ifelse(ni, "n.i.", sprintf("%.2f", prob_decline))
    )

  if (any(ni)) {
    cat("[T5] Stocks reportados como n.i. en tabla formateada:",
        paste(unique(summ$stock_label[ni]), collapse = ", "),
        "(ver _raw.csv para numeros crudos)\n")
  }

  write.csv(out, path, row.names = FALSE)
  cat("[T5] Tabla escrita:", path, "\n")

  # Tambien una version numerica cruda (sin formateo) para uso programatico
  num_path <- sub("\\.csv$", "_raw.csv", path)
  write.csv(summ, num_path, row.names = FALSE)
  cat("[T5] Tabla numerica:", num_path, "\n\n")

  invisible(out)
}

# -----------------------------------------------------------------------------
# Paso 6 -- Figura ridgeline (pct_change por stock x escenario)
# -----------------------------------------------------------------------------

t5_plot_ridgeline <- function(draws_scen, path = T5_FIG_OUT) {

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  # Excluir stocks no identificados -- su posterior en %change cruza cero
  # con banda obscena (ver t5_summarise); ridgeline sobre prior-dominado
  # solo engana al lector.
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
    # Colas extremas (>|300%|) no aportan lectura -- clipeamos para la figura,
    # sin afectar la tabla (que conserva todo).
    mutate(pct_clip = pmin(pmax(pct_change, -1), 3))

  excluded <- setdiff(unique(draws_scen$stock_id),
                      unique(plot_df$stock_id))
  subtitle_note <- if (length(excluded) > 0) {
    paste0("Stocks no identificados excluidos (",
           paste(T5_STOCK_LABEL[excluded], collapse = ", "),
           "); ver tabla para detalle.")
  } else {
    "T4b-full; caja Centro-Sur (IPSL-CM6A-LR)"
  }

  if (.HAS_GGRIDGES) {
    p <- ggplot(plot_df,
                ggplot2::aes(x = pct_clip,
                             y = scenario_label,
                             fill = stock_label)) +
      ggridges::geom_density_ridges(alpha = 0.55,
                                    scale = 1.1,
                                    rel_min_height = 0.01,
                                    color = "white", linewidth = 0.2) +
      facet_wrap(~ stock_label, ncol = 1, scales = "free_y") +
      scale_x_continuous(labels = scales::percent_format(accuracy = 1),
                         breaks = c(-1, -0.5, 0, 0.5, 1, 2, 3)) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "grey30") +
      scale_fill_brewer(palette = "Set2", guide = "none") +
      labs(x = "Cambio % en r_eff vs baseline historico",
           y = NULL,
           title = "Comparative statics del crecimiento bajo CMIP6",
           subtitle = subtitle_note) +
      theme_minimal(base_size = 11) +
      theme(strip.text = element_text(face = "bold"),
            plot.title = element_text(face = "bold"))
  } else {
    message("[T5] ggridges no disponible -- usando violin como fallback")
    p <- ggplot(plot_df,
                ggplot2::aes(x = scenario_label, y = pct_clip,
                             fill = stock_label)) +
      geom_violin(alpha = 0.55, color = "white", scale = "width") +
      facet_wrap(~ stock_label, ncol = 1, scales = "free_y") +
      scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "grey30") +
      coord_flip() +
      scale_fill_brewer(palette = "Set2", guide = "none") +
      labs(y = "Cambio % en r_eff vs baseline historico",
           x = NULL,
           title = "Comparative statics del crecimiento bajo CMIP6",
           subtitle = subtitle_note) +
      theme_minimal(base_size = 11)
  }

  ggsave(path, p, width = 8.5, height = 7.5, dpi = 150)
  cat("[T5] Figura guardada:", path, "\n\n")

  invisible(p)
}

# -----------------------------------------------------------------------------
# Orquestador
# -----------------------------------------------------------------------------

t5_run <- function() {
  cat(strrep("=", 60), "\n",
      "T5 MINIMAL -- Comparative statics del crecimiento bajo CMIP6\n",
      strrep("=", 60), "\n\n", sep = "")

  scen  <- t5_build_scenario_scalars()
  draws <- t5_extract_draws()

  t5_sanity_plus1c(draws)

  ds    <- t5_compute_r_eff(draws, scen)
  summ  <- t5_summarise(ds)

  cat("[T5] Resumen (mediana y banda 90%):\n")
  print(summ %>%
          transmute(stock_label, scenario_label,
                    DSST    = round(DSST, 2),
                    DlogCHL = round(DlogCHL, 3),
                    pct     = sprintf("%+.1f%%", 100 * pct_median),
                    band    = sprintf("[%+.1f%%, %+.1f%%]",
                                      100 * pct_q05, 100 * pct_q95),
                    Pr_dec  = round(prob_decline, 2)))
  cat("\n")

  t5_write_table(summ)
  t5_plot_ridgeline(ds)

  invisible(list(scenarios = scen, summary = summ, draws_scen = ds))
}

# -----------------------------------------------------------------------------
# Main guard
# -----------------------------------------------------------------------------

if (isTRUE(getOption("t5.run_main", FALSE))) {
  t5_result <- t5_run()
}
