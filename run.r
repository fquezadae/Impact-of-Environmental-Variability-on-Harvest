# 1) Primero los tests puros (no tocan datos reales)
source("R/06_projections/04_forward_simulation.R")   # carga funciones
source("R/06_projections/04_forward_simulation_tests.R")
# Debe salir: T1..T5 todos PASS

# 2) Luego el pipeline completo con SUR real + mock deltas
options(fwd_sim.run_main = TRUE)
source("R/06_projections/04_forward_simulation.R")