# =============================================================================
# FONDECYT -- 02_inspect_jjm_qs.R
#
# Inspector del output JJM (Hipótesis H1 = 1 stock) serializado en formato qs,
# bajado desde SPRFMO/SCW15_report/data/h1_1.07.qs.
#
# Objetivo: descubrir la estructura del objeto y extraer series/priors
# usables para jurel:
#   - SSB histórico (Y(t))
#   - Reclutas históricos (R(t))
#   - F histórico
#   - Estimaciones puntuales de M, h, steepness, B0
#
# Uso (local, necesita R):
#   setwd("paper1/")
#   source("R/07_structural_bio/02_inspect_jjm_qs.R")
# =============================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("qs", quietly = TRUE)) {
    install.packages("qs")
  }
  library(qs)
  library(dplyr)
  library(tibble)
  library(purrr)
})

QS_PATH <- file.path("data", "bio_params", "h1_1.07.qs")

stopifnot(file.exists(QS_PATH))

cat(strrep("=", 70), "\n")
cat("Inspección h1_1.07.qs -- JJM Operating Model (H1 = 1 stock)\n")
cat(strrep("=", 70), "\n\n")

obj <- qs::qread(QS_PATH)

# --------------------------------------------------------------- top-level ----
cat("Clase:        ", paste(class(obj), collapse = " / "), "\n")
cat("Tipo base:    ", typeof(obj), "\n")
cat("Longitud:     ", length(obj), "\n")
if (!is.null(names(obj))) {
  cat("Nombres top:\n")
  print(names(obj))
}
cat("\n", strrep("-", 70), "\n", sep = "")
cat("Estructura (profundidad 2):\n\n")
str(obj, max.level = 2, list.len = 50)

# --------------------------------------------------- helpers de exploración ---
dig <- function(x, path = "", depth = 0, max_depth = 4) {
  if (depth > max_depth) return(invisible(NULL))
  if (is.list(x) && !is.null(names(x))) {
    for (nm in names(x)) {
      cur <- paste0(path, "$", nm)
      el  <- x[[nm]]
      tag <- sprintf("%-50s [%s, len=%d]",
                     cur, paste(class(el), collapse = "/"), length(el))
      cat(tag, "\n")
      dig(el, cur, depth + 1, max_depth)
    }
  }
}

cat("\n", strrep("-", 70), "\n", sep = "")
cat("Árbol completo hasta profundidad 4:\n\n")
dig(obj)

# ------------------------------------------ candidatos a series de interés ---
cat("\n", strrep("-", 70), "\n", sep = "")
cat("Candidatos con nombres típicos (SSB, R, F, M, h, B0):\n\n")

pat <- "(?i)(ssb|biomass|recruit|^r$|^f$|f_age|f_full|natural_m|^m$|steep|^h$|^b0$|virgin)"

find_pat <- function(x, path = "") {
  hits <- character()
  if (is.list(x) && !is.null(names(x))) {
    for (nm in names(x)) {
      if (grepl(pat, nm, perl = TRUE)) {
        hits <- c(hits, paste0(path, "$", nm))
      }
      hits <- c(hits, find_pat(x[[nm]], paste0(path, "$", nm)))
    }
  }
  hits
}

hits <- find_pat(obj)
if (length(hits) == 0) {
  cat("  (no encontrados por nombre -- hay que explorar a mano con str())\n")
} else {
  for (h in hits) cat("  ", h, "\n")
}

# ------------------- intento automático de extracción de series temporales ---
cat("\n", strrep("-", 70), "\n", sep = "")
cat("Intento de extracción automática de series temporales:\n\n")

try_extract_vec <- function(path_expr) {
  tryCatch({
    v <- eval(parse(text = paste0("obj", path_expr)))
    if (is.numeric(v) && length(v) >= 10 && length(v) <= 100) {
      cat(sprintf("  %-40s  n=%3d  rango=[%.3g, %.3g]\n",
                  path_expr, length(v), min(v, na.rm=TRUE), max(v, na.rm=TRUE)))
      return(tibble::tibble(var = path_expr, value = v, t = seq_along(v)))
    }
  }, error = function(e) NULL)
  NULL
}

series <- purrr::map_dfr(hits, try_extract_vec)
if (nrow(series) > 0) {
  saveRDS(series, "data/bio_params/jjm_series_extracted.rds")
  cat("\n  Guardadas en data/bio_params/jjm_series_extracted.rds\n")
}

cat("\n", strrep("=", 70), "\n", sep = "")
cat("Terminó la inspección. Revisá el árbol de arriba y decime qué rama\n")
cat("contiene las series (SSB, F, R) para escribir el extractor definitivo.\n")
cat(strrep("=", 70), "\n")
