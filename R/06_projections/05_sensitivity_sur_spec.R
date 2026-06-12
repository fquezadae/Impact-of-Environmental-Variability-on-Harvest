# =============================================================================
# FONDECYT -- 05_sensitivity_sur_spec.R
#
# Sensibilidad del SUR (Tarea 4 del revision plan):
#
#   Corre el forward simulation bajo DOS especificaciones del SUR y
#   compara los % change end-century y mid-century:
#
#     (a) "full"    -> con sst_c^2  (especificacion del draft actual)
#     (b) "no_sst2" -> sin sst_c^2  (sensibilidad)
#
# Motivacion:
#   rho_SST2 para jurel = -56.5. A sst_c^2 ~= 5.3 (deltas end-century)
#   contribuye -299 al growth equation -- una extrapolacion catastrofica
#   que el cap [0.2, 3.0] de 03_project_biomass.R escondia. Necesitamos
#   saber si la asimetria artesanal/industrial (punto cualitativo del
#   paper) sobrevive al quitar ese termino.
#
# Criterios que el paper debe superar:
#   1. Jurel end-century estable (no -99%) en no_sst2.
#   2. Signo del efecto en sardine/anchoveta preservado entre specs.
#   3. Magnitud razonable (|med| < 60% aprox.) en no_sst2.
#
# Outputs:
#   data/projections/sensitivity_full.rds
#   data/projections/sensitivity_no_sst2.rds
#   data/projections/sensitivity_comparison.rds  (tabla lado a lado)
#
# Uso:
#   options(fwd_sim.run_main = FALSE)  # o simplemente interactive()
#   source("R/06_projections/05_sensitivity_sur_spec.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(tibble)
})

# Carga helpers del forward simulation SIN ejecutar su main()
# (el main() solo corre si interactive() || fwd_sim.run_main == TRUE).
# Guardamos el estado previo y lo forzamos a FALSE por seguridad.
prev_run_main <- getOption("fwd_sim.run_main", FALSE)
options(fwd_sim.run_main = FALSE)
source("R/06_projections/04_forward_simulation.R", local = FALSE)
options(fwd_sim.run_main = prev_run_main)

# ---------------------------------------------------------------- driver ----

run_for_spec <- function(spec, cfg_base = FWD_CONFIG) {

  cat("\n", strrep("-", 70), "\n", sep = "")
  cat("SENSITIVITY: spec = '", spec, "'\n", sep = "")
  cat(strrep("-", 70), "\n", sep = "")

  cfg <- cfg_base
  cfg$sur_spec <- spec

  sur_bundle <- build_and_fit_sur(cfg$data_version, cfg$sur_spec)
  cat("  SUR ajustado (N =", nrow(sur_bundle$data),
      ", AIC =", round(AIC(sur_bundle$fit), 1), ")\n")

  deltas_raw <- if (cfg$mock_deltas) build_mock_deltas()
                else readRDS("data/projections/cmip6_deltas_ensemble.rds")

  deltas <- deltas_raw %>%
    pivot_wider(id_cols = c(model, scenario),
                names_from = window,
                values_from = c(sst_delta, chl_delta_ratio))

  ens <- run_ensemble(sur_bundle, deltas, cfg)
  smry <- summarise_trajectories(ens$traj, sur_bundle, ens$b0, cfg)

  list(spec = spec,
       sur_bundle = sur_bundle,
       b0 = ens$b0,
       traj = ens$traj,
       summary = smry)
}

# Dos specs en serie. Agregar "linear" o "no_eta" si se quiere exhaustivo,
# pero el paper solo necesita (full, no_sst2) para la sensibilidad.
specs <- c("full", "no_sst2")

results <- setNames(lapply(specs, run_for_spec), specs)

# -------------------------------------------------- comparison side-by-side ----

bind_summary <- function(res) {
  res$summary %>%
    mutate(spec = res$spec) %>%
    select(spec, scenario, window, species,
           med_vs_hist, med_vs_b0, p10_vs_b0, p90_vs_b0)
}

all_smry <- bind_rows(lapply(results, bind_summary))

# Pivot a wide: spec como columna
cmp <- all_smry %>%
  select(spec, scenario, window, species, med_vs_b0) %>%
  pivot_wider(names_from = spec, values_from = med_vs_b0,
              names_prefix = "med_b0_") %>%
  mutate(delta_pp = med_b0_no_sst2 - med_b0_full)

cmp_hist <- all_smry %>%
  select(spec, scenario, window, species, med_vs_hist) %>%
  pivot_wider(names_from = spec, values_from = med_vs_hist,
              names_prefix = "med_hist_")

cmp_full <- cmp %>%
  left_join(cmp_hist, by = c("scenario", "window", "species")) %>%
  arrange(scenario, window, species) %>%
  mutate(across(where(is.numeric), \(x) round(x, 1)))

# ----------------------------------------------------------- veredicto ----

# Criterio 1: jurel end-century estable en no_sst2 (|med| < 60 pp)
jurel_end <- cmp_full %>%
  filter(species == "jurel", window == "end")
ok_jurel <- all(abs(jurel_end$med_b0_no_sst2) < 60)

# Criterio 2: signo preservado entre specs (al menos mediana)
sign_pres <- cmp_full %>%
  mutate(sign_match = sign(med_b0_full) == sign(med_b0_no_sst2)) %>%
  summarise(pct = mean(sign_match), .groups = "drop") %>%
  pull(pct)

# Criterio 3: magnitud razonable en no_sst2 end-century
end_rows <- cmp_full %>% filter(window == "end")
ok_magn <- all(abs(end_rows$med_b0_no_sst2) < 80)

cat("\n", strrep("=", 70), "\n", sep = "")
cat("SENSITIVITY COMPARISON:  full  vs  no_sst2\n")
cat(strrep("=", 70), "\n")
cat("\nMediana % change vs b0 (inicial) por escenario, ventana y especie:\n\n")
print(cmp_full %>% as.data.frame(), row.names = FALSE)

cat("\n", strrep("-", 70), "\n", sep = "")
cat("CRITERIOS:\n")
cat(sprintf("  [%s] Jurel end-century estable (no_sst2):   |med| < 60 pp\n",
            if (ok_jurel) "PASS" else "FAIL"))
cat(sprintf("  [%s] Signo preservado entre specs:          %.0f%% de filas\n",
            if (sign_pres >= 0.75) "PASS" else "WARN",
            100 * sign_pres))
cat(sprintf("  [%s] Magnitud razonable (no_sst2, end):     |med| < 80 pp\n",
            if (ok_magn) "PASS" else "FAIL"))
cat(strrep("-", 70), "\n", sep = "")

# Mini resumen con dos cifras clave para copiar al draft:
end_cmp <- cmp_full %>% filter(window == "end") %>%
  select(scenario, species, med_b0_full, med_b0_no_sst2, delta_pp)
cat("\nEnd-century (window", paste0(range(FWD_CONFIG$window_end), collapse = "-"), "):\n")
print(end_cmp %>% as.data.frame(), row.names = FALSE)

# ----------------------------------------------------------- salvar ----

dir.create("data/projections", showWarnings = FALSE, recursive = TRUE)
saveRDS(results$full$summary,    "data/projections/sensitivity_full.rds")
saveRDS(results$no_sst2$summary, "data/projections/sensitivity_no_sst2.rds")
saveRDS(cmp_full,                "data/projections/sensitivity_comparison.rds")

# Guardar trayectorias completas tambien (por si quieres plotear despues)
saveRDS(results$full$traj,    "data/projections/traj_full.rds")
saveRDS(results$no_sst2$traj, "data/projections/traj_no_sst2.rds")

cat("\nGuardado:\n")
cat("  data/projections/sensitivity_full.rds\n")
cat("  data/projections/sensitivity_no_sst2.rds\n")
cat("  data/projections/sensitivity_comparison.rds\n")
cat("  data/projections/traj_full.rds\n")
cat("  data/projections/traj_no_sst2.rds\n")
cat(strrep("=", 70), "\n")

invisible(list(results = results, comparison = cmp_full))
