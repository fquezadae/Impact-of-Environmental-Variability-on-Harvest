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
# Maximum exploitation rate u_bar_s -- Version C (paper 2)
# -----------------------------------------------------------------------------
# u_bar_s is the upper bound on annual harvest fraction H/B that biology
# allows; it appears in the feasibility constraint
#     H_opp_{vy,s} = omega_{vs} * min( Q_{sy}, u_bar_s * B_{sy} )
# of the trip equation (see paper1/version_C_spec.md §3.2).
#
# CALIBRATION ROUTE (revised 2026-05-08 after running regime_diagnostic.R)
# ---------------------------------------------------------------------------
# The diagnostic showed the Schaefer F_MSY = r/2 derivation was inconsistent
# with the data for sardina (over by 2x) and jurel (under by 1.4x). Adopted
# values below are the empirical p95 of H/B over the diagnostic window
# (2012-2024, quota-binding cells in data/outputs/regime_diagnostic_u_bar_empirical.csv)
# with a small upward margin so realised exploitation rates do not exceed
# u_bar in normal operations.
#
#   species         p95 H/B   max H/B   adopted   margin
#   anchoveta       0.318     0.321     0.35      ~10%
#   sardina_comun   0.209     0.228     0.25      ~20%
#   jurel           0.261     0.310     0.32      ~3% (binding cell at edge)
#
# These should be re-checked against the Stan-fit posterior of B_{s,y} once
# the forward simulator (paper 2) consumes them -- the empirical p95 above
# uses the official assessment biomass as B_{s,y}, which is what the bio
# model targets in observation.
#
# Sensitivity ±20% reported as robustness (paper1/version_C_spec.md §5).
U_BAR <- c(
  anchoveta     = 0.35,   # empirical p95 = 0.32 (regime_diagnostic 2026-05-08)
  sardina_comun = 0.25,   # empirical p95 = 0.21
  jurel         = 0.32    # empirical p95 = 0.26
)
U_BAR_SOURCE <- "Empirical p95 of H/B over 2012-2024 quota-binding cells (data/outputs/regime_diagnostic_u_bar_empirical.csv) with a small upward margin. Schaefer F_MSY = r/2 derivation rejected after diagnostic showed factor-of-2 inconsistency for sardina and jurel."

cat("Config loaded. dirdata =", dirdata, "\n")
