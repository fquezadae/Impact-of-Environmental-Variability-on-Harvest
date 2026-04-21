# =============================================================================
# FONDECYT -- ifop_industrial_data.R
#
# >>> USADO POR PAPER 2 (bioeconomic optimization - Stackelberg). NO paper 1. <<<
#
# Paper 1 (climate projections) trabaja con series de biomasa (SSB oficial +
# acústica) y NO necesita estos datos. Los precios que aparecen en paper 1
# como covariables de la trip equation ya vienen deflactados a 2018 desde
# el Rmd principal y se cargan vía un pipeline separado — no desde aquí.
#
# Para paper 2 en cambio, este loader alimenta:
#   (i) precios ex-vessel por especie (input del modelo de planta/comprador)
#  (ii) MP procesada como tamaño de mercado (calibración de demanda)
# (iii) nivel planta (NUI) separado por clase HUMANO / ANIMAL / MIXTA_AH
#
# Loader de datos de Precios + Proceso IFOP 2012-2024 (Monitoreo Económico
# de la Industria Pesquera y Acuícola Nacional).
#
# Inputs (CSVs producidos desde ifop_precios_proceso_raw.xlsx):
#   - data/bio_params/ifop_precios_mp_mensual.csv    (nivel mensual × planta)
#   - data/bio_params/ifop_precios_mp_anual.csv      (agregado anual)
#   - data/bio_params/ifop_proceso_mp_mensual.csv    (nivel mensual × planta)
#   - data/bio_params/ifop_proceso_anual.csv         (agregado anual × línea)
#   - data/bio_params/catch_proxy_paper1_stocks.csv  (MP total como proxy C_t
#                                                     — nombre legacy, puede
#                                                     renombrarse a
#                                                     catch_proxy_mp_procesada.csv)
#
# Notas importantes:
#   (a) PRECIO proviene de encuesta muestral IFOP (no censal). Unidad: CLP/t
#       NOMINAL. Para paper 2 deflactar con IPC BCCh a año base a definir.
#   (b) PROCESO es censal SERNAPESCA. Unidad: toneladas de MP (=input) y
#       producción (=output, producto terminado).
#   (c) MP total es un PROXY de la captura industrial desembarcada-en-planta.
#       NO equivale a la captura total (no incluye venta fresco al consumidor
#       ni flota artesanal que no pasa por planta monitoreada).
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

BP <- "data/bio_params"

# ---------------------------------------------------- loaders por tabla ----

load_precios_mensual <- function() {
  readr::read_csv(file.path(BP, "ifop_precios_mp_mensual.csv"),
                  show_col_types = FALSE) %>%
    dplyr::mutate(
      date = as.Date(sprintf("%d-%02d-01", anio, mes))
    )
}

load_precios_anual <- function() {
  readr::read_csv(file.path(BP, "ifop_precios_mp_anual.csv"),
                  show_col_types = FALSE)
}

load_proceso_mensual <- function() {
  readr::read_csv(file.path(BP, "ifop_proceso_mp_mensual.csv"),
                  show_col_types = FALSE) %>%
    dplyr::mutate(
      date = as.Date(sprintf("%d-%02d-01", anio, mes))
    )
}

load_catch_proxy <- function() {
  readr::read_csv(file.path(BP, "catch_proxy_paper1_stocks.csv"),
                  show_col_types = FALSE) %>%
    dplyr::rename(catch_proxy_t = mp_total_t)
}

# ---------------------------------------- serie anual precio por stock ----
# Precio medio ponderado por volumen de MP procesada en cada recurso
# (más honesto que mean simple si una planta distorsiona la muestra)

compute_annual_price_weighted <- function() {

  pm <- load_precios_mensual() %>%
    dplyr::rename(anio_p = anio)
  prm <- load_proceso_mensual()

  # Join por planta × año × mes × recurso × tipo_mp
  join_keys <- c("nui","anio","mes","cd_recurso","tipo_mp")
  pm_join <- pm %>%
    dplyr::rename(anio = anio_p) %>%
    dplyr::select(all_of(join_keys), precio, clase_industria_ii)

  prm_join <- prm %>%
    dplyr::select(all_of(join_keys), mp_total, nm_recurso, clase_industria)

  merged <- dplyr::inner_join(pm_join, prm_join, by = join_keys)

  merged %>%
    dplyr::group_by(anio, nm_recurso) %>%
    dplyr::summarise(
      price_weighted_clp_per_t = sum(precio * mp_total, na.rm = TRUE) /
                                 sum(mp_total, na.rm = TRUE),
      price_mean_clp_per_t     = mean(precio, na.rm = TRUE),
      price_med_clp_per_t      = median(precio, na.rm = TRUE),
      mp_joined_t              = sum(mp_total, na.rm = TRUE),
      n_obs                    = dplyr::n(),
      .groups = "drop"
    )
}

# ---------------------------------------------------- QA visual rapido ----

plot_ifop_industrial_qa <- function(
    out_dir = "data/bio_params/qa"
) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  cp <- load_catch_proxy()
  p_cp <- ggplot(cp, aes(x = year, y = catch_proxy_t / 1e3, colour = stock_id)) +
    geom_line(linewidth = 1) + geom_point(size = 2.5) +
    labs(title = "MP procesada IFOP (proxy de captura industrial)",
         subtitle = "2012-2024, regiones V-X (centro-sur); jurel: range-wide",
         x = "Año", y = "Miles de t", colour = NULL) +
    theme_minimal(base_size = 11)
  ggsave(file.path(out_dir, "catch_proxy_paper1.png"),
         p_cp, width = 8, height = 5, dpi = 150)

  pw <- compute_annual_price_weighted()
  p_pw <- ggplot(pw, aes(x = anio, y = price_weighted_clp_per_t / 1e3,
                         colour = nm_recurso)) +
    geom_line(linewidth = 1) + geom_point(size = 2.5) +
    labs(title = "Precio MP ponderado por volumen",
         subtitle = "CLP constantes nominales — revisar deflactor antes de interpretar",
         x = "Año", y = "Miles de CLP / t", colour = "Recurso") +
    theme_minimal(base_size = 11)
  ggsave(file.path(out_dir, "precio_mp_ponderado.png"),
         p_pw, width = 8, height = 5, dpi = 150)

  invisible(list(catch = p_cp, price = p_pw))
}

# --------------------------------------------------------------- main() ----

if (isTRUE(getOption("structural_bio.run_main", FALSE))) {

  cat(strrep("=", 70), "\n")
  cat("IFOP industrial data (precios + proceso 2012-2024)\n")
  cat(strrep("=", 70), "\n\n")

  cp <- load_catch_proxy()
  cat("Catch proxy (MP total procesada, t) por stock × año:\n")
  print(cp %>% tidyr::pivot_wider(names_from = stock_id, values_from = catch_proxy_t) %>%
        as.data.frame(), row.names = FALSE)

  pw <- compute_annual_price_weighted()
  cat("\nPrecio MP ponderado por volumen (CLP nominal / t):\n")
  print(pw %>% dplyr::select(anio, nm_recurso, price_weighted_clp_per_t,
                             price_med_clp_per_t, mp_joined_t) %>%
        dplyr::mutate(dplyr::across(dplyr::starts_with("price_"),
                                    ~ round(.x, 0))) %>%
        as.data.frame(), row.names = FALSE)

  plot_ifop_industrial_qa()
  cat("\nQA plots guardados en data/bio_params/qa/\n")
}
