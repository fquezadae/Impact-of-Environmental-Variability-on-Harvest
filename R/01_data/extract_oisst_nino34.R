# =============================================================================
# FONDECYT -- extract_oisst_nino34.R
#
# Paper 1, pivote ENSO (decidido 2026-05-04): construye serie historica del
# indice Nino 3.4 anual sobre 2000-2024 para uso como shifter climatico
# basin-scale en el refit T4b-full con Eq. 11 stock-specific (jurel forzado
# por ENSO; anch y sard mantienen SST_D1 + logCHL_D1 sin cambios).
#
# Fuente: NOAA-CPC sstoi.indices, derivado de ERSSTv5 mensual sobre la region
# Nino 3.4 (lat [-5, +5], lon [-170, -120]).
#   URL: https://www.cpc.ncep.noaa.gov/data/indices/sstoi.indices
#   Cobertura: 1982-01 a presente, monthly absolute SST (degC) y anomaly.
#   Es la fuente canonica que cita Pena-Torres et al. (2017) y la literatura
#   de pesquerias chilenas que usa ENSO. Para nuestra ventana 2000-2024
#   ERSSTv5 es estable (no hay reproceso significativo dentro del periodo).
#
# Convencion de centering: media muestral 2000-2024 sobre la serie anual,
# IDENTICA a la convencion usada en R/06_projections/06_extended_env_anomalies.R
# para SST_D1 y logCHL_D1. Esto deja el shifter ENSO apples-to-apples con los
# costeros y compatible con la Eq. 11 stock-specific del Apendice E.
#
# La anomalia publicada por NOAA-CPC (col 10 del archivo) usa el baseline
# rolling 1991-2020 y NO es lo que necesitamos -- se reporta solamente como
# sanity. Ver el bloque de validacion al final del script.
#
# Salidas:
#   - data/bio_params/enso_nino34_annual_2000_2024.csv
#       columnas: year, n_months, nino34_sst, nino34_anom_cpc, ENSO_c
#   - data/bio_params/enso_nino34_diagnostics.txt
#       (sanity: cor con SST_D1, sd, range, lag-1 cor)
#   - <dirdata>raw/climate_extended/sstoi_indices_<DATE>.txt   (cache)
#
# Uso:
#   source("R/00_config/config.R")
#   source("R/01_data/extract_oisst_nino34.R")
#
# Lo siguiente (no en este script):
#   - R/06_projections/download_cmip6_ensemble.py corrido con bbox Nino 3.4
#     (Felipe corre paralelo).
#   - R/08_stan_t4/14_refit_t4b_full_appendix_e.R extendido para soportar
#     covariate stock-specific (jurel = ENSO; anch/sard = SST_D1 + logCHL_D1).
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})

if (!exists("dirdata")) source("R/00_config/config.R")

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
ENSO_WINDOW   <- 2000:2024
ENSO_URL      <- "https://www.cpc.ncep.noaa.gov/data/indices/sstoi.indices"

ENSO_CACHE_DIR <- file.path(dirdata, "raw", "climate_extended")
ENSO_OUT_DIR   <- "data/bio_params"

dir.create(ENSO_CACHE_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(ENSO_OUT_DIR,   recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Helper: descargar el sstoi.indices (con cache de reproducibilidad)
# -----------------------------------------------------------------------------
download_sstoi_indices <- function(force = FALSE) {
  cache_file <- file.path(ENSO_CACHE_DIR,
                          sprintf("sstoi_indices_%s.txt",
                                  format(Sys.Date(), "%Y%m%d")))
  if (!force && file.exists(cache_file)) {
    cat(sprintf("[enso] usando cache: %s\n", basename(cache_file)))
    return(cache_file)
  }
  cat(sprintf("[enso] descargando: %s\n", ENSO_URL))
  ok <- tryCatch({
    utils::download.file(ENSO_URL, cache_file,
                         mode = "wb", quiet = FALSE,
                         method = "auto")
    TRUE
  }, error = function(e) {
    cat("[enso] download.file fallo: ", conditionMessage(e), "\n")
    FALSE
  })
  if (!ok || !file.exists(cache_file) || file.size(cache_file) < 1000) {
    stop("[enso] no pude descargar sstoi.indices. ",
         "Probar con un cliente HTTPS distinto o descargar manualmente y ",
         "guardarlo en: ", cache_file)
  }
  cat(sprintf("[enso] descargado OK (%d bytes)\n", file.size(cache_file)))
  cache_file
}

# -----------------------------------------------------------------------------
# Helper: parsear sstoi.indices (whitespace-delimited)
# Header esperado: YR MON NINO1+2 ANOM NINO3 ANOM NINO4 ANOM NINO3.4 ANOM
# -----------------------------------------------------------------------------
parse_sstoi_indices <- function(path) {
  raw <- readr::read_lines(path)
  if (length(raw) < 10) stop("[enso] archivo demasiado corto: ", path)
  if (!grepl("^\\s*YR", raw[1])) {
    stop("[enso] header inesperado en sstoi.indices: '", raw[1], "'")
  }
  body <- raw[-1]
  # Whitespace-delimited; columnas con nombres de mi propia convencion
  dt <- readr::read_table(
    paste(body, collapse = "\n"),
    col_names = c("year", "month",
                  "nino12_sst", "nino12_anom",
                  "nino3_sst",  "nino3_anom",
                  "nino4_sst",  "nino4_anom",
                  "nino34_sst", "nino34_anom"),
    col_types = cols(
      .default       = col_double(),
      year           = col_integer(),
      month          = col_integer()
    ),
    show_col_types = FALSE
  )
  if (any(is.na(dt$nino34_sst))) {
    n_na <- sum(is.na(dt$nino34_sst))
    warning("[enso] ", n_na, " filas con NA en NINO3.4; se descartan.")
    dt <- dt[!is.na(dt$nino34_sst), ]
  }
  dt
}

# -----------------------------------------------------------------------------
# Helper: agregar mensual -> anual y centrar sobre 2000-2024
# -----------------------------------------------------------------------------
build_enso_annual <- function(monthly, window) {
  yr <- monthly %>%
    dplyr::filter(year %in% window) %>%
    dplyr::group_by(year) %>%
    dplyr::summarise(
      n_months         = dplyr::n(),
      nino34_sst       = mean(nino34_sst, na.rm = TRUE),
      nino34_anom_cpc  = mean(nino34_anom, na.rm = TRUE),
      .groups = "drop"
    )
  if (nrow(yr) != length(window)) {
    stop(sprintf("[enso] esperaba %d anios, obtuve %d. Revisar window/cobertura.",
                 length(window), nrow(yr)))
  }
  if (any(yr$n_months != 12L)) {
    bad <- yr$year[yr$n_months != 12L]
    stop("[enso] cobertura mensual incompleta en anos: ",
         paste(bad, collapse = ", "))
  }
  yr %>%
    dplyr::mutate(ENSO_c = nino34_sst - mean(nino34_sst))
}

# -----------------------------------------------------------------------------
# Sanity: cargar SST_D1 de env_extended_3domains y reportar correlaciones
# -----------------------------------------------------------------------------
load_sst_d1 <- function() {
  ext_csv <- file.path(ENSO_OUT_DIR, "env_extended_3domains_2000_2024.csv")
  if (!file.exists(ext_csv)) {
    warning("[enso] no encontre ", ext_csv, " (saltando sanity vs SST_D1).")
    return(NULL)
  }
  ext <- readr::read_csv(ext_csv, show_col_types = FALSE)
  ext %>%
    dplyr::filter(domain == "centro_sur_eez", year %in% ENSO_WINDOW) %>%
    dplyr::arrange(year) %>%
    dplyr::select(year, SST_D1_c = SST_c, logCHL_D1_c = logCHL_c)
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("enso.run_main", TRUE))) {

  cat(strrep("=", 72), "\n", sep = "")
  cat("Paper 1 -- pivote ENSO: construyendo serie anual Nino 3.4 (2000-2024)\n")
  cat("Fuente: NOAA-CPC sstoi.indices (ERSSTv5)\n")
  cat("Centering: media muestral 2000-2024 (paralelo a SST_D1, logCHL_D1)\n")
  cat(strrep("=", 72), "\n\n", sep = "")

  src_path  <- download_sstoi_indices()
  monthly   <- parse_sstoi_indices(src_path)
  cat(sprintf("[enso] %d filas mensuales, rango %d-%d a %d-%d\n",
              nrow(monthly),
              min(monthly$year), min(monthly$month[monthly$year ==
                                                     min(monthly$year)]),
              max(monthly$year), max(monthly$month[monthly$year ==
                                                     max(monthly$year)])))

  enso_yr <- build_enso_annual(monthly, ENSO_WINDOW)

  out_csv <- file.path(ENSO_OUT_DIR, "enso_nino34_annual_2000_2024.csv")
  readr::write_csv(enso_yr, out_csv)
  cat(sprintf("\n[enso] escribi %s (%d filas)\n", out_csv, nrow(enso_yr)))

  # ---- Sanity 1: stats descriptivos -----------------------------------------
  cat(sprintf("\n[enso] descriptivos serie anual (2000-2024):\n"))
  cat(sprintf("  nino34_sst   : mean=%.3f  sd=%.3f  range=[%.2f, %.2f]\n",
              mean(enso_yr$nino34_sst), sd(enso_yr$nino34_sst),
              min(enso_yr$nino34_sst),  max(enso_yr$nino34_sst)))
  cat(sprintf("  ENSO_c (own) : sd=%.3f  range=[%.2f, %.2f]\n",
              sd(enso_yr$ENSO_c),
              min(enso_yr$ENSO_c), max(enso_yr$ENSO_c)))
  cat(sprintf("  CPC anom 91-20: sd=%.3f  range=[%.2f, %.2f]\n",
              sd(enso_yr$nino34_anom_cpc),
              min(enso_yr$nino34_anom_cpc),
              max(enso_yr$nino34_anom_cpc)))
  cat(sprintf("  cor(ENSO_c, CPC anom) = %.4f  ",
              cor(enso_yr$ENSO_c, enso_yr$nino34_anom_cpc)))
  cat("(esperado ~0.99: misma serie con baseline distinto)\n")

  # ---- Sanity 2: cor con SST_D1 y logCHL_D1 ---------------------------------
  d1 <- load_sst_d1()
  if (!is.null(d1)) {
    join <- dplyr::inner_join(enso_yr, d1, by = "year")
    cat(sprintf("\n[enso] cor con dominios costeros (paper 1):\n"))
    cat(sprintf("  cor(ENSO_c, SST_D1_c)    = %+.3f  ",
                cor(join$ENSO_c, join$SST_D1_c)))
    cat("(esperado <0.30: si sale alto, considerar implicancias)\n")
    cat(sprintf("  cor(ENSO_c, logCHL_D1_c) = %+.3f\n",
                cor(join$ENSO_c, join$logCHL_D1_c)))
    cat(sprintf("  cor lag1 (ENSO_{t-1} vs SST_D1_t) = %+.3f\n",
                cor(join$ENSO_c[-nrow(join)], join$SST_D1_c[-1])))
  }

  # ---- Sanity 3: identificar anos El Nino fuertes (corroboracion historica)--
  cat(sprintf("\n[enso] anos top El Nino (ENSO_c) y top La Nina:\n"))
  ord <- enso_yr %>% dplyr::arrange(dplyr::desc(ENSO_c))
  cat("  El Nino (top 5):  ")
  cat(paste(sprintf("%d (%+.2f)", ord$year[1:5], ord$ENSO_c[1:5]),
            collapse = ", "), "\n")
  cat("  La Nina (top 5):  ")
  cat(paste(sprintf("%d (%+.2f)",
                    ord$year[nrow(ord):(nrow(ord) - 4)],
                    ord$ENSO_c[nrow(ord):(nrow(ord) - 4)]),
            collapse = ", "), "\n")
  cat("  (esperado: 2015 y 2023 entre top El Nino; 2010-2011, 2007 entre top La Nina)\n")

  # ---- Diagnostics file -----------------------------------------------------
  diag_path <- file.path(ENSO_OUT_DIR, "enso_nino34_diagnostics.txt")
  sink(diag_path)
  cat("ENSO Nino 3.4 anual 2000-2024 -- diagnosticos\n")
  cat("Fuente: NOAA-CPC sstoi.indices (ERSSTv5)\n")
  cat("Generado: ", as.character(Sys.time()), "\n")
  cat(strrep("-", 60), "\n", sep = "")
  cat(sprintf("nino34_sst      : mean=%.3f sd=%.3f\n",
              mean(enso_yr$nino34_sst), sd(enso_yr$nino34_sst)))
  cat(sprintf("ENSO_c          : sd=%.3f\n", sd(enso_yr$ENSO_c)))
  cat(sprintf("lag-1 autocor   : %.3f\n",
              cor(enso_yr$ENSO_c[-1], enso_yr$ENSO_c[-nrow(enso_yr)])))
  if (!is.null(d1)) {
    join <- dplyr::inner_join(enso_yr, d1, by = "year")
    cat(sprintf("cor(ENSO, SST_D1)    = %+.3f\n",
                cor(join$ENSO_c, join$SST_D1_c)))
    cat(sprintf("cor(ENSO, logCHL_D1) = %+.3f\n",
                cor(join$ENSO_c, join$logCHL_D1_c)))
  }
  sink()
  cat(sprintf("\n[enso] diagnosticos en: %s\n", diag_path))

  cat("\n[enso] DONE. Siguiente paso: ",
      "extender pipeline Stan T4b para covariate jurel-specific = ENSO.\n")
}
