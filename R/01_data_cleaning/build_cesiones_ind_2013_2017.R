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

# ¿la celda de col1 es el encabezado de una unidad de pesquería target?
# unit_key in {"anchoveta_VX","sardina_VX","jurel_VIX","jurel_XIVX"}
is_unit_header <- function(cell, unit_key) {
  s <- norm(cell)
  if (s == "") return(FALSE)
  z <- str_remove_all(s, "\\s")            # quita espacios para testear la zona
  if (unit_key == "anchoveta_VX") {
    return(str_starts(s, "anchoveta") &&
           str_detect(z, "v-x") && !str_detect(z, "xv") &&
           !str_detect(z, "iii") && !str_detect(z, "v-ix") && !str_detect(z, "xiv"))
  }
  if (unit_key == "sardina_VX") {
    return(str_detect(s, "^s(ardina)?\\.? ?com") &&
           str_detect(z, "v-x") && !str_detect(z, "xv") &&
           !str_detect(z, "iii") && !str_detect(z, "v-ix") && !str_detect(z, "xiv"))
  }
  if (unit_key == "jurel_VIX") {
    return(str_starts(s, "jurel") &&
           str_detect(z, "v-ix") && !str_detect(z, "xv") && !str_detect(z, "xiv"))
  }
  if (unit_key == "jurel_XIVX") {
    return(str_starts(s, "jurel") && str_detect(z, "xiv-x"))
  }
  FALSE
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

extract_unit <- function(df, unit_key, col_asig, col_ces, mode, verbose = TRUE) {
  n <- nrow(df)
  in_block <- FALSE; asig <- 0; ces <- 0; rows_used <- list()
  sub_candidates <- list()
  for (i in seq_len(n)) {
    c1 <- df[[1]][i]
    if (!is.na(c1) && nzchar(norm(c1))) {
      if (is_unit_header(c1, unit_key)) { in_block <- TRUE }
      else if (is_any_unit(c1))         { in_block <- FALSE }
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
  if (verbose) cat(sprintf("    [%s] filas usadas: %s\n", unit_key,
                           paste(unlist(rows_used), collapse = ",")))
  list(asignada = asig, cesion = ces)
}

# --- loop ---------------------------------------------------------------------
# Cada unidad reconstruida se reporta como una FILA en el CSV detallado
# (anchoveta V-X, sardina V-X, jurel V-IX, jurel XIV-X). El consolidated y la
# Tabla H.3b suman jurel V-IX + XIV-X en una fila "jurel" por año.
unit_map <- list(
  list(key = "anchoveta_VX", species = "anchoveta",   zone = "V-X"),
  list(key = "sardina_VX",   species = "sardina",     zone = "V-X"),
  list(key = "jurel_VIX",    species = "jurel",       zone = "V-IX"),
  list(key = "jurel_XIVX",   species = "jurel",       zone = "XIV-X")
)
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
  for (u in unit_map) {
    r <- extract_unit(df, u$key, cf$col_asig, cf$col_ces, cf$mode)
    if (is.na(r$asignada) || r$asignada <= 0) { cat(sprintf("  %-13s: sin datos\n", u$key)); next }
    share <- abs(r$cesion) / r$asignada
    cat(sprintf("  %-13s asignada=%10.1f t  cesion=%11.1f t  share=%6.1f%%\n",
                u$key, r$asignada, r$cesion, 100 * share))
    out[[length(out)+1]] <- data.frame(year = as.integer(yr), species = u$species, zone = u$zone,
                                        IND_asignada_t = r$asignada, IND_cesion_t = r$cesion,
                                        share = share)
  }
}
res <- dplyr::bind_rows(out)

# --- VALIDACIÓN 2017 (no negociable) -----------------------------------------
# Tolerancias absolutas en toneladas (kt rounded en NOTA -> 5t para anch/sard;
# jurel V-IX/XIV-X tomados de los subtotales raw, tolerancia más amplia).
chk <- function(y, sp, zn, a_exp, c_exp, tol = 5) {
  row <- res %>% filter(year == y, species == sp, zone == zn)
  if (nrow(row) == 0) { cat(sprintf("VALIDACION %d %s %s: FALTA\n", y, sp, zn)); return(FALSE) }
  ok <- abs(row$IND_asignada_t - a_exp) < tol && abs(row$IND_cesion_t - c_exp) < tol
  cat(sprintf("VALIDACION %d %-9s %-5s: asignada %.1f (esp %.1f) cesion %.1f (esp %.1f) -> %s\n",
              y, sp, zn, row$IND_asignada_t, a_exp, row$IND_cesion_t, c_exp,
              ifelse(ok, "OK", "*** FALLA ***")))
  ok
}
cat("\n----- validación contra 2017 verificado -----\n")
v1 <- chk(2017, "anchoveta", "V-X",  12558.0,  -9034.18)
v2 <- chk(2017, "sardina",   "V-X",  72401.5, -48885.2)
v3 <- chk(2017, "jurel",     "V-IX", 200384.8,  7279.2, tol = 50)
v4 <- chk(2017, "jurel",     "XIV-X", 27905.0,  2406.2, tol = 20)
if (!(v1 && v2 && v3 && v4))
  warning("La validación 2017 falló: revisá la config del año antes de usar los números 2013-2016.")

# --- resumen + rango ----------------------------------------------------------
res <- res %>% mutate(share_pct = round(100 * share, 1))
cat("\n----- TABLA RECONSTRUIDA detallada por unidad -----\n")
print(res, row.names = FALSE)

# Suma jurel V-IX + XIV-X en una fila "jurel" por año (consistente con
# cesiones_consolidated_2013_2024.csv y con la Tabla H.3b 2018-2024).
res_jurel_sum <- res %>%
  filter(species == "jurel") %>%
  group_by(year) %>%
  summarise(species = "jurel",
            zone = "V-IX + XIV-X",
            IND_asignada_t = sum(IND_asignada_t),
            IND_cesion_t   = sum(IND_cesion_t),
            .groups = "drop") %>%
  mutate(share = abs(IND_cesion_t) / IND_asignada_t,
         share_pct = round(100 * share, 1))
res_consol <- bind_rows(res %>% filter(species != "jurel"), res_jurel_sum) %>%
  arrange(year, species)

cat("\n----- VISTA CONSOLIDADA (jurel V-IX + XIV-X sumados) -----\n")
print(res_consol, row.names = FALSE)

cat(sprintf("\nRANGO share cedido anch/sard V-X 2013-2017 = %.0f%% a %.0f%%\n",
            100 * min(res$share[res$species %in% c("anchoveta","sardina")]),
            100 * max(res$share[res$species %in% c("anchoveta","sardina")])))
cat(sprintf("RANGO share cedido jurel (V-IX+XIV-X) 2013-2017 = %.1f%% a %.1f%%\n",
            100 * min(res_jurel_sum$share), 100 * max(res_jurel_sum$share)))

# --- salida -------------------------------------------------------------------
outpath <- here::here("paper1", "portfolio_check", "cesiones_ind_2013_2017_rebuilt.csv")
write.csv(res, outpath, row.names = FALSE)
cat(sprintf("\nEscrito (detallado por unidad): %s\n", outpath))

outpath_consol <- here::here("paper1", "portfolio_check", "cesiones_ind_2013_2017_consolidated_view.csv")
write.csv(res_consol, outpath_consol, row.names = FALSE)
cat(sprintf("Escrito (vista consolidada, jurel sumado): %s\n", outpath_consol))
cat("Revisá las filas/bloques impresos arriba antes de pisar cesiones_consolidated_2013_2024.csv.\n")
