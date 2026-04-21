# =============================================================================
# FONDECYT -- 06_load_catch_series.R
#
# Loader y QA de la serie anual de captura (desembarques SERNAPESCA)
# 2000-2023 para anchoveta centro-sur, sardina común centro-sur y jurel Chile.
#
# Fuente: base de datos SERNAPESCA bd_desembarque.csv — nivel mes × puerto ×
# especie × tipo_agente, Felipe lo subió el 2026-04-21. Encoding latin-1.
#
# Inputs:
#   data/bio_params/catch_annual_paper1.csv            (stock_id × year × C_t)
#   data/bio_params/catch_annual_paper1_by_sector.csv  (split Industrial/Artesanal)
#
# stock_id mapping:
#   anchoveta_cs      : Anchoveta (Engraulis ringens), regiones V-X (CS)
#   sardina_comun_cs  : Sardina común (Strangomera bentincki), regiones V-X
#   jurel_chile       : Jurel (Trachurus murphyi), TOTAL Chile nacional
#                       ⚠ NO es range-wide OROP-PS; hay mismatch con SSB oficial.
#                       Chile ≈ 5% de SSB global; usar con precaución para
#                       calibrar ρ^SST/ρ^CHL del jurel.
#
# Notas:
#  (a) Agregación incluye Industrial + Artesanal (excluye Acuicultura/Fábrica
#      porque son reprocesamiento, no captura de mar).
#  (b) Post-colapso 2013, anchoveta_cs y sardina_comun_cs pasaron a ser
#      casi 100% Artesanal (registros de flota reclasificados <18m bajo
#      art. 55 LGPA). El split Industrial/Artesanal NO es informativo como
#      controlador fleet-size para estos dos stocks.
#  (c) Jurel Chile mantiene share industrial ≈ 90% (cerqueros grandes).
#  (d) Serie termina en 2023. 2024 pendiente de actualización SERNAPESCA.
#  (e) Para sardina común el período IFOP SSB empieza 1991, y anchoveta 1997,
#      pero la captura SERNAPESCA solo cubre 2000-2023. Pre-2000 requiere
#      fuentes complementarias (SERNAPESCA Anuarios históricos o IFOP
#      Seguimiento Fig. 64/95/96).
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

CATCH_CSV         <- file.path("data", "bio_params", "catch_annual_paper1.csv")
CATCH_SPLIT_CSV   <- file.path("data", "bio_params", "catch_annual_paper1_by_sector.csv")
SSB_CSV           <- file.path("data", "bio_params", "official_biomass_series.csv")

# ------------------------------------------------------------------ loaders --

load_catch_annual <- function(path = CATCH_CSV) {
  stopifnot(file.exists(path))
  raw <- readr::read_csv(path, show_col_types = FALSE)
  expected <- c("stock_id","year","catch_t")
  miss <- setdiff(expected, names(raw))
  if (length(miss) > 0) stop("CSV le faltan columnas: ", paste(miss, collapse=", "))
  stopifnot(
    all(raw$year >= 1990 & raw$year <= 2030),
    all(raw$catch_t >= 0)
  )
  raw
}

load_catch_split_sector <- function(path = CATCH_SPLIT_CSV) {
  readr::read_csv(path, show_col_types = FALSE)
}

# ---------- harvest rate C_t / SSB_t (útil como prior para F o como QA) ------

compute_harvest_rate <- function(
    catch = load_catch_annual(),
    ssb   = readr::read_csv(SSB_CSV, show_col_types = FALSE)
) {
  # Keep first-semester SSB (annual stocks)
  ssb1 <- ssb %>%
    dplyr::filter(semester == 1) %>%
    dplyr::select(stock_id, year, ssb_t)

  # Jurel captura Chile vs SSB OROP range-wide — aplicar factor 1000 (miles_de_t)
  catch_m <- catch %>%
    dplyr::mutate(stock_ssb = ifelse(stock_id == "jurel_chile",
                                     "jurel_orop_ps", stock_id))

  dplyr::inner_join(catch_m, ssb1,
                    by = c("stock_ssb" = "stock_id", "year" = "year")) %>%
    dplyr::mutate(
      ssb_t_real = ifelse(stock_ssb == "jurel_orop_ps", ssb_t * 1000, ssb_t),
      harvest_rate = catch_t / ssb_t_real
    ) %>%
    dplyr::select(stock_id, year, catch_t, ssb_t_real, harvest_rate)
}

# ----------------------------------------------------- QA visual (ggplot) ----

plot_catch_qa <- function(
    out_dir = "data/bio_params/qa"
) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  cap <- load_catch_annual()

  # Panel 1: series temporales captura
  p_cap <- ggplot(cap, aes(x = year, y = catch_t / 1e3, colour = stock_id)) +
    geom_line(linewidth = 1) + geom_point(size = 2) +
    facet_wrap(~ stock_id, ncol = 1, scales = "free_y",
               labeller = as_labeller(c(
                 anchoveta_cs = "Anchoveta centro-sur",
                 sardina_comun_cs = "Sardina común centro-sur",
                 jurel_chile = "Jurel total Chile (≠ range-wide OROP)"
               ))) +
    labs(title = "Captura anual SERNAPESCA 2000-2023",
         subtitle = "Industrial + Artesanal, mil toneladas",
         x = "Año", y = "Captura (mil t)") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "none")
  ggsave(file.path(out_dir, "catch_annual_paper1.png"),
         p_cap, width = 8, height = 7, dpi = 150)

  # Panel 2: harvest rate C/SSB
  hr <- compute_harvest_rate()
  p_hr <- ggplot(hr, aes(x = year, y = harvest_rate, colour = stock_id)) +
    geom_line(linewidth = 1) + geom_point(size = 2) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "grey60") +
    facet_wrap(~ stock_id, ncol = 1, scales = "free_y") +
    labs(title = "Harvest rate aparente C_t / SSB_t",
         subtitle = "Jurel: C es Chile, SSB es range-wide OROP → rate baja (~5%)",
         x = "Año", y = "Captura / SSB") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "none")
  ggsave(file.path(out_dir, "catch_vs_ssb_rate.png"),
         p_hr, width = 8, height = 7, dpi = 150)

  # Panel 3: split Industrial vs Artesanal
  spl <- load_catch_split_sector()
  p_spl <- ggplot(spl, aes(x = year, y = catch_t / 1e3, fill = sector)) +
    geom_area(position = "stack", alpha = 0.75) +
    facet_wrap(~ stock_id, ncol = 1, scales = "free_y") +
    scale_fill_manual(values = c(Industrial = "#377EB8", Artesanal = "#E41A1C")) +
    labs(title = "Composición de flota por stock (SERNAPESCA)",
         subtitle = "Post-2013: anchoveta/sardina CS pasan a ~100% artesanal (re-clasificación flota)",
         x = "Año", y = "Captura (mil t)", fill = NULL) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom")
  ggsave(file.path(out_dir, "catch_by_sector.png"),
         p_spl, width = 8, height = 7, dpi = 150)

  invisible(list(catch = p_cap, harvest = p_hr, sector = p_spl))
}

# --------------------------------------------------------------- main() ----

if (isTRUE(getOption("structural_bio.run_main", FALSE))) {

  cat(strrep("=", 70), "\n")
  cat("SERNAPESCA catch series loader (paper 1)\n")
  cat(strrep("=", 70), "\n\n")

  cap <- load_catch_annual()
  cat("Filas:", nrow(cap), " |  años:", paste(range(cap$year), collapse="-"), "\n\n")

  # Pivot wide
  piv <- cap %>% tidyr::pivot_wider(names_from = stock_id, values_from = catch_t)
  cat("Captura anual (toneladas):\n")
  print(as.data.frame(piv), row.names = FALSE)

  cat("\n--- Harvest rate C/SSB (últimos 10 años) ---\n")
  hr <- compute_harvest_rate()
  print(hr %>% dplyr::filter(year >= 2014) %>%
        dplyr::mutate(harvest_rate = round(harvest_rate, 3)) %>%
        as.data.frame(), row.names = FALSE)

  plot_catch_qa()
  cat("\nQA plots en data/bio_params/qa/\n")
  cat(strrep("=", 70), "\n")
}
