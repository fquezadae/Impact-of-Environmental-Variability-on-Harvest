# =============================================================================
# FONDECYT -- 99_aggregate_catch_cs_from_xlsx.R
#
# FUENTE: IFOP -- "4. DESEMBARQUES.xlsx" (archivo institucional, 2026-04-23).
# Agrega desembarques (captura landed) Centro-Sur V-X para los 3 stocks SPF
# (anchoveta_cs, sardina_comun_cs, jurel_cs). Genera CSV con estructura
# identica a catch_annual_paper1.csv (previo, SERNAPESCA) pero extendido a 2024.
#
# CAMBIO DE FUENTE (2026-04-23): se migra de SERNAPESCA a IFOP. Motivacion:
#   (1) Consistencia metodologica: priors r/K/M del YAML vienen de modelos
#       IFOP SCAA; usar captura IFOP con biomasa IFOP es mismo organismo,
#       misma definicion de captura (incluye ajustes post-temporada y
#       sub-reporte que SERNAPESCA no incluye).
#   (2) Cobertura: IFOP llega a 2024; SERNAPESCA consolidada a 2023.
#   (3) Cruce IFOP vs SERNAPESCA 2019-2023: diferencias <1.3% en los 3 stocks
#       (max: jurel 2021 -1.3%). Las series son equivalentes a nivel de
#       magnitud; las diferencias residuales son ajustes por descartes y
#       sub-reporte que IFOP contabiliza.
#
# METODOLOGIA:
#   - INDUSTRIAL (nacional): filtro a regiones CS {V=5, VIII=8, XIV=14, X=10}.
#     No hay columnas industrial VI/VII/IX porque no hay operacion industrial
#     en esas regiones (pesca industrial se concentra en V-VIII-X con XIV como
#     region creada 2007 desde X).
#   - LANCHAS (CentroSur): todas las cols de region son CS {V=5, VII=7, VIII=8,
#     IX=9, XIV=14, X=10, XI=11} -- la hoja ya esta pre-filtrada por IFOP.
#   - BOTES (CentroSur): idem lanchas.
#   - Captura CS anual = suma de las 3 flotas por especie y ano.
#
# Output:
#   - data/bio_params/catch_annual_cs_2000_2024.csv
#     columnas: stock_id, year, catch_t  (mismo schema que
#     catch_annual_paper1.csv pero 2024 incluido)
#
# Corre con:
#   source("R/01_data/99_aggregate_catch_cs_from_xlsx.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readxl)
  library(readr)
})

# Preserva nombre original del archivo institucional IFOP (con espacio tras el "4.").
XLSX_PATH   <- "data/bio_params/refs/deep_search/4. DESEMBARQUES.xlsx"
XLSX_UPLOAD <- "/sessions/quirky-upbeat-dirac/mnt/uploads/4. DESEMBARQUES.xlsx"
OUT_CSV     <- "data/bio_params/catch_annual_cs_2000_2024.csv"

# Usar la ruta local si esta, si no el upload directo (para correr en worker).
xlsx_path <- if (file.exists(XLSX_PATH)) XLSX_PATH else XLSX_UPLOAD
if (!file.exists(xlsx_path)) {
  stop("[catch-xlsx] No encuentro el Excel fuente. Esperaba:\n  ", XLSX_PATH,
       call. = FALSE)
}

# Regiones CS V-X (+ XIV Los Rios = creada 2007 desde X; + XVI Nuble = creada
# 2018 desde VIII, pero no aparece en headers del Excel). Todas numero entero.
CS_REGIONS <- c(5, 6, 7, 8, 9, 10, 14, 16)

SPECIES_MAP <- c("JUREL" = "jurel_cs",
                 "SARDINA COMÚN" = "sardina_comun_cs",
                 "ANCHOVETA" = "anchoveta_cs")

# -----------------------------------------------------------------------------
# Parser: extrae bloques por especie desde una hoja
# -----------------------------------------------------------------------------
parse_sheet_blocks <- function(xlsx_path, sheet) {
  raw <- suppressMessages(readxl::read_excel(xlsx_path, sheet = sheet,
                                             col_names = FALSE, .name_repair = "minimal"))
  species_row <- unlist(raw[1, ])
  header_row  <- unlist(raw[2, ])
  data        <- raw[-c(1, 2), , drop = FALSE]

  # Identificar indices de columna por especie (hasta el siguiente species header)
  blocks <- list()
  current_sp <- NA_character_
  block_cols <- integer(0)
  for (j in seq_along(species_row)) {
    v <- species_row[j]
    if (!is.na(v) && is.character(v) && v %in% names(SPECIES_MAP)) {
      if (!is.na(current_sp)) blocks[[current_sp]] <- block_cols
      current_sp <- v
      block_cols <- j
    } else if (!is.na(current_sp)) {
      block_cols <- c(block_cols, j)
    }
  }
  if (!is.na(current_sp)) blocks[[current_sp]] <- block_cols

  list(data = data, header = header_row, blocks = blocks)
}

# -----------------------------------------------------------------------------
# Para un bloque, sumar columnas de regiones CS y agrupar por ano
# -----------------------------------------------------------------------------
aggregate_block_cs <- function(data, header, cols, cs_regions) {
  # En cada bloque: col 1 = year, col 2 = month, cols 3..N-1 = regiones,
  # col N = "Total general" (string, se excluye).
  year_col   <- cols[1]
  region_cols <- cols[3:(length(cols) - 1)]   # descarta year, month, total
  # header[region_cols] contiene los numeros de region (pueden ser chr "5" o num 5)
  region_nums <- suppressWarnings(as.integer(header[region_cols]))
  keep <- which(!is.na(region_nums) & region_nums %in% cs_regions)
  if (length(keep) == 0) return(tibble::tibble(year = integer(), catch_t = numeric()))
  cs_cols <- region_cols[keep]

  years <- suppressWarnings(as.integer(unlist(data[[year_col]])))
  # Suma por fila
  dat_num <- lapply(cs_cols, function(c) suppressWarnings(as.numeric(unlist(data[[c]]))))
  row_sum <- Reduce(`+`, lapply(dat_num, function(x) ifelse(is.na(x), 0, x)))

  df <- tibble::tibble(year = years, catch_t = row_sum) %>%
    dplyr::filter(!is.na(year)) %>%
    dplyr::group_by(year) %>%
    dplyr::summarise(catch_t = sum(catch_t, na.rm = TRUE), .groups = "drop")
  df
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
cat("[catch-xlsx] Leyendo", xlsx_path, "\n")

all_parts <- list()
for (sheet in c("INDUSTRIAL (nacional)", "LANCHAS (CentroSur)", "BOTES (CentroSur)")) {
  parsed <- parse_sheet_blocks(xlsx_path, sheet)
  for (sp_excel in names(parsed$blocks)) {
    cols <- parsed$blocks[[sp_excel]]
    agg <- aggregate_block_cs(parsed$data, parsed$header, cols, CS_REGIONS)
    if (nrow(agg) > 0) {
      agg$stock_id <- SPECIES_MAP[[sp_excel]]
      agg$fleet    <- sheet
      all_parts[[length(all_parts) + 1]] <- agg
    }
  }
}

catch_long <- dplyr::bind_rows(all_parts)
cat("[catch-xlsx] Filas crudas agregadas:", nrow(catch_long), "\n")

# Sumar industrial + lanchas + botes por stock_id y year
catch_total <- catch_long %>%
  dplyr::group_by(stock_id, year) %>%
  dplyr::summarise(catch_t = sum(catch_t, na.rm = TRUE), .groups = "drop") %>%
  dplyr::arrange(stock_id, year)

# Validacion: comparar con catch_annual_paper1.csv donde haya overlap
old <- readr::read_csv("data/bio_params/catch_annual_paper1.csv",
                       show_col_types = FALSE) %>%
  dplyr::filter(stock_id %in% unique(catch_total$stock_id))

comp <- catch_total %>%
  dplyr::rename(new = catch_t) %>%
  dplyr::full_join(old %>% dplyr::rename(old = catch_t),
                   by = c("stock_id", "year")) %>%
  dplyr::mutate(diff = new - old,
                pct  = round(100 * diff / old, 2)) %>%
  dplyr::arrange(stock_id, year)

cat("\n[catch-xlsx] Diferencias max por stock (donde hay overlap):\n")
print(comp %>%
        dplyr::filter(!is.na(old)) %>%
        dplyr::group_by(stock_id) %>%
        dplyr::summarise(max_abs_diff_t = max(abs(diff), na.rm = TRUE),
                         max_abs_pct    = max(abs(pct),  na.rm = TRUE),
                         n_overlap      = sum(!is.na(old)),
                         .groups = "drop"))

cat("\n[catch-xlsx] Anios nuevos (no estaban en catch_annual_paper1.csv):\n")
print(comp %>% dplyr::filter(is.na(old)) %>% dplyr::select(stock_id, year, new))

# Escribir CSV final
readr::write_csv(catch_total, OUT_CSV)
cat(sprintf("\n[catch-xlsx] Guardado: %s (%d filas)\n", OUT_CSV, nrow(catch_total)))
cat(sprintf("[catch-xlsx] Rango anios: %d-%d\n",
            min(catch_total$year), max(catch_total$year)))
