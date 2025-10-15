
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


## --> Add the other biomass database
biomass_v2 <- read_excel(paste0(dirdata, "IFOP/Datos_estimación biomasa.xlsx")) %>%
  dplyr::rename(year = `Año (calendario/.5 semestral)`,
                ind_chl_per_ecu = `Reclutas (millones individuos)`,
                sb_chl_per_ecu = `Biomasa desovante (t)`) %>%
  dplyr::filter(Especie == "Jurel",
                year >= 2000) %>%
  dplyr::select(c("year", "ind_chl_per_ecu", "sb_chl_per_ecu"))

jurel_biomass <- left_join(jurel_biomass, biomass_v2, by = "year")
rm(biomass_v2)

## --> Add the harvest database
harvest <- readRDS("data/harvest/sernapesca_v2.rds") %>%
  filter(specie == "JUREL") %>%
  select(c(year, total_harvest_sernapesca_v2_centro_sur))
jurel_biomass <- left_join(jurel_biomass, harvest, by = "year")
rm(harvest)


# GLM models with log link



model1 <- glm(
  jurel_biomass_cs ~ jurel_biomass_no + sb_chl_per_ecu,
  family = Gamma(link = "log"),
  data = jurel_biomass
  )

model2 <- glm(
  jurel_biomass_cs ~ jurel_biomass_no + sb_chl_per_ecu + jurel_biomass_no:sb_chl_per_ecu,
  family = Gamma(link = "log"), 
  data = jurel_biomass
  )

model3 <- glm(
  jurel_biomass_cs ~ jurel_biomass_no + I(jurel_biomass_no^2),
  family = Gamma(link = "log"),
  data = jurel_biomass)

model4 <- glm(
  jurel_biomass_cs ~ jurel_biomass_no + I(jurel_biomass_no^2) + sb_chl_per_ecu + I(sb_chl_per_ecu^2) + jurel_biomass_no:sb_chl_per_ecu,
  family = Gamma(link = "log"),
  data = jurel_biomass)

# Add GLM predictions (always >= 0)
jurel_biomass <- jurel_biomass %>% 
  mutate(
    jurel_biomass_cs_p1 = predict(model1, newdata = ., type = "response"),
    jurel_biomass_cs_p1 = pmax(jurel_biomass_cs_p1, total_harvest_sernapesca_v2_centro_sur),
    jurel_biomass_cs_p2 = predict(model2, newdata = ., type = "response"),
    jurel_biomass_cs_p2 = pmax(jurel_biomass_cs_p2, total_harvest_sernapesca_v2_centro_sur),
    jurel_biomass_cs_p3 = predict(model3, newdata = ., type = "response"),
    jurel_biomass_cs_p3 = pmax(jurel_biomass_cs_p3, total_harvest_sernapesca_v2_centro_sur),
    jurel_biomass_cs_p4 = predict(model4, newdata = ., type = "response"),
    jurel_biomass_cs_p4 = pmax(jurel_biomass_cs_p4, total_harvest_sernapesca_v2_centro_sur),
  ) %>%
  mutate(
    jurel_biomass_cs_p1 = ifelse(jurel_biomass_cs_p1 > 0, jurel_biomass_cs_p1, NA),
    jurel_biomass_cs_p2 = ifelse(jurel_biomass_cs_p2 > 0, jurel_biomass_cs_p2, NA),
    jurel_biomass_cs_p3 = ifelse(jurel_biomass_cs_p3 > 0, jurel_biomass_cs_p3, NA),
    jurel_biomass_cs_p4 = ifelse(jurel_biomass_cs_p4 > 0, jurel_biomass_cs_p4, NA)
  ) %>%
  mutate(jurel_biomass_cs_intra = ifelse(is.na(jurel_biomass_cs), 
                                         jurel_biomass_cs_p1, 
                                         jurel_biomass_cs)) %>%
  dplyr::select(c(year, jurel_biomass_cs, jurel_biomass_cs_intra))

# library(ggplot2)
# library(tidyr)
# 
# jurel_biomass %>%
#   select(year,
#          jurel_biomass_cs,
#          jurel_biomass_cs_p1) %>%
#   pivot_longer(
#     cols = starts_with("jurel_biomass_cs"),
#     names_to = "model",
#     values_to = "predicted_biomass"
#   ) %>%
#   ggplot(aes(x = year, y = predicted_biomass, color = model)) +
#   geom_smooth(linewidth = 1) +
#   # geom_line(linewidth = 1) +
#   # geom_point(size = 2) +
#   labs(
#     title = "Predicciones de Biomasa (Modelos GLM 1–4)",
#     x = "Año",
#     y = "Biomasa Predicha (t)",
#     color = "Modelo"
#   ) +
#   theme_minimal(base_size = 13) 


# Merge databse
biomass <- full_join(anch_sard_biomass, jurel_biomass, by = c("year")) %>% arrange(year)
rm(list = c("anch_sard_biomass", "jurel_biomass"))


# Save data
saveRDS(biomass, file="data/biomass/biomass_dt.rds")



