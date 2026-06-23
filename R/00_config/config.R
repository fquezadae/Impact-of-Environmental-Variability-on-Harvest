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

cat("Config loaded. dirdata =", dirdata, "\n")
