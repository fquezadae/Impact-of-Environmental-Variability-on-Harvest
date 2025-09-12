#-------------------------------------------#
#               Biomass Model               #
#-------------------------------------------#

rm(list = ls())
gc()

# Define directory

usuario <- Sys.info()[["user"]]
# computador <- Sys.info()[["nodename"]]  # Alternativamente puedes usar esto
if (usuario == "felip") {
  dirdata <- "C:/Users/felip/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "FACEA") {
  dirdata <- "C:/Users/FACEA/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else {
  stop("Usuario no reconocido. Defina el directorio correspondiente.")
}
rm(usuario)

# Load packages 
library(tidyverse)

# Load data
biomass <- readRDS("data/biomass/biomass_dt.rds")

# Model biomass
str(biomass)
model1 <- lm(sardine_biomass ~ anchoveta_biomass + jurel_biomass_cs_intra, data = biomass)
summary(model1)










