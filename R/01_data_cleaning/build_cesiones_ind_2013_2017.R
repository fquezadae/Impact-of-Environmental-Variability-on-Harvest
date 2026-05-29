# =============================================================================
# build_cesiones_ind_2013_2017.R
# -----------------------------------------------------------------------------
# Reconstruye la CESIÓN INDUSTRIAL Centro-Sur (unidad V-X) por año/especie
# (anchoveta y sardina común) a partir de los workbooks SERNAPESCA originales
# "Control Cuotas globales industriales ... LTP y PEP", para reemplazar la
# cifra "11–72%" del Online Appendix H.3 con un rango VERIFICADO y para
# corregir las filas 2013–2017 de cesiones_consolidated_2013_2024.csv
# (ese consolidated está mal: shares 0–28% y valores erráticos tipo 3673 kt).
#
# CONTEXTO / HALLAZGOS (ver paper1/portfolio_check/raw_sernapesca/NOTA_*.md):
#   * Fuente correcta = workbook INDUSTRIAL, hoja "Pelagicos LTP", unidad V-X.
#   * Las FECHAS internas de las planillas son artefactos de plantilla
#     (el archivo 2014 trae fechas "2007"; el "2016" trae 2015) -> usar el
#     AÑO DEL TÍTULO/archivo, NO las fechas de las celdas.
#   * Cada año tiene layout distinto -> config por año más abajo.
#   * VALOR VERIFICADO (2017, filas de subtotal, = cesiones_ind_2013_2017_raw.csv):
#       Anchoveta V-X:      asignada 12558.0 t, cesión -9034.18 t  -> 71.9%
#       Sardina Común V-X:  asignada 72401.5 t, cesión -48885.2 t  -> 67.5%
#     El script ASSERTA estos valores; si no los reproduce, NO confíes en el
#     resto y revisá la config del año.
#
# REQUISITOS: install.packages(c("readxl","dplyr","stringr","here"))
#   readxl lee .xls y .xlsx nativamente (no hace falta convertir nada).
#
# USO: Rscript R/01_data_cleaning/build_cesiones_ind_2013_2017.R
#   Imprime, por año/especie, el bloque de la unidad V-X y los totales,
#   para que VALIDES a ojo antes de usar los números en el paper.
# =============================================================================

suppressPackageStartupMessages({
  library(readxl); library(dplyr); library(stringr); library(here)
})

RAW <- here::here("paper1", "portfolio_check", "raw_sernapesca")

# --- helpers -----------------------------------------------------------------
norm <- function(x) stringr::str_squish(tolower(ifelse(is.na(x), "", as.character(x))))

# ¿la celda de col1 es el encabezado de una unidad de pesquería de la especie en V-X?
# (zona "v-x"/"v - x", excluye XV-II, III-IV, V-IX, XIV-X, etc.)
is_unit_header <- function(cell, species) {
  s <- norm(cell)
  if (s == "") return(FALSE)
  sp_ok <- if (species == "anchoveta") str_starts(s, "anchoveta")
           else str_detect(s, "^s(ardina)?\\.? ?com")
  if (!sp_ok) return(FALSE)
  z <- str_remove_all(s, "\\s")            # quita espacios para testear la zona
  str_detect(z, "v-x") && !str_detect(z, "xv") &&
    !str_detect(z, "iii") && !str_detect(z, "v-ix") && !str_detect(z, "xiv")
}
# ¿col1 abre OTRA unidad (para cerrar el bloque actual)?
is_any_unit <- function(cell) {
  s <- norm(cell)
  str_detect(s, "^(anchoveta|sardina|s\\.? ?com|jurel|caballa|merluza|sard)")
}

# --- CONFIG POR AÑO ----------------------------------------------------------
# col_asig / col_ces son ÍNDICES DE COLUMNA (base 1) en la hoja.
# mode = "per_titular" : asignada = suma de col_asig en filas con titular (col2)
#                        no vacío (1ra fila de período); cesión = suma de col_ces.
# mode = "subtotal"    : usa las filas de subtotal por unidad (col1,col2,col3
#                        vacíos, col_asig numérico); toma el subtotal de mayor
#                        asignada dentro del bloque (= total LTP de la unidad).
cfg <- list(
  `2013` = list(file = "Control Cuotas globales industriales y Asignadas por Titular LTP y PEP 2013.xls",
                sheet = "Pelagicos LMC y LTP ",  col_asig = 3, col_ces = 4, mode = "per_titular"),
  `2014` = list(file = "Control Cuotas globales industriales y Asignadas por Titular LTP y PEP 2014.xls",
                sheet = "Pelagicos LTP ",        col_asig = 5, col_ces = 6, mode = "per_titular"),
  `2015` = list(file = "Control Cuotas globales industriales y Asignadas por Titular LTP y PEP 2015.xlsx",
                sheet = "Pelagicos LTP ",        col_asig = 5, col_ces = 6, mode = "per_titular"),
  `2016` = list(file = "Control Cuotas globales industriales y Asignadas por Titular LTP y PEP 2016.xlsx",
                sheet = "Pelagicos LTP ",        col_asig = 5, col_ces = 6, mode = "per_titular"),
  `2017` = list(file = "Control Cuotas globales industriales y Asignadas por Titular LTP y PEP 2017.xlsx",
                sheet = "Pelagicos LTP",         col_asig = 4, col_ces = 5, mode = "subtotal")
)
# NOTA columnas: índices base-1. En 2013 la hoja LMC tiene
#   col1=Unidad, col2=Armador, col3="Cuota LMC", col4="Cesiones o traspasos".
#   En 2014-2016: col1=Unidad, col2=Titular, col3/4=fechas, col5=Asignada, col6=Cesión.
#   En 2017: col1=Unidad, col2=Titular, col3=Período(texto), col4=Asignada, col5=Cesión.
#   (Revisá con readxl si SERNAPESCA reusó el formato; ajustá aquí si cambió.)

num <- function(x) suppressWarnings(as.numeric(x))

extract_unit <- function(df, species, col_asig, col_ces, mode, verbose = TRUE) {
  n <- nrow(df)
  in_block <- FALSE; asig <- 0; ces <- 0; rows_used <- list()
  sub_candidates <- list()
  for (i in seq_len(n)) {
    c1 <- df[[1]][i]
    if (!is.na(c1) && nzchar(norm(c1))) {
      if (is_unit_header(c1, species)) { in_block <- TRUE }
      else if (is_any_unit(c1))        { in_block <- FALSE }
    }
    if (!in_block) next
    a  <- num(df[[col_asig]][i]); ce <- num(df[[col_ces]][i])
    c2 <- df[[2]][i]
    if (mode == "per_titular") {
      # asignada: sólo en filas que abren un titular (col2 no vacío y no fecha)
      titular_row <- !is.na(c2) && nzchar(norm(c2)) && is.na(suppressWarnings(as.numeric(c2)))
      if (titular_row && !is.na(a)) { asig <- asig + a; rows_used[[length(rows_used)+1]] <- i }
      if (!is.na(ce)) ces <- ces + ce
    } else { # subtotal
      sub_row <- (is.na(c2) || !nzchar(norm(c2))) &&
                 (is.na(df[[3]][i]) || !nzchar(norm(df[[3]][i]))) && !is.na(a) && a > 0
      if (sub_row) sub_candidates[[length(sub_candidates)+1]] <- list(i = i, a = a, ce = ce)
    }
  }
  if (mode == "subtotal") {
    if (length(sub_candidates) == 0) return(list(asignada = NA, cesion = NA))
    # toma el subtotal de MAYOR asignada (= total LTP de la unidad)
    best <- sub_candidates[[which.max(sapply(sub_candidates, `[[`, "a"))]]
    asig <- best$a; ces <- ifelse(is.na(best$ce), 0, best$ce)
    rows_used <- list(best$i)
  }
  if (verbose) cat(sprintf("    [%s] filas usadas: %s\n", species,
                           paste(unlist(rows_used), collapse = ",")))
  list(asignada = asig, cesion = ces)
}

# --- loop ---------------------------------------------------------------------
out <- list()
for (yr in names(cfg)) {
  cf <- cfg[[yr]]
  path <- file.path(RAW, cf$file)
  cat(sprintf("\n===== %s :: %s :: %s (mode=%s) =====\n", yr, basename(cf$file), cf$sheet, cf$mode))
  if (!file.exists(path)) { cat("  ARCHIVO NO ENCONTRADO:", path, "\n"); next }
  df <- tryCatch(
    read_excel(path, sheet = cf$sheet, col_names = FALSE, col_types = "text", .name_repair = "minimal"),
    error = function(e) { cat("  ERROR leyendo:", conditionMessage(e), "\n"); NULL })
  if (is.null(df)) next
  for (sp in c("anchoveta", "sardina")) {
    r <- extract_unit(df, sp, cf$col_asig, cf$col_ces, cf$mode)
    if (is.na(r$asignada) || r$asignada <= 0) { cat(sprintf("  %s: sin datos\n", sp)); next }
    share <- abs(r$cesion) / r$asignada
    cat(sprintf("  %-9s asignada=%10.1f t  cesion=%11.1f t  share=%6.1f%%\n",
                sp, r$asignada, r$cesion, 100 * share))
    out[[length(out)+1]] <- data.frame(year = as.integer(yr), species = sp,
                                        IND_asignada_t = r$asignada, IND_cesion_t = r$cesion,
                                        share = share)
  }
}
res <- dplyr::bind_rows(out)

# --- VALIDACIÓN 2017 (no negociable) -----------------------------------------
chk <- function(y, sp, a_exp, c_exp) {
  row <- res %>% filter(year == y, species == sp)
  if (nrow(row) == 0) { cat(sprintf("VALIDACION %d %s: FALTA\n", y, sp)); return(FALSE) }
  ok <- abs(row$IND_asignada_t - a_exp) < 5 && abs(row$IND_cesion_t - c_exp) < 5
  cat(sprintf("VALIDACION %d %-9s: asignada %.1f (esp %.1f) cesion %.1f (esp %.1f) -> %s\n",
              y, sp, row$IND_asignada_t, a_exp, row$IND_cesion_t, c_exp, ifelse(ok, "OK", "*** FALLA ***")))
  ok
}
cat("\n----- validación contra 2017 verificado -----\n")
v1 <- chk(2017, "anchoveta", 12558.0, -9034.18)
v2 <- chk(2017, "sardina",   72401.5, -48885.2)
if (!(v1 && v2)) warning("La validación 2017 falló: revisá la config del año antes de usar los números 2013-2016.")

# --- resumen + rango ----------------------------------------------------------
res <- res %>% mutate(share_pct = round(100 * share, 1))
cat("\n----- TABLA RECONSTRUIDA (anchoveta + sardina común, V-X) -----\n")
print(res, row.names = FALSE)
cat(sprintf("\nRANGO share cedido IND->ART 2013-2017 = %.0f%% a %.0f%%\n",
            100 * min(res$share), 100 * max(res$share)))
cat("  -> usar este rango (redondeado) para reemplazar el '11-72%' del Online Appendix H.3.\n")

# --- salida -------------------------------------------------------------------
outpath <- here::here("paper1", "portfolio_check", "cesiones_ind_2013_2017_rebuilt.csv")
write.csv(res, outpath, row.names = FALSE)
cat(sprintf("\nEscrito: %s\n", outpath))
cat("Revisá las filas/bloques impresos arriba antes de pisar cesiones_consolidated_2013_2024.csv.\n")
