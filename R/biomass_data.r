
###----------------------------------------------###
###               Biomass data                   ### 
### and interpolation of mackerel missing values ###  
###----------------------------------------------###

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

library(readxl)
library(tidyverse)

# library(knitr)
# library(kableExtra)
# library(ggalluvial)
# library(purrr)
# library(stringr)
# library(readxl)

#Anchovy and sardine biomass
anch_sard_biomass <- read_excel(paste0(dirdata, "IFOP/3. ESTIMACIONES CRUCERO ACUSTICO.xlsx"), sheet = "SARDINA-ANCHOVETA")
anch_sard_biomass <- anch_sard_biomass[, c(1, 2, 3, 4)]
anch_sard_biomass <- anch_sard_biomass[-1, ]
colnames(anch_sard_biomass) <- c("year", "cruise", "sardine_biomass", "anchoveta_biomass")
anch_sard_biomass <- anch_sard_biomass %>%
  filter(str_detect(cruise, "Reclas")) %>%  ## Summer survey!
  dplyr::select(-c(cruise)) %>%
  mutate(across(ends_with("biomass"), ~as.numeric(.))) 
anch_sard_biomass$year <- as.numeric(anch_sard_biomass$year)

#Jurel biomass
jurel_biomass <- read_excel(paste0(dirdata, "IFOP/3. ESTIMACIONES CRUCERO ACUSTICO.xlsx"), sheet = "JUREL")
jurel_biomass <- jurel_biomass[, c(1, 3,8)]
jurel_biomass <- jurel_biomass[-1, ]
colnames(jurel_biomass) <- c("year", "jurel_biomass_cs", "jurel_biomass_no")
jurel_biomass <- jurel_biomass %>%
  mutate(across(ends_with("biomass_cs"), ~as.numeric(.))) %>%
  mutate(across(ends_with("biomass_no"), ~as.numeric(.))) %>%
  mutate(jurel_biomass_cs = ifelse(jurel_biomass_cs == 0, NA, jurel_biomass_cs)) %>%
  mutate(jurel_biomass_no = ifelse(jurel_biomass_no == 0, NA, jurel_biomass_no))
jurel_biomass$year <- as.numeric(jurel_biomass$year)


## Add the other database
biomass_v2 <- read_excel(paste0(dirdata, "IFOP/Datos_estimación biomasa.xlsx")) %>%
  dplyr::rename(year = `Año (calendario/.5 semestral)`) %>%
  dplyr::filter(Especie == "Jurel",
                year >= 2000)

biomass_v2$`Año (calendario/.5 semestral)`



# Merge databse
biomass <- full_join(anch_sard_biomass, jurel_biomass, by = c("year")) %>% arrange(year)
rm(list = c("anch_sard_biomass", "jurel_biomass"))