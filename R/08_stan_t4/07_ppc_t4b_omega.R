# =============================================================================
# FONDECYT -- 07_ppc_t4b_omega.R
#
# Posterior predictive check + diagnosticos visuales del fit T4b-omega
# (3 stocks + Omega via LKJ(4)). Reusa la logica del 05_ppc_t4b_ind.R pero
# apunta a los outputs de 06_fit_t4b_omega.R y agrega un forest plot de las
# 3 correlaciones off-diagonal de Omega.
#
# Figuras en figs/t4b/ con prefijo t4b_omega_:
#   (1) t4b_omega_smooth_vs_obs.png  -- idem 05 pero para el fit omega.
#   (2) t4b_omega_residuals.png      -- idem 05.
#   (3) t4b_omega_traces.png         -- traces de r, K, sigma_proc, Omega[i,j].
#   (4) t4b_omega_correlations.png   -- FOREST PLOT de Omega[1,2], [1,3], [2,3]
#        con posterior median + CI 50%/90%. El resultado principal de 6(c).
#
# Corre con:
#   options(t4b.omega.ppc.run_main = TRUE)
#   source("R/08_stan_t4/07_ppc_t4b_omega.R")
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
T4B_OMEGA_WINDOW  <- 2000:2024
T4B_OMEGA_OUT_DIR <- "data/outputs/t4b"
T4B_OMEGA_FIG_DIR <- "figs/t4b"
T4B_OMEGA_STOCKS  <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
STOCK_LABELS <- c(anchoveta_cs = "Anchoveta CS",
                  sardina_comun_cs = "Sardina común CS",
                  jurel_cs = "Jurel CS")
dir.create(T4B_OMEGA_FIG_DIR, recursive = TRUE, showWarnings = FALSE)

theme_ppc <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = "grey95", color = NA),
        plot.title = element_text(face = "bold"))

# -----------------------------------------------------------------------------
# Carga
# -----------------------------------------------------------------------------
ppc_omega_load_all <- function() {
  fit       <- readRDS(file.path(T4B_OMEGA_OUT_DIR, "t4b_omega_fit.rds"))
  stan_data <- readRDS(file.path(T4B_OMEGA_OUT_DIR, "t4b_omega_stan_data.rds"))

  mk_obs <- function(stock_idx, t_vec, B_vec, is_cen_vec = NULL) {
    tibble::tibble(
      stock_idx = stock_idx,
      stock_id  = T4B_OMEGA_STOCKS[stock_idx],
      t         = t_vec,
      year      = T4B_OMEGA_WINDOW[t_vec],
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
# (1) Smooth vs obs -- identico al 05
# -----------------------------------------------------------------------------
plot_smooth_vs_obs_omega <- function(fit, obs_df) {
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
    mutate(year      = T4B_OMEGA_WINDOW[t],
           stock_id  = T4B_OMEGA_STOCKS[stock_idx],
           stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_OMEGA_STOCKS]))

  obs_plot <- obs_df %>%
    mutate(stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_OMEGA_STOCKS]))

  ggplot(bs, aes(x = year)) +
    geom_ribbon(aes(ymin = q05, ymax = q95), fill = "steelblue", alpha = 0.20) +
    geom_ribbon(aes(ymin = q25, ymax = q75), fill = "steelblue", alpha = 0.35) +
    geom_line(aes(y = med), color = "steelblue", linewidth = 0.8) +
    geom_point(data = filter(obs_plot, !is_censored),
               aes(y = B_obs), color = "black", size = 1.8) +
    geom_point(data = filter(obs_plot, is_censored),
               aes(y = B_obs), color = "red", shape = 6, size = 2.5, stroke = 1) +
    facet_wrap(~ stock_lbl, scales = "free_y", ncol = 1) +
    labs(title = "(1) T4b-OMEGA: B_smooth vs obs",
         subtitle = "mediana + bandas 50%/90% posterior; puntos = obs; triangulos rojos = jurel left-censored",
         x = NULL, y = "Biomasa total (mil t)") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (2) Residuos -- identico al 05
# -----------------------------------------------------------------------------
plot_residuals_omega <- function(fit, stan_data) {
  draws <- fit$draws(c("logB", "sigma_obs"), format = "draws_df")

  compute_resid <- function(t_vec, B_vec, stock_idx) {
    col_sigma <- sprintf("sigma_obs[%d]", stock_idx)
    purrr::map_dfr(seq_along(t_vec), function(n) {
      t_obs <- t_vec[n]
      # logB representation in omega model is array[T] vector[S] -> Stan emits
      # posterior draws column names as logB[t,s] igual que matrix, asi que
      # la sintaxis aqui funciona sin cambios.
      col_logB <- sprintf("logB[%d,%d]", t_obs, stock_idx)
      r_std <- (log(B_vec[n]) - draws[[col_logB]]) / draws[[col_sigma]]
      tibble::tibble(
        stock_idx = stock_idx,
        stock_id  = T4B_OMEGA_STOCKS[stock_idx],
        year      = T4B_OMEGA_WINDOW[t_obs],
        r_mean    = mean(r_std),
        r_q05     = quantile(r_std, 0.05),
        r_q95     = quantile(r_std, 0.95)
      )
    })
  }

  resid_df <- dplyr::bind_rows(
    compute_resid(stan_data$t_anch,    stan_data$B_obs_anch, 1),
    compute_resid(stan_data$t_sard,    stan_data$B_obs_sard, 2),
    compute_resid(stan_data$t_jur_unc, stan_data$B_obs_jur,  3)
  ) %>%
    mutate(stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_OMEGA_STOCKS]))

  ggplot(resid_df, aes(x = year, y = r_mean)) +
    geom_hline(yintercept = 0, color = "grey40") +
    geom_hline(yintercept = c(-2, 2), linetype = "dashed", color = "red", alpha = 0.6) +
    geom_linerange(aes(ymin = r_q05, ymax = r_q95), color = "steelblue") +
    geom_point(color = "steelblue", size = 1.8) +
    facet_wrap(~ stock_lbl, scales = "free_y", ncol = 1) +
    labs(title = "(2) T4b-OMEGA: Residuos standardizados por stock",
         subtitle = "(log(B_obs) - log(B_smooth)) / sigma_obs, CI 90%",
         x = NULL, y = "Residuo std") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (3) Trace plots -- mismo esquema que 05 + Omega off-diagonal
# -----------------------------------------------------------------------------
plot_traces_omega <- function(fit) {
  vars_struct <- c(sprintf("r_nat[%d]", 1:3),
                   sprintf("K_nat[%d]", 1:3),
                   sprintf("sigma_proc[%d]", 1:3))
  tr_struct <- fit$draws(vars_struct, format = "draws_df") %>%
    pivot_longer(all_of(vars_struct), names_to = "param", values_to = "val") %>%
    mutate(stock_idx = as.integer(sub(".*\\[(\\d+)\\].*", "\\1", param)),
           stock_lbl = STOCK_LABELS[T4B_OMEGA_STOCKS[stock_idx]],
           pname     = sub("\\[\\d+\\]", "", param),
           pname     = factor(pname, levels = c("r_nat", "K_nat", "sigma_proc")))

  p_struct <- ggplot(tr_struct, aes(x = .iteration, y = val, color = factor(.chain))) +
    geom_line(alpha = 0.6, linewidth = 0.25) +
    facet_grid(pname ~ stock_lbl, scales = "free_y") +
    scale_color_viridis_d(name = "chain", option = "D") +
    labs(title = "(3a) Traces estructurales",
         x = "iteracion", y = NULL) +
    theme_ppc +
    theme(legend.position = "bottom")
  p_struct
}

# -----------------------------------------------------------------------------
# (4) FOREST PLOT de Omega off-diagonal
# -----------------------------------------------------------------------------
plot_omega_forest <- function(fit) {
  pairs_label <- c(
    "Omega[1,2]" = "Anchoveta × Sardina",
    "Omega[1,3]" = "Anchoveta × Jurel",
    "Omega[2,3]" = "Sardina × Jurel"
  )
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
    labs(title = "(4) Omega off-diagonal -- correlaciones de ruido de proceso",
         subtitle = "mediana + CI 50% (grueso) y 90% (fino); LKJ(4) apretado hacia 0",
         x = "correlacion (rho)", y = NULL) +
    theme_ppc
}

# -----------------------------------------------------------------------------
# Reporte numerico
# -----------------------------------------------------------------------------
report_omega_numeric <- function(fit, stan_data) {
  # Residuos por stock
  draws <- fit$draws(c("logB", "sigma_obs"), format = "draws_df")
  compute_tbl <- function(t_vec, B_vec, stock_idx) {
    col_sigma <- sprintf("sigma_obs[%d]", stock_idx)
    purrr::map_dfr(seq_along(t_vec), function(n) {
      t_obs <- t_vec[n]
      col_logB <- sprintf("logB[%d,%d]", t_obs, stock_idx)
      r_std <- (log(B_vec[n]) - draws[[col_logB]]) / draws[[col_sigma]]
      tibble::tibble(stock_id = T4B_OMEGA_STOCKS[stock_idx],
                     year = T4B_OMEGA_WINDOW[t_obs],
                     r_mean = mean(r_std))
    })
  }
  tbl <- dplyr::bind_rows(
    compute_tbl(stan_data$t_anch,    stan_data$B_obs_anch, 1),
    compute_tbl(stan_data$t_sard,    stan_data$B_obs_sard, 2),
    compute_tbl(stan_data$t_jur_unc, stan_data$B_obs_jur,  3)
  )
  cat("\n[t4b-omega-ppc] Resumen residuos std por stock:\n")
  print(tbl %>%
          dplyr::group_by(stock_id) %>%
          dplyr::summarise(n = n(),
                           mean = mean(r_mean),
                           sd   = sd(r_mean),
                           n_abs2 = sum(abs(r_mean) > 2),
                           max_abs = max(abs(r_mean)),
                           .groups = "drop"))

  # Omega posterior
  pairs_label <- c("Omega[1,2]" = "Anchoveta-Sardina",
                   "Omega[1,3]" = "Anchoveta-Jurel",
                   "Omega[2,3]" = "Sardina-Jurel")
  om_tbl <- fit$draws(names(pairs_label), format = "draws_df") %>%
    pivot_longer(all_of(names(pairs_label)), names_to = "pair", values_to = "rho") %>%
    dplyr::group_by(pair) %>%
    dplyr::summarise(med = median(rho),
                     q05 = quantile(rho, 0.05),
                     q95 = quantile(rho, 0.95),
                     p_gt_0 = mean(rho > 0),
                     .groups = "drop") %>%
    dplyr::mutate(pair_lbl = pairs_label[pair])
  cat("\n[t4b-omega-ppc] Omega off-diagonal posterior:\n")
  print(om_tbl %>% dplyr::select(pair_lbl, med, q05, q95, p_gt_0))
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.omega.ppc.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b-OMEGA PPC multi-stock + correlaciones\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  L  <- ppc_omega_load_all()
  p1 <- plot_smooth_vs_obs_omega(L$fit, L$obs_df)
  p2 <- plot_residuals_omega(L$fit, L$stan_data)
  p3 <- plot_traces_omega(L$fit)
  p4 <- plot_omega_forest(L$fit)

  ggsave(file.path(T4B_OMEGA_FIG_DIR, "t4b_omega_smooth_vs_obs.png"),
         p1, width = 9, height = 10, dpi = 120)
  ggsave(file.path(T4B_OMEGA_FIG_DIR, "t4b_omega_residuals.png"),
         p2, width = 9, height = 9, dpi = 120)
  ggsave(file.path(T4B_OMEGA_FIG_DIR, "t4b_omega_traces.png"),
         p3, width = 11, height = 8, dpi = 120)
  ggsave(file.path(T4B_OMEGA_FIG_DIR, "t4b_omega_correlations.png"),
         p4, width = 8, height = 4, dpi = 120)

  report_omega_numeric(L$fit, L$stan_data)

  cat(sprintf("\n[t4b-omega-ppc] Figuras guardadas en %s/\n", T4B_OMEGA_FIG_DIR))
  cat("Interpretacion clave del forest Omega:\n")
  cat("  - Si CI 90% de Omega[1,2] NO cruza 0 -> correlacion anch-sard significativa\n")
  cat("  - Omega[*,3] con CI amplio cruzando 0: esperado por sigma_proc[3] grande\n")
  cat("  - Si todo Omega es indistinguible de 0, el modelo Omega=I era suficiente;\n")
  cat("    no se pierde nada con agregar Omega pero tampoco se gana.\n")

  invisible(NULL)
}
