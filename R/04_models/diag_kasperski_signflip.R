###============================================================###
###  Diagnostics for Kasperski-aligned NB spec (2026-05-11)    ###
###  Investigates two surprises from poisson_model.R Sec 13:    ###
###    (A) beta_h^anchoveta < 0 in both fleets                  ###
###    (B) price_sardina sign flip: IND negative, ART positive  ###
###                                                              ###
###  Three diagnostics:                                          ###
###    D1. Kasperski WITHOUT year FE                             ###
###    D2. H_alloc_anchoveta x TIPO_EMB interaction in ART       ###
###    D3. Kasperski with REGIONAL-ONLY prices (no fallback)     ###
###                                                              ###
###  Run AFTER poisson_model.R (needs poisson_dt.rds + the      ###
###  saved kasperski/legacy fits)                                ###
###============================================================###

rm(list = setdiff(ls(), c("dirdata")))
gc()

suppressPackageStartupMessages({
  library(dplyr)
  library(MASS)
  library(sandwich)
  library(lmtest)
})
select <- dplyr::select
filter <- dplyr::filter

dt <- readRDS("data/trips/poisson_dt.rds")
df_ind <- dt %>% filter(TIPO_FLOTA == "IND")
df_art <- dt %>% filter(TIPO_FLOTA == "ART")

# Reload baseline fits (Kasperski + legacy with year FE)
nb_ind_k_base    <- readRDS("data/outputs/nb_kasperski/nb_ind_kasperski.rds")
nb_art_k_base    <- readRDS("data/outputs/nb_kasperski/nb_art_kasperski.rds")
nb_ind_leg_base  <- readRDS("data/outputs/nb_kasperski/nb_ind_legacy_fe.rds")
nb_art_leg_base  <- readRDS("data/outputs/nb_kasperski/nb_art_legacy_fe.rds")

# Pretty-print helper for main coefs (skip factor(year)/TIPO_EMB rows)
print_main <- function(ct, label) {
  cat("\n----- ", label, " -----\n", sep = "")
  keep <- !grepl("factor\\(year\\)|TIPO_EMB", rownames(ct))
  print(round(ct[keep, , drop = FALSE], 6))
}

# Coef extractor with cluster SE
fit_ct <- function(mod, df) {
  coeftest(mod, vcov = vcovCL(mod, cluster = df$COD_BARCO))
}

# Beta_h^s and beta_p^s extractor
bp_row <- function(ct, var, fleet, model) {
  if (!(var %in% rownames(ct))) return(NULL)
  r <- ct[var, ]
  data.frame(
    model = model, fleet = fleet, var = var,
    beta = signif(r[1], 4), se = signif(r[2], 3),
    z = round(r[3], 2), p = signif(r[4], 3),
    row.names = NULL
  )
}
bp_tab <- function(ct, fleet, model) {
  vars <- c("H_alloc_anchoveta", "H_alloc_sardina_comun", "H_alloc_jurel",
            "price_anchov", "price_sardina", "price_jurel")
  do.call(rbind, lapply(vars, function(v) bp_row(ct, v, fleet, model)))
}

# =========================================================
# BASELINE (for comparison)
# =========================================================
cat("\n=========================================================\n")
cat("  BASELINE: Kasperski-aligned with year FE (from SEC 13)\n")
cat("=========================================================\n")
ct_ind_base <- fit_ct(nb_ind_k_base, df_ind)
ct_art_base <- fit_ct(nb_art_k_base, df_art)
res_base <- rbind(
  bp_tab(ct_ind_base, "IND", "0_baseline"),
  bp_tab(ct_art_base, "ART", "0_baseline")
)
print(res_base)


# =========================================================
# D1: Kasperski WITHOUT year FE
# =========================================================
cat("\n=========================================================\n")
cat("  D1: Kasperski-aligned WITHOUT year FE\n")
cat("=========================================================\n")
cat("Hypothesis: if the price_sardina sign-flip disappears here,\n")
cat("it was the year FE absorbing the time trajectory.\n\n")

nb_ind_d1 <- glm.nb(
  T_vy ~ log_bodega +
    H_alloc_anchoveta + H_alloc_sardina_comun + H_alloc_jurel +
    price_anchov + price_sardina + price_jurel +
    days_bad_weather + days_closed_vy + TIPO_EMB,
  data = df_ind
)
nb_art_d1 <- glm.nb(
  T_vy ~ log_bodega +
    H_alloc_anchoveta + H_alloc_sardina_comun + H_alloc_jurel +
    price_anchov + price_sardina + price_jurel +
    days_bad_weather + days_closed_vy + TIPO_EMB,
  data = df_art
)
ct_ind_d1 <- fit_ct(nb_ind_d1, df_ind)
ct_art_d1 <- fit_ct(nb_art_d1, df_art)
print_main(ct_ind_d1, "IND  - D1 (no year FE)")
print_main(ct_art_d1, "ART  - D1 (no year FE)")
res_d1 <- rbind(
  bp_tab(ct_ind_d1, "IND", "D1_no_yearFE"),
  bp_tab(ct_art_d1, "ART", "D1_no_yearFE")
)

cat("\n  AIC comparison:\n")
cat("    IND  baseline (with FE):  ", round(AIC(nb_ind_k_base), 1), "\n")
cat("    IND  D1       (no FE):    ", round(AIC(nb_ind_d1),     1), "\n")
cat("    ART  baseline (with FE):  ", round(AIC(nb_art_k_base), 1), "\n")
cat("    ART  D1       (no FE):    ", round(AIC(nb_art_d1),     1), "\n")


# =========================================================
# D2: H_alloc_anchoveta x TIPO_EMB interaction in ART
# =========================================================
cat("\n=========================================================\n")
cat("  D2: H_alloc_anchoveta x TIPO_EMB interaction in ART\n")
cat("=========================================================\n")
cat("Hypothesis: beta_h^anch < 0 is heterogeneity by vessel type:\n")
cat("PAM (large, bulk-capture) may have beta > 0, while LM/BR\n")
cat("(small specialists) drive the average negative.\n\n")

# Inspect TIPO_EMB distribution in ART first
cat("TIPO_EMB distribution in ART:\n")
print(df_art %>% count(TIPO_EMB, sort = TRUE))

# Fit with interaction
nb_art_d2 <- glm.nb(
  T_vy ~ log_bodega +
    H_alloc_anchoveta * TIPO_EMB +
    H_alloc_sardina_comun + H_alloc_jurel +
    price_anchov + price_sardina + price_jurel +
    days_bad_weather + days_closed_vy +
    factor(year),
  data = df_art
)

ct_art_d2 <- fit_ct(nb_art_d2, df_art)
cat("\n----- ART - D2 (H_alloc_anch x TIPO_EMB) -----\n")
keep <- grepl("H_alloc_anchoveta|TIPO_EMB", rownames(ct_art_d2)) &
        !grepl("factor\\(year\\)", rownames(ct_art_d2))
print(round(ct_art_d2[keep, , drop = FALSE], 6))

# Compute marginal beta_h^anch by TIPO_EMB (base + interaction)
# Find the base coef (H_alloc_anchoveta alone) and interactions
coefs_anch <- ct_art_d2[grep("H_alloc_anchoveta", rownames(ct_art_d2)), , drop = FALSE]
base_anch <- coefs_anch["H_alloc_anchoveta", "Estimate"]
inter_rows <- rownames(coefs_anch)[grepl(":", rownames(coefs_anch))]
cat("\n  Marginal beta_h^anch by TIPO_EMB in ART:\n")
cat(sprintf("    %-25s %12.3e   (baseline TIPO_EMB)\n",
            "H_alloc_anchoveta", base_anch))
for (r in inter_rows) {
  tipo <- sub("H_alloc_anchoveta:TIPO_EMB", "", r)
  effect <- base_anch + coefs_anch[r, "Estimate"]
  cat(sprintf("    %-25s %12.3e   (TIPO_EMB = %s)\n",
              paste0("anch x ", tipo), effect, tipo))
}

cat("\n  AIC:\n")
cat("    ART  baseline (no interaction):  ", round(AIC(nb_art_k_base), 1), "\n")
cat("    ART  D2       (anch x TIPO_EMB): ", round(AIC(nb_art_d2),     1), "\n")
cat("    Delta:                            ", round(AIC(nb_art_d2) - AIC(nb_art_k_base), 1), "\n")


# =========================================================
# D3: Kasperski with REGIONAL-ONLY prices (no coalesce)
# =========================================================
cat("\n=========================================================\n")
cat("  D3: Kasperski with regional prices, NO fallback\n")
cat("=========================================================\n")
cat("Hypothesis: if the sign-flip / sign of beta_p^sardina changes\n")
cat("here, the coalesce(regional, national) was injecting noise.\n\n")

# Replace price_* with the *_reg only (drops rows with NA reg price)
prep_reg_only <- function(df) {
  df %>%
    mutate(
      price_anchov  = price_anchov_reg,
      price_sardina = price_sardina_reg,
      price_jurel   = price_jurel_reg
    ) %>%
    filter(!is.na(price_anchov), !is.na(price_sardina), !is.na(price_jurel))
}

df_ind_reg <- prep_reg_only(df_ind)
df_art_reg <- prep_reg_only(df_art)
cat("Dropped rows due to NA regional price:\n")
cat("    IND: ", nrow(df_ind) - nrow(df_ind_reg), " of ", nrow(df_ind),
    " (", round(100 * (nrow(df_ind) - nrow(df_ind_reg)) / nrow(df_ind), 1), "%)\n", sep = "")
cat("    ART: ", nrow(df_art) - nrow(df_art_reg), " of ", nrow(df_art),
    " (", round(100 * (nrow(df_art) - nrow(df_art_reg)) / nrow(df_art), 1), "%)\n", sep = "")

nb_ind_d3 <- glm.nb(
  T_vy ~ log_bodega +
    H_alloc_anchoveta + H_alloc_sardina_comun + H_alloc_jurel +
    price_anchov + price_sardina + price_jurel +
    days_bad_weather + days_closed_vy +
    TIPO_EMB + factor(year),
  data = df_ind_reg
)
nb_art_d3 <- glm.nb(
  T_vy ~ log_bodega +
    H_alloc_anchoveta + H_alloc_sardina_comun + H_alloc_jurel +
    price_anchov + price_sardina + price_jurel +
    days_bad_weather + days_closed_vy +
    TIPO_EMB + factor(year),
  data = df_art_reg
)

ct_ind_d3 <- fit_ct(nb_ind_d3, df_ind_reg)
ct_art_d3 <- fit_ct(nb_art_d3, df_art_reg)
print_main(ct_ind_d3, "IND - D3 (regional only, with FE)")
print_main(ct_art_d3, "ART - D3 (regional only, with FE)")

res_d3 <- rbind(
  bp_tab(ct_ind_d3, "IND", "D3_regional_only"),
  bp_tab(ct_art_d3, "ART", "D3_regional_only")
)


# =========================================================
# SIDE-BY-SIDE FINAL TABLE
# =========================================================
cat("\n\n=========================================================\n")
cat("  SUMMARY TABLE: beta_h^s and beta_p^s across 4 specs\n")
cat("=========================================================\n")
res_all <- rbind(res_base, res_d1, res_d3)

# Wide format for easy comparison
cat("\n*** beta_h^s (Kasperski main coefs) ***\n")
res_h <- res_all %>% filter(grepl("^H_alloc_", var))
print(res_h %>% arrange(fleet, var, model))

cat("\n*** beta_p^s (sign-flip candidates) ***\n")
res_p <- res_all %>% filter(grepl("^price_", var))
print(res_p %>% arrange(fleet, var, model))


# Save the table
dir.create("data/outputs/nb_kasperski", showWarnings = FALSE, recursive = TRUE)
write.csv(res_all, "data/outputs/nb_kasperski/diag_signflip_results.csv", row.names = FALSE)
cat("\n[OK] Saved: data/outputs/nb_kasperski/diag_signflip_results.csv\n")
