###============================================================###
###   Regime diagnostic — Version C (paper 2)                  ###
###   Empirical classification of the historical binding       ###
###   regime by (year, species, sector).                       ###
###                                                            ###
###   Spec: paper1/version_C_spec.md §4.                       ###
###                                                            ###
###   Decision rule output drives whether Version C is         ###
###   adopted as primary, demoted to robustness, or dropped.   ###
###============================================================###
#
# Inputs:
#   data/bio_params/official_biomass_series.csv      — B_{s,y} (biomass_total_t)
#   data/bio_params/acoustic_biomass_series.csv      — B_{s,y} for jurel_cs
#   data/bio_params/catch_annual_paper1_by_sector.csv — H_{s,y,f} realized
#   data/trips/tac_art.rds                            — Q_{s,y,r} artisanal regional
#   data/trips/tac_ind.rds                            — Q_{s,y,z} industrial zonal
#
# Outputs:
#   data/outputs/regime_diagnostic_cell.csv          — one row per (year,species,sector)
#   data/outputs/regime_diagnostic_summary.csv       — fractions by species×sector×decade
#   data/outputs/regime_diagnostic_decision.txt      — Version A vs C decision text
#   data/outputs/regime_diagnostic_u_bar_empirical.csv — direct-empirical p90/p95 of H/B
#
# Convention:
#   util       = H_realized / Q_legal       (legal-cap utilisation)
#   biom_rate  = H_realized / B_year        (biomass extraction rate)
#
#   regime = quota_binding   if util >= 0.85 & biom_rate <  0.4
#          = biology_binding if util <  0.85 & biom_rate >= 0.3
#          = ambiguous       otherwise
#
#   Aggregation of TAC: regional/zonal Q is summed within
#   (year, species, sector) before computing util — see remark 2 of
#   §3.2 of the spec on identification of beta_q^s.
###============================================================###

rm(list = ls())
gc()

source("R/00_config/config.R")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
  library(stringr)
})

# ------------------------------------------------------------------ paths ----

OUT_DIR <- "data/outputs"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)


# =========================================================================
# 1. BIOMASS B_{s,y}
# =========================================================================
# Use total biomass (biomass_total_t) from the official assessment series
# for anchoveta_cs and sardina_comun_cs. For jurel use the acoustic series
# (no age-structured assessment at CS scale; see official_assessments.yaml).

biomass_official <- read_csv(
  "data/bio_params/official_biomass_series.csv",
  show_col_types = FALSE
) %>%
  filter(stock_id %in% c("anchoveta_cs", "sardina_comun_cs")) %>%
  transmute(
    stock_id,
    species = case_when(
      stock_id == "anchoveta_cs"     ~ "anchoveta",
      stock_id == "sardina_comun_cs" ~ "sardina_comun"
    ),
    year     = as.integer(year),
    B_year_t = biomass_total_t
  ) %>%
  filter(!is.na(B_year_t), B_year_t > 0)

# Jurel CS: acoustic_biomass_series.csv (centro-sur scale) — column is
# `species`, not `stock_id`. May have multiple cruises per year (RECLAS
# verano + PELACES otoño); take the annual mean as B_{s,y}. Years with no
# survey are missing from the series — those cells will join to NA and be
# flagged 'no_data' below.
biomass_jurel <- read_csv(
  "data/bio_params/acoustic_biomass_series.csv",
  show_col_types = FALSE
) %>%
  filter(species == "jurel_cs") %>%
  transmute(
    species  = "jurel",
    year     = as.integer(year),
    biomass_t
  ) %>%
  filter(!is.na(biomass_t), biomass_t > 0) %>%
  group_by(species, year) %>%
  summarise(B_year_t = mean(biomass_t), .groups = "drop")

biomass <- bind_rows(biomass_official %>% select(-stock_id), biomass_jurel) %>%
  select(year, species, B_year_t)

cat("\n=== Biomass series loaded ===\n")
biomass %>% count(species, name = "n_years") %>% print()


# =========================================================================
# 2. REALIZED HARVEST H_{s,y,f}
# =========================================================================
# Sector breakdown from SERNAPESCA bd_desembarque (paper1).
# For anchoveta_cs and sardina_comun_cs the file already has the CS sector
# split. For jurel we want CS-only (not Chile-total): take catch_jurel_cs
# total and split by the institutional 90/10 IND/ART share documented in
# official_assessments.yaml::jurel_cs::regulacion. This matches the
# geographic scale of the biomass series.

harvest_sector_pelagics <- read_csv(
  "data/bio_params/catch_annual_paper1_by_sector.csv",
  show_col_types = FALSE
) %>%
  filter(stock_id %in% c("anchoveta_cs", "sardina_comun_cs")) %>%
  transmute(
    species = case_when(
      stock_id == "anchoveta_cs"     ~ "anchoveta",
      stock_id == "sardina_comun_cs" ~ "sardina_comun"
    ),
    year   = as.integer(year),
    sector = case_when(
      sector == "Artesanal"  ~ "ART",
      sector == "Industrial" ~ "IND",
      TRUE                    ~ NA_character_
    ),
    H_realized_t = catch_t
  ) %>%
  filter(!is.na(sector))

# Jurel CS sector split: prefer the SERNAPESCA-derived sectoral series
# (data/bio_params/catch_jurel_cs_by_sector.csv, written by
# R/07_structural_bio/08_build_jurel_cs_catch.R::write_jurel_cs_by_sector_csv).
# That file aggregates SERNAPESCA bd_desembarque restricted to V-X+Los Ríos
# and grouped by tipo_agente, so the geographic scale matches the acoustic
# biomass series exactly. If the file is missing (build hasn't been run on
# this machine) fall back to the institutional 90/10 IND/ART split from the
# YAML, with a clear warning.

jurel_sec_csv <- "data/bio_params/catch_jurel_cs_by_sector.csv"

if (file.exists(jurel_sec_csv)) {
  harvest_sector_jurel <- read_csv(jurel_sec_csv, show_col_types = FALSE) %>%
    filter(stock_id == "jurel_cs") %>%
    transmute(
      species = "jurel",
      year    = as.integer(year),
      sector  = case_when(
        sector == "Artesanal"  ~ "ART",
        sector == "Industrial" ~ "IND",
        TRUE                    ~ NA_character_
      ),
      H_realized_t = catch_t
    ) %>%
    filter(!is.na(sector))
  cat("\n[INFO] jurel_cs sectoral catch from SERNAPESCA bd_desembarque (",
      jurel_sec_csv, ")\n", sep = "")
} else {
  warning(
    "catch_jurel_cs_by_sector.csv not found. ",
    "Run R/07_structural_bio/08_build_jurel_cs_catch.R::write_jurel_cs_by_sector_csv() ",
    "with options(structural_bio.run_main = TRUE) to generate it. ",
    "Falling back to the institutional 90/10 IND/ART split."
  )
  JUREL_CS_IND_SHARE <- 0.90
  JUREL_CS_ART_SHARE <- 0.10
  harvest_sector_jurel <- read_csv(
    "data/bio_params/catch_jurel_cs.csv",
    show_col_types = FALSE
  ) %>%
    filter(stock_id == "jurel_cs") %>%
    transmute(species = "jurel",
              year    = as.integer(year),
              catch_t) %>%
    tidyr::crossing(sector = c("IND", "ART")) %>%
    mutate(H_realized_t = catch_t * if_else(sector == "IND",
                                             JUREL_CS_IND_SHARE,
                                             JUREL_CS_ART_SHARE)) %>%
    select(species, year, sector, H_realized_t)
}

harvest_sector <- bind_rows(harvest_sector_pelagics, harvest_sector_jurel)

cat("\n=== Realized harvest rows ===\n")
harvest_sector %>% count(species, sector) %>%
  pivot_wider(names_from = sector, values_from = n) %>% print()


# =========================================================================
# 3. LEGAL TAC Q_{s,y,f}
# =========================================================================
# Aggregate regional/zonal cuotas into a single sectoral cap per (year,
# species). This sums Q_{s,y,r} across regions for ART and Q_{s,y,z}
# across zones for IND, matching the convention used to compare against
# H_realized at the sector level.

tac_art <- readRDS("data/trips/tac_art.rds")     # year, species, region_code, COD_ESPECIE, TAC_art
tac_ind <- readRDS("data/trips/tac_ind.rds")     # year, species, zone, COD_ESPECIE, TAC_ind

species_norm <- function(x) {
  case_when(
    x == "anchoveta"     ~ "anchoveta",
    x == "sardina_comun" ~ "sardina_comun",
    x == "jurel"         ~ "jurel",
    TRUE                  ~ NA_character_
  )
}

Q_art <- tac_art %>%
  transmute(year = as.integer(year), species = species_norm(species),
            sector = "ART", TAC_t = TAC_art) %>%
  group_by(year, species, sector) %>%
  summarise(Q_legal_t = sum(TAC_t, na.rm = TRUE), .groups = "drop")

Q_ind <- tac_ind %>%
  transmute(year = as.integer(year), species = species_norm(species),
            sector = "IND", TAC_t = TAC_ind) %>%
  group_by(year, species, sector) %>%
  summarise(Q_legal_t = sum(TAC_t, na.rm = TRUE), .groups = "drop")

Q_sectoral <- bind_rows(Q_art, Q_ind) %>% filter(!is.na(species))

cat("\n=== Sectoral TAC coverage ===\n")
Q_sectoral %>%
  group_by(species, sector) %>%
  summarise(years = paste(min(year), max(year), sep = "-"),
            n     = n(), .groups = "drop") %>% print()


# =========================================================================
# 4. JOIN AND CLASSIFY
# =========================================================================

regime_cell <- harvest_sector %>%
  left_join(biomass,    by = c("year", "species")) %>%
  left_join(Q_sectoral, by = c("year", "species", "sector")) %>%
  mutate(
    util      = H_realized_t / Q_legal_t,
    biom_rate = H_realized_t / B_year_t,
    decade    = paste0(10L * (year %/% 10L), "s"),
    regime    = case_when(
      is.na(B_year_t) | is.na(Q_legal_t)        ~ "no_data",
      util >= 0.85 & biom_rate <  0.4           ~ "quota_binding",
      util <  0.85 & biom_rate >= 0.3           ~ "biology_binding",
      TRUE                                       ~ "ambiguous"
    )
  ) %>%
  arrange(species, sector, year)

write_csv(regime_cell, file.path(OUT_DIR, "regime_diagnostic_cell.csv"))
cat("\n[OK] Saved cell-level diagnostic:",
    file.path(OUT_DIR, "regime_diagnostic_cell.csv"), "\n")

cat("\n=== Cells with usable (B,Q) by species × sector ===\n")
regime_cell %>%
  filter(regime != "no_data") %>%
  count(species, sector) %>%
  pivot_wider(names_from = sector, values_from = n, values_fill = 0) %>% print()


# =========================================================================
# 5. AGGREGATE: fractions by species × sector × decade
# =========================================================================

regime_summary <- regime_cell %>%
  filter(regime != "no_data") %>%
  count(species, sector, decade, regime) %>%
  group_by(species, sector, decade) %>%
  mutate(
    n_total = sum(n),
    share   = n / n_total
  ) %>%
  ungroup() %>%
  pivot_wider(names_from = regime, values_from = c(n, share),
              values_fill = 0) %>%
  select(species, sector, decade, n_total,
         starts_with("n_"), starts_with("share_"))

write_csv(regime_summary, file.path(OUT_DIR, "regime_diagnostic_summary.csv"))
cat("\n[OK] Saved decade summary:",
    file.path(OUT_DIR, "regime_diagnostic_summary.csv"), "\n")

cat("\n=== Regime fractions by species × sector × decade ===\n")
print(regime_summary, n = Inf)


# =========================================================================
# 6. POOLED HEADLINE: biology-binding share for the decision rule
# =========================================================================

pooled <- regime_cell %>%
  filter(regime != "no_data") %>%
  count(regime) %>%
  mutate(
    n_total = sum(n),
    share   = n / n_total
  )

share_biology   <- pooled$share[pooled$regime == "biology_binding"]
share_biology   <- ifelse(length(share_biology) == 0, 0, share_biology)
share_quota     <- pooled$share[pooled$regime == "quota_binding"]
share_quota     <- ifelse(length(share_quota)  == 0, 0, share_quota)
share_ambiguous <- pooled$share[pooled$regime == "ambiguous"]
share_ambiguous <- ifelse(length(share_ambiguous) == 0, 0, share_ambiguous)

cat("\n=== Pooled regime shares (decision rule input) ===\n")
print(pooled)


# =========================================================================
# 7. DECISION RULE (spec §4.1)
# =========================================================================

decision <- if (share_biology >= 0.20) {
  list(
    bracket = ">= 20%",
    path    = "Adopt Version C as primary specification.",
    framing = sprintf(
      paste0("Headline fraction biology_binding = %.1f%% across %.0f cells. ",
             "Substantial fraction of historical observations were biology-",
             "binding; the assumption of universal quota-binding mis-identifies",
             " beta_h^s and biases the projection of climate impacts."),
      100 * share_biology, sum(pooled$n)
    )
  )
} else if (share_biology >= 0.05) {
  list(
    bracket = "5%-20%",
    path    = "Adopt Version A as primary; report Version C as robustness in appendix.",
    framing = sprintf(
      paste0("Headline fraction biology_binding = %.1f%% across %.0f cells. ",
             "Version C extension is marginal but defensible given the ",
             "heterogeneity of regime conditions across the sample."),
      100 * share_biology, sum(pooled$n)
    )
  )
} else {
  list(
    bracket = "< 5%",
    path    = "Adopt Version A pure (Kasperski direct), drop Version C.",
    framing = sprintf(
      paste0("Headline fraction biology_binding = %.1f%% across %.0f cells. ",
             "The legal TAC was the active constraint in essentially all ",
             "observations; the min operator is decorative."),
      100 * share_biology, sum(pooled$n)
    )
  )
}

decision_lines <- c(
  "=== Version C decision (paper1/version_C_spec.md §4.1) ===",
  sprintf("biology_binding share = %.1f%%", 100 * share_biology),
  sprintf("quota_binding share   = %.1f%%", 100 * share_quota),
  sprintf("ambiguous share       = %.1f%%", 100 * share_ambiguous),
  sprintf("decision bracket      = %s", decision$bracket),
  sprintf("recommended path      = %s", decision$path),
  "",
  "Framing for the manuscript:",
  decision$framing
)

writeLines(decision_lines, file.path(OUT_DIR, "regime_diagnostic_decision.txt"))
cat("\n", paste(decision_lines, collapse = "\n"), "\n", sep = "")


# =========================================================================
# 8. EMPIRICAL u_bar (sensitivity / fallback calibration)
# =========================================================================
# Spec §5 — direct calibration of u_bar_s as the 90th–95th percentile of
# H/B over quota-binding cells. Useful as cross-check vs the external
# Schaefer F_MSY = r/2 baked into config.R::U_BAR.

u_bar_empirical <- regime_cell %>%
  filter(regime == "quota_binding", !is.na(biom_rate)) %>%
  group_by(species) %>%
  summarise(
    n_cells     = n(),
    p50_HoverB  = quantile(biom_rate, 0.50, na.rm = TRUE),
    p90_HoverB  = quantile(biom_rate, 0.90, na.rm = TRUE),
    p95_HoverB  = quantile(biom_rate, 0.95, na.rm = TRUE),
    max_HoverB  = max(biom_rate, na.rm = TRUE),
    .groups     = "drop"
  ) %>%
  mutate(
    u_bar_external = U_BAR[match(species, names(U_BAR))],
    ratio_p95_ext  = p95_HoverB / u_bar_external
  )

write_csv(u_bar_empirical, file.path(OUT_DIR, "regime_diagnostic_u_bar_empirical.csv"))
cat("\n=== Empirical u_bar from quota-binding cells (vs external in config.R) ===\n")
print(u_bar_empirical)
cat("\n[OK] Saved:", file.path(OUT_DIR, "regime_diagnostic_u_bar_empirical.csv"), "\n")


# =========================================================================
# 9. SANITY: H/B exceeding u_bar_external
# =========================================================================
# Flag (year, species, sector) cells where realized exploitation rate
# exceeds the external u_bar. Many such cells suggest u_bar is too low
# and U_BAR in config.R should be revised upward before downstream use.

over_ubar <- regime_cell %>%
  filter(!is.na(biom_rate)) %>%
  mutate(u_bar_ext = U_BAR[match(species, names(U_BAR))]) %>%
  filter(biom_rate > u_bar_ext) %>%
  count(species, name = "n_cells_above_u_bar")

cat("\n=== Cells with H/B > U_BAR (config.R) — sanity check on u_bar ===\n")
if (nrow(over_ubar) == 0) {
  cat("  none — config.R U_BAR values are consistent with the data.\n")
} else {
  print(over_ubar)
  cat("\n  If a species has many such cells, raise U_BAR in config.R.\n",
      "  See empirical p95 above for a data-driven alternative.\n", sep = "")
}

cat("\n=== regime_diagnostic.R done ===\n")
