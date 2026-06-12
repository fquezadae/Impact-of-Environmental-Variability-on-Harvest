###============================================================###
###  P4b2: Identify ART vessels missing from delta_w (CMIP6)   ###
###  ~125 ART vessels lack delta_days_bw projection.            ###
###  Check if their exclusion materially biases the headline    ###
###  asymmetry (11:1 marg / 2:1 cond) of the primary spec.      ###
###============================================================###

rm(list = setdiff(ls(), c("dirdata")))
gc()

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})
select <- dplyr::select
filter <- dplyr::filter

dt  <- readRDS("data/trips/poisson_dt.rds")
dbw <- readRDS("data/cmip6/delta_days_bw_vessel.rds")

dt$COD_BARCO  <- as.character(dt$COD_BARCO)
dbw$COD_BARCO <- as.character(dbw$COD_BARCO)

# Vessels with delta_w available under SSP585 end
dbw_vessels <- dbw %>%
  filter(scenario == "ssp585", window == "end") %>%
  pull(COD_BARCO) %>%
  unique()

# Vessel-level summary from poisson_dt
v_summary <- dt %>%
  group_by(COD_BARCO, TIPO_FLOTA, TIPO_EMB) %>%
  summarise(
    n_years         = n(),
    T_vy_mean       = mean(T_vy, na.rm = TRUE),
    T_vy_total      = sum(T_vy, na.rm = TRUE),
    H_anch_mean     = mean(H_alloc_anchoveta, na.rm = TRUE),
    H_sard_mean     = mean(H_alloc_sardina_comun, na.rm = TRUE),
    H_jurel_mean    = mean(H_alloc_jurel, na.rm = TRUE),
    H_total_mean    = mean(H_alloc_vy, na.rm = TRUE),
    log_bodega      = first(log_bodega),
    cog_stable      = first(cog_stable),
    days_bw_avail   = mean(!is.na(days_bad_weather)),
    .groups = "drop"
  ) %>%
  mutate(has_delta_w = COD_BARCO %in% dbw_vessels)

# How many vessels do/don't have delta_w?
cat("=== Coverage of delta_w (SSP585 end) by fleet ===\n")
cov_by_fleet <- v_summary %>%
  group_by(TIPO_FLOTA) %>%
  summarise(
    n_total      = n(),
    n_with_dw    = sum(has_delta_w),
    n_missing_dw = sum(!has_delta_w),
    pct_missing  = round(100 * mean(!has_delta_w), 1),
    .groups = "drop"
  )
print(cov_by_fleet)

# Focus on ART missing vessels
cat("\n=== ART vessels MISSING delta_w: characteristics ===\n")
art_miss <- v_summary %>% filter(TIPO_FLOTA == "ART", !has_delta_w)
art_have <- v_summary %>% filter(TIPO_FLOTA == "ART",  has_delta_w)

cat(sprintf("  N missing: %d  N have: %d\n", nrow(art_miss), nrow(art_have)))

cat("\nTIPO_EMB distribution (missing vs have):\n")
emb_compare <- bind_rows(
  art_miss %>% count(TIPO_EMB) %>% mutate(group = "missing"),
  art_have %>% count(TIPO_EMB) %>% mutate(group = "have")
) %>%
  pivot_wider(names_from = group, values_from = n, values_fill = 0) %>%
  mutate(
    pct_missing = round(100 * missing / (missing + have), 1)
  ) %>%
  arrange(desc(missing + have))
print(emb_compare)

cat("\nCOG stability (missing vs have):\n")
print(bind_rows(
  art_miss %>% summarise(group = "missing", n = n(),
                         pct_cog_stable = round(100 * mean(cog_stable, na.rm = TRUE), 1),
                         n_cog_NA = sum(is.na(cog_stable))),
  art_have %>% summarise(group = "have", n = n(),
                         pct_cog_stable = round(100 * mean(cog_stable, na.rm = TRUE), 1),
                         n_cog_NA = sum(is.na(cog_stable)))
))

cat("\ndays_bad_weather availability (missing vs have):\n")
print(bind_rows(
  art_miss %>% summarise(group = "missing", n = n(),
                         pct_dbw_avail = round(100 * mean(days_bw_avail), 1)),
  art_have %>% summarise(group = "have", n = n(),
                         pct_dbw_avail = round(100 * mean(days_bw_avail), 1))
))

cat("\nSize comparison (median):\n")
size_cmp <- bind_rows(
  art_miss %>% summarise(group = "missing", n = n(),
                         T_vy_mean  = round(median(T_vy_mean), 1),
                         T_vy_total = round(median(T_vy_total), 0),
                         H_total    = round(median(H_total_mean), 1),
                         log_bodega = round(median(log_bodega, na.rm = TRUE), 2),
                         n_years    = round(median(n_years), 1)),
  art_have %>% summarise(group = "have", n = n(),
                         T_vy_mean  = round(median(T_vy_mean), 1),
                         T_vy_total = round(median(T_vy_total), 0),
                         H_total    = round(median(H_total_mean), 1),
                         log_bodega = round(median(log_bodega, na.rm = TRUE), 2),
                         n_years    = round(median(n_years), 1))
)
print(size_cmp)

# Total share of effort and quota represented by missing vessels
cat("\n=== Share of effort and quota represented by MISSING ART vessels ===\n")
art_total <- v_summary %>% filter(TIPO_FLOTA == "ART") %>%
  summarise(
    T_total   = sum(T_vy_total),
    H_total   = sum(H_total_mean * n_years),
    n         = n()
  )
art_miss_total <- art_miss %>%
  summarise(
    T_missing = sum(T_vy_total),
    H_missing = sum(H_total_mean * n_years),
    n         = n()
  )
cat(sprintf("  N vessels missing:    %d of %d (%.1f%%)\n",
            art_miss_total$n, art_total$n,
            100 * art_miss_total$n / art_total$n))
cat(sprintf("  Total trips missing:  %d of %d (%.1f%%)\n",
            as.integer(art_miss_total$T_missing), as.integer(art_total$T_total),
            100 * art_miss_total$T_missing / art_total$T_total))
cat(sprintf("  Total H_alloc missing: %.0f of %.0f tons (%.1f%%)\n",
            art_miss_total$H_missing, art_total$H_total,
            100 * art_miss_total$H_missing / art_total$H_total))

# What fraction of trips/quota fall outside the panel used in P4d?
cat("\n=== Effort-weighted bias check ===\n")
cat("If we re-weight the primary headline by (effort share of vessels included),\n")
cat("would the aggregate change much?\n\n")

# Compute the share of T_vy (effort) and H_total (quota) represented by HAVE vessels
art_have_shares <- art_have %>%
  summarise(
    T_share = sum(T_vy_total),
    H_share = sum(H_total_mean * n_years)
  )
cat(sprintf("  ART have-delta_w vessels:  %.1f%% of total ART trips,  %.1f%% of total ART H_alloc\n",
            100 * art_have_shares$T_share / art_total$T_total,
            100 * art_have_shares$H_share / art_total$H_total))

# Decision aid
cat("\n=== Decision aid for P4 ===\n")
miss_share_T <- art_miss_total$T_missing / art_total$T_total
miss_share_H <- art_miss_total$H_missing / art_total$H_total
if (miss_share_T < 0.05 && miss_share_H < 0.05) {
  cat("  -> Missing vessels are <5% of both trips and quota in ART. SAFE TO PROCEED.\n")
  cat("     The 11:1 marg / 2:1 cond from preliminary is robust to this exclusion.\n")
} else if (miss_share_T < 0.10 && miss_share_H < 0.10) {
  cat("  -> Missing vessels are 5-10% of ART effort. CAUTION but proceed.\n")
  cat("     Report a sensitivity in P4: aggregates restricted to vessels with delta_w.\n")
} else {
  cat("  -> Missing vessels are >10% of ART effort. INVESTIGATE before P4.\n")
  cat("     Likely fix: relax cog_stable filter or impute delta_w from nearby grid.\n")
}
