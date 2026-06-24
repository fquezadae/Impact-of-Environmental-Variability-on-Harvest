# =========================================================================
# refit_from_poisson_dt.R
#
# Reproducibility entry point for replicators WITHOUT the confidential IFOP
# logbooks. Re-fits the four negative-binomial trip models that
# R/08_stan_t4/13_trip_comparative_statics.R consumes, reading only the
# shipped vessel-year panel data/trips/poisson_dt.rds.
#
# The full builder R/04_models/poisson_model.R rebuilds the panel from the
# raw logbooks (data/logbooks/, confidential) and is author-only; this script
# is the public path. The four fits below are byte-identical in specification
# to poisson_model.R SEC 13 (Kasperski / legacy) and SEC 14 (primary ART).
#
# Usage (from the project root):
#   Rscript R/04_models/refit_from_poisson_dt.R
# then:
#   options(t6.run_main = TRUE); source("R/08_stan_t4/13_trip_comparative_statics.R")
# =========================================================================

suppressPackageStartupMessages(library(dplyr))

poisson_df <- readRDS("data/trips/poisson_dt.rds")

df_ind <- poisson_df %>% filter(TIPO_FLOTA == "IND")
df_art <- poisson_df %>% filter(TIPO_FLOTA == "ART")

# Primary ART: restrict to vessel-type categories with N >= 50 (BM, LM, UNK)
# so both H_alloc x TIPO_EMB interactions are identifiable (matches the
# manuscript and poisson_model.R SEC 14).
df_art_primary <- df_art %>%
  filter(TIPO_EMB %in% c("BM", "LM", "UNK")) %>%
  mutate(TIPO_EMB = droplevels(factor(TIPO_EMB)))

# --- nb_ind_primary (= nb_ind_kasperski): 3 H_alloc + 3 prices + year FE ---
nb_ind_primary <- MASS::glm.nb(
  T_vy ~ log_bodega +
    H_alloc_anchoveta + H_alloc_sardina_comun + H_alloc_jurel +
    price_anchov + price_sardina + price_jurel +
    days_bad_weather + days_closed_vy +
    TIPO_EMB + factor(year),
  data = df_ind
)

# --- nb_art_primary: + H_alloc_(anch & sard) x TIPO_EMB on BM/LM/UNK ---
nb_art_primary <- MASS::glm.nb(
  T_vy ~ log_bodega +
    H_alloc_anchoveta * TIPO_EMB +
    H_alloc_sardina_comun * TIPO_EMB + H_alloc_jurel +
    price_anchov + price_sardina + price_jurel +
    days_bad_weather + days_closed_vy +
    factor(year),
  data = df_art_primary
)

# --- legacy fits (scalar H_alloc_vy) used for the sensitivity comparison ---
nb_ind_legacy_fe <- MASS::glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB + factor(year),
  data = df_ind
)
nb_art_legacy_fe <- MASS::glm.nb(
  T_vy ~ log_bodega + H_alloc_vy +
    price_jurel + price_sardina + price_anchov +
    days_bad_weather + days_closed_vy +
    TIPO_EMB + factor(year),
  data = df_art
)

dir.create("data/outputs/nb_kasperski", showWarnings = FALSE, recursive = TRUE)
saveRDS(nb_ind_primary,   "data/outputs/nb_kasperski/nb_ind_primary.rds")
saveRDS(nb_art_primary,   "data/outputs/nb_kasperski/nb_art_primary.rds")
saveRDS(nb_ind_legacy_fe, "data/outputs/nb_kasperski/nb_ind_legacy_fe.rds")
saveRDS(nb_art_legacy_fe, "data/outputs/nb_kasperski/nb_art_legacy_fe.rds")

cat(sprintf("[OK] 4 NB fits written to data/outputs/nb_kasperski/ (N_IND=%d, N_ART_primary=%d)\n",
            nobs(nb_ind_primary), nobs(nb_art_primary)))
