# =============================================================================
# FONDECYT -- 09_ppc_t4b_full.R
#
# Posterior predictive check + diagnosticos visuales del fit T4b-full
# (3 stocks + Omega + shifters SST/CHL). Reusa logica del 07 y agrega:
#   (4) Forest plot Omega off-diagonal (comparable con t4b_omega_correlations)
#   (5) Forest plot rho_SST y rho_CHL por stock -- LOS RESULTADOS CENTRALES
#       del paper 1 (efecto ambiental sobre tasa de crecimiento)
#   (6) Serie temporal r_eff[t,s] -- crecimiento efectivo ano-a-ano por stock
#       mostrando la modulacion ambiental
#
# Corre con:
#   options(t4b.full.ppc.run_main = TRUE)
#   source("R/08_stan_t4/09_ppc_t4b_full.R")
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
T4B_FULL_WINDOW  <- 2000:2024
T4B_FULL_OUT_DIR <- "data/outputs/t4b"
T4B_FULL_FIG_DIR <- "figs/t4b"
T4B_FULL_STOCKS  <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
STOCK_LABELS <- c(anchoveta_cs = "Anchoveta CS",
                  sardina_comun_cs = "Sardina común CS",
                  jurel_cs = "Jurel CS")
dir.create(T4B_FULL_FIG_DIR, recursive = TRUE, showWarnings = FALSE)

theme_ppc <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = "grey95", color = NA),
        plot.title = element_text(face = "bold"))

# -----------------------------------------------------------------------------
# Carga
# -----------------------------------------------------------------------------
ppc_full_load_all <- function() {
  fit       <- readRDS(file.path(T4B_FULL_OUT_DIR, "t4b_full_fit.rds"))
  stan_data <- readRDS(file.path(T4B_FULL_OUT_DIR, "t4b_full_stan_data.rds"))

  mk_obs <- function(stock_idx, t_vec, B_vec, is_cen_vec = NULL) {
    tibble::tibble(
      stock_idx = stock_idx,
      stock_id  = T4B_FULL_STOCKS[stock_idx],
      t         = t_vec,
      year      = T4B_FULL_WINDOW[t_vec],
      B_obs     = B_vec,
      is_censored = if (is.null(is_cen_vec)) FALSE else is_cen_vec
    )
  }
  obs_df <- dplyr::bind_rows(
    mk_obs(1, stan_data$t_anch, stan_data$B_obs_anch),
    mk_obs(2, stan_data$t_sard, stan_data$B_obs_sard),
    mk_obs(3, stan_data$t_jur_unc, stan_data$B_obs_jur, FALSE),
    mk_obs(3, stan_data$t_jur_cen,
           rep(stan_data$B_censor_limit_jurel, stan_data$N_obs_jur_cen), TRUE)
  )

  list(fit = fit, stan_data = stan_data, obs_df = obs_df)
}

# -----------------------------------------------------------------------------
# (1) Smooth vs obs
# -----------------------------------------------------------------------------
plot_smooth_vs_obs_full <- function(fit, obs_df) {
  bs <- fit$draws("B_smooth", format = "draws_df") %>%
    select(-.chain, -.iteration, -.draw) %>%
    pivot_longer(everything(), names_to = "var", values_to = "B") %>%
    mutate(t = as.integer(sub("B_smooth\\[(\\d+),(\\d+)\\]", "\\1", var)),
           stock_idx = as.integer(sub("B_smooth\\[(\\d+),(\\d+)\\]", "\\2", var))) %>%
    group_by(t, stock_idx) %>%
    summarise(med = median(B),
              q05 = quantile(B, 0.05), q95 = quantile(B, 0.95),
              q25 = quantile(B, 0.25), q75 = quantile(B, 0.75),
              .groups = "drop") %>%
    mutate(year     = T4B_FULL_WINDOW[t],
           stock_id = T4B_FULL_STOCKS[stock_idx],
           stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_FULL_STOCKS]))

  obs_plot <- obs_df %>%
    mutate(stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_FULL_STOCKS]))

  ggplot(bs, aes(x = year)) +
    geom_ribbon(aes(ymin = q05, ymax = q95), fill = "steelblue", alpha = 0.20) +
    geom_ribbon(aes(ymin = q25, ymax = q75), fill = "steelblue", alpha = 0.35) +
    geom_line(aes(y = med), color = "steelblue", linewidth = 0.8) +
    geom_point(data = filter(obs_plot, !is_censored),
               aes(y = B_obs), color = "black", size = 1.8) +
    geom_point(data = filter(obs_plot, is_censored),
               aes(y = B_obs), color = "red", shape = 6, size = 2.5, stroke = 1) +
    facet_wrap(~ stock_lbl, scales = "free_y", ncol = 1) +
    labs(title = "(1) T4b-FULL: B_smooth vs obs",
         subtitle = "mediana + bandas 50%/90% posterior",
         x = NULL, y = "Biomasa total (mil t)") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (2) Residuos
# -----------------------------------------------------------------------------
plot_residuals_full <- function(fit, stan_data) {
  draws <- fit$draws(c("logB", "sigma_obs"), format = "draws_df")
  compute_resid <- function(t_vec, B_vec, stock_idx) {
    col_sigma <- sprintf("sigma_obs[%d]", stock_idx)
    purrr::map_dfr(seq_along(t_vec), function(n) {
      t_obs <- t_vec[n]
      col_logB <- sprintf("logB[%d,%d]", t_obs, stock_idx)
      r_std <- (log(B_vec[n]) - draws[[col_logB]]) / draws[[col_sigma]]
      tibble::tibble(stock_id = T4B_FULL_STOCKS[stock_idx],
                     year = T4B_FULL_WINDOW[t_obs],
                     r_mean = mean(r_std),
                     r_q05 = quantile(r_std, 0.05),
                     r_q95 = quantile(r_std, 0.95))
    })
  }
  resid_df <- dplyr::bind_rows(
    compute_resid(stan_data$t_anch,    stan_data$B_obs_anch, 1),
    compute_resid(stan_data$t_sard,    stan_data$B_obs_sard, 2),
    compute_resid(stan_data$t_jur_unc, stan_data$B_obs_jur,  3)
  ) %>%
    mutate(stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_FULL_STOCKS]))

  ggplot(resid_df, aes(x = year, y = r_mean)) +
    geom_hline(yintercept = 0, color = "grey40") +
    geom_hline(yintercept = c(-2, 2), linetype = "dashed", color = "red", alpha = 0.6) +
    geom_linerange(aes(ymin = r_q05, ymax = r_q95), color = "steelblue") +
    geom_point(color = "steelblue", size = 1.8) +
    facet_wrap(~ stock_lbl, scales = "free_y", ncol = 1) +
    labs(title = "(2) T4b-FULL: Residuos standardizados",
         subtitle = "(log(B_obs) - log(B_smooth)) / sigma_obs, CI 90%",
         x = NULL, y = "Residuo std") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (4) Omega forest (comparable con 6c)
# -----------------------------------------------------------------------------
plot_omega_forest_full <- function(fit) {
  pairs_label <- c("Omega[1,2]" = "Anchoveta × Sardina",
                   "Omega[1,3]" = "Anchoveta × Jurel",
                   "Omega[2,3]" = "Sardina × Jurel")
  vars <- names(pairs_label)
  om <- fit$draws(vars, format = "draws_df") %>%
    pivot_longer(all_of(vars), names_to = "pair", values_to = "rho") %>%
    group_by(pair) %>%
    summarise(med = median(rho),
              q05 = quantile(rho, 0.05),
              q95 = quantile(rho, 0.95),
              q25 = quantile(rho, 0.25),
              q75 = quantile(rho, 0.75),
              p_gt_0 = mean(rho > 0),
              .groups = "drop") %>%
    mutate(lbl = pairs_label[pair])
  ggplot(om, aes(y = reorder(lbl, med), x = med)) +
    geom_vline(xintercept = 0, color = "grey50", linetype = "dashed") +
    geom_linerange(aes(xmin = q05, xmax = q95), color = "steelblue",
                   linewidth = 0.6) +
    geom_linerange(aes(xmin = q25, xmax = q75), color = "steelblue",
                   linewidth = 1.8) +
    geom_point(size = 3, color = "steelblue") +
    geom_text(aes(label = sprintf("P(rho>0)=%.2f", p_gt_0)),
              hjust = -0.15, vjust = -0.6, size = 3) +
    xlim(-1, 1) +
    labs(title = "(4) T4b-FULL: Omega residual (despues de SST/CHL)",
         subtitle = "Si mas chico que 6(c), parte era forzamiento ambiental comun.",
         x = "correlacion (rho)", y = NULL) +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (5) rho_SST y rho_CHL -- EL RESULTADO CENTRAL DEL PAPER
# -----------------------------------------------------------------------------
plot_rho_forest <- function(fit) {
  vars <- c(sprintf("rho_sst[%d]", 1:3), sprintf("rho_chl[%d]", 1:3))
  dr <- fit$draws(vars, format = "draws_df") %>%
    pivot_longer(all_of(vars), names_to = "var", values_to = "rho") %>%
    mutate(
      stock_idx = as.integer(sub(".*\\[(\\d+)\\]", "\\1", var)),
      covar     = ifelse(grepl("sst", var), "SST", "log(CHL)"),
      stock_id  = T4B_FULL_STOCKS[stock_idx],
      stock_lbl = STOCK_LABELS[stock_id]
    ) %>%
    group_by(stock_lbl, covar) %>%
    summarise(med = median(rho),
              q05 = quantile(rho, 0.05),
              q95 = quantile(rho, 0.95),
              q25 = quantile(rho, 0.25),
              q75 = quantile(rho, 0.75),
              p_gt_0 = mean(rho > 0),
              .groups = "drop")

  ggplot(dr, aes(y = stock_lbl, x = med, color = covar)) +
    geom_vline(xintercept = 0, color = "grey50", linetype = "dashed") +
    geom_linerange(aes(xmin = q05, xmax = q95), linewidth = 0.6,
                   position = position_dodge(width = 0.5)) +
    geom_linerange(aes(xmin = q25, xmax = q75), linewidth = 1.8,
                   position = position_dodge(width = 0.5)) +
    geom_point(size = 3, position = position_dodge(width = 0.5)) +
    geom_text(aes(label = sprintf("%.2f", med)),
              position = position_dodge(width = 0.5),
              hjust = 0.5, vjust = -1.2, size = 3, show.legend = FALSE) +
    scale_color_manual(values = c(SST = "firebrick", `log(CHL)` = "forestgreen"),
                       name = NULL) +
    labs(title = "(5) Shifters ambientales -- efecto sobre r_t,s (paper 1 main)",
         subtitle = "r_t,s = r_base * exp(rho_SST * SST_c[t-1] + rho_CHL * logCHL_c[t-1])",
         x = "rho (coef de elasticidad semi-log)", y = NULL) +
    theme_ppc +
    theme(legend.position = "bottom")
}

# -----------------------------------------------------------------------------
# (6) r_eff[t,s] -- serie temporal del crecimiento efectivo
# -----------------------------------------------------------------------------
plot_r_eff_timeseries <- function(fit) {
  re <- fit$draws("r_eff", format = "draws_df") %>%
    select(-.chain, -.iteration, -.draw) %>%
    pivot_longer(everything(), names_to = "var", values_to = "r") %>%
    mutate(t  = as.integer(sub("r_eff\\[(\\d+),(\\d+)\\]", "\\1", var)),
           stock_idx = as.integer(sub("r_eff\\[(\\d+),(\\d+)\\]", "\\2", var))) %>%
    group_by(t, stock_idx) %>%
    summarise(med = median(r),
              q05 = quantile(r, 0.05), q95 = quantile(r, 0.95),
              .groups = "drop") %>%
    mutate(year      = T4B_FULL_WINDOW[t + 1],   # r_eff[t] aplica al ano t+1
           stock_id  = T4B_FULL_STOCKS[stock_idx],
           stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_FULL_STOCKS]))

  ggplot(re, aes(x = year)) +
    geom_ribbon(aes(ymin = q05, ymax = q95), fill = "steelblue", alpha = 0.25) +
    geom_line(aes(y = med), color = "steelblue", linewidth = 0.8) +
    geom_hline(yintercept = 0, color = "grey50", linetype = "dotted") +
    facet_wrap(~ stock_lbl, scales = "free_y", ncol = 1) +
    labs(title = "(6) r_eff[t] ano-a-ano (crecimiento intrinseco modulado por SST/CHL)",
         subtitle = "banda 90% posterior; referencia = r_base stock",
         x = NULL, y = "r_eff (anio^-1)") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# Reporte numerico
# -----------------------------------------------------------------------------
report_full_numeric <- function(fit, stan_data) {
  # rho posteriors
  vars <- c(sprintf("rho_sst[%d]", 1:3), sprintf("rho_chl[%d]", 1:3))
  rho <- fit$draws(vars, format = "draws_df") %>%
    pivot_longer(all_of(vars), names_to = "var", values_to = "rho") %>%
    dplyr::group_by(var) %>%
    dplyr::summarise(med    = median(rho),
                     q05    = quantile(rho, 0.05),
                     q95    = quantile(rho, 0.95),
                     p_gt_0 = mean(rho > 0),
                     p_lt_0 = mean(rho < 0),
                     .groups = "drop") %>%
    dplyr::mutate(stock_idx = as.integer(sub(".*\\[(\\d+)\\]", "\\1", var)),
                  stock_id  = T4B_FULL_STOCKS[stock_idx],
                  covar     = ifelse(grepl("sst", var), "SST", "CHL"))
  cat("\n[t4b-full-ppc] Shifters ambientales posterior:\n")
  print(rho %>% dplyr::select(stock_id, covar, med, q05, q95, p_gt_0, p_lt_0))

  # Omega residual
  pairs_label <- c("Omega[1,2]" = "Anchoveta-Sardina",
                   "Omega[1,3]" = "Anchoveta-Jurel",
                   "Omega[2,3]" = "Sardina-Jurel")
  om <- fit$draws(names(pairs_label), format = "draws_df") %>%
    pivot_longer(all_of(names(pairs_label)), names_to = "pair", values_to = "rho") %>%
    dplyr::group_by(pair) %>%
    dplyr::summarise(med = median(rho),
                     q05 = quantile(rho, 0.05),
                     q95 = quantile(rho, 0.95),
                     p_gt_0 = mean(rho > 0),
                     .groups = "drop") %>%
    dplyr::mutate(pair_lbl = pairs_label[pair])
  cat("\n[t4b-full-ppc] Omega RESIDUAL (despues de controlar por SST/CHL):\n")
  print(om %>% dplyr::select(pair_lbl, med, q05, q95, p_gt_0))

  # Residuos
  draws <- fit$draws(c("logB", "sigma_obs"), format = "draws_df")
  compute_tbl <- function(t_vec, B_vec, stock_idx) {
    col_sigma <- sprintf("sigma_obs[%d]", stock_idx)
    purrr::map_dfr(seq_along(t_vec), function(n) {
      t_obs <- t_vec[n]
      col_logB <- sprintf("logB[%d,%d]", t_obs, stock_idx)
      r_std <- (log(B_vec[n]) - draws[[col_logB]]) / draws[[col_sigma]]
      tibble::tibble(stock_id = T4B_FULL_STOCKS[stock_idx],
                     year = T4B_FULL_WINDOW[t_obs],
                     r_mean = mean(r_std))
    })
  }
  tbl <- dplyr::bind_rows(
    compute_tbl(stan_data$t_anch,    stan_data$B_obs_anch, 1),
    compute_tbl(stan_data$t_sard,    stan_data$B_obs_sard, 2),
    compute_tbl(stan_data$t_jur_unc, stan_data$B_obs_jur,  3)
  )
  cat("\n[t4b-full-ppc] Residuos std por stock:\n")
  print(tbl %>%
          dplyr::group_by(stock_id) %>%
          dplyr::summarise(n = n(),
                           mean = mean(r_mean),
                           sd   = sd(r_mean),
                           n_abs2 = sum(abs(r_mean) > 2),
                           max_abs = max(abs(r_mean)),
                           .groups = "drop"))
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.full.ppc.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b-FULL PPC -- multi-stock + Omega + shifters SST/CHL\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  L  <- ppc_full_load_all()
  p1 <- plot_smooth_vs_obs_full(L$fit, L$obs_df)
  p2 <- plot_residuals_full(L$fit, L$stan_data)
  p4 <- plot_omega_forest_full(L$fit)
  p5 <- plot_rho_forest(L$fit)
  p6 <- plot_r_eff_timeseries(L$fit)

  ggsave(file.path(T4B_FULL_FIG_DIR, "t4b_full_smooth_vs_obs.png"),
         p1, width = 9, height = 10, dpi = 120)
  ggsave(file.path(T4B_FULL_FIG_DIR, "t4b_full_residuals.png"),
         p2, width = 9, height = 9, dpi = 120)
  ggsave(file.path(T4B_FULL_FIG_DIR, "t4b_full_omega_residual.png"),
         p4, width = 8, height = 4, dpi = 120)
  ggsave(file.path(T4B_FULL_FIG_DIR, "t4b_full_rho_shifters.png"),
         p5, width = 9, height = 5, dpi = 120)
  ggsave(file.path(T4B_FULL_FIG_DIR, "t4b_full_r_eff_timeseries.png"),
         p6, width = 9, height = 9, dpi = 120)

  report_full_numeric(L$fit, L$stan_data)

  cat(sprintf("\n[t4b-full-ppc] Figuras guardadas en %s/\n", T4B_FULL_FIG_DIR))
  cat("Interpretacion clave:\n")
  cat("  - t4b_full_rho_shifters.png  <- FIGURA PRINCIPAL del paper 1\n")
  cat("  - t4b_full_r_eff_timeseries  <- muestra modulacion ambiental de r\n")
  cat("  - omega_residual vs 6(c)     <- si achico, parte del Omega era ENSO comun\n")

  invisible(NULL)
}
