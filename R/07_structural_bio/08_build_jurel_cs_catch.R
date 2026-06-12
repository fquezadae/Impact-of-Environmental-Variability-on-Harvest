# =============================================================================
# FONDECYT -- 08_build_jurel_cs_catch.R
#
# Tarea T3/T4 del plan V2: construir serie de captura de JUREL centro-sur
# (regiones V a X incluyendo Los Ríos) a partir de la base cruda SERNAPESCA
# bd_desembarque.csv.
#
# CONTEXTO (2026-04-21 tarde):
#   La arquitectura V2 asumía jurel_chile (captura Chile-total) emparejado con
#   jurel_orop_ps (SSB range-wide). Hindcast T3 falló estructuralmente (plan
#   líneas 226-229, sospechosos #1 y #4). Discusión con Felipe muestra que:
#     (a) SÍ hay biomasa acústica de jurel a escala centro-sur
#         (acoustic_biomass_series.csv::jurel_cs, IFOP 2000-2024, 25 obs).
#     (b) SERNAPESCA tiene región por puerto → puede separarse la captura a
#         nivel centro-sur coherentemente con la escala de la biomasa acústica.
#   Esto habilita modelar jurel con arquitectura CS consistente (igual que
#   anchoveta_cs y sardina_comun_cs), sin mismatch geográfico.
#
# REGIONES CS (confirmado con Felipe 2026-04-21):
#   V a X = Valparaíso, O'Higgins, Maule, Bío-Bío, La Araucanía, Los Ríos,
#   Los Lagos. Incluye Los Ríos (XIV) que antes de 2007 era parte de Los Lagos.
#
# SHARE CS OBSERVADO EN LOS DATOS (validación del enfoque):
#   2000-2007: 83-91% de Chile-total
#   2008-2011: 50-77% (flota migra al norte durante el crash)
#   2014-2023: 80-95% (recuperación)
#   El share NO es constante → usar jurel_chile como proxy sobre-estima
#   captura durante el crash (justo cuando más importa para identificar r).
#
# Outputs:
#   - data/bio_params/catch_jurel_cs.csv         (stock_id, year, catch_t)
#   - data/bio_params/catch_jurel_cs_by_sector.csv
#       (stock_id, year, sector ∈ {Artesanal, Industrial}, catch_t) — versión
#       desagregada por tipo_agente, consumida por regime_diagnostic.R
#       (Version C, paper 2). NO altera la serie agregada que usa T3/T4.
#   - Actualiza data/bio_params/catch_annual_paper1.csv agregando filas con
#     stock_id = "jurel_cs" (mantiene la fila jurel_chile como archivo histórico;
#     02_hindcast_check.R consumirá jurel_cs de ahora en adelante).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# Regiones centro-sur (nomenclatura SERNAPESCA raw: nombres con tildes)
CS_REGIONS <- c(
  "Valparaíso", "O'Higgins", "Maule", "Bio-bío",
  "La Araucanía", "Los Ríos", "Los Lagos"
)

# -----------------------------------------------------------------------------
# Loader con encoding latin-1 (SERNAPESCA no usa UTF-8)
# -----------------------------------------------------------------------------
# El raw vive en OneDrive (no en el repo) en la ruta convencional
# `dirdata/SERNAPESCA/bd_desembarque.csv`. `dirdata` se resuelve por usuario
# en R/00_config/config.R; lo reutilizamos aquí en vez de hard-codear una
# ruta dentro del repo.
default_sernapesca_raw_path <- function() {
  if (!exists("dirdata", inherits = TRUE)) {
    source("R/00_config/config.R")  # define dirdata por usuario
  }
  file.path(dirdata, "SERNAPESCA", "bd_desembarque.csv")
}

load_sernapesca_raw <- function(path = default_sernapesca_raw_path()) {
  stopifnot(file.exists(path))

  # Headers con ñ/tildes mal codificados → leer como latin1 y renombrar
  # (readr usa "latin1" sin guión; "latin-1" da Unknown encoding error)
  raw <- readr::read_delim(
    path, delim = ";", locale = readr::locale(encoding = "latin1"),
    show_col_types = FALSE
  )

  # Homogeneizar nombres (columnas originales: año, aguas, region, ...)
  names(raw) <- c("anio", "aguas", "region", "cd_puerto", "puerto",
                  "mes", "cd_especie", "especie", "toneladas", "tipo_agente")
  raw
}

# -----------------------------------------------------------------------------
# Agregador: jurel centro-sur anual
# -----------------------------------------------------------------------------
build_jurel_cs_annual <- function(raw = load_sernapesca_raw()) {
  raw %>%
    dplyr::filter(
      grepl("^jurel", especie, ignore.case = TRUE),
      region %in% CS_REGIONS,
      # excluir Acuicultura/Fábrica para ser consistente con build
      # original de catch_annual_paper1 (sólo captura de mar)
      tipo_agente %in% c("Industrial", "Artesanal")
    ) %>%
    dplyr::group_by(year = as.integer(anio)) %>%
    dplyr::summarise(catch_t = sum(toneladas, na.rm = TRUE), .groups = "drop") %>%
    dplyr::mutate(stock_id = "jurel_cs") %>%
    dplyr::select(stock_id, year, catch_t) %>%
    dplyr::arrange(year)
}

# -----------------------------------------------------------------------------
# Agregador: jurel centro-sur anual POR SECTOR (Industrial vs Artesanal)
# -----------------------------------------------------------------------------
# Idéntico filtro que build_jurel_cs_annual pero conserva tipo_agente.
# Output con la misma escala geográfica (V-X + Los Ríos) que la biomasa
# acústica IFOP, condición necesaria para que regime_diagnostic.R compute
# H/B sin inflar el numerador con captura del norte.
build_jurel_cs_by_sector_annual <- function(raw = load_sernapesca_raw()) {
  raw %>%
    dplyr::filter(
      grepl("^jurel", especie, ignore.case = TRUE),
      region %in% CS_REGIONS,
      tipo_agente %in% c("Industrial", "Artesanal")
    ) %>%
    dplyr::group_by(year = as.integer(anio), sector = tipo_agente) %>%
    dplyr::summarise(catch_t = sum(toneladas, na.rm = TRUE), .groups = "drop") %>%
    dplyr::mutate(stock_id = "jurel_cs") %>%
    dplyr::select(stock_id, year, sector, catch_t) %>%
    dplyr::arrange(year, sector)
}

# -----------------------------------------------------------------------------
# Sanity check: share CS vs Chile-total (debe variar con la dinámica conocida)
# -----------------------------------------------------------------------------
qa_share_cs <- function(raw = load_sernapesca_raw()) {
  jurel_all <- raw %>%
    dplyr::filter(
      grepl("^jurel", especie, ignore.case = TRUE),
      tipo_agente %in% c("Industrial", "Artesanal")
    )

  total_yr <- jurel_all %>%
    dplyr::group_by(year = as.integer(anio)) %>%
    dplyr::summarise(chile_total_t = sum(toneladas, na.rm = TRUE),
                     .groups = "drop")

  cs_yr <- jurel_all %>%
    dplyr::filter(region %in% CS_REGIONS) %>%
    dplyr::group_by(year = as.integer(anio)) %>%
    dplyr::summarise(cs_t = sum(toneladas, na.rm = TRUE),
                     .groups = "drop")

  dplyr::inner_join(total_yr, cs_yr, by = "year") %>%
    dplyr::mutate(share_cs = round(cs_t / chile_total_t, 3))
}

# -----------------------------------------------------------------------------
# Escritor + actualización del master CSV
# -----------------------------------------------------------------------------
write_jurel_cs_csv <- function(
    out_path    = file.path("data", "bio_params", "catch_jurel_cs.csv"),
    master_path = file.path("data", "bio_params", "catch_annual_paper1.csv")
) {
  cs <- build_jurel_cs_annual()

  # archivo stand-alone
  readr::write_csv(cs, out_path)
  message("Escrito ", out_path, " (", nrow(cs), " filas)")

  # append a master
  master <- readr::read_csv(master_path, show_col_types = FALSE)
  # eliminar filas previas de jurel_cs si existen (idempotencia)
  master <- master %>% dplyr::filter(stock_id != "jurel_cs")
  master_new <- dplyr::bind_rows(master, cs) %>%
    dplyr::arrange(stock_id, year)

  readr::write_csv(master_new, master_path)
  message("Actualizado ", master_path,
          " (stocks: ", paste(sort(unique(master_new$stock_id)), collapse = ", "), ")")

  invisible(cs)
}

# -----------------------------------------------------------------------------
# Escritor: jurel_cs desagregado por sector (Version C, paper 2)
# -----------------------------------------------------------------------------
write_jurel_cs_by_sector_csv <- function(
    out_path = file.path("data", "bio_params", "catch_jurel_cs_by_sector.csv")
) {
  cs_sec <- build_jurel_cs_by_sector_annual()
  readr::write_csv(cs_sec, out_path)
  message("Escrito ", out_path, " (", nrow(cs_sec), " filas, ",
          paste(sort(unique(cs_sec$sector)), collapse = " + "), ")")
  invisible(cs_sec)
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("structural_bio.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("Construcción serie captura jurel_cs (V-X + Los Ríos)\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  raw <- load_sernapesca_raw()
  cat("Filas base SERNAPESCA:", nrow(raw), "\n")

  cs <- build_jurel_cs_annual(raw)
  cat("Serie jurel_cs:", nrow(cs), "años |",
      paste(range(cs$year), collapse = "-"), "\n")
  cat("Captura promedio 2000-2023:", round(mean(cs$catch_t)/1e3, 1), "mil t\n\n")

  cat("--- Share CS vs Chile-total (QA) ---\n")
  share <- qa_share_cs(raw)
  print(as.data.frame(share), row.names = FALSE)

  write_jurel_cs_csv()
  write_jurel_cs_by_sector_csv()

  cat("\n", strrep("=", 70), "\n", sep = "")
}
