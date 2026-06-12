# =============================================================================
# FONDECYT -- 11_lfo_t4b_compare.R
#
# Leave-Future-Out (LFO) CV 1-step-ahead para los tres fits T4b. Robustness
# check complementario a PSIS-LOO del 10_loo_t4b_compare.R, pensado para
# el appendix del paper 1. LFO es la forma canonica de validar modelos
# temporales porque evita el p_loo inflado del estado-espacio y evalua
# prediccion genuinamente out-of-sample.
#
# Diseno:
#   - Horizonte h=1 (predecir el ano t+1 dado y_{1:t}).
#   - 5 puntos de origen t_cut en {2011, 2014, 2017, 2020, 2022}, con
#     target years {2012, 2015, 2018, 2021, 2023}. La predicion para
#     jurel en 2012 y 2015 es CENSURADA (log normal_lcdf), se reporta
#     aparte. Cubre ~50% de la ventana temporal 2000-2024, suficiente
#     para cuantificar drift entre modelos.
#   - Para cada (modelo, t_cut): refit corto (4 chains, 1500 warmup + 1500
#     iter, ~2-3 min). Extrae draws de (r_base, log_K, sigma_proc, sigma_obs,
#     logB[t_cut,:]) mas (rho_sst, rho_chl) si full. Aplica la dinamica
#     Schaefer-log del .stan en R por draw, calcula la predictiva marginal
#     1-step-ahead p(y_{t_cut+1, s} | theta, y_{1:t_cut}) via formula
#     cerrada normal(logB_mean_{t+1}, sqrt(sigma_proc^2 + sigma_obs^2)).
#   - ELPD_LFO_{t_cut+1, s} = logSumExp(log_pred_draws) - log(n_draws).
#   - Agrega sobre (t_cut, s) para cada modelo y compara.
#
# Nota: la correlacion cross-stock (Omega) no entra en la marginal por obs
# univariada, solo en la conjunta. Consistente con como log_lik se definio
# en el .stan (por-obs, no conjunta).
#
# Tiempo total esperado: 5 cutoffs x 3 modelos = 15 refits x ~2-4 min =
# 30-60 minutos en laptop moderno. Lanzable overnight sin supervision.
#
# Salidas:
#   tables/lfo_t4b_compare.csv        -- ELPD_LFO por modelo (agregado)
#   tables/lfo_t4b_by_stock.csv       -- ELPD_LFO por (modelo, stock, year)
#   figs/t4b/lfo_t4b_elpd_path.png    -- trayectoria ELPD_LFO por cutoff
#
# Corre con:
#   options(t4b.lfo.run_main = TRUE)
#   source("R/08_stan_t4/11_lfo_t4b_compare.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readr)
  library(posterior)
  library(cmdstanr)
  library(matrixStats)  # logSumExp
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
# Configuracion
# -----------------------------------------------------------------------------
LFO_CUTOFFS      <- c(2011L, 2014L, 2017L, 2020L, 2022L)
LFO_WINDOW_START <- 2000L
LFO_OUT_DIR      <- "data/outputs/t4b"
LFO_FIG_DIR      <- "figs/t4b"
LFO_TABLES_DIR   <- "tables"
dir.create(LFO_FIG_DIR,    recursive = TRUE, showWarnings = FALSE)
dir.create(LFO_TABLES_DIR, recursive = TRUE, showWarnings = FALSE)

LFO_MODELS <- list(
  ind = list(
    label         = "T4b-ind",
    color         = "#6c757d",
    stan_file     = "paper1/stan/t4b_state_space_ind.stan",
    stan_data_rds = "data/outputs/t4b/t4b_ind_stan_data.rds",
    has_shifters  = FALSE,
    r_var_name    = "r_"       # ind usa "r_" (underscore)
  ),
  omega = list(
    label         = "T4b-omega",
    color         = "#1f77b4",
    stan_file     = "paper1/stan/t4b_state_space_omega.stan",
    stan_data_rds = "data/outputs/t4b/t4b_omega_stan_data.rds",
    has_shifters  = FALSE,
    r_var_name    = "r_"       # omega tambien usa "r_"
  ),
  full = list(
    label         = "T4b-full",
    color         = "#d62728",
    stan_file     = "paper1/stan/t4b_state_space_full.stan",
    stan_data_rds = "data/outputs/t4b/t4b_full_stan_data.rds",
    has_shifters  = TRUE,
    r_var_name    = "r_base"   # full usa "r_base"
  )
)

LFO_FIT <- list(
  chains          = 4,
  parallel_chains = 4,
  iter_warmup     = 1500,
  iter_sampling   = 1500,
  adapt_delta     = 0.99,
  max_treedepth   = 14,
  seed            = 2026L,
  refresh         = 500
)

STOCK_LABELS <- c(anchoveta_cs     = "Anchoveta CS",
                  sardina_comun_cs = "Sardina comun CS",
                  jurel_cs         = "Jurel CS")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
truncate_stan_data <- function(sdat, T_cut) {
  stopifnot(T_cut >= 2L, T_cut <= sdat$T)

  filter_obs <- function(t_vec, B_vec) {
    keep <- t_vec <= T_cut
    list(t = as.integer(t_vec[keep]),
         B = B_vec[keep],
         N = as.integer(sum(keep)))
  }
  a  <- filter_obs(sdat$t_anch,    sdat$B_obs_anch)
  s_ <- filter_obs(sdat$t_sard,    sdat$B_obs_sard)
  jU <- filter_obs(sdat$t_jur_unc, sdat$B_obs_jur)

  if (isTRUE(sdat$N_obs_jur_cen > 0L)) {
    keep_jc <- sdat$t_jur_cen <= T_cut
    t_jc <- as.integer(sdat$t_jur_cen[keep_jc])
    n_jc <- as.integer(sum(keep_jc))
  } else {
    t_jc <- integer(0); n_jc <- 0L
  }

  out <- sdat
  out$T <- as.integer(T_cut)
  out$C <- sdat$C[1:T_cut, , drop = FALSE]
  if (!is.null(sdat$SST_c))    out$SST_c    <- sdat$SST_c[1:T_cut]
  if (!is.null(sdat$logCHL_c)) out$logCHL_c <- sdat$logCHL_c[1:T_cut]

  out$N_obs_anch    <- a$N;  out$t_anch    <- a$t;  out$B_obs_anch <- a$B
  out$N_obs_sard    <- s_$N; out$t_sard    <- s_$t; out$B_obs_sard <- s_$B
  out$N_obs_jur_unc <- jU$N; out$t_jur_unc <- jU$t; out$B_obs_jur  <- jU$B
  out$N_obs_jur_cen <- n_jc; out$t_jur_cen <- t_jc

  # Stan tiene <lower=1> en N_obs_anch y N_obs_sard -- si algun stock queda
  # vacio por truncar demasiado, avisar.
  if (a$N < 1 || s_$N < 1 || jU$N < 1) {
    stop(sprintf("Truncacion a T_cut=%d deja algun stock sin obs: anch=%d, sard=%d, jur_unc=%d",
                 T_cut, a$N, s_$N, jU$N))
  }

  out
}

fit_short <- function(mod, stan_data) {
  mod$sample(
    data            = stan_data,
    chains          = LFO_FIT$chains,
    parallel_chains = LFO_FIT$parallel_chains,
    iter_warmup     = LFO_FIT$iter_warmup,
    iter_sampling   = LFO_FIT$iter_sampling,
    adapt_delta     = LFO_FIT$adapt_delta,
    max_treedepth   = LFO_FIT$max_treedepth,
    seed            = LFO_FIT$seed,
    refresh         = LFO_FIT$refresh
  )
}

# Schaefer-step en log-space, replicando schaefer_step_log() del .stan
schaefer_step_log_R <- function(logB_prev, K, r_t, C_prev) {
  B_prev <- exp(logB_prev)
  g      <- r_t * B_prev * (1 - B_prev / K)
  B_next <- B_prev + g - C_prev
  floor_ <- 0.01 * K
  log(pmax(floor_, B_next))
}

# 1-step-ahead marginal predictive density a partir de los draws del fit
# truncado a y_{1:T_cut}, evaluada sobre las obs del ano T_cut+1.
compute_lfo_1step <- function(fit, sdat_full, T_cut, model_tag) {
  cfg <- LFO_MODELS[[model_tag]]
  r_var <- cfg$r_var_name

  vars <- c(r_var, "log_K", "sigma_proc", "sigma_obs")
  if (cfg$has_shifters) vars <- c(vars, "rho_sst", "rho_chl")

  logB_vars <- sprintf("logB[%d,%d]", T_cut, 1:3)

  draws_params <- posterior::as_draws_matrix(fit$draws(vars))
  draws_logB   <- posterior::as_draws_matrix(fit$draws(logB_vars))

  n_draws <- nrow(draws_params)
  S <- 3L

  get_vec <- function(nm, D) {
    cols <- paste0(nm, "[", 1:S, "]")
    mat  <- as.matrix(D[, cols, drop = FALSE])
    storage.mode(mat) <- "double"
    mat  # [n_draws, S]
  }
  r_base     <- get_vec(r_var,        draws_params)
  log_K      <- get_vec("log_K",      draws_params)
  K          <- exp(log_K)
  sigma_proc <- get_vec("sigma_proc", draws_params)
  sigma_obs  <- get_vec("sigma_obs",  draws_params)

  if (cfg$has_shifters) {
    rho_sst <- get_vec("rho_sst", draws_params)
    rho_chl <- get_vec("rho_chl", draws_params)
    SST_lag    <- sdat_full$SST_c[T_cut]      # ambiente del ano T_cut
    logCHL_lag <- sdat_full$logCHL_c[T_cut]
    r_eff <- r_base * exp(rho_sst * SST_lag + rho_chl * logCHL_lag)
  } else {
    r_eff <- r_base
  }

  # logB[T_cut, :] por draw
  logB_T <- as.matrix(draws_logB[, logB_vars, drop = FALSE])
  storage.mode(logB_T) <- "double"

  # Captura del ano T_cut (para Schaefer step T_cut -> T_cut+1)
  C_T_cut <- sdat_full$C[T_cut, ]  # vector length S

  # logB_mean_{T_cut+1, s} por draw y por stock
  logB_mean_next <- matrix(NA_real_, nrow = n_draws, ncol = S)
  for (s in 1:S) {
    logB_mean_next[, s] <- schaefer_step_log_R(
      logB_prev = logB_T[, s],
      K         = K[, s],
      r_t       = r_eff[, s],
      C_prev    = C_T_cut[s]
    )
  }

  # Desviacion predictiva marginal por stock
  sd_pred <- sqrt(sigma_proc^2 + sigma_obs^2)

  # Targets: obs del ano T_target (T_cut+1) por stock
  T_target <- T_cut + 1L
  year_target <- T_target + (LFO_WINDOW_START - 1L)

  pick_target <- function(stock_name, t_vec, B_vec, stock_idx, censored = FALSE) {
    hit <- match(T_target, t_vec)
    if (is.na(hit)) return(NULL)
    if (!censored) {
      log_y <- log(B_vec[hit])
    } else {
      log_y <- log(sdat_full$B_censor_limit_jurel)
    }
    list(stock = stock_name, stock_idx = stock_idx, log_y = log_y,
         censored = censored)
  }

  targets <- Filter(Negate(is.null), list(
    pick_target("anchoveta_cs",     sdat_full$t_anch,    sdat_full$B_obs_anch, 1L),
    pick_target("sardina_comun_cs", sdat_full$t_sard,    sdat_full$B_obs_sard, 2L),
    pick_target("jurel_cs",         sdat_full$t_jur_unc, sdat_full$B_obs_jur,  3L),
    pick_target("jurel_cs",         sdat_full$t_jur_cen, numeric(0),           3L,
                censored = TRUE)
  ))

  out <- list()
  for (tg in targets) {
    s <- tg$stock_idx
    logmean_s <- logB_mean_next[, s]
    sd_s      <- sd_pred[, s]
    if (!tg$censored) {
      log_pred <- dnorm(tg$log_y, mean = logmean_s, sd = sd_s, log = TRUE)
    } else {
      log_pred <- pnorm(tg$log_y, mean = logmean_s, sd = sd_s, log.p = TRUE)
    }
    # ELPD marginal (Monte Carlo de la predictive mixture)
    elpd <- matrixStats::logSumExp(log_pred) - log(length(log_pred))
    out[[length(out) + 1]] <- tibble::tibble(
      model     = model_tag,
      T_cut     = T_cut,
      year      = year_target,
      stock     = tg$stock,
      censored  = tg$censored,
      log_y     = tg$log_y,
      elpd_lfo  = elpd,
      n_draws   = length(log_pred),
      lp_min    = min(log_pred),
      lp_max    = max(log_pred)
    )
  }
  dplyr::bind_rows(out)
}

# -----------------------------------------------------------------------------
# Loop principal
# -----------------------------------------------------------------------------
run_lfo_all <- function() {
  all_elpd <- list()
  fit_diag <- list()

  for (tag in names(LFO_MODELS)) {
    cfg <- LFO_MODELS[[tag]]
    cat(sprintf("\n========================================\n[LFO] %s\n========================================\n",
                cfg$label))

    mod <- cmdstanr::cmdstan_model(cfg$stan_file)   # usa exe cacheado
    sdat_full <- readRDS(cfg$stan_data_rds)

    for (yr in LFO_CUTOFFS) {
      T_cut <- as.integer(yr - LFO_WINDOW_START + 1L)
      stopifnot(T_cut >= 2L, T_cut <= sdat_full$T - 1L)

      cat(sprintf("\n[LFO:%s] t_cut = %d (T_cut = %d)\n", tag, yr, T_cut))
      sdat_trunc <- truncate_stan_data(sdat_full, T_cut)
      t0 <- Sys.time()
      fit <- fit_short(mod, sdat_trunc)
      dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
      cat(sprintf("[LFO:%s] fit done en %.1f s\n", tag, dt))

      # Diagnostico rapido
      d <- fit$diagnostic_summary()
      fit_diag[[length(fit_diag) + 1]] <- tibble::tibble(
        model       = tag, T_cut = T_cut, year_cut = yr,
        num_divergent = sum(d$num_divergent %||% 0L),
        num_max_treedepth = sum(d$num_max_treedepth %||% 0L),
        ebfmi_min = if (!is.null(d$ebfmi)) min(d$ebfmi, na.rm = TRUE) else NA_real_,
        fit_sec = dt
      )

      elpd_df <- compute_lfo_1step(fit, sdat_full, T_cut, tag)
      all_elpd[[length(all_elpd) + 1]] <- elpd_df

      rm(fit); gc(verbose = FALSE)
    }
  }

  list(elpd = dplyr::bind_rows(all_elpd),
       diag = dplyr::bind_rows(fit_diag))
}

# Helper: coalesce
`%||%` <- function(a, b) if (is.null(a)) b else a

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.lfo.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("LFO-CV 1-step T4b-ind vs T4b-omega vs T4b-full\n")
  cat(sprintf("Cutoffs: %s -> targets %s\n",
              paste(LFO_CUTOFFS, collapse = ", "),
              paste(LFO_CUTOFFS + 1L, collapse = ", ")))
  cat(strrep("=", 70), "\n\n", sep = "")

  res <- run_lfo_all()

  # --- Por-obs table ---
  elpd_obs <- res$elpd %>%
    dplyr::mutate(
      model_label = vapply(model, function(t) LFO_MODELS[[t]]$label, character(1)),
      stock_label = STOCK_LABELS[stock]
    )
  readr::write_csv(elpd_obs, file.path(LFO_TABLES_DIR, "lfo_t4b_by_stock.csv"))
  cat("\n[LFO] ELPD_LFO por (modelo, cutoff, stock):\n")
  print(elpd_obs %>%
          dplyr::select(model_label, year, stock_label, censored, elpd_lfo) %>%
          dplyr::arrange(year, stock_label, model_label),
        n = 60)

  # --- Agregado por modelo ---
  elpd_agg <- elpd_obs %>%
    dplyr::group_by(model, model_label) %>%
    dplyr::summarise(
      n_points      = dplyr::n(),
      n_censored    = sum(censored),
      elpd_lfo_sum  = sum(elpd_lfo),
      elpd_lfo_mean = mean(elpd_lfo),
      .groups       = "drop"
    ) %>%
    dplyr::arrange(dplyr::desc(elpd_lfo_sum))

  # Diff vs mejor modelo
  best <- elpd_agg$elpd_lfo_sum[1]
  elpd_agg <- elpd_agg %>%
    dplyr::mutate(elpd_diff = elpd_lfo_sum - best)

  readr::write_csv(elpd_agg, file.path(LFO_TABLES_DIR, "lfo_t4b_compare.csv"))
  cat("\n[LFO] ELPD_LFO agregado (ordenado mejor -> peor):\n")
  print(elpd_agg)

  # --- Diagnosticos fit por cutoff ---
  cat("\n[LFO] Diagnosticos fits cortos por (modelo, cutoff):\n")
  print(res$diag, n = 30)

  # --- Figura: trayectoria ELPD_LFO por cutoff y modelo ---
  model_colors <- setNames(
    vapply(LFO_MODELS, function(x) x$color, character(1)),
    vapply(LFO_MODELS, function(x) x$label, character(1))
  )

  p <- ggplot(elpd_obs %>% dplyr::filter(!censored),
              aes(x = year, y = elpd_lfo, color = model_label,
                  group = model_label)) +
    geom_hline(yintercept = 0, color = "grey60", linetype = "dashed") +
    geom_line(alpha = 0.7, linewidth = 0.8) +
    geom_point(size = 2.4) +
    scale_color_manual(values = model_colors, name = NULL) +
    facet_wrap(~ stock_label, ncol = 1, scales = "free_y") +
    labs(x = "Target year (t_cut + 1)",
         y = expression("ELPD"[LFO]^{(1)})) +
    theme_bw(base_size = 11) +
    theme(legend.position = "bottom",
          panel.grid.minor = element_blank(),
          strip.background = element_rect(fill = "grey95", color = NA))

  ggsave(file.path(LFO_FIG_DIR, "lfo_t4b_elpd_path.png"),
         p, width = 7.2, height = 7.8, dpi = 300)

  cat(sprintf("\n[LFO] Listo. Tablas en %s/, figura en %s/\n",
              LFO_TABLES_DIR, LFO_FIG_DIR))

  invisible(res)
}
