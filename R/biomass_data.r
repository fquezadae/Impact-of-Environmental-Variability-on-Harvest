
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

# Jurel biomass
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


## --> Add the other database
biomass_v2 <- read_excel(paste0(dirdata, "IFOP/Datos_estimación biomasa.xlsx")) %>%
  dplyr::rename(year = `Año (calendario/.5 semestral)`,
                ind_chl_per_ecu = `Reclutas (millones individuos)`,
                sb_chl_per_ecu = `Biomasa desovante (t)`) %>%
  dplyr::filter(Especie == "Jurel",
                year >= 2000) %>%
  dplyr::select(c("year", "ind_chl_per_ecu", "sb_chl_per_ecu"))


# GLM models with log link
model1 <- glm(jurel_biomass_cs ~ jurel_biomass_no + sb_chl_per_ecu,
              family = gaussian(link = "log"),
              data = jurel_biomass)

model2 <- glm(jurel_biomass_cs ~ jurel_biomass_no + sb_chl_per_ecu + 
                jurel_biomass_no:sb_chl_per_ecu,
              family = gaussian(link = "log"),
              data = jurel_biomass)

model3 <- glm(jurel_biomass_cs ~ jurel_biomass_no + I(jurel_biomass_no^2),
              family = gaussian(link = "log"),
              data = jurel_biomass)

model4 <- glm(jurel_biomass_cs ~ jurel_biomass_no + I(jurel_biomass_no^2) + 
                sb_chl_per_ecu + I(sb_chl_per_ecu^2) + 
                jurel_biomass_no:sb_chl_per_ecu,
              family = gaussian(link = "log"),
              data = jurel_biomass)

# Add GLM predictions (always >= 0)
jurel_biomass <- jurel_biomass %>% 
  mutate(
    jurel_biomass_cs_p1 = predict(model1, newdata = ., type = "response"),
    jurel_biomass_cs_p2 = predict(model2, newdata = ., type = "response"),
    jurel_biomass_cs_p3 = predict(model3, newdata = ., type = "response"),
    jurel_biomass_cs_p4 = predict(model4, newdata = ., type = "response")
  )

# Merge databse
biomass <- full_join(anch_sard_biomass, jurel_biomass, by = c("year")) %>% arrange(year)
rm(list = c("anch_sard_biomass", "jurel_biomass"))