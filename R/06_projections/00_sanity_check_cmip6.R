# =============================================================================
# 00_sanity_check_cmip6.R
# Sanity check del pipeline CMIP6 IPSL existente, antes de extender a ensemble.
#
# Para correr antes de bajar otros 5 modelos. Verifica que el output del pipeline
# actual (data/projections/cmip6_deltas.rds) es consistente con lo que el paper
# reporta en Tabla 3 (sec 4.3.1).
#
# Si todo pasa, podemos proceder a Fase A.2 (extender a 6 modelos).
# Si algo no pasa, debuggear primero antes de tocar nada nuevo.
# =============================================================================

library(data.table)

# 1. Load output existente
deltas <- readRDS("data/projections/cmip6_deltas.rds")
cat("=== Estructura general ===\n")
str(deltas)
cat("\n=== Dimensiones ===\n")
cat("Total rows:", nrow(deltas), "\n")
cat("Cols:", paste(colnames(deltas), collapse = ", "), "\n")

# 2. Verificar combinaciones esperadas
cat("\n=== Combinaciones (variable, ssp, window) ===\n")
print(deltas[, .N, by = .(variable, ssp, window)])

# Esperado: 4 variables (uas, vas, sst, chl) x 2 ssp (245, 585) x 2 windows (mid, end) = 16 combos
# Cada combo con N celdas espacio-mes = ~12 meses x N_cells_bbox

# 3. Estadísticas esperadas vs Tabla 3 del paper
cat("\n=== Resumen por variable, ssp, window (debería matchear Tabla 3) ===\n")
print(deltas[, .(
  mean_delta = round(mean(delta, na.rm = TRUE), 4),
  median_delta = round(median(delta, na.rm = TRUE), 4),
  sd_delta = round(sd(delta, na.rm = TRUE), 4),
  n = .N,
  n_na = sum(is.na(delta))
), by = .(variable, ssp, window)])

# 4. Tabla 3 del paper reporta:
#   SSP2-4.5 mid:  SST=0.811, CHL=0.971 (ratio), Wind=0.060
#   SSP2-4.5 end:  SST=1.480, CHL=0.942, Wind=0.037
#   SSP5-8.5 mid:  SST=0.970, CHL=0.988, Wind=-0.049
#   SSP5-8.5 end:  SST=2.333, CHL=0.959, Wind=0.068
#
# Nuestro output debe matchear estos valores cuando se promedia espacialmente.
# (Wind viene de uas, vas: speed = sqrt(uas^2 + vas^2). El delta de wind speed
# se calcula despues, no se almacena en cmip6_deltas.rds. Solo verificamos
# uas, vas, sst, chl aquí.)

cat("\n=== Sanity check vs Tabla 3 (SST y CHL) ===\n")
expected <- data.table(
  variable = c("sst", "sst", "sst", "sst", "chl", "chl", "chl", "chl"),
  ssp      = c("ssp245", "ssp245", "ssp585", "ssp585", "ssp245", "ssp245", "ssp585", "ssp585"),
  window   = c("mid", "end", "mid", "end", "mid", "end", "mid", "end"),
  expected_value = c(0.811, 1.480, 0.970, 2.333, 0.971, 0.942, 0.988, 0.959)
)

actual <- deltas[variable %in% c("sst", "chl"),
                 .(actual = round(mean(delta, na.rm = TRUE), 3)),
                 by = .(variable, ssp, window)]

comparison <- merge(expected, actual, by = c("variable", "ssp", "window"))
comparison[, diff := round(actual - expected_value, 3)]
comparison[, abs_diff := abs(diff)]
print(comparison)

cat("\nMax |diff|:", max(comparison$abs_diff, na.rm = TRUE), "\n")
if (max(comparison$abs_diff, na.rm = TRUE) < 0.05) {
  cat("✓ PASS: deltas existentes coinciden con Tabla 3 del paper.\n")
} else {
  cat("✗ FAIL: hay discrepancia significativa con Tabla 3. Investigar antes de extender ensemble.\n")
}

# 5. Verificar que no hay NaN o valores absurdos
cat("\n=== Sanity check: valores extremos ===\n")
cat("SST delta range:", range(deltas[variable == "sst"]$delta, na.rm = TRUE), "(esperado: 0.5-3 °C)\n")
cat("CHL delta range:", range(deltas[variable == "chl"]$delta, na.rm = TRUE), "(esperado: 0.5-1.5 ratio)\n")
if ("uas" %in% deltas$variable) {
  cat("UAS delta range:", range(deltas[variable == "uas"]$delta, na.rm = TRUE), "(esperado: -1 to +1 m/s)\n")
}
if ("vas" %in% deltas$variable) {
  cat("VAS delta range:", range(deltas[variable == "vas"]$delta, na.rm = TRUE), "(esperado: -1 to +1 m/s)\n")
}

cat("\n=== FIN SANITY CHECK ===\n")
