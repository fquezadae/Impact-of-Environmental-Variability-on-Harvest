rm(list = ls())
gc()

usuario <- Sys.info()[["user"]]
# computador <- Sys.info()[["nodename"]]  # Alternativamente puedes usar esto
if (usuario == "felip") {
  dirdata <- "C:/Users/felip/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "FACEA") {
  dirdata <- "C:/Users/FACEA/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "Felipe") {
  dirdata <- "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else {
  stop("Usuario no reconocido. Defina el directorio correspondiente.")
}
rm(usuario)
library(readxl)
library(dplyr)
library(tidyr)
library(stringi)


#---- SERNAPESCA data ----

annual_harvest_SERNAPESCA_ART <- 
  read_excel(paste0(dirdata, "SERNAPESCA/AH010T0006857_sobre_desembarque_pelagicos_2012_2024.xlsx"), 
             sheet = "ART_2012_2024", 
             range = "A6:S36337") %>%
  rename(specie = Especie,
         year = Año,
         region = `Región de Operación`) %>%
  mutate(zone = case_when(
    region %in% c(1,2,3,4,15) ~ "Norte",
    region %in% c(5,6,7,8,9,10,14,16) ~ "Centro_Sur",
    region %in% c(11,12) ~ "Extremo_Sur",
    TRUE ~ "No_Especifica")) %>% 
  group_by(specie, year, zone) %>%
  summarize(annual_harvest_ART_SERNAPESCA = 
              sum(SumaDeDesembarque, na.rm = TRUE), .groups = "drop") 

annual_harvest_SERNAPESCA_IND <- 
  read_excel(paste0(dirdata, "SERNAPESCA/AH010T0006857_sobre_desembarque_pelagicos_2012_2024.xlsx"), 
             sheet = "IND_2012_2024", 
             range = "A6:R3349") %>%
  rename(specie = Especie,
         year = Año,
         region = `Región`) %>%
  mutate(zone = case_when(
    region %in% c(1,2,3,4,15) ~ "Norte",
    region %in% c(5,6,7,8,9,10,14,16) ~ "Centro_Sur",
    region %in% c(11,12) ~ "Extremo_Sur",
    TRUE ~ "No_Especifica"
  )) %>% 
  group_by(specie, year, zone) %>%
  summarize(annual_harvest_IND_SERNAPESCA = 
              sum(Desembarque, na.rm = TRUE), .groups = "drop")

annual_harvest_SERNAPESCA_BF <- 
  read_excel(paste0(dirdata, "SERNAPESCA/AH010T0006857_sobre_desembarque_pelagicos_2012_2024.xlsx"), 
             sheet = "BF_2017_2024", 
             range = "A7:R144") %>%
  rename(specie = DESCR1TABL,
         year = Año,
         region = `Cd_Region`) %>%
  mutate(zone = case_when(
    region %in% c(1,2,3,4,15) ~ "Norte",
    region %in% c(5,6,7,8,9,10,14,16) ~ "Centro_Sur",
    region %in% c(11,12) ~ "Extremo_Sur",
    TRUE ~ "No_Especifica"
  )) %>% 
  group_by(specie, year, zone) %>%
  summarize(annual_harvest_BF_SERNAPESCA = sum(DESEMBARQUE, na.rm = TRUE), .groups = "drop")

harvest_SERNAPESCA <- 
  left_join(annual_harvest_SERNAPESCA_ART, annual_harvest_SERNAPESCA_IND, by = c("year", "specie", "zone")) %>%
  left_join(annual_harvest_SERNAPESCA_BF, by = c("year", "specie", "zone")) %>%
  mutate(total_harvest_SERNAPESCA = rowSums(across(c(annual_harvest_IND_SERNAPESCA, annual_harvest_ART_SERNAPESCA)), na.rm = TRUE)) %>%
  mutate(total_harvest_all_SERNAPESCA = rowSums(across(c(annual_harvest_IND_SERNAPESCA, annual_harvest_BF_SERNAPESCA, annual_harvest_ART_SERNAPESCA)), na.rm = TRUE))

harvest_SERNAPESCA <- harvest_SERNAPESCA %>%
  pivot_wider(
    names_from = zone,
    values_from = c(
      annual_harvest_ART_SERNAPESCA,
      annual_harvest_IND_SERNAPESCA,
      annual_harvest_BF_SERNAPESCA,
      total_harvest_SERNAPESCA,
      total_harvest_all_SERNAPESCA
    ),
    names_sep = "_"
  )

saveRDS(harvest_SERNAPESCA, "data/harvest/sernapesca.rds")


#---- SERNAPESCA data V2 ----

library(janitor)

harvest_SERNAPESCA_v2 <- read.csv(
  file.path(dirdata, "SERNAPESCA", "bd_desembarque.csv"),
  fileEncoding = "Latin1",
  sep = ";") %>%
  rename(specie = especie,
         year = año) %>%
  mutate(zone = case_when(
    region %in% c("Valparaíso", "Metropolitana" , "O'Higgins", "Maule", "Ñuble", "Bio-bío", "La Araucanía", "Los Ríos", "Los Lagos") ~ "Centro_Sur", 
    region %in% c("Arica y Parinacota", "Tarapacá", "Antofagasta", "Atacama", "Coquimbo" ) ~ "Norte",
    region %in% c("Magallanes", "Aysén") ~ "Extremo_Sur",
    TRUE ~ "No_Especifica")) %>% 
  group_by(specie, year, zone) %>%
  summarize(total_harvest_SERNAPESCA_v2 = 
              sum(toneladas, na.rm = TRUE), .groups = "drop") %>%
  mutate(specie = toupper(stri_trans_general(specie, "Latin-ASCII"))) %>%
  pivot_wider(
    names_from = zone,
    values_from = total_harvest_SERNAPESCA_v2,
    names_glue = "total_harvest_sernapesca_v2_{zone}"
  ) %>%
  janitor::clean_names() %>% 
  filter(specie %in% c("ANCHOVETA", "JUREL", "SARDINA COMUN"))


saveRDS(harvest_SERNAPESCA_v2, "data/harvest/sernapesca_v2.rds")



#---- IFOP data ----

### Industriales 

harvest_IFOP_jmck_IND_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"), 
             sheet = "INDUSTRIAL (nacional)", 
             range = "A2:L293") %>% 
  mutate(specie = "JUREL") %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_IND_IFOP_norte = rowSums(across(c('15', '1', '2', '3', '4')), na.rm = TRUE)) %>%
  mutate(harvest_IND_IFOP_centrosur = rowSums(across(c('5', '8', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_IND_IFOP_norte, harvest_IND_IFOP_centrosur)

harvest_IFOP_sardine_IND_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"), 
             sheet = "INDUSTRIAL (nacional)", 
             range = "N2:W196") %>% 
  mutate(specie = "SARDINA COMUN") %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_IND_IFOP_norte = rowSums(across(c('1', '2', '4')), na.rm = TRUE)) %>%
  mutate(harvest_IND_IFOP_centrosur = rowSums(across(c('5', '8', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_IND_IFOP_norte, harvest_IND_IFOP_centrosur)

harvest_IFOP_anchoveta_IND_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"), 
             sheet = "INDUSTRIAL (nacional)", 
             range = "Y2:AJ273") %>% 
  mutate(specie = "ANCHOVETA") %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_IND_IFOP_norte = rowSums(across(c('15', '1', '2', '3', '4')), na.rm = TRUE)) %>%
  mutate(harvest_IND_IFOP_centrosur = rowSums(across(c('5', '8', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_IND_IFOP_norte, harvest_IND_IFOP_centrosur)

harvest_IFOP_IND_month <- rbind(harvest_IFOP_jmck_IND_month, harvest_IFOP_sardine_IND_month, harvest_IFOP_anchoveta_IND_month)
rm(list = c("harvest_IFOP_jmck_IND_month", "harvest_IFOP_sardine_IND_month", "harvest_IFOP_anchoveta_IND_month"))


### Lanchas

harvest_IFOP_jmck_LANCHAS_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"), 
             sheet = "LANCHAS (CentroSur)", 
             range = "A2:I143") %>% 
  mutate(specie = "JUREL") %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_LANCHAS_IFOP_centrosur = rowSums(across(c('5', '7', '8', '9', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_LANCHAS_IFOP_centrosur)

harvest_IFOP_sardine_LANCHAS_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"), 
             sheet = "LANCHAS (CentroSur)", 
             range = "K2:S170") %>% 
  mutate(specie = "SARDINA COMUN") %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_LANCHAS_IFOP_centrosur = rowSums(across(c('5', '7', '8', '9', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_LANCHAS_IFOP_centrosur)

harvest_IFOP_anchoveta_LANCHAS_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"),  
             sheet = "LANCHAS (CentroSur)", 
             range = "U2:AC169") %>% 
  mutate(specie = "ANCHOVETA") %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_LANCHAS_IFOP_centrosur = rowSums(across(c('5', '8', '9', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_LANCHAS_IFOP_centrosur)

harvest_IFOP_LANCHAS_month <- rbind(harvest_IFOP_jmck_LANCHAS_month, 
                                    harvest_IFOP_sardine_LANCHAS_month, 
                                    harvest_IFOP_anchoveta_LANCHAS_month)
rm(list = c("harvest_IFOP_jmck_LANCHAS_month", 
            "harvest_IFOP_sardine_LANCHAS_month", 
            "harvest_IFOP_anchoveta_LANCHAS_month"))

### Botes

harvest_IFOP_jmck_BOTES_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"), 
             sheet = "BOTES (CentroSur)", 
             range = "A2:I146") %>% 
  mutate(specie = "JUREL") %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_BOTES_IFOP_centrosur = 
           rowSums(across(c('5', '7', '8', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_BOTES_IFOP_centrosur)

harvest_IFOP_sardine_BOTES_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"), 
             sheet = "BOTES (CentroSur)", 
             range = "K2:S163") %>% 
  mutate(specie = "SARDINA COMUN")  %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_BOTES_IFOP_centrosur = 
           rowSums(across(c('5', '7', '8', '9', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_BOTES_IFOP_centrosur)

harvest_IFOP_anchoveta_BOTES_month <- 
  read_excel(paste0(dirdata, "IFOP/4. DESEMBARQUES.xlsx"), 
             sheet = "BOTES (CentroSur)", 
             range = "U2:AD109") %>% 
  mutate(specie = "ANCHOVETA") %>%
  rename(year = `Años (Fc_Llegada)`) %>%
  rename(month = `Meses (Fc_Llegada)`) %>%
  mutate(harvest_BOTES_IFOP_centrosur = 
           rowSums(across(c('5', '7', '8', '9', '14', '10')), na.rm = TRUE)) %>% 
  dplyr::select(year, month, specie, harvest_BOTES_IFOP_centrosur) 

harvest_IFOP_BOTES_month <- 
  rbind(harvest_IFOP_jmck_BOTES_month,
        harvest_IFOP_sardine_BOTES_month, 
        harvest_IFOP_anchoveta_BOTES_month)
rm(list = c("harvest_IFOP_jmck_BOTES_month", 
            "harvest_IFOP_sardine_BOTES_month", 
            "harvest_IFOP_anchoveta_BOTES_month"))


### Unir Industriales, botes y lanchas
harvest_IFOP_month <- 
  full_join(harvest_IFOP_LANCHAS_month, harvest_IFOP_BOTES_month, by = c("year", "specie", "month")) %>%
  full_join(harvest_IFOP_IND_month, by = c("year", "specie", "month")) %>%
  mutate(total_harvest_IFOP_centrosur = 
           rowSums(
             across(
               c(harvest_IND_IFOP_centrosur,
                 harvest_LANCHAS_IFOP_centrosur, 
                 harvest_BOTES_IFOP_centrosur)), 
             na.rm = TRUE)) %>%
  mutate(total_harvest_IFOP_norte = harvest_IND_IFOP_norte) %>% filter(year >= 2012)

saveRDS(harvest_IFOP_month, "data/harvest/IFOP_month.rds")


harvest_IFOP <- harvest_IFOP_month %>%
  group_by(specie, year) %>%
  summarise(
    harvest_LANCHAS_IFOP_centrosur = sum(harvest_LANCHAS_IFOP_centrosur, na.rm = TRUE),
    harvest_BOTES_IFOP_centrosur = sum(harvest_BOTES_IFOP_centrosur, na.rm = TRUE),
    harvest_IND_IFOP_norte = sum(harvest_IND_IFOP_norte, na.rm = TRUE),
    harvest_IND_IFOP_centrosur = sum(harvest_IND_IFOP_centrosur, na.rm = TRUE),
    total_harvest_IFOP_centrosur = sum(total_harvest_IFOP_centrosur, na.rm = TRUE),
    total_harvest_IFOP_norte = sum(total_harvest_IFOP_norte, na.rm = TRUE),
    .groups = "drop"
  )

saveRDS(harvest_IFOP, "data/harvest/IFOP.rds")




