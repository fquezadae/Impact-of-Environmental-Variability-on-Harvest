# =============================================================================
# FONDECYT -- 99b_aggregate_catch_cs_from_sernapesca_v3.R
#
# FUENTE: SERNAPESCA (transparencia AH010T0006857; respuesta 2025-05-05).
# Reemplaza el CSV híbrido v2 (SERNAPESCA 2000-2023 + IFOP-cerco 2024
# placeholder) producido por `99_aggregate_catch_cs_from_xlsx.R` con el
# dato oficial todas-las-artes 2000-2024.
#
# Cross-validation v3 vs v2 (2026-04-29 PM): diff <0.5% en las 75 celdas
# (3 stocks x 25 años); el placeholder IFOP-cerco 2024 resultó ex-post
# casi-exacto porque en 2024 cerco representó >99.5% del total CS.
#
# El script no toca la versión legacy (`99_aggregate_catch_cs_from_xlsx.R`);
# ambos co-existen en el repo, pero `99b_*.R` es el camino canónico desde
# 2026-04-29 PM y produce el archivo definitivo.
#
# Procedencia, hojas y disclaimers en
# `data/bio_params/refs/sernapesca_v3/README.md`.
#
# Entradas:
#   - BD_desembarque.csv  (CSV agregado nacional, ISO-8859-1, sep `;`,
#     220 215 filas, 11 columnas; ver SERNA_V3_PATHS abajo).
#
# Salida:
#   - data/bio_params/catch_annual_cs_2000_2024.csv
#     columnas: stock_id, year, catch_t  (75 filas; mismo schema que
#     antes para drop-in con T4b y trip pipeline).
#
# Corre con:
#   source("R/01_data/99b_aggregate_catch_cs_from_sernapesca_v3.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

# -----------------------------------------------------------------------------
# Localización del archivo fuente (16 MB, fuera del repo por tamaño)
# -----------------------------------------------------------------------------
# Intenta 4 ubicaciones en orden:
#   1. local repo (data/bio_params/refs/sernapesca_v3/)
#   2. OneDrive raw data (computadora Felipe)
#   3. uploads del worker Cowork (sandbox actual)
#   4. junto al config dirdata
SERNA_V3_CANDIDATES <- c(
  "data/bio_params/refs/sernapesca_v3/BD_desembarque.csv",
  "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/raw/sernapesca/v3/BD_desembarque.csv",
  "/sessions/practical-zealous-hopper/mnt/uploads/BD_desembarque.csv",
  file.path(getOption("dirdata", ""), "raw/sernapesca/v3/BD_desembarque.csv")
)

bd_path <- SERNA_V3_CANDIDATES[file.exists(SERNA_V3_CANDIDATES)][1]
if (is.na(bd_path)) {
  stop("[sernapesca-v3] No se encontró BD_desembarque.csv en ninguna de:\n  ",
       paste(SERNA_V3_CANDIDATES, collapse = "\n  "), call. = FALSE)
}

OUT_CSV <- "data/bio_params/catch_annual_cs_2000_2024.csv"

# -----------------------------------------------------------------------------
# Filtros (regiones, especies, tipo de agente)
# -----------------------------------------------------------------------------

# Centro-Sur EEZ: 8 regiones administrativas (V Valparaíso, VI O'Higgins,
# VII Maule, XVI Ñuble (creada 2018 desde VIII), VIII Bio-bío, IX La
# Araucanía, XIV Los Ríos (creada 2007 desde X), X Los Lagos).
CS_REGIONS <- c(
  "Valparaíso", "O'Higgins", "Maule", "Ñuble", "Bio-bío",
  "La Araucanía", "Los Ríos", "Los Lagos"
)

# Especies SPF Centro-Sur. Mapping a stock_id canónico del paper.
SPECIES_MAP <- c(
  "Anchoveta"     = "anchoveta_cs",
  "Sardina común" = "sardina_comun_cs",
  "Jurel"         = "jurel_cs"
)

# Tipo de agente: solo capturas de pesca extractiva. Excluye Acuicultura
# (cría) y Fábrica (Sernapesca aclara en el oficio que BF se registra
# desde 2017 y "no en cantidad significativa" -- se descarta para la
# serie histórica continua 2000-2024).
KEEP_AGENTS <- c("Industrial", "Artesanal")

# -----------------------------------------------------------------------------
# Carga + filtrado + agregación
# -----------------------------------------------------------------------------

cat("[sernapesca-v3] Leyendo:", bd_path, "\n")

# El archivo viene en ISO-8859-1; readr usa locale para el encoding.
bd <- readr::read_delim(
  bd_path,
  delim = ";",
  locale = readr::locale(encoding = "ISO-8859-1"),
  show_col_types = FALSE,
  col_types = readr::cols(
    .default     = readr::col_character(),
    año          = readr::col_integer(),
    cd_puerto    = readr::col_integer(),
    mes          = readr::col_integer(),
    cd_especie   = readr::col_integer(),
    toneladas    = readr::col_double()
  )
)

cat(sprintf("[sernapesca-v3] Filas crudas: %d\n", nrow(bd)))
cat(sprintf("[sernapesca-v3] Cobertura años: %d-%d\n",
            min(bd$año, na.rm = TRUE), max(bd$año, na.rm = TRUE)))

# Filtros + agregación
catch_cs <- bd %>%
  dplyr::filter(
    region %in% CS_REGIONS,
    especie %in% names(SPECIES_MAP),
    tipo_agente %in% KEEP_AGENTS
  ) %>%
  dplyr::mutate(stock_id = SPECIES_MAP[especie]) %>%
  dplyr::group_by(stock_id, year = año) %>%
  dplyr::summarise(catch_t = sum(toneladas, na.rm = TRUE), .groups = "drop") %>%
  dplyr::arrange(stock_id, year)

cat(sprintf("[sernapesca-v3] Filas agregadas (stock x año): %d\n",
            nrow(catch_cs)))

# Verificación dimensiones esperadas
expected_rows <- length(unique(catch_cs$stock_id)) * length(unique(catch_cs$year))
stopifnot(nrow(catch_cs) == expected_rows)
stopifnot(!any(duplicated(catch_cs[, c("stock_id", "year")])))

# -----------------------------------------------------------------------------
# Cross-check vs CSV existente (debe ser <1% para todas las celdas)
# -----------------------------------------------------------------------------

if (file.exists(OUT_CSV)) {
  old <- readr::read_csv(OUT_CSV, show_col_types = FALSE) %>%
    dplyr::rename(catch_t_old = catch_t)
  comp <- catch_cs %>%
    dplyr::full_join(old, by = c("stock_id", "year")) %>%
    dplyr::mutate(diff   = catch_t - catch_t_old,
                  pct    = round(100 * diff / catch_t_old, 4)) %>%
    dplyr::arrange(stock_id, year)

  worst <- comp %>%
    dplyr::filter(!is.na(catch_t_old)) %>%
    dplyr::slice_max(abs(pct), n = 1)
  cat(sprintf("[sernapesca-v3] Cross-check vs CSV anterior: peor diff = %+.3f%% (%s %d)\n",
              worst$pct, worst$stock_id, worst$year))
  cat(sprintf("    (esperado <0.5%% si v2 era hibrido SERNAPESCA + IFOP-cerco 2024)\n"))

  flag <- comp %>% dplyr::filter(!is.na(catch_t_old), abs(pct) > 1) %>% nrow()
  if (flag > 0) {
    cat(sprintf("[sernapesca-v3] WARNING: %d celdas con |diff| > 1%%; revisar.\n",
                flag))
    print(comp %>% dplyr::filter(!is.na(catch_t_old), abs(pct) > 1) %>%
            dplyr::select(stock_id, year, catch_t, catch_t_old, diff, pct))
  } else {
    cat("[sernapesca-v3] Todas las celdas dentro de tolerancia 1%. Safe.\n")
  }
}

# -----------------------------------------------------------------------------
# Escritura
# -----------------------------------------------------------------------------

readr::write_csv(catch_cs, OUT_CSV)
cat(sprintf("[sernapesca-v3] Guardado: %s (%d filas)\n",
            OUT_CSV, nrow(catch_cs)))

cat("\n[sernapesca-v3] Resumen 2024 (primer año oficial post-placeholder):\n")
print(catch_cs %>% dplyr::filter(year == 2024) %>%
        dplyr::mutate(catch_kt = round(catch_t / 1000, 1)) %>%
        dplyr::select(stock_id, year, catch_kt))

cat("\n[sernapesca-v3] Captura agregada por stock (mediana 2000-2024, kt):\n")
print(catch_cs %>%
        dplyr::group_by(stock_id) %>%
        dplyr::summarise(catch_kt_median = round(median(catch_t) / 1000, 1),
                         catch_kt_min    = round(min(catch_t) / 1000, 1),
                         catch_kt_max    = round(max(catch_t) / 1000, 1),
                         .groups = "drop"))
