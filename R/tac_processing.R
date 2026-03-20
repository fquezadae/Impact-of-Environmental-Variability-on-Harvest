###------------------------------------------------------###
###  TAC OFICIAL: Procesamiento de TAC_anual.xlsx         ###
###  Output: tac_sy — TAC por especie, región, año       ###
###  Para reemplazar lagged proxy en poisson_model.R      ###
###------------------------------------------------------###


rm(list = ls())
gc()

library(readxl)
library(dplyr)
library(tidyr)
library(lubridate)
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

# Normalize species names
normalize_species <- function(x) {
  x <- str_to_lower(str_trim(x))
  case_when(
    str_detect(x, "anchov")           ~ "anchoveta",
    str_detect(x, "jurel")            ~ "jurel",
    str_detect(x, "sardina c|sardina$") ~ "sardina_comun",
    TRUE                              ~ NA_character_
  )
}

# Map artisanal region strings to numeric region codes
# CS regions: 5, 6, 7, 8, 9, 14, 10, 16
map_art_region <- function(x) {
  x <- str_trim(x)
  case_when(
    str_detect(x, "^V[^I]|^V$|^V |^ARTESANAL V$|^V Reg")                  ~ 5L,
    str_detect(x, "^VI[^I]|^VI$|^VI |^ARTESANAL VI$|^VI Reg")             ~ 6L,
    str_detect(x, "^VII[^I]|^VII$|^VII |^ARTESANAL VII$|^VII Del|^VII Reg") ~ 7L,
    str_detect(x, "^VIII|^ARTESANAL VIII")                                  ~ 8L,
    str_detect(x, "^IX|^ARTESANAL IX")                                      ~ 9L,
    str_detect(x, "^XIV|^ARTESANAL XIV")                                    ~ 14L,
    str_detect(x, "^X[^IV]|^X$|^X |^ARTESANAL X$|^X Reg")                 ~ 10L,
    str_detect(x, "^XVI|^ARTESANAL XVI")                                    ~ 16L,
    TRUE                                                                    ~ NA_integer_
  )
}

tac_art <- tac_art_raw %>%
  rename(year = 1, species_raw = 2, region_raw = 3, TAC = 4) %>%
  mutate(
    species    = normalize_species(species_raw),
    region_code = map_art_region(region_raw)
  ) %>%
  filter(
    !is.na(species),
    !is.na(region_code),
    region_code %in% c(5, 6, 7, 8, 9, 14, 10, 16)
  ) %>%
  select(year, species, region_code, TAC_art = TAC)

# Handle VIII-XVI merged regions (2018+)
# When region_code == 8 and the raw name includes XVI, it's VIII+XVI combined
# Split: assign full amount to region 8 (most activity is there)
# Alternatively, check if XVI appears separately
tac_art <- tac_art %>%
  mutate(
    # If region 8 already captured VIII-XVI combined, keep as 8
    # XVI vessels will get region 8 TAC (conservative, same area)
    region_code = if_else(region_code == 16, 8L, region_code)
  ) %>%
  group_by(year, species, region_code) %>%
  summarise(TAC_art = sum(TAC_art, na.rm = TRUE), .groups = "drop")

cat("=== ARTISANAL TAC (CS) ===\n")
cat("Years:", paste(sort(unique(tac_art$year)), collapse = ", "), "\n")
cat("Species:", paste(unique(tac_art$species), collapse = ", "), "\n")
cat("Regions:", paste(sort(unique(tac_art$region_code)), collapse = ", "), "\n")
cat("Rows:", nrow(tac_art), "\n\n")

# Quick check: total by species-year
tac_art %>%
  group_by(year, species) %>%
  summarise(TAC_cs = round(sum(TAC_art)), .groups = "drop") %>%
  pivot_wider(names_from = species, values_from = TAC_cs) %>%
  print(n = 15)


# =========================================================================
# 3. INDUSTRIAL: Clean and filter CS zones
# =========================================================================

# Industrial zones for CS:
#   Anchoveta: "V - X" / "V-X" / "V -X"
#   Sardina:   "V - X" / "V-X" / "V -X"
#   Jurel:     "V - IX" / "V-IX" + "XIV - X" / "XIV-X"

map_ind_zone <- function(x) {
  x <- str_trim(x)
  case_when(
    str_detect(x, "V.*IX|V-IX|INDUSTRIAL V-IX")  ~ "V_IX",
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
# 4. COMBINE: Total TAC CS by species-year (artesanal + industrial)
# =========================================================================

# Artisanal: sum across CS regions
tac_art_total <- tac_art %>%
  group_by(year, species) %>%
  summarise(TAC_art_cs = sum(TAC_art, na.rm = TRUE), .groups = "drop")

# Industrial: sum V-IX + XIV-X for jurel; V-X for anchoveta/sardina
tac_ind_total <- tac_ind %>%
  group_by(year, species) %>%
  summarise(TAC_ind_cs = sum(TAC_ind, na.rm = TRUE), .groups = "drop")

# Merge
tac_total <- tac_art_total %>%
  full_join(tac_ind_total, by = c("year", "species")) %>%
  mutate(
    TAC_art_cs = replace_na(TAC_art_cs, 0),
    TAC_ind_cs = replace_na(TAC_ind_cs, 0),
    TAC_cs     = TAC_art_cs + TAC_ind_cs
  )

cat("\n=== TOTAL TAC CS (ART + IND) ===\n")
tac_total %>%
  select(year, species, TAC_cs) %>%
  pivot_wider(names_from = species, values_from = TAC_cs) %>%
  print(n = 15)


# =========================================================================
# 5. MAP SPECIES TO COD_ESPECIE (for merge with poisson_df)
# =========================================================================

species_map <- tibble(
  species      = c("anchoveta", "jurel", "sardina_comun"),
  COD_ESPECIE  = c(114L, 26L, 33L)
)

tac_sy <- tac_total %>%
  left_join(species_map, by = "species") %>%
  select(year, COD_ESPECIE, species, TAC_art_cs, TAC_ind_cs, TAC_cs)

cat("\n=== TAC_sy FINAL ===\n")
print(tac_sy, n = 40)


# =========================================================================
# 6. COMPUTE H_alloc_vy WITH OFFICIAL TAC
# =========================================================================
# Replace the lagged proxy with actual TAC

# Option A: Use total CS TAC (art + ind combined)
# This is appropriate if vessels can access the full CS quota pool
halloc_official <- shares_vs %>%
  left_join(
    tac_sy %>% select(year, COD_ESPECIE, TAC_cs),
    by = "COD_ESPECIE",
    relationship = "many-to-many"
  ) %>%
  mutate(H_alloc_vys = omega_vs * TAC_cs) %>%
  group_by(COD_BARCO, year) %>%
  summarise(H_alloc_vy = sum(H_alloc_vys, na.rm = TRUE), .groups = "drop")

# Option B: Use fleet-specific TAC (art TAC for artisanal vessels, ind TAC for industrial)
# This is more accurate if fleets face separate quota pools
halloc_by_fleet <- shares_vs %>%
  left_join(vessel_chars %>% select(COD_BARCO, TIPO_FLOTA), by = "COD_BARCO") %>%
  left_join(
    tac_sy %>% select(year, COD_ESPECIE, TAC_art_cs, TAC_ind_cs),
    by = "COD_ESPECIE",
    relationship = "many-to-many"
  ) %>%
  mutate(
    TAC_fleet = if_else(TIPO_FLOTA == "IND", TAC_ind_cs, TAC_art_cs),
    H_alloc_vys = omega_vs * TAC_fleet
  ) %>%
  group_by(COD_BARCO, year) %>%
  summarise(H_alloc_vy = sum(H_alloc_vys, na.rm = TRUE), .groups = "drop")

cat("\nH_alloc comparison (mean by fleet):\n")
cat("  Option A (total TAC):\n")
halloc_official %>%
  left_join(vessel_chars %>% select(COD_BARCO, TIPO_FLOTA), by = "COD_BARCO") %>%
  group_by(TIPO_FLOTA) %>%
  summarise(mean_halloc = round(mean(H_alloc_vy), 1), .groups = "drop") %>%
  print()

cat("  Option B (fleet-specific TAC):\n")
halloc_by_fleet %>%
  left_join(vessel_chars %>% select(COD_BARCO, TIPO_FLOTA), by = "COD_BARCO") %>%
  group_by(TIPO_FLOTA) %>%
  summarise(mean_halloc = round(mean(H_alloc_vy), 1), .groups = "drop") %>%
  print()

cat("\n[RECOMMENDATION] Use Option B (fleet-specific TAC).\n")
cat("  Artesanal and industrial face separate quota pools in Chile.\n")
cat("  Replace 'halloc' in the merge with 'halloc_by_fleet'.\n")


# =========================================================================
# 7. SAVE
# =========================================================================

dir.create("data/trips", showWarnings = FALSE, recursive = TRUE)
saveRDS(tac_sy, file = "data/trips/tac_sy.rds")
cat("\n✓ Saved: data/trips/tac_sy.rds\n")
