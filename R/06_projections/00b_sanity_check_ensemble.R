# =============================================================================
# FONDECYT -- 00b_sanity_check_ensemble.R
#
# Regression test del output de 01_cmip6_deltas.R (ensemble 6 modelos):
#   data/cmip6/deltas_ensemble.csv
#   data/cmip6/deltas_ensemble_log.csv
#
# Falla rapido (stopifnot) si algo se rompe en alguna iteracion futura del
# pipeline (e.g., cambio de bbox, nuevo modelo, distinto baseline window).
#
# Corre con:
#   source("R/06_projections/00b_sanity_check_ensemble.R")
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
})

CSV <- "data/cmip6/deltas_ensemble.csv"
LOG <- "data/cmip6/deltas_ensemble_log.csv"

stopifnot(file.exists(CSV), file.exists(LOG))
out <- fread(CSV)
log <- fread(LOG)

cat(strrep("=", 70), "\n", sep = "")
cat("Sanity check ensemble CMIP6 deltas\n")
cat(strrep("=", 70), "\n", sep = "")

# -----------------------------------------------------------------------------
# 1. Conteos
# -----------------------------------------------------------------------------
EXPECTED_NROW   <- 106L  # 5 modelos x 5 vars x 4 ssp*window = 100 + CESM2 (4 sst + 2 chlos)
EXPECTED_NDROP  <- 5L    # CESM2: chlos/ssp245(2), uas baseline, vas baseline, wind_speed all
EXPECTED_MODELS <- c("IPSL-CM6A-LR", "GFDL-ESM4", "CESM2",
                     "CNRM-ESM2-1", "UKESM1-0-LL", "MPI-ESM1-2-HR")
EXPECTED_VARS   <- c("sst", "logchl", "uas", "vas", "wind_speed")

stopifnot(nrow(out) == EXPECTED_NROW)
stopifnot(nrow(log) == EXPECTED_NDROP)
stopifnot(setequal(unique(out$model), EXPECTED_MODELS))
stopifnot(setequal(unique(out$var),   EXPECTED_VARS))
cat(sprintf("[OK] nrow=%d (esperado %d), ndrop=%d (esperado %d)\n",
            nrow(out), EXPECTED_NROW, nrow(log), EXPECTED_NDROP))

# -----------------------------------------------------------------------------
# 2. Drop registry: solo CESM2, exactamente los 5 huecos conocidos
# -----------------------------------------------------------------------------
stopifnot(all(log$model == "CESM2"))
expected_keys <- sort(c(
  "chlos|future/ssp245/mid",
  "chlos|future/ssp245/end",
  "uas|baseline",
  "vas|baseline",
  "wind_speed|all"
))
actual_keys <- sort(paste(log$var, log$stage, sep = "|"))
stopifnot(identical(actual_keys, expected_keys))
cat("[OK] Drop registry = 5 huecos CESM2 esperados\n")

# -----------------------------------------------------------------------------
# 3. n_models por celda (var, scenario, window)
# -----------------------------------------------------------------------------
expected_n <- function(v, s) {
  if (v == "sst")    return(6L)
  if (v == "logchl") return(if (s == "ssp245") 5L else 6L)
  return(5L)  # uas, vas, wind_speed: CESM2 dropped en todas las celdas
}
nm <- out[, .(n = .N), by = .(var, scenario, window)]
nm[, expected := mapply(expected_n, var, scenario)]
mismatches <- nm[n != expected]
if (nrow(mismatches) > 0) {
  cat("[FAIL] n_models por celda:\n"); print(mismatches)
  stop("n_models no matchea esperado")
}
cat("[OK] n_models por celda matchea esperado\n")

# -----------------------------------------------------------------------------
# 4. Rangos fisicos
# -----------------------------------------------------------------------------
stopifnot(!any(is.na(out$delta)))
# SST: warming siempre positivo, magnitud razonable (no >5degC en bbox subtropical)
stopifnot(all(out[var == "sst"]$delta > 0))
stopifnot(all(out[var == "sst"]$delta < 5))
# logCHL: |delta| < log(2) ~ 0.7 (i.e., menos que duplicar/halvar)
stopifnot(all(abs(out[var == "logchl"]$delta) < log(2)))
# uas, vas: |delta| < 1.5 m/s para una bbox subtropical
stopifnot(all(abs(out[var %in% c("uas", "vas")]$delta) < 1.5))
# wind_speed: |delta| < 2 m/s
stopifnot(all(abs(out[var == "wind_speed"]$delta) < 2))
cat("[OK] Rangos fisicos en sst/logchl/uas/vas/wind_speed\n")

# -----------------------------------------------------------------------------
# 5. Monotonia climatica: el ensemble debe respetar SSP585 end > SSP245 mid en SST
# -----------------------------------------------------------------------------
sst_means <- out[var == "sst", .(m = mean(delta)),
                 by = .(scenario, window)]
m_245mid <- sst_means[scenario == "ssp245" & window == "mid", m]
m_585end <- sst_means[scenario == "ssp585" & window == "end", m]
stopifnot(m_585end > 2 * m_245mid)
cat(sprintf("[OK] SST monotonia: ssp585 end (%.2f) > ssp245 mid (%.2f) x 2\n",
            m_585end, m_245mid))

# -----------------------------------------------------------------------------
# 6. Splice override: solo CESM2/chlos usa ssp585 splice; el resto ssp245
# -----------------------------------------------------------------------------
splice_check <- unique(out[, .(model, var, splice_exp)])
non_default <- splice_check[splice_exp != "ssp245"]
stopifnot(nrow(non_default) == 1L)
stopifnot(non_default$model == "CESM2",
          non_default$var == "logchl",
          non_default$splice_exp == "ssp585")
cat("[OK] Splice override: solo CESM2/chlos -> ssp585\n")

# -----------------------------------------------------------------------------
# 7. IPSL nuevo vs paper viejo (Tabla 3): ssp585 end SST viejo = 2.333 (baseline
#    1995-2014). Esperamos nuevo < viejo por shift de baseline ~0.15-0.30 degC.
# -----------------------------------------------------------------------------
ipsl_585end <- out[model == "IPSL-CM6A-LR" & var == "sst" &
                     scenario == "ssp585" & window == "end", delta]
stopifnot(length(ipsl_585end) == 1L)
shift <- 2.333 - ipsl_585end
stopifnot(shift > 0.05, shift < 0.40)
cat(sprintf("[OK] IPSL ssp585 end SST: viejo=2.333  nuevo=%.3f  shift=%.3f (en [0.05, 0.40])\n",
            ipsl_585end, shift))

# -----------------------------------------------------------------------------
# 8. n_years por celda (sanity de las ventanas)
# -----------------------------------------------------------------------------
# Baseline: 25 anios (2000-2024). Para CESM2/chlos/ssp585, n_years_baseline
# tambien deberia ser 25. mid: 20 anios (2041-2060). end: 20 anios (2081-2100).
ny_base <- unique(out$n_years_baseline)
ny_mid  <- unique(out[window == "mid", n_years_future])
ny_end  <- unique(out[window == "end", n_years_future])
# Permitir +/-1 anio por edge cases de calendario (UKESM 360-day, files
# truncos). El analisis anual no se afecta por un mes de menos.
stopifnot(all(ny_base %in% 24:25))
stopifnot(all(ny_mid  %in% 19:20))
stopifnot(all(ny_end  %in% 19:20))
cat(sprintf("[OK] n_years: base in {%s}, mid in {%s}, end in {%s}\n",
            paste(sort(ny_base), collapse = ","),
            paste(sort(ny_mid),  collapse = ","),
            paste(sort(ny_end),  collapse = ",")))

# -----------------------------------------------------------------------------
cat(strrep("=", 70), "\n", sep = "")
cat("ALL ASSERTS PASSED\n")
cat(strrep("=", 70), "\n", sep = "")

# Imprime resumen util al final
cat("\nResumen ensemble:\n")
print(out[, .(n = .N,
              mean = round(mean(delta), 4),
              sd   = round(sd(delta),   4),
              q05  = round(quantile(delta, 0.05), 4),
              q95  = round(quantile(delta, 0.95), 4)),
          by = .(var, scenario, window)])
