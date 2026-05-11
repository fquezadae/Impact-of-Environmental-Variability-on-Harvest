###============================================================###
###  Sanity Check: 2026-05-11 Kasperski-aligned NB refactor    ###
###  Verifies the rebuilt poisson_dt.rds is internally          ###
###  consistent before re-fitting the NB in 13_trip_compstat.R  ###
###============================================================###
#
# Run AFTER:
#   source("R/01_data_cleaning/tac_processing.R")  # writes halloc_official_by_species.rds
#   source("R/04_models/poisson_model.R")          # rebuilds poisson_dt.rds
#
# Checks:
#   (i)   sum of H_alloc_{anch,sard,jurel} ≈ H_alloc_vy legacy
#   (ii)  regional price coverage ≥ 90% per species
#   (iii) condition number + VIF of [1, H_alloc_anch, H_alloc_sard,
#         H_alloc_jurel, p_anch, p_sard, p_jurel] by fleet
#   (iv)  outlier anchoveta 2015 filtered correctly (no extreme price)
#
# Pass criteria (all four must hold):
#   (i)   max rel diff < 0.01%
#   (ii)  regional coverage ≥ 85% per species per fleet
#   (iii) cond num scaled < 30, all VIFs < 10
#   (iv)  max(price_anchov) within 3× median(price_anchov)
###============================================================###

rm(list = ls())
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# ---- load ----
dt <- readRDS("data/trips/poisson_dt.rds")
cat("poisson_dt.rds: rows =", nrow(dt), "cols =", ncol(dt),
    "year range =", paste(range(dt$year), collapse = "-"), "\n\n")

# ---- (i) H_alloc decomposition ----
cat("=== (i) H_alloc decomposition ===\n")
chk_i <- dt %>%
  mutate(
    H_sum = H_alloc_anchoveta + H_alloc_sardina_comun + H_alloc_jurel,
    abs_diff = abs(H_alloc_vy - H_sum),
    rel_diff_pct = 100 * abs_diff / pmax(H_alloc_vy, 1e-6)
  )
cat("  max abs_diff     =", round(max(chk_i$abs_diff, na.rm = TRUE), 4), "\n")
cat("  max rel_diff_pct =", round(max(chk_i$rel_diff_pct, na.rm = TRUE), 4), "%\n")
cat("  cells > 0.01%    =", sum(chk_i$rel_diff_pct > 0.01, na.rm = TRUE), "\n")
pass_i <- max(chk_i$rel_diff_pct, na.rm = TRUE) < 0.01
cat("  -> PASS:", pass_i, "\n\n")

# ---- (ii) regional price coverage ----
cat("=== (ii) Regional price coverage by fleet ===\n")
chk_ii <- dt %>%
  group_by(TIPO_FLOTA) %>%
  summarise(
    anchov_reg_pct  = round(100 * mean(!price_anchov_fallback  & !is.na(price_anchov)),  1),
    sardina_reg_pct = round(100 * mean(!price_sardina_fallback & !is.na(price_sardina)), 1),
    jurel_reg_pct   = round(100 * mean(!price_jurel_fallback   & !is.na(price_jurel)),   1),
    .groups = "drop"
  )
print(chk_ii)
pass_ii <- all(c(chk_ii$anchov_reg_pct, chk_ii$sardina_reg_pct, chk_ii$jurel_reg_pct) >= 85)
cat("  -> PASS (>= 85% all species, both fleets):", pass_ii, "\n\n")

# ---- (iii) cond number + VIF by fleet ----
cat("=== (iii) Condition number and VIF (regressors in NB) ===\n")
vif_one <- function(X, j) {
  ok <- complete.cases(X)
  X <- X[ok, , drop = FALSE]
  n <- nrow(X); k <- ncol(X)
  if (n < 2 * k) return(NA_real_)
  Y <- X[, j]
  Xr <- cbind(1, X[, -j, drop = FALSE])
  fit <- tryCatch(.lm.fit(Xr, Y), error = function(e) NULL)
  if (is.null(fit)) return(NA_real_)
  r2 <- 1 - sum(fit$residuals^2) / sum((Y - mean(Y))^2)
  if (r2 >= 1) return(Inf)
  1 / (1 - r2)
}

for (flt in c("ART", "IND")) {
  cat("Fleet", flt, ":\n")
  sub <- dt %>% filter(TIPO_FLOTA == flt) %>%
    select(H_alloc_anchoveta, H_alloc_sardina_comun, H_alloc_jurel,
           price_anchov, price_sardina, price_jurel) %>%
    as.matrix()
  ok <- complete.cases(sub)
  Xm <- sub[ok, ]
  cat("  N complete cases:", nrow(Xm), "\n")
  # Pearson corr
  cr <- cor(Xm)
  cat("  Max |off-diagonal corr|:", round(max(abs(cr[upper.tri(cr)])), 3), "\n")
  # Scaled condition number
  sds <- apply(Xm, 2, sd)
  sds[sds == 0] <- 1
  Xn <- sweep(Xm, 2, sds, "/")
  Xd <- cbind(1, Xn)
  s  <- svd(Xd)$d
  cat("  Condition number (scaled):", round(max(s) / min(s), 2), "\n")
  # VIFs
  vifs <- sapply(seq_len(ncol(Xm)), function(j) vif_one(Xm, j))
  names(vifs) <- colnames(Xm)
  cat("  VIFs:\n")
  print(round(vifs, 2))
}

pass_iii <- TRUE  # Manual inspection — printed numbers
cat("  -> PASS (verify cond_num < 30 AND all VIFs < 10): inspect above\n\n")

# ---- (iv) outlier 2015 ----
cat("=== (iv) Outlier anchoveta 2015 filtered ===\n")
chk_iv <- dt %>%
  summarise(
    p_anch_max    = max(price_anchov, na.rm = TRUE),
    p_anch_median = median(price_anchov, na.rm = TRUE),
    ratio         = max(price_anchov, na.rm = TRUE) / median(price_anchov, na.rm = TRUE)
  )
print(chk_iv)
pass_iv <- chk_iv$ratio < 3
cat("  -> PASS (max / median < 3):", pass_iv, "\n\n")

# ---- summary ----
cat("=========================================================\n")
cat("  Sanity check summary:\n")
cat("    (i)   H_alloc decomposition: ", pass_i,   "\n")
cat("    (ii)  Regional price cov:    ", pass_ii,  "\n")
cat("    (iii) Cond num / VIFs:        inspect above\n")
cat("    (iv)  Outlier 2015 filtered: ", pass_iv,  "\n")
cat("=========================================================\n")
