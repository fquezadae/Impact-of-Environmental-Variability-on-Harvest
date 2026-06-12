# =============================================================================
# FONDECYT -- 03_ppc_t4b_single_anchoveta.R
#
# Posterior predictive check + diagnosticos visuales del fit T4b single-species
# (anchoveta_cs). Se corre DESPUES de 02_fit_t4b_single_anchoveta.R.
#
# Produce 4 figuras + un panel combinado:
#   (1) t4b_ppc_B_smooth_vs_obs.png -- estado latente suavizado (mediana + banda
#       90%) contra observaciones SSB SCAA.
#   (2) t4b_ppc_densities.png        -- densidades de B_rep[t] por anio,
#       overlaying B_obs[t] como linea vertical.
#   (3) t4b_ppc_residuals.png        -- residuos standardizados por anio
#       (log(B_obs) - mediana(log(B_smooth))) / sigma_obs_posterior.
#   (4) t4b_traces.png               -- trace plots de r_nat, K_nat, sigma_proc
#       por chain; visual check que todas exploran la misma region.
#   (5) t4b_panel_ppc.png            -- los 4 combinados.
#
# Corre con:
#   options(t4b.ppc.run_main = TRUE)
#   source("R/08_stan_t4/03_ppc_t4b_single_anchoveta.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(posterior)
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

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
T4B_WINDOW  <- 2000:2024
T4B_OUT_DIR <- "data/outputs/t4b"
T4B_FIG_DIR <- "figs/t4b"
dir.create(T4B_FIG_DIR, recursive = TRUE, showWarnings = FALSE)

theme_ppc <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = "grey95", color = NA),
        plot.title = element_text(face = "bold"))

# -----------------------------------------------------------------------------
# Carga
# -----------------------------------------------------------------------------
ppc_load_all <- function() {
  fit       <- readRDS(file.path(T4B_OUT_DIR, "t4b_single_anch_fit.rds"))
  stan_data <- readRDS(file.path(T4B_OUT_DIR, "t4b_single_anch_stan_data.rds"))

  # Observaciones en formato long para merge
  obs_df <- tibble::tibble(
    year    = T4B_WINDOW,
    t       = seq_along(T4B_WINDOW),
    B_obs   = NA_real_
  )
  obs_df$B_obs[stan_data$t_obs] <- stan_data$B_obs

  list(fit = fit, stan_data = stan_data, obs_df = obs_df)
}

# -----------------------------------------------------------------------------
# (1) B_smooth vs obs
# -----------------------------------------------------------------------------
plot_smooth_vs_obs <- function(fit, obs_df) {
  bs <- fit$draws("B_smooth", format = "draws_df")
  bs_long <- bs %>%
    select(-.chain, -.iteration, -.draw) %>%
    pivot_longer(everything(), names_to = "var", values_to = "B") %>%
    mutate(t = as.integer(sub("B_smooth\\[(\\d+)\\]", "\\1", var))) %>%
    group_by(t) %>%
    summarise(
      med = median(B),
      q05 = quantile(B, 0.05),
      q95 = quantile(B, 0.95),
      q25 = quantile(B, 0.25),
      q75 = quantile(B, 0.75),
      .groups = "drop"
    ) %>%
    left_join(obs_df, by = "t")

  ggplot(bs_long, aes(x = year)) +
    geom_ribbon(aes(ymin = q05, ymax = q95), fill = "steelblue", alpha = 0.20) +
    geom_ribbon(aes(ymin = q25, ymax = q75), fill = "steelblue", alpha = 0.35) +
    geom_line(aes(y = med), color = "steelblue", linewidth = 0.9) +
    geom_point(aes(y = B_obs), color = "black", size = 2.2) +
    labs(title = "(1) Estado latente B_smooth vs obs (anchoveta_cs)",
         subtitle = "mediana + bandas 50% / 90% posterior; puntos = B_obs (biomasa total SCAA IFOP)",
         x = NULL, y = "Biomasa total (mil t)") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (2) PPC densities -- B_rep por anio con linea vertical en B_obs
# -----------------------------------------------------------------------------
plot_ppc_densities <- function(fit, stan_data) {
  br <- fit$draws("B_rep", format = "draws_df") %>%
    select(-.chain, -.iteration, -.draw)
  # Columnas son B_rep[1], B_rep[2], ..., B_rep[N_obs] indexadas por N_obs
  # (orden coincide con stan_data$t_obs).
  br_long <- br %>%
    pivot_longer(everything(), names_to = "var", values_to = "B_rep") %>%
    mutate(n = as.integer(sub("B_rep\\[(\\d+)\\]", "\\1", var)),
           year = T4B_WINDOW[stan_data$t_obs[n]],
           B_obs = stan_data$B_obs[n])

  # Sampleamos 800 draws por anio para densidad no muy pesada
  set.seed(42)
  br_sample <- br_long %>%
    group_by(n) %>%
    slice_sample(n = 800) %>%
    ungroup()

  ggplot(br_sample, aes(x = B_rep)) +
    geom_density(fill = "steelblue", color = NA, alpha = 0.45) +
    geom_vline(aes(xintercept = B_obs), color = "red", linewidth = 0.6) +
    facet_wrap(~ year, scales = "free", ncol = 5) +
    labs(title = "(2) PPC: densidad de B_rep por anio vs obs (linea roja)",
         subtitle = "Si las obs caen fuera de las densidades, el modelo no describe bien los datos",
         x = "B_rep (mil t)", y = NULL) +
    theme_ppc +
    theme(axis.text.y = element_blank(), axis.ticks.y = element_blank())
}

# -----------------------------------------------------------------------------
# (3) Residuos standardizados
# -----------------------------------------------------------------------------
plot_residuals <- function(fit, stan_data) {
  draws <- fit$draws(c("logB", "sigma_obs"), format = "draws_df")

  # Para cada observacion, residuo standardizado = (log(B_obs) - logB[t]) / sigma_obs
  resid_df <- purrr::map_dfr(seq_len(stan_data$N_obs), function(n) {
    t_obs <- stan_data$t_obs[n]
    col_logB <- sprintf("logB[%d]", t_obs)
    log_B_obs <- log(stan_data$B_obs[n])
    r_std <- (log_B_obs - draws[[col_logB]]) / draws[["sigma_obs"]]
    tibble::tibble(
      n      = n,
      year   = T4B_WINDOW[t_obs],
      r_mean = mean(r_std),
      r_q05  = quantile(r_std, 0.05),
      r_q95  = quantile(r_std, 0.95)
    )
  })

  ggplot(resid_df, aes(x = year, y = r_mean)) +
    geom_hline(yintercept = 0, linetype = "solid", color = "grey40") +
    geom_hline(yintercept = c(-2, 2), linetype = "dashed", color = "red", alpha = 0.6) +
    geom_linerange(aes(ymin = r_q05, ymax = r_q95), color = "steelblue") +
    geom_point(color = "steelblue", size = 2) +
    labs(title = "(3) Residuos standardizados (log-escala)",
         subtitle = "(log(B_obs) - log(B_smooth)) / sigma_obs, posterior mean con CI 90%. |r|>2 = outlier",
         x = NULL, y = "Residuo std") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (4) Trace plots de parametros clave
# -----------------------------------------------------------------------------
plot_traces <- function(fit) {
  tr <- fit$draws(c("r_nat", "K_nat", "sigma_proc"), format = "draws_df")
  tr_long <- tr %>%
    pivot_longer(c(r_nat, K_nat, sigma_proc),
                 names_to = "param", values_to = "val") %>%
    mutate(param = factor(param, levels = c("r_nat", "K_nat", "sigma_proc")))

  ggplot(tr_long, aes(x = .iteration, y = val, color = factor(.chain))) +
    geom_line(alpha = 0.7, linewidth = 0.3) +
    facet_wrap(~ param, scales = "free_y", ncol = 1) +
    scale_color_viridis_d(name = "chain", option = "D") +
    labs(title = "(4) Trace plots (post-warmup)",
         subtitle = "Las 8 cadenas deben superponerse; si se separan = mal mixing",
         x = "iteracion", y = NULL) +
    theme_ppc +
    theme(legend.position = "bottom")
}

# -----------------------------------------------------------------------------
# Panel combinado (simple grid usando gridExtra si esta disponible; si no,
# guardamos los 4 individuales y listo)
# -----------------------------------------------------------------------------
save_all <- function(p1, p2, p3, p4) {
  ggsave(file.path(T4B_FIG_DIR, "t4b_ppc_B_smooth_vs_obs.png"),
         p1, width = 8, height = 5, dpi = 120)
  ggsave(file.path(T4B_FIG_DIR, "t4b_ppc_densities.png"),
         p2, width = 11, height = 9, dpi = 120)
  ggsave(file.path(T4B_FIG_DIR, "t4b_ppc_residuals.png"),
         p3, width = 8, height = 4, dpi = 120)
  ggsave(file.path(T4B_FIG_DIR, "t4b_traces.png"),
         p4, width = 8, height = 8, dpi = 120)

  have_gridExtra <- requireNamespace("gridExtra", quietly = TRUE)
  if (have_gridExtra) {
    panel <- gridExtra::arrangeGrob(p1, p3, p4, p2,
                                    layout_matrix = rbind(c(1, 3),
                                                          c(2, 3),
                                                          c(4, 4)),
                                    heights = c(1, 0.5, 1.6))
    ggsave(file.path(T4B_FIG_DIR, "t4b_panel_ppc.png"),
           panel, width = 14, height = 14, dpi = 110)
  } else {
    message("[t4b-ppc] gridExtra no disponible -- saltando panel combinado.")
  }
}

# -----------------------------------------------------------------------------
# Diagnosticos numericos (print)
# -----------------------------------------------------------------------------
report_numeric <- function(fit, stan_data) {
  # Residuos standardizados agregados: cuantas obs estan fuera de [-2, 2]?
  draws <- fit$draws(c("logB", "sigma_obs"), format = "draws_df")
  r_tbl <- purrr::map_dfr(seq_len(stan_data$N_obs), function(n) {
    t_obs <- stan_data$t_obs[n]
    col_logB <- sprintf("logB[%d]", t_obs)
    log_B_obs <- log(stan_data$B_obs[n])
    r_std <- (log_B_obs - draws[[col_logB]]) / draws[["sigma_obs"]]
    tibble::tibble(year = T4B_WINDOW[t_obs], r_mean = mean(r_std))
  })

  cat("\n[t4b-ppc] Resumen de residuos standardizados:\n")
  cat(sprintf("  Media: %.3f   SD: %.3f\n",
              mean(r_tbl$r_mean), sd(r_tbl$r_mean)))
  cat(sprintf("  |r| > 2: %d de %d obs (%.0f%%)\n",
              sum(abs(r_tbl$r_mean) > 2), nrow(r_tbl),
              100 * mean(abs(r_tbl$r_mean) > 2)))
  cat(sprintf("  Rango residuos mean: [%.2f, %.2f]\n",
              min(r_tbl$r_mean), max(r_tbl$r_mean)))

  # Outliers para inspeccion
  outliers <- r_tbl %>% filter(abs(r_mean) > 1.5) %>% arrange(desc(abs(r_mean)))
  if (nrow(outliers) > 0) {
    cat("\n  Anios con |residuo| > 1.5 (revisar en plot de residuos):\n")
    for (i in seq_len(nrow(outliers))) {
      cat(sprintf("    %d: r_std = %+.2f\n",
                  outliers$year[i], outliers$r_mean[i]))
    }
  } else {
    cat("\n  Ningun residuo |r| > 1.5. PPC excelente.\n")
  }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.ppc.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b PPC single-species anchoveta_cs\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  L  <- ppc_load_all()
  p1 <- plot_smooth_vs_obs(L$fit, L$obs_df)
  p2 <- plot_ppc_densities(L$fit, L$stan_data)
  p3 <- plot_residuals(L$fit, L$stan_data)
  p4 <- plot_traces(L$fit)

  save_all(p1, p2, p3, p4)

  report_numeric(L$fit, L$stan_data)

  cat(sprintf("\n[t4b-ppc] Figuras guardadas en %s/\n", T4B_FIG_DIR))
  cat("Inspeccionar visualmente antes de escalar a paso 6(b) (3 stocks).\n")

  invisible(NULL)
}
