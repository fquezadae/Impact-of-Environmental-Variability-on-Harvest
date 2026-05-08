###============================================================###
###   Project configuration: paths, libraries, constants       ###
###============================================================###
#
# Source this file at the top of every script:
#   source("R/00_config/config.R")
#
# It sets `dirdata` based on the current user and loads
# the most common libraries used across the project.
###============================================================###

# --- Detect user and set data directory ---
usuario <- Sys.info()[["user"]]

dirdata <- switch(usuario,
  "felip" = "C:/Users/felip/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/",
  "FACEA" = "C:/Users/FACEA/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/",
  "Felipe" = "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/",
  stop("Usuario no reconocido: ", usuario, ". Agregue su ruta en R/00_config/config.R")
)

rm(usuario)

# --- Core libraries (loaded everywhere) ---
suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(lubridate)
})

# --- Project constants ---
SPECIES_CODES <- c(JUREL = 26L, SARDINA_COMUN = 33L, ANCHOVETA = 114L)
CENTRO_SUR_REGIONS <- c(5L, 6L, 7L, 8L, 9L, 10L, 14L, 16L)

# Species name standardization
standardize_species <- function(x) {
  x <- toupper(stringi::stri_trans_general(x, "Latin-ASCII"))
  x
}

# -----------------------------------------------------------------------------
# Maximum exploitation rate u_bar_s — Version C (paper 2)
# -----------------------------------------------------------------------------
# u_bar_s is the upper bound on annual harvest fraction H/B that biology
# allows; it appears in the feasibility constraint
#     H_opp_{vy,s} = omega_{vs} * min( Q_{sy}, u_bar_s * B_{sy} )
# of the trip equation (see paper1/version_C_spec.md §3.2).
#
# Primary route: Schaefer F_MSY = r/2 with r priors from IFOP/SPRFMO
# assessments documented in data/bio_params/official_assessments.yaml
# (priors_primarias_verificadas_2026_04_22):
#     anchoveta_cs   r = 0.6  -> u_bar = 0.30
#     sardina_cs     r = 0.9  -> u_bar = 0.45
#     jurel_cs       r = 0.35 -> u_bar = 0.18
#
# The diagnostic in R/04_models/regime_diagnostic.R also reports the
# direct-empirical p95 of H/B over quota-binding observations as a
# fallback calibration. Sensitivity ±20% reported as robustness
# (paper1/version_C_spec.md §5).
#
# IMPORTANT: these are placeholder defaults for the diagnostic. Validate
# against the empirical p95 before using in the NB regression or the
# planner; if the diagnostic flags inconsistency (e.g. lots of years
# with H/B > u_bar), revisit before downstream estimation.
U_BAR <- c(
  anchoveta     = 0.30,   # F_MSY ~ r/2 with r = 0.6 (IFOP V-X 2024)
  sardina_comun = 0.45,   # F_MSY ~ r/2 with r = 0.9 (IFOP V-X 2022)
  jurel         = 0.18    # F_MSY ~ r/2 with r = 0.35 (SPRFMO + IFOP nacional 2023)
)
U_BAR_SOURCE <- "Schaefer F_MSY = r/2 from official_assessments.yaml priors_primarias_verificadas_2026_04_22; cross-check vs p95 of H/B in regime_diagnostic.R."

cat("Config loaded. dirdata =", dirdata, "\n")
