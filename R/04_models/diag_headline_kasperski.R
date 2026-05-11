###============================================================###
###  P4d: HEADLINE ASYMMETRY CHECK with primary spec            ###
###  Quick (point-estimate) recomputation of factor_trips       ###
###  under SSP5-8.5 end-of-century, to see if the 11:1 marg /   ###
###  3.4:1 cond asymmetry moves materially with the Kasperski   ###
###  primary spec (3 beta_h^s + TIPO_EMB interaction in ART).   ###
###                                                              ###
###  No posterior propagation here -- only point estimates.     ###
###  Full propagation comes in P4 proper (13_trip_comparative). ###
###============================================================###

rm(list = setdiff(ls(), c("dirdata")))
gc()

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(MASS)
})
select <- dplyr::select
filter <- dplyr::filter

# --- Inputs ---------------------------------------------------------------
dt <- readRDS("data/trips/poisson_dt.rds")

# Primary fits (saved by SEC 14)
nb_ind <- readRDS("data/outputs/nb_kasperski/nb_ind_primary.rds")
nb_art <- readRDS("data/outputs/nb_kasperski/nb_art_primary.rds")

# Legacy fits for comparison
nb_ind_leg <- readRDS("data/outputs/nb_kasperski/nb_ind_legacy_fe.rds")
nb_art_leg <- readRDS("data/outputs/nb_kasperski/nb_art_legacy_fe.rds")

# CMIP6 delta_days_bw per vessel x model x scenario x window
dbw <- readRDS("data/cmip6/delta_days_bw_vessel.rds")

# --- factor_B SSP5-8.5 end-of-century medians from growth compstat -------
# From paper1/tables/growth_comparative_statics.csv (cross-model medians):
#   Anchoveta: -89.6% -> factor_B = 0.104
#   Sardine:   -99.9% -> factor_B = 0.001
#   Jurel:     n.i.   -> factor_B = 1.0
factor_B <- c(anchoveta = 0.104, sardina_comun = 0.001, jurel = 1.0)
cat("\nfactor_B (SSP5-8.5 2081-2100, cross-model medians):\n")
print(factor_B)

# --- H_alloc_hist per vessel x species (median over 2013-2024) ----------
v_halloc <- dt %>%
  group_by(COD_BARCO, TIPO_FLOTA, TIPO_EMB) %>%
  summarise(
    H_alloc_anchoveta     = median(H_alloc_anchoveta,     na.rm = TRUE),
    H_alloc_sardina_comun = median(H_alloc_sardina_comun, na.rm = TRUE),
    H_alloc_jurel         = median(H_alloc_jurel,         na.rm = TRUE),
    H_alloc_vy_legacy     = median(H_alloc_vy,            na.rm = TRUE),
    .groups = "drop"
  )

# --- Vessel-level delta_days_bw cross-model median (SSP585 end) ---------
dbw_v <- dbw %>%
  filter(scenario == "ssp585", window == "end") %>%
  group_by(COD_BARCO) %>%
  summarise(delta_w = median(delta_days_bw), .groups = "drop")
# Note: panel COD_BARCO is character (e.g. "18A3D"); dbw should match
v_halloc$COD_BARCO <- as.character(v_halloc$COD_BARCO)
dbw_v$COD_BARCO   <- as.character(dbw_v$COD_BARCO)
v_panel <- v_halloc %>% inner_join(dbw_v, by = "COD_BARCO")
cat("\nVessels with both H_alloc and delta_w (SSP585 end):", nrow(v_panel), "\n")
cat("  by fleet:\n"); print(v_panel %>% count(TIPO_FLOTA))

# --- Coefficients from primary fits --------------------------------------
cf_ind <- coef(nb_ind)
cf_art <- coef(nb_art)
cf_ind_leg <- coef(nb_ind_leg)
cf_art_leg <- coef(nb_art_leg)

cat("\n--- Primary betas (point estimates) ---\n")
cat("IND:\n")
cat("  beta_h_anch:    ", signif(cf_ind["H_alloc_anchoveta"], 4), "\n")
cat("  beta_h_sard:    ", signif(cf_ind["H_alloc_sardina_comun"], 4), "\n")
cat("  beta_h_jurel:   ", signif(cf_ind["H_alloc_jurel"], 4), "\n")
cat("  beta_weather:   ", signif(cf_ind["days_bad_weather"], 4), "\n")

cat("ART (base, TIPO_EMB = BM):\n")
cat("  beta_h_anch_BM: ", signif(cf_art["H_alloc_anchoveta"], 4), "\n")
cat("  beta_h_sard:    ", signif(cf_art["H_alloc_sardina_comun"], 4), "\n")
cat("  beta_h_jurel:   ", signif(cf_art["H_alloc_jurel"], 4), "\n")
cat("  beta_weather:   ", signif(cf_art["days_bad_weather"], 4), "\n")
cat("  interactions H_alloc_anchoveta x TIPO_EMB:\n")
inter_terms <- cf_art[grep("^H_alloc_anchoveta:TIPO_EMB", names(cf_art))]
print(round(inter_terms, 6))

# Build a lookup of marginal beta_h_anch by TIPO_EMB in ART
base_anch <- cf_art["H_alloc_anchoveta"]
beta_h_anch_by_emb <- c(BM = base_anch)
for (nm in names(inter_terms)) {
  em <- sub("H_alloc_anchoveta:TIPO_EMB", "", nm)
  beta_h_anch_by_emb[em] <- base_anch + inter_terms[nm]
}
cat("\nMarginal beta_h^anch by TIPO_EMB (ART):\n")
print(round(beta_h_anch_by_emb, 6))


# --- Compute factor_trips per vessel: PRIMARY vs LEGACY -----------------
# Drop TIPO_EMB with N < 50 (BR, BRV, L) before computing indirect_primary
# These have absurd interaction coefficients (overflow exp); drop or cap
v_panel <- v_panel %>%
  filter(!(TIPO_FLOTA == "ART" & TIPO_EMB %in% c("BR", "BRV", "L")))
cat("After dropping TIPO_EMB N<50 in ART: ", nrow(v_panel), "vessels\n")

# Map beta_h_anch by TIPO_EMB; safe fallback to base for any new level
get_beta_anch <- function(fleet, emb) {
  if (fleet == "IND") return(cf_ind["H_alloc_anchoveta"])
  v <- beta_h_anch_by_emb[emb]
  if (is.na(v)) v <- base_anch
  v
}
v_panel$beta_h_anch_used <- mapply(get_beta_anch, v_panel$TIPO_FLOTA, v_panel$TIPO_EMB)

v_panel <- v_panel %>%
  mutate(
    H_total_legacy = pmax(H_alloc_anchoveta + H_alloc_sardina_comun + H_alloc_jurel, 1e-9),
    omega_anch     = H_alloc_anchoveta     / H_total_legacy,
    omega_sard     = H_alloc_sardina_comun / H_total_legacy,
    omega_jur      = H_alloc_jurel         / H_total_legacy,
    # vessel-specific factor_H = sum_s omega_v_s * factor_B_s
    factor_H_v     = omega_anch * factor_B["anchoveta"] +
                     omega_sard * factor_B["sardina_comun"] +
                     omega_jur  * factor_B["jurel"],
    # Indirect channel PRIMARY (Kasperski): sum_s beta_h^s * H_alloc_s * (f_s - 1)
    indirect_primary = case_when(
      TIPO_FLOTA == "IND" ~ cf_ind["H_alloc_anchoveta"]     * H_alloc_anchoveta     * (factor_B["anchoveta"]     - 1) +
                            cf_ind["H_alloc_sardina_comun"] * H_alloc_sardina_comun * (factor_B["sardina_comun"] - 1) +
                            cf_ind["H_alloc_jurel"]         * H_alloc_jurel         * (factor_B["jurel"]         - 1),
      TIPO_FLOTA == "ART" ~ beta_h_anch_used                * H_alloc_anchoveta     * (factor_B["anchoveta"]     - 1) +
                            cf_art["H_alloc_sardina_comun"] * H_alloc_sardina_comun * (factor_B["sardina_comun"] - 1) +
                            cf_art["H_alloc_jurel"]         * H_alloc_jurel         * (factor_B["jurel"]         - 1)
    ),
    # Indirect channel LEGACY: beta_H_scalar * H_alloc_vy * (factor_H_v - 1)
    # using the vessel-specific factor_H_v, NOT cross-species mean.
    indirect_legacy = case_when(
      TIPO_FLOTA == "IND" ~ cf_ind_leg["H_alloc_vy"] * H_alloc_vy_legacy * (factor_H_v - 1),
      TIPO_FLOTA == "ART" ~ cf_art_leg["H_alloc_vy"] * H_alloc_vy_legacy * (factor_H_v - 1)
    ),
    # Direct channel (weather)
    direct_primary = case_when(
      TIPO_FLOTA == "IND" ~ cf_ind["days_bad_weather"] * delta_w,
      TIPO_FLOTA == "ART" ~ cf_art["days_bad_weather"] * delta_w
    ),
    direct_legacy = case_when(
      TIPO_FLOTA == "IND" ~ cf_ind_leg["days_bad_weather"] * delta_w,
      TIPO_FLOTA == "ART" ~ cf_art_leg["days_bad_weather"] * delta_w
    ),
    # Combined factor_trips
    factor_trips_primary = exp(indirect_primary + direct_primary),
    factor_trips_legacy  = exp(indirect_legacy  + direct_legacy),
    delta_pct_primary    = 100 * (factor_trips_primary - 1),
    delta_pct_legacy     = 100 * (factor_trips_legacy  - 1),
    # Portfolio collapse flag (Pr_loss > 50%): vessel-specific f^H_v
    # Approximation: f^H = (H_anch * factor_B_anch + H_sard * factor_B_sard + H_jur * factor_B_jur) / H_total
    H_total              = H_alloc_anchoveta + H_alloc_sardina_comun + H_alloc_jurel,
    f_H_v                = (H_alloc_anchoveta * factor_B["anchoveta"] +
                            H_alloc_sardina_comun * factor_B["sardina_comun"] +
                            H_alloc_jurel * factor_B["jurel"]) / pmax(H_total, 1e-6),
    portfolio_collapse   = f_H_v < 0.5
  )

# beta_h_anch_used already attached above (cleaner version)


# --- Aggregate by fleet --------------------------------------------------
cat("\n=========================================================\n")
cat("  HEADLINE COMPARISON: PRIMARY vs LEGACY (point estimates)\n")
cat("=========================================================\n")
cat("\n--- Marginal (all vessels) ---\n")
agg_marg <- v_panel %>%
  group_by(TIPO_FLOTA) %>%
  summarise(
    n = n(),
    median_delta_primary = median(delta_pct_primary),
    median_delta_legacy  = median(delta_pct_legacy),
    pr_loss_primary      = mean(delta_pct_primary < 0),
    pr_loss_legacy       = mean(delta_pct_legacy  < 0),
    .groups = "drop"
  )
print(agg_marg)

cat("\n--- Conditional (excluding portfolio collapse, f_H_v >= 0.5) ---\n")
agg_cond <- v_panel %>%
  filter(!portfolio_collapse) %>%
  group_by(TIPO_FLOTA) %>%
  summarise(
    n_cond                = n(),
    median_delta_primary  = median(delta_pct_primary),
    median_delta_legacy   = median(delta_pct_legacy),
    .groups = "drop"
  )
print(agg_cond)

cat("\n--- Asymmetry headline (ART / IND ratio) ---\n")
art_marg_p <- agg_marg$median_delta_primary[agg_marg$TIPO_FLOTA == "ART"]
ind_marg_p <- agg_marg$median_delta_primary[agg_marg$TIPO_FLOTA == "IND"]
art_marg_l <- agg_marg$median_delta_legacy[agg_marg$TIPO_FLOTA == "ART"]
ind_marg_l <- agg_marg$median_delta_legacy[agg_marg$TIPO_FLOTA == "IND"]

art_cond_p <- agg_cond$median_delta_primary[agg_cond$TIPO_FLOTA == "ART"]
ind_cond_p <- agg_cond$median_delta_primary[agg_cond$TIPO_FLOTA == "IND"]
art_cond_l <- agg_cond$median_delta_legacy[agg_cond$TIPO_FLOTA == "ART"]
ind_cond_l <- agg_cond$median_delta_legacy[agg_cond$TIPO_FLOTA == "IND"]

cat(sprintf("  Marginal  PRIMARY : ART %.2f%% / IND %.2f%% = %.2f:1\n",
            art_marg_p, ind_marg_p, art_marg_p / ind_marg_p))
cat(sprintf("  Marginal  LEGACY  : ART %.2f%% / IND %.2f%% = %.2f:1\n",
            art_marg_l, ind_marg_l, art_marg_l / ind_marg_l))
cat(sprintf("  Cond      PRIMARY : ART %.2f%% / IND %.2f%% = %.2f:1\n",
            art_cond_p, ind_cond_p, art_cond_p / ind_cond_p))
cat(sprintf("  Cond      LEGACY  : ART %.2f%% / IND %.2f%% = %.2f:1\n",
            art_cond_l, ind_cond_l, art_cond_l / ind_cond_l))

cat("\n  Paper-1 published numbers (from tables/trip_comparative_statics.csv,\n")
cat("  SSP5-8.5 end-of-century): ART marg -10.2%, IND marg -0.9% (= 11.3:1);\n")
cat("                            ART cond  -2.7%, IND cond -0.8% (=  3.4:1).\n")


# --- Within-ART decomposition by TIPO_EMB --------------------------------
cat("\n=========================================================\n")
cat("  WITHIN-ART decomposition by TIPO_EMB (primary spec)\n")
cat("=========================================================\n")
agg_emb <- v_panel %>%
  filter(TIPO_FLOTA == "ART") %>%
  group_by(TIPO_EMB) %>%
  summarise(
    n                    = n(),
    median_delta_primary = median(delta_pct_primary),
    median_delta_legacy  = median(delta_pct_legacy),
    .groups = "drop"
  ) %>%
  arrange(desc(n))
print(agg_emb)


# Save full table for inspection
dir.create("data/outputs/nb_kasperski", showWarnings = FALSE, recursive = TRUE)
write.csv(v_panel %>% select(COD_BARCO, TIPO_FLOTA, TIPO_EMB,
                             H_alloc_anchoveta, H_alloc_sardina_comun, H_alloc_jurel,
                             delta_w, beta_h_anch_used,
                             indirect_primary, indirect_legacy,
                             direct_primary, direct_legacy,
                             delta_pct_primary, delta_pct_legacy,
                             f_H_v, portfolio_collapse),
          "data/outputs/nb_kasperski/headline_check_ssp585_end.csv", row.names = FALSE)
cat("\n[OK] Saved: data/outputs/nb_kasperski/headline_check_ssp585_end.csv\n")
