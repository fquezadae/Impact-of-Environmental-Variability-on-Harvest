# =============================================================================
# FONDECYT -- 05_load_official_biomass.R
#
# Loader de series oficiales de evaluación de stock (SSB / Biomasa Total /
# Reclutas) compiladas por Felipe desde evaluaciones age-structured IFOP.
#
# Input:
#   data/bio_params/official_biomass_series.csv   (259 filas, 6 stocks)
#
# Estructura del CSV:
#   stock_id        : "anchoveta_cs", "sardina_comun_cs", "jurel_orop_ps",
#                     "anchoveta_norte", "anchoveta_sur_peru_norte_chile",
#                     "sardina_austral_los_lagos"
#   especie, zona, regiones
#   year            : año calendario (int)
#   semester        : 1 = primer semestre / calendario anual; 2 = segundo sem.
#                     (relevante solo para anchoveta_sur_peru_norte_chile)
#   year_label      : "2024" o "2024.5"
#   ssb_t           : biomasa desovante — toneladas (CAVEAT: ver unidades abajo)
#   biomass_total_t : biomasa total — toneladas (NA para jurel_orop_ps)
#   recruits_mil_ind: reclutas en millones de individuos
#
# CAVEATS importantes:
#  (a) Unidades jurel_orop_ps y anchoveta_sur_peru_norte_chile están en DUDA.
#      Valores demasiado bajos para ser toneladas puras si el stock es
#      range-wide. Hipótesis: miles de t. Ver PEND-5 en official_assessments.yaml.
#  (b) Para anchoveta_sur_peru_norte_chile hay 2 obs/año (semianual).
#      Para todos los demás hay 1 obs/año.
#  (c) Sardina común centro-sur llega hasta 2025; el resto hasta 2024.
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

OBS_CSV <- file.path("data", "bio_params", "official_biomass_series.csv")

# ------------------------------------------------------------------ loader ----

load_official_biomass <- function(path = OBS_CSV) {

  stopifnot(file.exists(path))

  raw <- readr::read_csv(path, show_col_types = FALSE)

  expected <- c("stock_id","especie","zona","regiones",
                "year","semester","year_label",
                "ssb_t","biomass_total_t","recruits_mil_ind")
  missing <- setdiff(expected, names(raw))
  if (length(missing) > 0) stop("CSV le faltan columnas: ",
                                paste(missing, collapse = ", "))

  # Validaciones
  stopifnot(
    all(raw$year    >= 1970 & raw$year    <= 2030),
    all(raw$semester %in% c(1,2)),
    all(raw$ssb_t             >= 0, na.rm = TRUE),
    all(raw$biomass_total_t   >= 0, na.rm = TRUE),
    all(raw$recruits_mil_ind  >= 0, na.rm = TRUE)
  )

  raw
}

# ----------------------------- subset por stock con filtro a los papers -----

load_paper1_stocks <- function(df = load_official_biomass()) {
  df %>%
    dplyr::filter(stock_id %in% c("anchoveta_cs",
                                  "sardina_comun_cs",
                                  "jurel_orop_ps"))
}

# --------- anualizar anchoveta_sur_peru_norte_chile (2 obs → 1 obs/año) -----
# (No lo usamos en paper1, pero dejo el helper por completitud)

collapse_semesters <- function(df, method = c("mean","max","s1_only")) {
  method <- match.arg(method)
  fn <- switch(method, mean = mean, max = max, s1_only = function(x) x[1])

  df %>%
    dplyr::group_by(stock_id, especie, zona, regiones, year) %>%
    dplyr::summarise(
      n_semesters       = dplyr::n(),
      ssb_t             = fn(ssb_t,            na.rm = TRUE),
      biomass_total_t   = fn(biomass_total_t,  na.rm = TRUE),
      recruits_mil_ind  = fn(recruits_mil_ind, na.rm = TRUE),
      .groups = "drop"
    )
}

# -------------------- sanity check unidades vs. biomasa acústica/MPDH -------
# Compara SSB oficial (Datos_estimación) con biomasa acústica (RECLAS/PELACES)
# para stocks donde ambas existen (anchoveta_cs, sardina_comun_cs).

reconcile_official_vs_acoustic <- function(
    official = load_paper1_stocks(),
    acoustic_csv = "data/bio_params/acoustic_biomass_series.csv"
) {
  stopifnot(file.exists(acoustic_csv))
  ac <- readr::read_csv(acoustic_csv, show_col_types = FALSE)

  # Promedio anual acústico (RECLAS + PELACES cuando ambos existen)
  ac_annual <- ac %>%
    dplyr::filter(species %in% c("sardina_comun_cs","anchoveta_cs")) %>%
    dplyr::group_by(stock_id = species, year) %>%
    dplyr::summarise(
      biomass_ac_t = mean(biomass_t, na.rm = TRUE),
      .groups = "drop"
    )

  off_annual <- official %>%
    dplyr::filter(stock_id %in% c("anchoveta_cs","sardina_comun_cs")) %>%
    dplyr::select(stock_id, year, ssb_t, biomass_total_t)

  dplyr::inner_join(off_annual, ac_annual, by = c("stock_id","year")) %>%
    dplyr::mutate(
      ratio_ssb_to_ac = ssb_t / biomass_ac_t,
      ratio_bt_to_ac  = biomass_total_t / biomass_ac_t
    )
}

# ------------------------------------------------------- QA visual ggplot ---

plot_official_qa <- function(
    df = load_official_biomass(),
    out_dir = "data/bio_params/qa"
) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # --- Panel 1: SSB por stock (log scale) ---
  df_plot <- df %>%
    dplyr::mutate(t_index = year + (semester - 1) * 0.5)

  p_ssb <- ggplot(df_plot, aes(x = t_index, y = ssb_t / 1e3,
                               colour = stock_id)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.8) +
    facet_wrap(~ stock_id, ncol = 2, scales = "free_y") +
    scale_y_log10() +
    labs(title = "SSB oficial por stock (log scale)",
         subtitle = "Datos_estimación biomasa.xlsx — 1970-2025",
         x = "Año", y = "SSB (miles de t)") +
    theme_minimal(base_size = 10) +
    theme(legend.position = "none")
  ggsave(file.path(out_dir, "official_ssb_by_stock.png"),
         p_ssb, width = 10, height = 7, dpi = 150)

  # --- Panel 2: Reclutamiento por stock ---
  p_rec <- ggplot(df_plot, aes(x = t_index, y = recruits_mil_ind / 1e3,
                               colour = stock_id)) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.8) +
    facet_wrap(~ stock_id, ncol = 2, scales = "free_y") +
    labs(title = "Reclutas oficiales por stock",
         subtitle = "Eje Y: miles de millones de individuos",
         x = "Año", y = "R (mil millones ind)") +
    theme_minimal(base_size = 10) +
    theme(legend.position = "none")
  ggsave(file.path(out_dir, "official_recruits_by_stock.png"),
         p_rec, width = 10, height = 7, dpi = 150)

  # --- Panel 3: S-R scatter (Stock-Recruitment) ---
  # (útil para informar prior de steepness si decidimos estimar algo S-R)
  p_sr <- ggplot(df_plot, aes(x = ssb_t / 1e3, y = recruits_mil_ind / 1e3,
                              colour = year)) +
    geom_point(size = 2) +
    facet_wrap(~ stock_id, ncol = 2, scales = "free") +
    scale_colour_viridis_c() +
    labs(title = "Relación Stock-Recluta (exploratorio)",
         subtitle = "Para informar prior de steepness (h) en surplus production",
         x = "SSB (mil t)", y = "R (mil millones ind)",
         colour = "Año") +
    theme_minimal(base_size = 10)
  ggsave(file.path(out_dir, "official_sr_scatter.png"),
         p_sr, width = 10, height = 7, dpi = 150)

  # --- Panel 4: reconciliación oficial vs acústica (solo anchoveta/sardina CS) ---
  tryCatch({
    rec <- reconcile_official_vs_acoustic(df)
    p_rec2 <- ggplot(rec, aes(x = biomass_ac_t / 1e3, y = biomass_total_t / 1e3,
                              colour = stock_id)) +
      geom_point(size = 2.5) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                  colour = "grey40") +
      labs(title = "Oficial vs Acústica (miles de t) — identity line dashed",
           subtitle = "Esperamos covarianza, no identidad: distintos métodos",
           x = "Biomasa acústica anual (promedio RECLAS+PELACES)",
           y = "Biomasa total oficial") +
      theme_minimal(base_size = 10)
    ggsave(file.path(out_dir, "official_vs_acoustic.png"),
           p_rec2, width = 7, height = 5, dpi = 150)
  }, error = function(e) {
    message("No se pudo generar reconciliación: ", e$message)
  })

  invisible(list(ssb = p_ssb, rec = p_rec, sr = p_sr))
}

# --------------------------------------------------------------- main() ----

if (isTRUE(getOption("structural_bio.run_main", FALSE))) {

  cat(strrep("=", 70), "\n")
  cat("Official biomass series loader (SSB/BT/R age-structured IFOP)\n")
  cat(strrep("=", 70), "\n\n")

  d <- load_official_biomass()
  cat("Filas totales:", nrow(d), "\n")

  # Cobertura por stock
  cat("\nCobertura por stock:\n")
  print(d %>% dplyr::group_by(stock_id) %>%
        dplyr::summarise(
          n       = dplyr::n(),
          yr_min  = min(year),
          yr_max  = max(year),
          ssb_med = round(median(ssb_t, na.rm = TRUE), 0),
          .groups = "drop"
        ) %>% as.data.frame(), row.names = FALSE)

  # Stocks target paper1 — últimos 10 años
  cat("\n--- ANCHOVETA CS (últimos 10 años) ---\n")
  print(d %>% dplyr::filter(stock_id == "anchoveta_cs") %>%
        dplyr::arrange(year) %>% tail(10) %>%
        dplyr::select(year, ssb_t, biomass_total_t, recruits_mil_ind) %>%
        as.data.frame(), row.names = FALSE)

  cat("\n--- SARDINA COMÚN CS (últimos 10 años) ---\n")
  print(d %>% dplyr::filter(stock_id == "sardina_comun_cs") %>%
        dplyr::arrange(year) %>% tail(10) %>%
        dplyr::select(year, ssb_t, biomass_total_t, recruits_mil_ind) %>%
        as.data.frame(), row.names = FALSE)

  # Reconciliación oficial vs acústica
  cat("\n--- Reconciliación SSB oficial vs biomasa acústica ---\n")
  rec <- reconcile_official_vs_acoustic()
  print(rec %>% dplyr::mutate(dplyr::across(
    c(ssb_t, biomass_total_t, biomass_ac_t),
    ~ round(.x / 1e3, 1))) %>% as.data.frame(), row.names = FALSE)

  plot_official_qa(d)
  cat("\nQA plots guardados en data/bio_params/qa/\n")

  cat(strrep("=", 70), "\n")
  cat("ATENCIÓN: PEND-5. Verificar unidades de jurel_orop_ps y\n")
  cat("         anchoveta_sur_peru_norte_chile (ver official_assessments.yaml)\n")
  cat(strrep("=", 70), "\n")
}
