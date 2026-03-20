###------------------------------------------------------###
###  TAC OFICIAL: Procesamiento de TAC_anual.xlsx         ###
###  Output: halloc — H_alloc_vy regional/zonal, oficial ###
###  Para reemplazar lagged proxy en poisson_model.R      ###
###------------------------------------------------------###

rm(list = ls())
gc()

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)


# ---- Directory setup ----
usuario <- Sys.info()[["user"]]
if (usuario == "felip") {
  dirdata <- "C:/Users/felip/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "FACEA") {
  dirdata <- "C:/Users/FACEA/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "Felipe") {
  dirdata <- "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else {
  stop("Usuario no reconocido.")
}
rm(usuario)


# =========================================================================
# 1. LOAD TAC DATA
# =========================================================================

tac_art_raw <- read_excel(
  paste0(dirdata, "TAC/TAC_anual.xlsx"),
  sheet = "artesanal"
)

tac_ind_raw <- read_excel(
  paste0(dirdata, "TAC/TAC_anual.xlsx"),
  sheet = "industrial"
)


# =========================================================================
# 2. ARTISANAL: Clean and filter CS regions
# =========================================================================

normalize_species <- function(x) {
  x <- str_to_lower(str_trim(x))
  case_when(
    str_detect(x, "anchov")             ~ "anchoveta",
    str_detect(x, "jurel")              ~ "jurel",
    str_detect(x, "sardina c|sardina$") ~ "sardina_comun",
    TRUE                                ~ NA_character_
  )
}

map_art_region <- function(x) {
  x <- str_trim(x)
  case_when(
    str_detect(x, "^V[^I]|^V$|^V |^ARTESANAL V$|^V Reg")                    ~ 5L,
    str_detect(x, "^VI[^I]|^VI$|^VI |^ARTESANAL VI$|^VI Reg")               ~ 6L,
    str_detect(x, "^VII[^I]|^VII$|^VII |^ARTESANAL VII$|^VII Del|^VII Reg")  ~ 7L,
    str_detect(x, "^VIII|^ARTESANAL VIII")                                    ~ 8L,
    str_detect(x, "^IX|^ARTESANAL IX")                                        ~ 9L,
    str_detect(x, "^XIV|^ARTESANAL XIV")                                      ~ 14L,
    str_detect(x, "^X[^IV]|^X$|^X |^ARTESANAL X$|^X Reg")                   ~ 10L,
    str_detect(x, "^XVI|^ARTESANAL XVI")                                      ~ 16L,
    TRUE                                                                      ~ NA_integer_
  )
}

tac_art <- tac_art_raw %>%
  rename(year = 1, species_raw = 2, region_raw = 3, TAC = 4) %>%
  mutate(
    species     = normalize_species(species_raw),
    region_code = map_art_region(region_raw)
  ) %>%
  filter(!is.na(species), !is.na(region_code),
         region_code %in% c(5, 6, 7, 8, 9, 14, 10, 16)) %>%
  # Merge XVI into VIII (same fishing area; XVI created 2018)
  mutate(region_code = if_else(region_code == 16, 8L, region_code)) %>%
  group_by(year, species, region_code) %>%
  summarise(TAC_art = sum(TAC, na.rm = TRUE), .groups = "drop")

cat("=== ARTISANAL TAC (CS) ===\n")
tac_art %>%
  group_by(year, species) %>%
  summarise(TAC_cs = round(sum(TAC_art)), .groups = "drop") %>%
  pivot_wider(names_from = species, values_from = TAC_cs) %>%
  print(n = 15)


# =========================================================================
# 3. INDUSTRIAL: Clean and filter CS zones
# =========================================================================

map_ind_zone <- function(x) {
  x <- str_trim(x)
  case_when(
    str_detect(x, "V.*IX|V-IX|INDUSTRIAL V-IX") ~ "V_IX",
    str_detect(x, "XIV.*X|XIV-X|INDUSTRIAL XIV-X") ~ "XIV_X",
    str_detect(x, "V.*X|V-X|V -X|INDUSTRIAL V-X") ~ "V_X",
    TRUE ~ NA_character_
  )
}

tac_ind <- tac_ind_raw %>%
  rename(year = 1, species_raw = 2, zone_raw = 3, TAC = 4) %>%
  mutate(
    species = normalize_species(species_raw),
    zone    = map_ind_zone(zone_raw)
  ) %>%
  filter(!is.na(species), !is.na(zone)) %>%
  select(year, species, zone, TAC_ind = TAC)

cat("\n=== INDUSTRIAL TAC (CS) ===\n")
tac_ind %>%
  group_by(year, species) %>%
  summarise(TAC_cs = round(sum(TAC_ind)), .groups = "drop") %>%
  pivot_wider(names_from = species, values_from = TAC_cs) %>%
  print(n = 15)


# =========================================================================
# 4. MAP SPECIES TO COD_ESPECIE
# =========================================================================

species_map <- tibble(
  species     = c("anchoveta", "jurel", "sardina_comun"),
  COD_ESPECIE = c(114L, 26L, 33L)
)

tac_art <- tac_art %>% left_join(species_map, by = "species")
tac_ind <- tac_ind %>% left_join(species_map, by = "species")


# =========================================================================
# 5. VESSEL -> REGION/ZONE (via modal departure port)
# =========================================================================

maestro_puertos <- readRDS(file = "data/trips/maestro_puertos.rds")
log_spf <- readRDS(file = "data/trips/log_spf.rds")
vessel_chars <- readRDS(file = "data/trips/vessel_chars.rds")

# Requires: log_spf, maestro_puertos, vessel_chars (from poisson_model.R)

puerto_modal <- log_spf %>%
  filter(!is.na(PUERTO_ZARPE)) %>%
  count(COD_BARCO, PUERTO_ZARPE) %>%
  group_by(COD_BARCO) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  left_join(maestro_puertos, by = c("PUERTO_ZARPE" = "CODIGO_PUERTO")) %>%
  select(COD_BARCO, port_region = COD_REGION)

vessel_region <- puerto_modal %>%
  left_join(vessel_chars %>% select(COD_BARCO, TIPO_FLOTA), by = "COD_BARCO") %>%
  mutate(
    # Industrial jurel: V-IX or XIV-X
    ind_zone_jurel = case_when(
      port_region %in% c(5, 6, 7, 8, 9, 16) ~ "V_IX",
      port_region %in% c(14, 10)             ~ "XIV_X",
      TRUE                                   ~ NA_character_
    ),
    # Industrial anchoveta/sardina: single zone V-X
    ind_zone_other = "V_X",
    # Artisanal: merge XVI into VIII (consistent with TAC)
    art_region = if_else(port_region == 16, 8L, as.integer(port_region))
  )

cat("\nVessels by port region and fleet:\n")
vessel_region %>% count(TIPO_FLOTA, port_region, sort = TRUE) %>% print(n = 20)


# =========================================================================
# 6. H_alloc_vy — REGIONAL (ART) + ZONAL (IND)
# =========================================================================

harvest_vys <- readRDS("data/trips/harvest_vys.rds")


# --- 6a. ARTISANAL: omega within region x regional TAC ---

harvest_art <- harvest_vys %>%
  left_join(vessel_region %>% select(COD_BARCO, art_region, TIPO_FLOTA),
            by = "COD_BARCO") %>%
  filter(TIPO_FLOTA == "ART")

# Vessel share within its region-species (full sample period)
shares_art_reg <- harvest_art %>%
  group_by(COD_BARCO, art_region, COD_ESPECIE) %>%
  summarise(v_total = sum(H_vys, na.rm = TRUE), .groups = "drop") %>%
  group_by(art_region, COD_ESPECIE) %>%
  mutate(omega_reg = v_total / sum(v_total)) %>%
  ungroup() %>%
  select(COD_BARCO, art_region, COD_ESPECIE, omega_reg)

cat("\nomega_reg sums (should = 1.0 per region-species):\n")
shares_art_reg %>%
  group_by(art_region, COD_ESPECIE) %>%
  summarise(sum_omega = round(sum(omega_reg), 4), .groups = "drop") %>%
  print(n = 25)

halloc_art <- shares_art_reg %>%
  left_join(tac_art %>% select(year, COD_ESPECIE, region_code, TAC_art),
            by = c("COD_ESPECIE", "art_region" = "region_code"),
            relationship = "many-to-many") %>%
  mutate(H_alloc_vys = omega_reg * TAC_art) %>%
  group_by(COD_BARCO, year) %>%
  summarise(H_alloc_vy = sum(H_alloc_vys, na.rm = TRUE), .groups = "drop")


# --- 6b. INDUSTRIAL: omega within zone x zonal TAC ---

harvest_ind <- harvest_vys %>%
  left_join(vessel_region %>% select(COD_BARCO, ind_zone_jurel, ind_zone_other, TIPO_FLOTA),
            by = "COD_BARCO") %>%
  filter(TIPO_FLOTA == "IND") %>%
  mutate(ind_zone = if_else(COD_ESPECIE == 26L, ind_zone_jurel, ind_zone_other))

shares_ind_zone <- harvest_ind %>%
  group_by(COD_BARCO, ind_zone, COD_ESPECIE) %>%
  summarise(v_total = sum(H_vys, na.rm = TRUE), .groups = "drop") %>%
  group_by(ind_zone, COD_ESPECIE) %>%
  mutate(omega_zone = v_total / sum(v_total)) %>%
  ungroup() %>%
  select(COD_BARCO, ind_zone, COD_ESPECIE, omega_zone)

halloc_ind <- shares_ind_zone %>%
  left_join(tac_ind %>% select(year, COD_ESPECIE, zone, TAC_ind),
            by = c("COD_ESPECIE", "ind_zone" = "zone"),
            relationship = "many-to-many") %>%
  mutate(H_alloc_vys = omega_zone * TAC_ind) %>%
  group_by(COD_BARCO, year) %>%
  summarise(H_alloc_vy = sum(H_alloc_vys, na.rm = TRUE), .groups = "drop")


# --- 6c. COMBINE ---
halloc <- bind_rows(halloc_art, halloc_ind)

cat("\n=== H_alloc_vy (official TAC, regional/zonal) ===\n")
halloc %>%
  left_join(vessel_chars %>% select(COD_BARCO, TIPO_FLOTA), by = "COD_BARCO") %>%
  group_by(TIPO_FLOTA) %>%
  summarise(
    n_vy        = n(),
    mean_halloc = round(mean(H_alloc_vy), 1),
    sd_halloc   = round(sd(H_alloc_vy), 1),
    .groups     = "drop"
  ) %>%
  print()


# =========================================================================
# 7. SAVE
# =========================================================================

dir.create("data/trips", showWarnings = FALSE, recursive = TRUE)
saveRDS(tac_art,  file = "data/trips/tac_art.rds")
saveRDS(tac_ind,  file = "data/trips/tac_ind.rds")
saveRDS(halloc,   file = "data/trips/halloc_official.rds")
cat("\n Saved: tac_art.rds, tac_ind.rds, halloc_official.rds\n")
cat("  Replace 'halloc' in poisson_model.R merge with this halloc.\n")
