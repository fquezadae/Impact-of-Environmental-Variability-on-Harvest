# =============================================================================
# FONDECYT -- 03_load_acoustic_series.R
#
# Loader y QA de la serie acústica IFOP (RECLAS verano + PELACES otoño)
# para sardina común y anchoveta centro-sur, 1999-2024.
#
# Fuente: tabla consolidada que Felipe mantenía aparte, guardada en
#         data/bio_params/acoustic_biomass_series.csv
#
# Outputs:
#   - tibble tidy en memoria (listo para joinear con captura y ambiente)
#   - data/bio_params/acoustic_series_annual.rds  (un valor anual por especie)
#   - data/bio_params/qa/acoustic_series_qa.png   (gráfico exploratorio)
#
# Uso:
#   source("R/07_structural_bio/03_load_acoustic_series.R")
#   series <- load_acoustic_series()
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

ACOUSTIC_CSV <- file.path("data", "bio_params", "acoustic_biomass_series.csv")

# --------------------------------------------------------------- loader ----

load_acoustic_series <- function(path = ACOUSTIC_CSV) {

  stopifnot(file.exists(path))

  raw <- readr::read_csv(path, show_col_types = FALSE)

  # Validaciones
  expected_cols <- c("year","crucero","survey","season","species",
                     "biomass_t","abundance_mil_ind")
  missing <- setdiff(expected_cols, names(raw))
  if (length(missing) > 0) {
    stop("CSV le faltan columnas: ", paste(missing, collapse = ", "))
  }
  stopifnot(
    all(raw$biomass_t >= 0),
    all(raw$abundance_mil_ind >= 0),
    all(raw$year >= 1990 & raw$year <= 2030),
    all(raw$species %in% c("sardina_comun_cs", "anchoveta_cs")),
    all(raw$survey %in% c("RECLAS","PELACES"))
  )

  # Peso medio implícito (sanity check y feature útil)
  df <- raw %>%
    mutate(
      mean_weight_g = ifelse(
        abundance_mil_ind > 0,
        (biomass_t * 1e6) / (abundance_mil_ind * 1e6),  # g/ind
        NA_real_
      )
    )

  df
}

# ---------------------------- agregación anual (si hay dos cruceros/año) ----

aggregate_to_annual <- function(df, method = c("mean","max","reclas_only","pelaces_only")) {
  method <- match.arg(method)

  if (method == "reclas_only") {
    return(df %>% filter(survey == "RECLAS") %>%
             select(year, species, biomass_t, abundance_mil_ind, mean_weight_g) %>%
             rename(biomass_annual_t = biomass_t,
                    abundance_annual_mil_ind = abundance_mil_ind))
  }
  if (method == "pelaces_only") {
    return(df %>% filter(survey == "PELACES") %>%
             select(year, species, biomass_t, abundance_mil_ind, mean_weight_g) %>%
             rename(biomass_annual_t = biomass_t,
                    abundance_annual_mil_ind = abundance_mil_ind))
  }

  # método = "mean" o "max": combina RECLAS + PELACES si ambos existen
  fn <- if (method == "mean") mean else max
  df %>%
    group_by(year, species) %>%
    summarise(
      n_surveys                = dplyr::n(),
      biomass_annual_t         = fn(biomass_t, na.rm = TRUE),
      abundance_annual_mil_ind = fn(abundance_mil_ind, na.rm = TRUE),
      mean_weight_g            = mean(mean_weight_g, na.rm = TRUE),
      .groups = "drop"
    )
}

# -------------------------------------------------- QA visual (ggplot) ----

plot_acoustic_qa <- function(df, out_path = "data/bio_params/qa/acoustic_series_qa.png") {
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

  # Panel 1: biomasa
  p_bio <- ggplot(df, aes(x = year, y = biomass_t / 1e3,
                          colour = survey, shape = survey)) +
    geom_line(alpha = 0.5) +
    geom_point(size = 2.5) +
    facet_wrap(~ species, ncol = 1, scales = "free_y",
               labeller = as_labeller(c(
                 sardina_comun_cs = "Sardina común (centro-sur)",
                 anchoveta_cs     = "Anchoveta (centro-sur)"
               ))) +
    scale_colour_manual(values = c(RECLAS = "#D55E00", PELACES = "#0072B2")) +
    labs(title = "Biomasa acústica IFOP — centro-sur",
         subtitle = "RECLAS (verano) vs PELACES (otoño), 1999–2024",
         x = "Año", y = "Biomasa (miles de t)",
         colour = NULL, shape = NULL) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom")

  # Panel 2: peso medio implícito
  p_w <- ggplot(df, aes(x = year, y = mean_weight_g,
                        colour = survey, shape = survey)) +
    geom_line(alpha = 0.5) +
    geom_point(size = 2) +
    facet_wrap(~ species, ncol = 1) +
    scale_colour_manual(values = c(RECLAS = "#D55E00", PELACES = "#0072B2")) +
    labs(title = "Peso medio implícito = Biomasa / Abundancia",
         subtitle = "Sanity check: valores bajos en RECLAS → dominan juveniles",
         x = "Año", y = "g / individuo") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom")

  ggsave(out_path, p_bio, width = 8, height = 6, dpi = 150)
  ggsave(sub("\\.png$", "_weights.png", out_path), p_w, width = 8, height = 6, dpi = 150)

  invisible(list(biomass = p_bio, weight = p_w))
}

# ----------------------------------------------- save consolidated rds ----

save_annual_rds <- function(df_annual,
                            out = "data/bio_params/acoustic_series_annual.rds") {
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  saveRDS(df_annual, out)
  message("Saved: ", out, "  (", nrow(df_annual), " filas)")
}

# --------------------------------------------------------------- main() ----

if (isTRUE(getOption("structural_bio.run_main", FALSE))) {

  cat(strrep("=", 70), "\n")
  cat("IFOP acoustic biomass series loader\n")
  cat(strrep("=", 70), "\n\n")

  d <- load_acoustic_series()
  cat("Filas totales:", nrow(d), "\n")
  cat("Años:", paste(range(d$year), collapse = "-"), "\n\n")

  # Cobertura por especie y survey
  cat("Cobertura:\n")
  print(d %>% count(species, survey) %>% tidyr::pivot_wider(
    names_from = survey, values_from = n))

  # Serie anual — método por defecto: promedio RECLAS+PELACES cuando están los dos
  annual <- aggregate_to_annual(d, method = "mean")
  cat("\nSerie anual (promedio cruceros):\n")
  print(annual %>% as.data.frame(), row.names = FALSE)

  plot_acoustic_qa(d)
  save_annual_rds(annual)

  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("Listo. Revisá data/bio_params/qa/*.png para validar visualmente.\n")
  cat(strrep("=", 70), "\n")
}
