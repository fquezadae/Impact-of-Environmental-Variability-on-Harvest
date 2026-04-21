# =============================================================================
# FONDECYT -- 10_env_correlation.R
#
# Diagnostico de colinealidad SST-CHL en la serie CS-wide 2000-2024.
# Decide si CHL entra a T4 Stan como segundo shifter o se deja fuera.
#
# Contexto: T3-bis (09_stress_test_sst.R) mostro que en anchoveta el fit
# conjunto SST+CHL baja el error a 19% pero con rho_SST pegado a -3 y
# rho_CHL flipeando signo respecto al univariado -> patron clasico de
# colinealidad. Aca lo cuantificamos directo en las covariables antes de
# decidir la especificacion T4.
#
# Decision rule (acordada 2026-04-21):
#   |r_pearson| > 0.7  -> colinealidad fuerte, CHL FUERA de T4
#   |r_pearson| < 0.5  -> CHL DENTRO con prior debil N(0, 0.5)
#   0.5 <= |r| <= 0.7  -> zona gris, requiere decision adicional (VIF,
#                         detrend, o comparacion AIC entre especificaciones)
#
# Tres correlaciones que importan:
#   (a) Pearson raw        : la que "ve" el modelo (shifter = x - mean)
#   (b) Pearson first-diff : quita tendencias secular/seculares comunes
#   (c) Spearman raw       : robusto a monotonica no-lineal
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(tibble)
})

source_utf8 <- function(file, envir = globalenv()) {
  con <- file(file, "rb"); on.exit(close(con), add = TRUE)
  bytes <- readBin(con, what = "raw", n = file.info(file)$size)
  txt <- rawToChar(bytes); Encoding(txt) <- "UTF-8"
  eval(parse(text = txt, encoding = "UTF-8"), envir = envir)
}

source_utf8("R/00_config/config.R")

# Reusa load_env_annual() definido en 09_stress_test_sst.R
source_utf8("R/07_structural_bio/09_stress_test_sst.R")

# -----------------------------------------------------------------------------

run_env_correlation <- function(year_lo = 2000, year_hi = 2024) {

  env <- load_env_annual() %>%
    dplyr::filter(year >= year_lo, year <= year_hi,
                  is.finite(sst), is.finite(chl))

  if (nrow(env) < 10) stop("Serie ambiental con <10 anos en ventana solicitada.")

  # Correlaciones
  r_p  <- cor(env$sst, env$chl, method = "pearson")
  r_s  <- cor(env$sst, env$chl, method = "spearman")
  d_sst <- diff(env$sst); d_chl <- diff(env$chl)
  r_pd <- cor(d_sst, d_chl, method = "pearson")

  # Test de significancia para el Pearson raw
  n <- nrow(env)
  t_stat <- r_p * sqrt(n - 2) / sqrt(1 - r_p^2)
  pval   <- 2 * pt(-abs(t_stat), df = n - 2)

  # Decision
  abs_r <- abs(r_p)
  decision <- if (abs_r > 0.7) {
    "COLINEALIDAD FUERTE -- CHL FUERA de T4 (reportar como limitacion)"
  } else if (abs_r < 0.5) {
    "CHL DENTRO de T4 con prior debil rho_CHL ~ N(0, 0.5)"
  } else {
    "ZONA GRIS (0.5 <= |r| <= 0.7) -- decidir con VIF o AIC comparativo"
  }

  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("Correlacion SST-CHL, serie CS-wide ", year_lo, "-", year_hi,
      " (N = ", n, ")\n", sep = "")
  cat(strrep("=", 70), "\n")

  res_tbl <- tibble::tibble(
    metric = c("Pearson raw",
               "Pearson first-diff",
               "Spearman raw"),
    r      = c(r_p, r_pd, r_s),
    abs_r  = abs(r)
  )
  print(as.data.frame(res_tbl), row.names = FALSE, digits = 4)

  cat("\nPearson raw p-value (H0: r=0): ", format.pval(pval, digits = 3), "\n")
  cat("\nDecision (regla |r|>0.7 -> fuera; |r|<0.5 -> dentro):\n  ",
      decision, "\n", sep = "")

  # Lectura adicional: si Pearson raw >> Pearson first-diff, la colinealidad
  # viene de tendencia comun y no de co-variabilidad interanual genuina.
  if (abs(r_p) - abs(r_pd) > 0.2) {
    cat("\nOBS: |r_pearson_raw| - |r_firstdiff| = ",
        round(abs(r_p) - abs(r_pd), 3),
        ". La correlacion raw esta inflada por tendencia comun.\n",
        "    Si decidis incluir CHL en T4, considera detrendar ambas series\n",
        "    (anomalias vs spline de tiempo) antes de pasarlas como shifter.\n",
        sep = "")
  }
  cat(strrep("=", 70), "\n")

  # QA scatter plot
  qa_dir <- "data/bio_params/qa"
  if (!dir.exists(qa_dir)) dir.create(qa_dir, recursive = TRUE)

  p <- ggplot(env, aes(x = sst, y = chl, label = year)) +
    geom_point(size = 2.5, colour = "grey30") +
    geom_smooth(method = "lm", se = TRUE, colour = "firebrick", linewidth = 0.5) +
    ggrepel::geom_text_repel(size = 3, colour = "grey40",
                             max.overlaps = Inf) +
    labs(
      title    = sprintf("SST vs CHL anual CS-wide (%d-%d)", year_lo, year_hi),
      subtitle = sprintf("Pearson raw = %.3f  |  first-diff = %.3f  |  Spearman = %.3f",
                         r_p, r_pd, r_s),
      x = "SST anual (deg C)", y = "CHL anual (mg/m3)"
    ) +
    theme_minimal(base_size = 11)

  out_png <- file.path(qa_dir, "env_sst_chl_correlation.png")
  ggsave(out_png, p, width = 7, height = 5, dpi = 130)
  cat("QA plot: ", out_png, "\n", sep = "")

  invisible(list(
    env = env,
    pearson_raw = r_p,
    pearson_firstdiff = r_pd,
    spearman = r_s,
    pval_pearson = pval,
    decision = decision
  ))
}

# ---------------------------------------------------------------- main() ----

if (isTRUE(getOption("structural_bio.run_main", FALSE))) {
  # Requiere ggrepel solo para el plot; si no esta, skip plot
  has_repel <- requireNamespace("ggrepel", quietly = TRUE)
  if (!has_repel) {
    message("ggrepel no disponible; corriendo sin labels en scatter.")
  }
  run_env_correlation()
}
