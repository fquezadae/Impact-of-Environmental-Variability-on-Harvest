# =============================================================================
# FONDECYT -- 05_ppc_t4b_ind.R
#
# Posterior predictive check + diagnosticos visuales del fit T4b-ind multi-stock
# (anch + sard + jurel con Omega=I). Analogo al 03 pero para 3 stocks.
#
# Figuras producidas (todas en figs/t4b/):
#   (1) t4b_ind_smooth_vs_obs.png -- 3 paneles (uno por stock): B_smooth
#       (mediana + bandas 50%/90%) contra B_obs. Para jurel, los 2 anios
#       left-censored se marcan con triangulos en y = limite de censura.
#   (2) t4b_ind_residuals.png     -- residuos std por stock (y anio).
#   (3) t4b_ind_traces.png        -- trace plots de r_nat, K_nat, sigma_proc
#       para los 3 stocks (15 traces).
#
# Observacion sobre jurel: con sigma_proc[3] ~ 1.24 (reventando el prior), se
# espera que la banda 90% del estado latente sea MUY amplia (log-escala 1.24
# -> factor multiplicativo ~3.5 entre q5 y q95). Eso no invalida el fit, pero
# si las obs caen dentro de esa banda es porque la banda es enorme, no porque
# el modelo este prediciendo bien. Leer los residuos standardizados con ese
# contexto en mente.
#
# Corre con:
#   options(t4b.ind.ppc.run_main = TRUE)
#   source("R/08_stan_t4/05_ppc_t4b_ind.R")
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
T4B_IND_WINDOW  <- 2000:2024
T4B_IND_OUT_DIR <- "data/outputs/t4b"
T4B_IND_FIG_DIR <- "figs/t4b"
T4B_IND_STOCKS  <- c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")
STOCK_LABELS <- c(anchoveta_cs = "Anchoveta CS",
                  sardina_comun_cs = "Sardina común CS",
                  jurel_cs = "Jurel CS")
dir.create(T4B_IND_FIG_DIR, recursive = TRUE, showWarnings = FALSE)

theme_ppc <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = "grey95", color = NA),
        plot.title = element_text(face = "bold"))

# -----------------------------------------------------------------------------
# Carga
# -----------------------------------------------------------------------------
ppc_ind_load_all <- function() {
  fit       <- readRDS(file.path(T4B_IND_OUT_DIR, "t4b_ind_fit.rds"))
  stan_data <- readRDS(file.path(T4B_IND_OUT_DIR, "t4b_ind_stan_data.rds"))

  # Observaciones en formato long (una fila por stock-t observado)
  # Incluye un flag is_censored para jurel (TRUE si el anio es left-censored).
  mk_obs <- function(stock_idx, t_vec, B_vec, is_cen_vec = NULL) {
    tibble::tibble(
      stock_idx  = stock_idx,
      stock_id   = T4B_IND_STOCKS[stock_idx],
      t          = t_vec,
      year       = T4B_IND_WINDOW[t_vec],
      B_obs      = B_vec,
      is_censored = if (is.null(is_cen_vec)) FALSE else is_cen_vec
    )
  }
  obs_df <- dplyr::bind_rows(
    mk_obs(1, stan_data$t_anch, stan_data$B_obs_anch),
    mk_obs(2, stan_data$t_sard, stan_data$B_obs_sard),
    mk_obs(3, stan_data$t_jur_unc, stan_data$B_obs_jur, FALSE),
    # Jurel censored: B_obs se marca al limite de censura para visualizacion
    mk_obs(3, stan_data$t_jur_cen,
           rep(stan_data$B_censor_limit_jurel, stan_data$N_obs_jur_cen), TRUE)
  )

  list(fit = fit, stan_data = stan_data, obs_df = obs_df)
}

# -----------------------------------------------------------------------------
# (1) B_smooth vs obs, paneles por stock
# -----------------------------------------------------------------------------
plot_smooth_vs_obs_ind <- function(fit, obs_df) {
  bs <- fit$draws("B_smooth", format = "draws_df") %>%
    select(-.chain, -.iteration, -.draw) %>%
    pivot_longer(everything(), names_to = "var", values_to = "B") %>%
    # B_smooth[t,s] ; extraer t y s
    mutate(t = as.integer(sub("B_smooth\\[(\\d+),(\\d+)\\]", "\\1", var)),
           stock_idx = as.integer(sub("B_smooth\\[(\\d+),(\\d+)\\]", "\\2", var))) %>%
    group_by(t, stock_idx) %>%
    summarise(med = median(B),
              q05 = quantile(B, 0.05),
              q95 = quantile(B, 0.95),
              q25 = quantile(B, 0.25),
              q75 = quantile(B, 0.75),
              .groups = "drop") %>%
    mutate(year     = T4B_IND_WINDOW[t],
           stock_id = T4B_IND_STOCKS[stock_idx],
           stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_IND_STOCKS]))

  obs_plot <- obs_df %>%
    mutate(stock_lbl = factor(STOCK_LABELS[stock_id],
                              levels = STOCK_LABELS[T4B_IND_STOCKS]))

  ggplot(bs, aes(x = year)) +
    geom_ribbon(aes(ymin = q05, ymax = q95), fill = "steelblue", alpha = 0.20) +
    geom_ribbon(aes(ymin = q25, ymax = q75), fill = "steelblue", alpha = 0.35) +
    geom_line(aes(y = med), color = "steelblue", linewidth = 0.8) +
    geom_point(data = filter(obs_plot, !is_censored),
               aes(y = B_obs), color = "black", size = 1.8) +
    geom_point(data = filter(obs_plot, is_censored),
               aes(y = B_obs), color = "red", shape = 6, size = 2.5, stroke = 1) +
    facet_wrap(~ stock_lbl, scales = "free_y", ncol = 1) +
    labs(title = "(1) Estado latente B_smooth vs observaciones",
         subtitle = "mediana + bandas 50%/90% posterior; puntos negros = obs; triangulos rojos = jurel left-censored (B <= 3 mil t)",
         x = NULL, y = "Biomasa total (mil t)") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (2) Residuos standardizados por stock
# -----------------------------------------------------------------------------
plot_residuals_ind <- function(fit, stan_data) {
  draws <- fit$draws(c("logB", "sigma_obs"), format = "draws_df")

  compute_resid <- function(t_vec, B_vec, stock_idx) {
    col_sigma <- sprintf("sigma_obs[%d]", stock_idx)
    purrr::map_dfr(seq_along(t_vec), function(n) {
      t_obs <- t_vec[n]
      col_logB <- sprintf("logB[%d,%d]", t_obs, stock_idx)
      r_std <- (log(B_vec[n]) - draws[[col_logB]]) / draws[[col_sigma]]
      tibble::tibble(
        stock_idx = stock_idx,
        stock_id  = T4B_IND_STOCKS[stock_idx],
        year      = T4B_IND_WINDOW[t_obs],
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
                              levels = STOCK_LABELS[T4B_IND_STOCKS]))

  ggplot(resid_df, aes(x = year, y = r_mean)) +
    geom_hline(yintercept = 0, color = "grey40") +
    geom_hline(yintercept = c(-2, 2), linetype = "dashed", color = "red", alpha = 0.6) +
    geom_linerange(aes(ymin = r_q05, ymax = r_q95), color = "steelblue") +
    geom_point(color = "steelblue", size = 1.8) +
    facet_wrap(~ stock_lbl, scales = "free_y", ncol = 1) +
    labs(title = "(2) Residuos standardizados por stock",
         subtitle = "(log(B_obs) - log(B_smooth)) / sigma_obs, CI 90%. Jurel censored no incluido.",
         x = NULL, y = "Residuo std") +
    theme_ppc
}

# -----------------------------------------------------------------------------
# (3) Trace plots
# -----------------------------------------------------------------------------
plot_traces_ind <- function(fit) {
  vars_to_trace <- c(sprintf("r_nat[%d]", 1:3),
                     sprintf("K_nat[%d]", 1:3),
                     sprintf("sigma_proc[%d]", 1:3))

  tr <- fit$draws(vars_to_trace, format = "draws_df") %>%
    pivot_longer(all_of(vars_to_trace),
                 names_to = "param", values_to = "val") %>%
    mutate(stock_idx = as.integer(sub(".*\\[(\\d+)\\].*", "\\1", param)),
           stock_id  = T4B_IND_STOCKS[stock_idx],
           stock_lbl = STOCK_LABELS[stock_id],
           pname     = sub("\\[\\d+\\]", "", param),
           pname     = factor(pname, levels = c("r_nat", "K_nat", "sigma_proc")))

  ggplot(tr, aes(x = .iteration, y = val, color = factor(.chain))) +
    geom_line(alpha = 0.6, linewidth = 0.25) +
    facet_grid(pname ~ stock_lbl, scales = "free_y") +
    scale_color_viridis_d(name = "chain", option = "D") +
    labs(title = "(3) Trace plots por stock (post-warmup)",
         x = "iteracion", y = NULL) +
    theme_ppc +
    theme(legend.position = "bottom")
}

# -----------------------------------------------------------------------------
# Reporte numerico
# -----------------------------------------------------------------------------
report_numeric_ind <- function(fit, stan_data) {
  draws <- fit$draws(c("logB", "sigma_obs"), format = "draws_df")

  compute_tbl <- function(t_vec, B_vec, stock_idx) {
    col_sigma <- sprintf("sigma_obs[%d]", stock_idx)
    purrr::map_dfr(seq_along(t_vec), function(n) {
      t_obs <- t_vec[n]
      col_logB <- sprintf("logB[%d,%d]", t_obs, stock_idx)
      r_std <- (log(B_vec[n]) - draws[[col_logB]]) / draws[[col_sigma]]
      tibble::tibble(stock_id = T4B_IND_STOCKS[stock_idx],
                     year = T4B_IND_WINDOW[t_obs],
                     r_mean = mean(r_std))
    })
  }

  tbl <- dplyr::bind_rows(
    compute_tbl(stan_data$t_anch,    stan_data$B_obs_anch, 1),
    compute_tbl(stan_data$t_sard,    stan_data$B_obs_sard, 2),
    compute_tbl(stan_data$t_jur_unc, stan_data$B_obs_jur,  3)
  )

  cat("\n[t4b-ind-ppc] Resumen residuos std por stock:\n")
  summary_by_stock <- tbl %>%
    group_by(stock_id) %>%
    summarise(n = n(),
              mean = mean(r_mean),
              sd   = sd(r_mean),
              n_outliers_abs2 = sum(abs(r_mean) > 2),
              max_abs = max(abs(r_mean)),
              .groups = "drop")
  print(summary_by_stock)

  for (s in T4B_IND_STOCKS) {
    outl <- tbl %>%
      filter(stock_id == s, abs(r_mean) > 1.5) %>%
      arrange(desc(abs(r_mean)))
    if (nrow(outl) > 0) {
      cat(sprintf("\n  %s -- anios con |residuo| > 1.5:\n", s))
      for (i in seq_len(nrow(outl))) {
        cat(sprintf("    %d: r_std = %+.2f\n", outl$year[i], outl$r_mean[i]))
      }
    } else {
      cat(sprintf("\n  %s: ningun |residuo| > 1.5\n", s))
    }
  }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.ind.ppc.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("T4b-ind PPC multi-stock\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  L  <- ppc_ind_load_all()
  p1 <- plot_smooth_vs_obs_ind(L$fit, L$obs_df)
  p2 <- plot_residuals_ind(L$fit, L$stan_data)
  p3 <- plot_traces_ind(L$fit)

  ggsave(file.path(T4B_IND_FIG_DIR, "t4b_ind_smooth_vs_obs.png"),
         p1, width = 9, height = 10, dpi = 120)
  ggsave(file.path(T4B_IND_FIG_DIR, "t4b_ind_residuals.png"),
         p2, width = 9, height = 9, dpi = 120)
  ggsave(file.path(T4B_IND_FIG_DIR, "t4b_ind_traces.png"),
         p3, width = 11, height = 8, dpi = 120)

  report_numeric_ind(L$fit, L$stan_data)

  cat(sprintf("\n[t4b-ind-ppc] Figuras guardadas en %s/\n", T4B_IND_FIG_DIR))
  cat("Interpretacion clave: si B_smooth jurel esta ajustando como random walk\n")
  cat("(banda 90% muy amplia, siguiendo a cada obs como referencia), confirmar\n")
  cat("visualmente antes de decidir 6(c).\n")

  invisible(NULL)
}
