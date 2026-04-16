```{r ind_harvest_substitution_SERNAPESCA, eval=FALSE, message=FALSE, warning=FALSE, include=FALSE}
library(readxl)
library(dplyr)
library(tidyr)
library(purrr)

ind_harvest_SERNAPESCA_ART <- 
  read_excel(paste0(dirdata, "SERNAPESCA/AH010T0006857_sobre_desembarque_pelagicos_2012_2024.xlsx"), 
             sheet = "ART_2012_2024", 
             range = "A6:S36337") %>%
  rename(specie = Especie,
         year = Año,
         region = `Región de Operación`,
         vessel_id = `RPA Embarcación`) %>%
  mutate(zone = case_when(
    region %in% c(1,2,3,4,15) ~ "Norte",
    region %in% c(5,6,7,8,9,10,14,16) ~ "Centro-Sur",
    region %in% c(11,12) ~ "Extremo Sur",
    TRUE ~ "No Especifica"
  )) %>%
  filter(zone == "Centro-Sur") 

vessel_species_year_ART <- ind_harvest_SERNAPESCA_ART %>% 
  select(vessel_id, year, specie, SumaDeDesembarque) %>%
  group_by(vessel_id, year, specie) %>%
  summarize(total_catch = sum(SumaDeDesembarque, na.rm = TRUE)) %>%
  group_by(vessel_id, year) %>%
  mutate(species_share = total_catch / sum(total_catch, na.rm = TRUE)) %>%
  ungroup() %>%
  select(-c(total_catch)) %>%
  complete(vessel_id, year, specie, fill = list(species_share = 0)) %>%
  group_by(vessel_id, year) %>%
  mutate(species_share_check = sum(species_share, na.rm = TRUE)) %>%
  filter(species_share_check > 0) %>%
  dplyr::select(-c(species_share_check)) %>%
  group_by(vessel_id, specie) %>% 
  summarize(species_share = mean(species_share, na.rm = TRUE)) %>%
  pivot_wider(
    names_from = specie,
    values_from = species_share,
    values_fill = 0) %>%
  rename(
    Anchoveta = `ANCHOVETA`,
    Sardine = `SARDINA COMUN`,
    AustralSardine = `SARDINA AUSTRAL`,
    SpanishSardine = `SARDINA ESPAÑOLA`,
    JackMackerel = `JUREL`
  )

get_strategy <- function(sardine, jackmackerel, anchoveta, australsardine, spanishsardine) {
  species <- c()
  if (sardine > 0.15) species <- c(species, "Sardine")
  if (jackmackerel > 0.15) species <- c(species, "JackMackerel")
  if (anchoveta > 0.15) species <- c(species, "Anchoveta")
  if (australsardine > 0.15) species <- c(species, "AustralSardine")
  if (spanishsardine> 0.15) species <- c(species, "SpanishSardine")
  
  n <- length(species)
  if (n == 0) return("None or negligible")
  if (n == 1) return(paste("Only", species[1]))
  if (n == 2) return(paste(species[1], "and", species[2]))
  if (n == 3) return(paste(species[1], ",", species[2], "and", species[3]))
  if (n == 4) return(paste(species[1], ",", species[2], ",", species[3], "and", species[4]))
  return("All species")
}

vessel_strategies_yearly_ART <- vessel_species_year_ART %>%
  mutate(strategy = pmap_chr(
    list(Sardine, JackMackerel, Anchoveta, AustralSardine, SpanishSardine),
    get_strategy
  ))

strategy_percent_ART <- vessel_strategies_yearly_ART %>%
  group_by(strategy) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(percent = round(100 * n / sum(n), 1)) %>%
  arrange(desc(percent))  %>%
  mutate(sector = "SmallScale")


#####################################################

ind_harvest_SERNAPESCA_IND <- 
  read_excel(paste0(dirdata, "SERNAPESCA/AH010T0006857_sobre_desembarque_pelagicos_2012_2024.xlsx"), 
             sheet = "IND_2012_2024", 
             range = "A6:R3349") %>%
  rename(specie = Especie,
         year = Año,
         region = `Región`,
         vessel_id = `CD_MATRICU`) %>%
  mutate(zone = case_when(
    region %in% c(1,2,3,4,15) ~ "Norte",
    region %in% c(5,6,7,8,9,10,14,16) ~ "Centro-Sur",
    region %in% c(11,12) ~ "Extremo Sur",
    TRUE ~ "No Especifica")) %>%
  filter(zone == "Centro-Sur") 

vessel_species_year_IND <- ind_harvest_SERNAPESCA_IND %>% 
  select(vessel_id, year, specie, Desembarque) %>%
  group_by(vessel_id, year, specie) %>%
  summarize(total_catch = sum(Desembarque, na.rm = TRUE)) %>%
  group_by(vessel_id, year) %>%
  mutate(species_share = total_catch / sum(total_catch, na.rm = TRUE)) %>%
  ungroup() %>%
  select(-c(total_catch)) %>%
  complete(vessel_id, year, specie, fill = list(species_share = 0)) %>%
  group_by(vessel_id, year) %>%
  mutate(species_share_check = sum(species_share, na.rm = TRUE)) %>%
  filter(species_share_check > 0) %>%
  dplyr::select(-c(species_share_check)) %>%
  group_by(vessel_id, specie) %>% ### OJO ACA!
  summarize(species_share = mean(species_share, na.rm = TRUE)) %>%
  pivot_wider(
    names_from = specie,
    values_from = species_share,
    values_fill = 0
  ) %>%
  rename(
    Anchoveta = `ANCHOVETA`,
    Sardine = `SARDINA COMUN`,
    SpanishSardine = `SARDINA ESPAÑOLA`,
    JackMackerel = `JUREL`
  )

get_strategy <- function(sardine, jackmackerel, anchoveta, spanishsardine) {
  species <- c()
  if (sardine > 0.15) species <- c(species, "Sardine")
  if (jackmackerel > 0.15) species <- c(species, "JackMackerel")
  if (anchoveta > 0.15) species <- c(species, "Anchoveta")
  if (spanishsardine> 0.15) species <- c(species, "SpanishSardine")
  
  n <- length(species)
  if (n == 0) return("None or negligible")
  if (n == 1) return(paste("Only", species[1]))
  if (n == 2) return(paste(species[1], "and", species[2]))
  if (n == 3) return(paste(species[1], ",", species[2], "and", species[3]))
  return("All species")
}

vessel_strategies_yearly_IND <- vessel_species_year_IND %>%
  mutate(strategy = pmap_chr(
    list(Sardine, JackMackerel, Anchoveta, SpanishSardine),
    get_strategy
  )) 

strategy_percent_IND <- vessel_strategies_yearly_IND %>%
  group_by(strategy) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(percent = round(100 * n / sum(n), 1)) %>%
  arrange(desc(percent)) %>%
  mutate(sector = "Industrial")


#####################################################

# 7 barcos de factoria que capturan puro JUREL!

# ind_harvest_SERNAPESCA_BF <- 
#   read_excel(paste0(dirdata, "SERNAPESCA/AH010T0006857_sobre_desembarque_pelagicos_2012_2024.xlsx"), 
#              sheet = "BF_2017_2024", 
#              range = "A7:R144") %>%
#   rename(specie = DESCR1TABL,
#          year = Año,
#          region = `Cd_Region`,
#          vessel_id = `CD_MATRICU`) %>%
#   mutate(zone = case_when(
#     region %in% c(1,2,3,4,15) ~ "Norte",
#     region %in% c(5,6,7,8,9,10,14,16) ~ "Centro-Sur",
#     region %in% c(11,12) ~ "Extremo Sur",
#     TRUE ~ "No Especifica")) %>%
#   filter(zone == "Centro-Sur") 
# 
# vessel_species_year_BF <- ind_harvest_SERNAPESCA_BF %>% 
#   select(vessel_id, year, specie, DESEMBARQUE) %>%
#   group_by(vessel_id, year, specie) %>%
#   summarize(total_catch = sum(DESEMBARQUE, na.rm = TRUE)) %>%
#   group_by(vessel_id, year) %>%
#   mutate(species_share = total_catch / sum(total_catch, na.rm = TRUE)) %>%
#   ungroup() %>%
#   select(-c(total_catch)) %>%
#   pivot_wider(
#     names_from = specie,
#     values_from = species_share,
#     values_fill = 0
#   ) 

# -----  Merge -----
strategy_all <- bind_rows(
  strategy_percent_ART,
  strategy_percent_IND
) %>%
  arrange(sector, desc(percent))

strategy_wide <- strategy_all %>%
  select(strategy, sector, n) %>%
  pivot_wider(names_from = sector, values_from = n, values_fill = 0) %>%
  mutate(Total = SmallScale + Industrial) %>%
  mutate(Percent = round(100 * Total / sum(Total), 1)) %>%
  arrange(desc(Percent))

rm(list = c("ind_harvest_SERNAPESCA_IND", "ind_harvest_SERNAPESCA_ART",
            "vessel_strategies_yearly_IND", "vessel_strategies_yearly_ART",
            "vessel_species_year_IND", "vessel_species_year_ART",
            "strategy_percent_ART", "strategy_percent_IND", "strategy_all"))


```

```{r strategy-table, eval=FALSE, include=FALSE, results='asis'}
library(knitr)
kable(strategy_wide, format = "markdown", 
      col.names = c("Strategy", "Industrial", "Small-Scale", "Total", "Percent (%)"))

rm(list = c("strategy_wide"))
```