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


# ---- CALCULAR CANTIDADES MENSUALES DESEMBARCADAS EN CENTRO-SUR ----

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




library(tidyverse)
library(lubridate)



harvest_IFOP_month <- 
  full_join(harvest_IFOP_LANCHAS_month, harvest_IFOP_BOTES_month, by = c("year", "specie", "month")) %>%
  full_join(harvest_IFOP_IND_month, by = c("year", "specie", "month")) %>%
  mutate(
    total_harvest_IFOP_centrosur =
      rowSums(
        across(c(harvest_IND_IFOP_centrosur,
                 harvest_LANCHAS_IFOP_centrosur, 
                 harvest_BOTES_IFOP_centrosur)),
        na.rm = TRUE
      ),
    total_harvest_IFOP_norte = harvest_IND_IFOP_norte
  ) %>%
  filter(year >= 2012) %>%
  mutate(
    month = match(tolower(month),
                  c("ene","feb","mar","abr","may","jun",
                    "jul","ago","sept","oct","nov","dic"))
  ) %>%
  arrange(specie, year, month)%>%
  complete(
    specie,
    year = full_seq(year, 1),
    month = 1:12,
    fill = list(
      harvest_IND_IFOP_centrosur     = 0,
      harvest_LANCHAS_IFOP_centrosur = 0,
      harvest_BOTES_IFOP_centrosur   = 0,
      harvest_IND_IFOP_norte         = 0,
      total_harvest_IFOP_centrosur   = 0,
      total_harvest_IFOP_norte       = 0
    )
  ) %>%
  arrange(specie, year, month)


# ---- CALCULAR PRECIO MENSUAL POR ESPECIE ----

library(readxl)
library(dplyr)

precios_IFOP <- read_excel(
  paste0(dirdata, "IFOP/2025.04.21.pelagicos_proceso-precios.mp.2012-2024.xlsx"),
  sheet = "PRECIO"
) %>%
  filter(RG %in% c("5","6","7","8","9","10","14","16")) %>%
  mutate(
    year   = as.integer(ANIO),
    month  = as.integer(MES),
    specie = as.character(NM_RECURSO)
  ) %>%
  group_by(specie, year, month) %>%
  summarize(precio_promedio = mean(PRECIO, na.rm = TRUE), .groups = "drop")


library(dplyr)
library(tidyr)
library(stringr)

harvest_price_IFOP_wide <- harvest_IFOP_month %>%
  left_join(precios_IFOP, by = c("specie","year","month")) %>%
  select(specie, year, month,
         P = precio_promedio,
         Q = total_harvest_IFOP_centrosur) %>%
  mutate(
    specie = tolower(specie) |> str_replace_all(" ", "_")
  ) %>%
  pivot_wider(
    names_from  = specie,
    values_from = c(P, Q),
    names_sep   = "_",
    values_fill = list(Q = 0)
  ) %>%
  arrange(year, month) # %>% drop_na() (sacar # si se quiere dejar una base sin NA)

saveRDS(harvest_price_IFOP_wide, "base_precios.rds")


