# =============================================================================
# FONDECYT -- 10a_refit_ind_for_mm.R
#
# One-shot: re-fitea T4b-ind compilando con model_methods habilitados, para
# que loo::moment_match funcione. El fit actual en
# data/outputs/t4b/t4b_ind_fit.rds fue compilado sin ellos, y el pareto-k
# quedo con 58.8% en (0.7, 1] sin MM disponible.
#
# Mantiene mismos seeds, chains, warmup, iter, adapt_delta y max_treedepth
# que 04_fit_t4b_ind.R. Sobrescribe t4b_ind_fit.rds (el stan_data no cambia,
# asi que no se regenera).
#
# Corre con:
#   options(t4b.refit_ind.run_main = TRUE)
#   source("R/08_stan_t4/10a_refit_ind_for_mm.R")
# =============================================================================

suppressPackageStartupMessages({
  library(cmdstanr)
})

source_utf8 <- function(file, envir = globalenv()) {
  con <- file(file, "rb")
  on.exit(close(con), add = TRUE)
  bytes <- readBin(con, what = "raw", n = file.info(file)$size)
  txt <- rawToChar(bytes)
  Encoding(txt) <- "UTF-8"
  eval(parse(text = txt, encoding = "UTF-8"), envir = envir)
  invisible(NULL)
}
source_utf8("R/00_config/config.R")

T4B_IND_STAN_FILE <- "paper1/stan/t4b_state_space_ind.stan"
T4B_IND_OUT_DIR   <- "data/outputs/t4b"

if (isTRUE(getOption("t4b.refit_ind.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b-ind  REFIT con compile_model_methods=TRUE  (para moment matching)\n")
  cat(strrep("=", 70), "\n", sep = "")

  stan_data <- readRDS(file.path(T4B_IND_OUT_DIR, "t4b_ind_stan_data.rds"))

  # IMPORTANTE 1: NO pasar compile_model_methods=TRUE. Eso crea un exe con
  # methods embebidos cuyos Xptr no sobreviven save_object()+readRDS()
  # (bug de serializacion en cmdstanr). La ruta que si funciona es dejar
  # el exe "pelado" y que cmdstanr auto-compile methods al llamar
  # $loo(moment_match=TRUE) ("Compiling additional model methods...").
  #
  # IMPORTANTE 2: pasar data como PATH a un JSON persistente, NO como lista.
  # Si se pasa lista, cmdstanr escribe un tempfile que no sobrevive el
  # cambio de sesion de R, y el MM auto-compile falla con
  # "JSON parsing...document is empty".
  mod <- cmdstanr::cmdstan_model(
    T4B_IND_STAN_FILE,
    force_recompile = TRUE
  )

  json_path <- file.path(T4B_IND_OUT_DIR, "t4b_ind_stan_data.json")
  cmdstanr::write_stan_json(stan_data, json_path)
  cat(sprintf("[t4b-ind refit] stan_data escrito a %s\n", json_path))

  fit <- mod$sample(
    data            = json_path,
    chains          = 8,
    parallel_chains = 8,
    iter_warmup     = 2000,
    iter_sampling   = 2000,
    adapt_delta     = 0.99,
    max_treedepth   = 14,
    seed            = 2026L,
    refresh         = 200
  )

  # No llamamos init_model_methods aqui: queremos que el rds se guarde SIN
  # Xptr embebidos, para que la ruta auto-compile de $loo(moment_match) los
  # construya en la sesion de consumo.
  fit$save_object(file = file.path(T4B_IND_OUT_DIR, "t4b_ind_fit.rds"))
  cat("[t4b-ind refit] guardado en data/outputs/t4b/t4b_ind_fit.rds\n")

  cat("\n[t4b-ind refit] Diagnosticos cmdstan (sanity):\n")
  print(fit$cmdstan_diagnose())

  invisible(fit)
}
