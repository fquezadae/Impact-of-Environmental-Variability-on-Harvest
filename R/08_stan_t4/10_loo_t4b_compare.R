# =============================================================================
# FONDECYT -- 10_loo_t4b_compare.R
#
# LOO-CV comparativa entre los tres fits T4b:
#   - t4b_ind    : 3 stocks independientes (sin Omega, sin shifters)
#   - t4b_omega  : 3 stocks + Omega LKJ(4) (sin shifters ambientales)
#   - t4b_full   : 3 stocks + Omega + shifters SST/CHL por stock
#
# Produce Delta-ELPD_loo con SE (via loo::loo_compare), y diagnosticos pareto-k
# descompuestos por stock aprovechando el orden de log_lik en el bloque
# generated quantities (anch -> sard -> jur_unc -> jur_cen).
#
# Moment-matching habilitado para todos los fits; si sigue habiendo k>0.7
# el script reporta los t indices afectados para eventual refit-sin-obs.
#
# Entradas:
#   data/outputs/t4b/t4b_{ind,omega,full}_fit.rds
#   data/outputs/t4b/t4b_{ind,omega,full}_stan_data.rds
#
# Salidas:
#   tables/loo_t4b_compare.csv            -- tabla Delta-ELPD formato paper
#   tables/loo_t4b_pareto_por_stock.csv   -- k summary por (modelo, stock)
#   tables/loo_t4b_elpd_por_stock.csv     -- ELPD por (modelo, stock)
#   data/outputs/t4b/loo_t4b_objects.rds  -- lista de objetos loo (para reuso)
#   figs/t4b/loo_t4b_pareto_k.png         -- scatter k por stock/modelo
#   figs/t4b/loo_t4b_elpd_stock.png       -- barras Delta-ELPD por stock
#
# Corre con:
#   options(t4b.loo.run_main = TRUE)
#   source("R/08_stan_t4/10_loo_t4b_compare.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readr)
  library(loo)
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
T4B_OUT_DIR <- "data/outputs/t4b"
T4B_FIG_DIR <- "figs/t4b"
TABLES_DIR  <- "tables"
dir.create(T4B_FIG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(TABLES_DIR,  recursive = TRUE, showWarnings = FALSE)

MODEL_SPECS <- list(
  ind   = list(label = "T4b-ind",   color = "#6c757d"),
  omega = list(label = "T4b-omega", color = "#1f77b4"),
  full  = list(label = "T4b-full",  color = "#d62728")
)

STOCK_LABELS <- c(anchoveta_cs    = "Anchoveta CS",
                  sardina_comun_cs = "Sardina comun CS",
                  jurel_cs        = "Jurel CS")

# -----------------------------------------------------------------------------
# Utilidades
# -----------------------------------------------------------------------------
load_fit_and_data <- function(tag) {
  fit  <- readRDS(file.path(T4B_OUT_DIR, sprintf("t4b_%s_fit.rds", tag)))
  sdat <- readRDS(file.path(T4B_OUT_DIR, sprintf("t4b_%s_stan_data.rds", tag)))

  # Los Xptr de log_prob/unconstrain_pars no sobreviven serializacion.
  # Si el exe ya fue compilado con compile_model_methods=TRUE, basta con
  # re-bindear los punteros en la sesion actual. Si no lo tiene (caso
  # omega/full antes del refit), fallara silenciosamente y $loo(moment_match)
  # activara la auto-compilacion por su cuenta.
  init_try <- tryCatch(
    {
      fit$init_model_methods(verbose = FALSE)
      TRUE
    },
    error = function(e) {
      message(sprintf("[load:%s] init_model_methods no disponible (%s); se intentara auto-compilar al llamar $loo().",
                      tag, conditionMessage(e)))
      FALSE
    }
  )
  if (isTRUE(init_try)) {
    cat(sprintf("[load:%s] init_model_methods OK tras readRDS\n", tag))
  }
  list(fit = fit, stan_data = sdat)
}

# Construye el mapa obs_index -> (stock, t, censored) usando el orden de
# log_lik en el bloque generated quantities.
#   1 .. N_obs_anch                             -> anchoveta_cs
#   N_obs_anch+1 .. +N_obs_sard                 -> sardina_comun_cs
#   +N_obs_jur_unc                              -> jurel_cs (no censurado)
#   +N_obs_jur_cen                              -> jurel_cs (censurado)
build_obs_index <- function(sdat) {
  n_a <- sdat$N_obs_anch
  n_s <- sdat$N_obs_sard
  n_ju <- sdat$N_obs_jur_unc
  n_jc <- sdat$N_obs_jur_cen
  tibble::tibble(
    obs_id   = seq_len(n_a + n_s + n_ju + n_jc),
    stock    = c(rep("anchoveta_cs", n_a),
                 rep("sardina_comun_cs", n_s),
                 rep("jurel_cs", n_ju + n_jc)),
    t_idx    = c(sdat$t_anch, sdat$t_sard, sdat$t_jur_unc, sdat$t_jur_cen),
    censored = c(rep(FALSE, n_a + n_s + n_ju), rep(TRUE, n_jc))
  )
}

# cmdstanr >=0.7: $loo() incorpora relative_eff y soporta moment_match.
# Si MM falla para un fit (tipico cuando el rds se guardo sin methods
# compilables), imprimimos el error antes de caer al loo() sin MM para que
# se vea por que se perdio el moment matching.
safe_fit_loo <- function(fit, moment_match = TRUE, tag = "?") {
  out <- tryCatch(
    fit$loo(moment_match = moment_match, save_psis = FALSE),
    error = function(e) {
      message(sprintf("[loo:%s] MM fallo. Mensaje: %s", tag, conditionMessage(e)))
      NULL
    }
  )
  if (is.null(out)) {
    message(sprintf("[loo:%s] fallback a loo() manual SIN moment-matching.", tag))
    ll_arr <- fit$draws("log_lik", format = "draws_array")
    r_eff <- loo::relative_eff(exp(ll_arr))
    out <- loo::loo(ll_arr, r_eff = r_eff)
    attr(out, "moment_match") <- FALSE
  } else {
    attr(out, "moment_match") <- TRUE
  }
  out
}

# PSIS-LOO restringido a un subconjunto de obs (sliced por stock).
slice_loo <- function(fit, obs_ids) {
  ll_arr <- fit$draws("log_lik", format = "draws_array")[ , , obs_ids, drop = FALSE]
  r_eff <- loo::relative_eff(exp(ll_arr))
  loo::loo(ll_arr, r_eff = r_eff)
}

# -----------------------------------------------------------------------------
# 1. LOO global por modelo + diagnostico pareto-k + ELPD por stock
# -----------------------------------------------------------------------------
compute_loo_all <- function() {
  tags <- names(MODEL_SPECS)
  loo_objs     <- list()
  stan_datas   <- list()
  obs_indices  <- list()
  k_tables     <- list()
  elpd_stock   <- list()

  for (tag in tags) {
    cat(sprintf("\n[loo] ===== %s =====\n", MODEL_SPECS[[tag]]$label))
    fd   <- load_fit_and_data(tag)
    fit  <- fd$fit
    sdat <- fd$stan_data
    obs_idx <- build_obs_index(sdat)

    # --- LOO global ---
    lo <- safe_fit_loo(fit, moment_match = TRUE, tag = tag)
    mm_used <- isTRUE(attr(lo, "moment_match"))
    cat(sprintf("[loo:%s] moment_match aplicado: %s\n",
                tag, if (mm_used) "SI" else "NO (resultados poco confiables si hay k>0.7)"))
    print(lo)
    loo_objs[[tag]]     <- lo
    stan_datas[[tag]]   <- sdat
    obs_indices[[tag]]  <- obs_idx

    # --- Pareto-k por obs, mapeado a stock/ano ---
    pk <- lo$diagnostics$pareto_k
    stopifnot(length(pk) == nrow(obs_idx))
    year_start <- min(sdat$t_anch, sdat$t_sard, sdat$t_jur_unc, sdat$t_jur_cen)
    # t_idx es un indice dentro de la ventana; la ventana arranca en 2000
    # (ver 08_fit_t4b_full.R T4B_FULL_WINDOW).
    k_tables[[tag]] <- obs_idx %>%
      dplyr::mutate(model    = MODEL_SPECS[[tag]]$label,
                    year     = 1999L + t_idx,    # ventana 2000-2024
                    pareto_k = pk,
                    k_bin    = cut(pk,
                                   breaks = c(-Inf, 0.5, 0.7, 1.0, Inf),
                                   labels = c("<=0.5", "(0.5, 0.7]",
                                              "(0.7, 1.0]", ">1.0"),
                                   right  = TRUE))

    # --- ELPD por stock (refit PSIS sobre subconjunto) ---
    stk_out <- list()
    for (stk in unique(obs_idx$stock)) {
      ids <- obs_idx$obs_id[obs_idx$stock == stk]
      lo_s <- slice_loo(fit, ids)
      stk_out[[stk]] <- tibble::tibble(
        model      = MODEL_SPECS[[tag]]$label,
        stock      = stk,
        n_obs      = length(ids),
        elpd_loo   = lo_s$estimates["elpd_loo", "Estimate"],
        se_elpd    = lo_s$estimates["elpd_loo", "SE"],
        p_loo      = lo_s$estimates["p_loo",    "Estimate"],
        n_k_gt_07  = sum(lo_s$diagnostics$pareto_k > 0.7, na.rm = TRUE),
        n_k_gt_10  = sum(lo_s$diagnostics$pareto_k > 1.0, na.rm = TRUE)
      )
    }
    elpd_stock[[tag]] <- dplyr::bind_rows(stk_out)
  }

  list(loo_objs    = loo_objs,
       stan_datas  = stan_datas,
       obs_indices = obs_indices,
       k_tables    = dplyr::bind_rows(k_tables),
       elpd_stock  = dplyr::bind_rows(elpd_stock))
}

# -----------------------------------------------------------------------------
# 2. Tabla comparativa Delta-ELPD_loo (formato paper)
# -----------------------------------------------------------------------------
make_compare_table <- function(loo_objs) {
  names(loo_objs) <- vapply(names(loo_objs),
                            function(t) MODEL_SPECS[[t]]$label,
                            character(1))
  cmp <- loo::loo_compare(loo_objs)
  # loo_compare ordena de mejor a peor; el mejor tiene elpd_diff == 0.
  # Lo exportamos con columnas clave.
  out <- as.data.frame(cmp) %>%
    tibble::rownames_to_column("model") %>%
    dplyr::select(model, elpd_diff, se_diff, elpd_loo, se_elpd_loo,
                  p_loo, looic) %>%
    dplyr::mutate(dplyr::across(-model, ~ round(.x, 2)))
  out
}

# -----------------------------------------------------------------------------
# 3. Figuras
# -----------------------------------------------------------------------------
plot_pareto_k <- function(k_tbl) {
  k_tbl <- k_tbl %>%
    dplyr::mutate(stock_lab = STOCK_LABELS[stock],
                  model = factor(model,
                                 levels = vapply(MODEL_SPECS,
                                                 function(x) x$label,
                                                 character(1))))
  model_colors <- setNames(
    vapply(MODEL_SPECS, function(x) x$color, character(1)),
    vapply(MODEL_SPECS, function(x) x$label, character(1))
  )
  p <- ggplot(k_tbl, aes(x = year, y = pareto_k, color = model, shape = censored)) +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey50") +
    geom_hline(yintercept = 0.7, linetype = "solid",  color = "grey40") +
    geom_point(size = 2.2, alpha = 0.85) +
    scale_color_manual(values = model_colors, name = NULL) +
    scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 4),
                       labels = c(`FALSE` = "observada", `TRUE` = "censurada"),
                       name = NULL) +
    facet_wrap(~ stock_lab, ncol = 1, scales = "free_y") +
    labs(x = NULL, y = expression("Pareto-" * hat(k))) +
    theme_bw(base_size = 11) +
    theme(legend.position = "bottom",
          panel.grid.minor = element_blank(),
          strip.background = element_rect(fill = "grey95", color = NA))
  p
}

plot_elpd_stock <- function(elpd_tbl) {
  # Delta respecto al modelo de referencia (el que gane loo_compare global).
  # Simpler: tomar T4b-ind como baseline (mas parsimonioso) y mostrar delta.
  base_label <- MODEL_SPECS$ind$label
  baseline <- elpd_tbl %>%
    dplyr::filter(model == base_label) %>%
    dplyr::select(stock, elpd_base = elpd_loo)
  d <- elpd_tbl %>%
    dplyr::left_join(baseline, by = "stock") %>%
    dplyr::mutate(
      delta    = elpd_loo - elpd_base,
      se_delta = se_elpd,  # aprox; SE exacto requiere pointwise
      stock_lab = STOCK_LABELS[stock],
      model = factor(model,
                     levels = vapply(MODEL_SPECS,
                                     function(x) x$label,
                                     character(1)))
    ) %>%
    dplyr::filter(model != base_label)
  model_colors <- setNames(
    vapply(MODEL_SPECS, function(x) x$color, character(1)),
    vapply(MODEL_SPECS, function(x) x$label, character(1))
  )
  ggplot(d, aes(x = stock_lab, y = delta, fill = model)) +
    geom_hline(yintercept = 0, color = "grey40") +
    geom_col(position = position_dodge(width = 0.7), width = 0.6) +
    geom_errorbar(aes(ymin = delta - se_delta, ymax = delta + se_delta),
                  position = position_dodge(width = 0.7),
                  width = 0.15, color = "grey30") +
    scale_fill_manual(values = model_colors, name = NULL) +
    labs(x = NULL,
         y = expression(Delta * "ELPD"[loo] * " vs T4b-ind")) +
    theme_bw(base_size = 11) +
    theme(legend.position = "bottom",
          panel.grid.minor = element_blank())
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("t4b.loo.run_main", FALSE))) {

  cat(strrep("=", 70), "\n", sep = "")
  cat("LOO-CV comparativa T4b-ind vs T4b-omega vs T4b-full\n")
  cat(strrep("=", 70), "\n", sep = "")

  res <- compute_loo_all()

  # Tabla global Delta-ELPD
  cmp_tbl <- make_compare_table(res$loo_objs)
  cat("\n[loo] loo_compare (ordenado mejor -> peor):\n")
  print(cmp_tbl)
  readr::write_csv(cmp_tbl, file.path(TABLES_DIR, "loo_t4b_compare.csv"))

  # Pareto-k por stock (tabla)
  k_summary <- res$k_tables %>%
    dplyr::group_by(model, stock) %>%
    dplyr::summarise(
      n_obs       = dplyr::n(),
      k_max       = max(pareto_k, na.rm = TRUE),
      k_median    = median(pareto_k, na.rm = TRUE),
      n_k_gt_05   = sum(pareto_k > 0.5, na.rm = TRUE),
      n_k_gt_07   = sum(pareto_k > 0.7, na.rm = TRUE),
      n_k_gt_10   = sum(pareto_k > 1.0, na.rm = TRUE),
      .groups     = "drop"
    ) %>%
    dplyr::mutate(stock = STOCK_LABELS[stock]) %>%
    dplyr::arrange(stock, model)
  cat("\n[loo] Pareto-k por (modelo, stock):\n")
  print(k_summary, n = 20)
  readr::write_csv(k_summary,
                   file.path(TABLES_DIR, "loo_t4b_pareto_por_stock.csv"))

  # ELPD por stock (tabla)
  elpd_tbl <- res$elpd_stock %>%
    dplyr::mutate(stock_lab = STOCK_LABELS[stock]) %>%
    dplyr::arrange(stock_lab, model)
  cat("\n[loo] ELPD por (modelo, stock):\n")
  print(elpd_tbl, n = 20)
  readr::write_csv(elpd_tbl,
                   file.path(TABLES_DIR, "loo_t4b_elpd_por_stock.csv"))

  # Objetos loo para reuso (paper, ppc, etc.)
  saveRDS(res$loo_objs,
          file.path(T4B_OUT_DIR, "loo_t4b_objects.rds"))

  # Figuras
  p_k <- plot_pareto_k(res$k_tables)
  ggsave(file.path(T4B_FIG_DIR, "loo_t4b_pareto_k.png"),
         p_k, width = 7.2, height = 7.8, dpi = 300)

  p_e <- plot_elpd_stock(res$elpd_stock)
  ggsave(file.path(T4B_FIG_DIR, "loo_t4b_elpd_stock.png"),
         p_e, width = 7.2, height = 4.0, dpi = 300)

  # --- Advertencias utiles para el paper ---
  cat("\n[loo] Observaciones con pareto-k > 0.7 (refit candidato):\n")
  bad <- res$k_tables %>%
    dplyr::filter(pareto_k > 0.7) %>%
    dplyr::arrange(dplyr::desc(pareto_k))
  if (nrow(bad) == 0) {
    cat("  ninguna. PSIS-LOO confiable en los tres modelos.\n")
  } else {
    print(bad, n = 40)
    cat("\n  -> Considerar K-fold (k=5) para validar el ranking si\n",
        "     persisten k>0.7 tras moment-matching.\n", sep = "")
  }

  invisible(res)
}
