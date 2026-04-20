# =============================================================================
# FONDECYT -- 04_forward_simulation_tests.R
#
# Tests de estabilidad para simulate_forward().
# Valida el loop con coeficientes y datos sinteticos conocidos, ANTES de
# enchufarlo al SUR real. Si alguno falla, el bug es del loop, no del fit.
#
# Tests:
#   T1. Zero-delta + F_hist: trayectoria estable en ausencia de cambio ambiental.
#   T2. Positive SST delta + rho_sst<0: biomasa DECLINA en direccion esperada.
#   T3. Negative CHL ratio + rho_chl>0: biomasa DECLINA (canal productividad).
#   T4. No-harvest + r>0: biomasa CRECE hacia el techo (densidad dep. no explota).
#   T5. Sanity bounds activos: con coeficientes patologicos, bounds impiden NaN/Inf.
#
# Uso:
#   source("R/06_projections/04_forward_simulation.R")      # para cargar fns
#   source("R/06_projections/04_forward_simulation_tests.R")
#
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(tibble); library(purrr)
})

# Sanity: asegurar que los helpers estan cargados
stopifnot(exists("simulate_forward"),
          exists("build_env_series"),
          exists("build_harvest_rule"))

# ---- helper: impresion compacta de resultados ----
check <- function(name, passed, detail = "") {
  tag <- if (passed) "PASS" else "FAIL"
  cat(sprintf("  [%s] %s", tag, name))
  if (nchar(detail)) cat("  |  ", detail, sep = "")
  cat("\n")
  invisible(passed)
}

# ---- fixture: coeficientes, medias, historico sinteticos ----
#
# Disenados para que el equilibrio del modelo sea aproximadamente
# b_eq ~ B_MEAN bajo zero delta y harvest = historical mean.
# El signo de rho_sst es negativo (consistente con jurel en el paper).

mk_synth_fixture <- function(rho_sst = -0.3, rho_sst2 = -0.5, rho_chl = 0.2,
                             beta = -0.2, eta = -0.05) {

  species <- c("sardine", "anchoveta", "jurel")

  # Medias historicas
  means <- list(
    SST_MEAN = 14.0, CHL_MEAN = 0.6,
    B_S_MEAN = 30.0, B_A_MEAN = 20.0, B_J_MEAN = 10.0,
    scale_b  = 1e5
  )
  B_MEAN <- c(sardine = 30, anchoveta = 20, jurel = 10)

  # Coeficientes: intercept se elige para que en equilibrio
  # (b=B_MEAN, sst=SST_MEAN, chl=CHL_MEAN, h=h_bar),
  # se cumpla b_{t+1} = b_t = B_MEAN. O sea:
  # intercept - h_bar = B_MEAN (porque b_c=0 -> beta*0 + eta*0 + rho*0 = 0)
  # =>  intercept = B_MEAN + h_bar
  h_bar <- c(sardine = 8, anchoveta = 6, jurel = 2)  # harvest medio escalado

  coefs <- list(
    intercept = B_MEAN + h_bar,
    beta      = setNames(rep(beta,     3), species),
    eta       = setNames(rep(eta,      3), species),
    rho_sst   = setNames(rep(rho_sst,  3), species),
    rho_sst2  = setNames(rep(rho_sst2, 3), species),
    rho_chl   = setNames(rep(rho_chl,  3), species)
  )

  # Historico sintetico: 23 anios de observaciones con variabilidad
  set.seed(42)
  hist_env <- tibble(
    year = 2002:2024,
    sst  = means$SST_MEAN + rnorm(23, 0, 0.4),
    chl  = means$CHL_MEAN + rnorm(23, 0, 0.08)
  )

  # Rango "historico" para sanity bounds
  hist_range <- list(
    min = c(sardine = 15,  anchoveta = 10, jurel = 4),
    max = c(sardine = 55,  anchoveta = 35, jurel = 20)
  )

  # Harvest rule: fija en h_bar (historical mean)
  h_rule <- function(t, b_t) h_bar

  list(coefs = coefs, means = means, hist_env = hist_env,
       hist_range = hist_range, h_rule = h_rule,
       h_bar = h_bar, B_MEAN = B_MEAN)
}

# ======================================================================
# T1. ZERO DELTA: sistema estable alrededor del equilibrio
# ======================================================================

test_zero_delta <- function() {
  cat("\nT1. Zero delta + harvest = h_bar -> sistema estable\n")
  fx <- mk_synth_fixture()

  env <- build_env_series(fx$hist_env, sst_delta = 0, chl_ratio = 1,
                          years = 2025:2100)

  traj <- simulate_forward(fx$coefs, fx$means, env,
                           b0 = fx$B_MEAN, h_rule = fx$h_rule,
                           hist_range = fx$hist_range)

  # Para cada especie, la biomasa promedio debe estar cerca de B_MEAN,
  # y la desviacion estandar debe ser razonable (no explotar).
  stats <- traj %>%
    group_by(species) %>%
    summarise(mean_b = mean(biomass), sd_b = sd(biomass), .groups = "drop")

  # Condicion: |mean(b) - B_MEAN| < 0.1 * B_MEAN y sd < 0.2 * B_MEAN
  err <- stats %>%
    mutate(target = fx$B_MEAN[species],
           bias   = abs(mean_b - target) / target,
           rel_sd = sd_b / target)

  print(err)
  ok_bias <- all(err$bias < 0.15)
  ok_sd   <- all(err$rel_sd < 0.25)
  check("bias < 15% del equilibrio",       ok_bias,
        sprintf("max bias = %.3f",  max(err$bias)))
  check("sd relativa < 25% del equilibrio", ok_sd,
        sprintf("max rel_sd = %.3f", max(err$rel_sd)))

  invisible(ok_bias && ok_sd)
}

# ======================================================================
# T2. DELTA POSITIVO de SST + rho_sst<0 -> biomasa declina
# ======================================================================

test_sst_decline <- function() {
  cat("\nT2. DeltaSST = +2.3C, rho_sst < 0 -> biomasa cae\n")
  fx <- mk_synth_fixture(rho_sst = -0.5, rho_sst2 = -0.2)

  env <- build_env_series(fx$hist_env, sst_delta = 2.3, chl_ratio = 1,
                          years = 2025:2100)

  traj <- simulate_forward(fx$coefs, fx$means, env,
                           b0 = fx$B_MEAN, h_rule = fx$h_rule,
                           hist_range = fx$hist_range)

  # End-century: promedio de biomasa debe ser < B_MEAN para las 3 especies
  end <- traj %>%
    filter(year %in% 2081:2100) %>%
    group_by(species) %>%
    summarise(mean_b_end = mean(biomass), .groups = "drop") %>%
    mutate(B_MEAN = fx$B_MEAN[species],
           rel    = mean_b_end / B_MEAN)
  print(end)

  ok <- all(end$rel < 0.95)  # declinar al menos 5%
  check("todas las especies declinan >5% end-century", ok,
        sprintf("min rel = %.3f", min(end$rel)))

  invisible(ok)
}

# ======================================================================
# T3. CHL ratio < 1 + rho_chl>0 -> biomasa declina via canal productividad
# ======================================================================

test_chl_decline <- function() {
  # CHL esta en escala ~0.6 mg/m3. Para un efecto detectable via el canal
  # productividad necesitamos: (a) un ratio agresivo (0.5 -> delta_chl = -0.3)
  # y (b) un rho_chl escalado a la magnitud esperada en el SUR real
  # (rho_chl del draft real ronda el orden de magnitudes de 20-40 sobre
  # chl_c escalado). Aqui usamos rho_chl = 20 para que el efecto sea
  # claramente separable del ruido cicladode.
  cat("\nT3. CHL ratio = 0.50, rho_chl = 20 -> biomasa cae (productividad)\n")
  fx <- mk_synth_fixture(rho_sst = 0, rho_sst2 = 0, rho_chl = 20)

  env <- build_env_series(fx$hist_env, sst_delta = 0, chl_ratio = 0.50,
                          years = 2025:2100)

  traj <- simulate_forward(fx$coefs, fx$means, env,
                           b0 = fx$B_MEAN, h_rule = fx$h_rule,
                           hist_range = fx$hist_range)

  end <- traj %>%
    filter(year %in% 2081:2100) %>%
    group_by(species) %>%
    summarise(mean_b_end = mean(biomass), .groups = "drop") %>%
    mutate(B_MEAN = fx$B_MEAN[species], rel = mean_b_end / B_MEAN)
  print(end)

  ok <- all(end$rel < 0.95)
  check("declinan via canal CHL", ok,
        sprintf("min rel = %.3f", min(end$rel)))

  invisible(ok)
}

# ======================================================================
# T4. NO HARVEST + intercept alto -> biomasa sube hasta techo sin explotar
# ======================================================================

test_no_harvest_bounded_growth <- function() {
  cat("\nT4. No harvest + crecimiento positivo -> converge a techo (no explota)\n")
  fx <- mk_synth_fixture()
  # Override: intercept alto (mas que h_bar) + sin harvest
  fx$coefs$intercept <- fx$B_MEAN * 1.2 + fx$h_bar  # crecimiento neto positivo
  fx$h_rule <- function(t, b_t) c(sardine = 0, anchoveta = 0, jurel = 0)

  env <- build_env_series(fx$hist_env, sst_delta = 0, chl_ratio = 1,
                          years = 2025:2100)

  traj <- simulate_forward(fx$coefs, fx$means, env,
                           b0 = fx$B_MEAN, h_rule = fx$h_rule,
                           hist_range = fx$hist_range)

  max_b <- traj %>% group_by(species) %>%
    summarise(max_b = max(biomass), .groups = "drop") %>%
    mutate(ceiling = 2 * fx$hist_range$max[species],
           hit_ceiling = max_b >= ceiling * 0.999)
  print(max_b)

  # Debe mantenerse <= 2 * max_hist (el techo duro). No debe haber NaN.
  ok_bound <- all(max_b$max_b <= max_b$ceiling + 1e-6)
  ok_finite <- all(is.finite(traj$biomass))
  check("biomasa acotada por techo 2 x max_hist", ok_bound)
  check("no NaN/Inf en trayectoria",              ok_finite)

  invisible(ok_bound && ok_finite)
}

# ======================================================================
# T5. COEFICIENTES PATOLOGICOS: sanity bounds salvan el dia
# ======================================================================

test_pathological_coefs <- function() {
  cat("\nT5. Coeficientes patologicos (rho_sst2 = -56.5 como en jurel real)\n")
  fx <- mk_synth_fixture(rho_sst = 0, rho_sst2 = -56.5, rho_chl = 0)

  # Delta grande: sst_c^2 ~ 5 -> contribucion = -56.5 * 5 = -282 (catastrofico)
  env <- build_env_series(fx$hist_env, sst_delta = 2.3, chl_ratio = 1,
                          years = 2025:2100)

  traj <- simulate_forward(fx$coefs, fx$means, env,
                           b0 = fx$B_MEAN, h_rule = fx$h_rule,
                           hist_range = fx$hist_range)

  ok_finite <- all(is.finite(traj$biomass))
  # Deberiamos haber chocado con el floor (0.1 * min_hist)
  floors <- 0.1 * fx$hist_range$min
  at_floor <- traj %>%
    filter(year > 2050) %>%
    group_by(species) %>%
    summarise(min_b = min(biomass), .groups = "drop") %>%
    mutate(floor_target = floors[species],
           at_or_near   = min_b <= 1.01 * floor_target)
  print(at_floor)

  check("trayectoria finita pese a coefs extremos", ok_finite)
  check("floor activo (biomasa >= 0.1 x min_hist)",
        all(at_floor$at_or_near),
        "si FAIL, hay especies que no golpearon el floor")

  invisible(ok_finite)
}

# ======================================================================
# RUNNER
# ======================================================================

cat("\n", strrep("=", 70), "\n", sep = "")
cat("FORWARD SIMULATION -- TESTS DE ESTABILIDAD\n")
cat(strrep("=", 70), "\n", sep = "")

results <- list(
  T1 = test_zero_delta(),
  T2 = test_sst_decline(),
  T3 = test_chl_decline(),
  T4 = test_no_harvest_bounded_growth(),
  T5 = test_pathological_coefs()
)

cat("\n", strrep("-", 70), "\n", sep = "")
cat("RESUMEN:\n")
for (nm in names(results)) {
  cat(sprintf("  %s : %s\n", nm, if (isTRUE(results[[nm]])) "PASS" else "FAIL"))
}

if (!all(unlist(results))) {
  stop("Algun test de estabilidad fallo. Revisar simulate_forward() antes de continuar.")
} else {
  cat("\nTodos los tests PASAN. El loop simulate_forward() es estable.\n")
  cat(strrep("=", 70), "\n", sep = "")
}
