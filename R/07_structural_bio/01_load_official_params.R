# =============================================================================
# FONDECYT -- 01_load_official_params.R
#
# Carga y valida parámetros de stock assessment oficiales desde el YAML
# `data/bio_params/official_assessments.yaml`.
#
# Devuelve una estructura lista-de-listas con:
#   - priors$anchoveta_cs$<param>
#   - priors$sardina_comun_cs$<param>
#   - priors$jurel$<param>
#   - status$<especie>$<indicador>
#   - hcr$<especie>$<regla>
#
# Uso:
#   source("R/07_structural_bio/01_load_official_params.R")
#   params <- load_official_assessments()
#   params$priors$anchoveta_cs$M
#   params$status$sardina_comun_cs$BD_actual_mil_t
# =============================================================================

suppressPackageStartupMessages({
  library(yaml)
  library(dplyr)
  library(tibble)
  library(purrr)
})

# --------------------------------------------------------------------- cfg ----

OFFICIAL_ASSESSMENTS_PATH <- file.path(
  "data", "bio_params", "official_assessments.yaml"
)

# Especies manejadas actualmente. Si agregamos sardina austral más adelante,
# sumarla aquí y en el YAML.
SPECIES_KEYS <- c("anchoveta_cs", "sardina_comun_cs", "jurel")

# Campos mínimos que TIENEN que estar presentes en priors_biologicos.
# Falta de cualquiera detiene el pipeline para evitar calibrar con basura.
REQUIRED_PRIOR_FIELDS <- c(
  "M_mean", "M_sd",
  "shape_n",
  "r_prior_mean", "r_prior_sd",
  "K_prior_mean_mil_t", "K_prior_sd_mil_t",
  "h_prior_mean", "h_prior_sd"
)

# ----------------------------------------------------------------- loader ----

load_official_assessments <- function(path = OFFICIAL_ASSESSMENTS_PATH) {

  if (!file.exists(path)) {
    stop("No encuentro el YAML en: ", path,
         "\nEjecutar desde la raíz de paper1/.")
  }

  # Forzar UTF-8: en Windows con locale no-UTF-8, ni readLines(encoding="UTF-8")
  # ni yaml::read_yaml() leen correctamente -- R convierte los bytes a la
  # locale nativa y rompe las secuencias multi-byte (ej. tildes espanolas).
  # Solucion robusta: leer el archivo como bytes puros y declarar UTF-8.
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  raw_bytes <- readBin(con, what = "raw", n = file.info(path)$size)
  txt <- rawToChar(raw_bytes)
  Encoding(txt) <- "UTF-8"
  raw <- yaml::yaml.load(txt)

  # Chequeo básico: las tres especies presentes
  missing_sp <- setdiff(SPECIES_KEYS, names(raw))
  if (length(missing_sp) > 0) {
    stop("El YAML no tiene las entradas de especie: ",
         paste(missing_sp, collapse = ", "))
  }

  # Construir priors_biologicos limpios (sacando metadata "_fuente")
  priors <- lapply(SPECIES_KEYS, function(sp) {
    pb <- raw[[sp]]$priors_biologicos
    if (is.null(pb)) stop("Falta priors_biologicos en ", sp)
    missing_fields <- setdiff(REQUIRED_PRIOR_FIELDS, names(pb))
    if (length(missing_fields) > 0) {
      stop("En priors_biologicos de ", sp,
           " faltan: ", paste(missing_fields, collapse = ", "))
    }
    # Numericos planos: todo lo que NO sea string de "_fuente".
    # (el regex anterior era buggy: no capturaba K_prior_mean_mil_t ni
    # K_prior_sd_mil_t porque exigia terminacion en _mean/_sd, y ademas
    # capturaba M_fuente como si fuera numerico -> NAs por coercion)
    numeric_fields <- grep("_fuente$", names(pb), value = TRUE, invert = TRUE)
    setNames(lapply(numeric_fields, \(f) as.numeric(pb[[f]])), numeric_fields)
  })
  names(priors) <- SPECIES_KEYS

  status <- lapply(SPECIES_KEYS, \(sp) raw[[sp]]$status_actual)
  names(status) <- SPECIES_KEYS

  hcr <- lapply(SPECIES_KEYS, \(sp) raw[[sp]]$regulacion)
  names(hcr) <- SPECIES_KEYS

  list(
    meta         = raw$metadata,
    priors       = priors,
    status       = status,
    hcr          = hcr,
    precedentes  = raw$precedentes_metodologicos,
    implementacion = raw$implementacion,
    pendientes   = raw$pendientes,
    raw          = raw
  )
}

# ------------------------------------------------------- summary pretty ----

summarise_priors_table <- function(params) {
  purrr::imap_dfr(params$priors, function(p, sp) {
    tibble::tibble(
      especie  = sp,
      M_mean   = p$M_mean,
      M_sd     = p$M_sd,
      r_mean   = p$r_prior_mean,
      r_sd     = p$r_prior_sd,
      K_mean_milt = p$K_prior_mean_mil_t,
      K_sd_milt   = p$K_prior_sd_mil_t,
      h_mean   = p$h_prior_mean,
      h_sd     = p$h_prior_sd,
      shape_n  = p$shape_n
    )
  })
}

summarise_status_table <- function(params) {
  purrr::imap_dfr(params$status, function(s, sp) {
    tibble::tibble(
      especie          = sp,
      ano              = ifelse(!is.null(s$ano_biologico), s$ano_biologico,
                                as.character(s$ano)),
      BD_BDRMS         = ifelse(!is.null(s$BD_sobre_BDRMS),
                                s$BD_sobre_BDRMS, NA_real_),
      F_FRMS           = ifelse(!is.null(s$F_sobre_FRMS),
                                s$F_sobre_FRMS, NA_real_),
      kobe             = ifelse(!is.null(s$kobe), s$kobe, NA_character_),
      fuente           = s$fuente %||% NA_character_
    )
  })
}

# Operador de coalescencia nula
`%||%` <- function(a, b) if (!is.null(a)) a else b

# --------------------------------------------------------------- main() ----

if (isTRUE(getOption("structural_bio.run_main", FALSE))) {

  params <- load_official_assessments()

  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("Parámetros oficiales cargados (versión:", params$meta$version, ")\n")
  cat("Fecha:", params$meta$fecha, "\n")
  cat("Estado:", params$meta$estado, "\n")
  cat(strrep("=", 70), "\n\n")

  cat("Priors biológicos:\n")
  print(summarise_priors_table(params) %>% as.data.frame(), row.names = FALSE)

  cat("\nStatus actual:\n")
  print(summarise_status_table(params) %>% as.data.frame(), row.names = FALSE)

  abiertos <- Filter(function(p) isTRUE(p$estado == "abierto") || is.null(p$estado),
                     params$pendientes)
  cat("\nPendientes abiertos (N=", length(abiertos), "):\n", sep = "")
  for (p in abiertos) {
    cat(sprintf("  [%s] %s (urgencia: %s)\n",
                p$id, p$descripcion, p$urgencia %||% "sin clasificar"))
  }
  cat(strrep("=", 70), "\n")

  invisible(params)
}
