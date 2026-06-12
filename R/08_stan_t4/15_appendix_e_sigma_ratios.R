# =============================================================================
# FONDECYT -- 15_appendix_e_sigma_ratios.R
#
# Apendice E del paper 1: tabla de razones sigma_post / sigma_prior para los
# shifters ambientales rho_sst[s] y rho_chl[s], s in {anchoveta, sardina, jurel},
# en cada uno de los 3 dominios anidados.
#
# Outcome principal del Apendice E:
#   rho_jurel ratios deben quedar cerca de 1.0 (no informacion en data) en los
#   3 dominios. Si estan cerca de 1.0 en D1/D2/D3 -> claim "non-id estructural"
#   robusto. Si caen <~ 0.7 en D3 -> reframe a "non-id en EEZ Centro-Sur".
#
# Para anchoveta y sardina: ratios deben ser bastante < 1 (data informativa)
# y consistentes entre dominios. Cualquier inversion de signo entre dominios
# es bandera roja para mencionar.
#
# Inputs:
#   - data/outputs/t4b/t4b_full_appE_<domain>_summary.csv   (3 archivos)
#   - data/outputs/t4b/t4b_full_summary.csv                  (fit principal)
#
# Outputs:
#   - tables/appendix_e_sigma_ratios.csv
#       columns: domain, stock, shifter, sigma_prior, sigma_post, ratio,
#                mean_post, q5, q95
#   - tables/appendix_e_sigma_ratios_wide.csv  (formato tabla paper-ready)
#   - figs/appendix_e_sigma_ratios.pdf         (forest plot opcional)
#   - tables/appendix_e_diagnostics.csv        (rhat, ess de los rho)
#
# Corre:
#   options(appE.sigma.run_main = TRUE)
#   source("R/08_stan_t4/15_appendix_e_sigma_ratios.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(ggplot2)
})

APP_E_T4B_OUT  <- "data/outputs/t4b"
APP_E_TBL_DIR  <- "tables"
APP_E_FIG_DIR  <- "figs"
dir.create(APP_E_TBL_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(APP_E_FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# Priors usados en t4b_full (T4B_FULL_RHO_*_SD = 1.0 para los 3 stocks);
# hardcodeo aqui para no depender del source del fit principal y para
# documentar explicitamente el denominador.
PRIOR_SD_RHO <- tibble::tribble(
  ~stock,            ~shifter, ~sigma_prior,
  "anchoveta_cs",    "rho_sst", 1.0,
  "sardina_comun_cs","rho_sst", 1.0,
  "jurel_cs",        "rho_sst", 1.0,
  "anchoveta_cs",    "rho_chl", 1.0,
  "sardina_comun_cs","rho_chl", 1.0,
  "jurel_cs",        "rho_chl", 1.0,
)

STOCK_INDEX <- c("1" = "anchoveta_cs",
                 "2" = "sardina_comun_cs",
                 "3" = "jurel_cs")

APP_E_DOMAINS_ORDER <- c("centro_sur_eez", "offshore_ext", "se_pacific")

# -----------------------------------------------------------------------------
# Helper: extraer rho_* de un summary csv
# -----------------------------------------------------------------------------
extract_rho_rows <- function(summary_path, domain_label) {
  if (!file.exists(summary_path)) {
    stop("No existe summary: ", summary_path)
  }
  smry <- readr::read_csv(summary_path, show_col_types = FALSE)
  rho <- smry %>%
    dplyr::filter(stringr::str_detect(variable, "^rho_(sst|chl)\\[\\d+\\]$")) %>%
    dplyr::transmute(
      domain   = domain_label,
      shifter  = stringr::str_extract(variable, "rho_(sst|chl)"),
      idx      = stringr::str_extract(variable, "\\d+"),
      stock    = unname(STOCK_INDEX[idx]),
      mean_post = mean,
      sd_post   = sd,
      q5,
      q95,
      rhat,
      ess_bulk
    ) %>%
    dplyr::select(-idx)
  rho
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("appE.sigma.run_main", TRUE))) {
  cat(strrep("=", 72), "\n", sep = "")
  cat("Apendice E -- tabla sigma_post / sigma_prior\n")
  cat(strrep("=", 72), "\n\n", sep = "")

  # Preflight: verificar que los 3 fits del Apendice E existen antes de empezar
  missing <- character()
  for (d in APP_E_DOMAINS_ORDER) {
    p <- file.path(APP_E_T4B_OUT, sprintf("t4b_full_appE_%s_summary.csv", d))
    if (!file.exists(p)) missing <- c(missing, p)
  }
  if (length(missing) > 0) {
    stop("[appE-sigma] Faltan summaries del Apendice E (",
         length(missing), "/", length(APP_E_DOMAINS_ORDER), "):\n  ",
         paste(missing, collapse = "\n  "),
         "\nCorre primero R/08_stan_t4/14_refit_t4b_full_appendix_e.R")
  }

  rows <- list()

  # Fit principal (referencia operativa, EnvCoastDaily Centro-Sur EEZ)
  main_path <- file.path(APP_E_T4B_OUT, "t4b_full_summary.csv")
  if (file.exists(main_path)) {
    rows[["main_envcoast"]] <- extract_rho_rows(main_path, "main_envcoast")
  } else {
    warning("No esta el fit principal en ", main_path, " -- omitido")
  }

  # Apendice E -- 3 dominios
  for (d in APP_E_DOMAINS_ORDER) {
    p <- file.path(APP_E_T4B_OUT, sprintf("t4b_full_appE_%s_summary.csv", d))
    rows[[d]] <- extract_rho_rows(p, d)
  }

  long <- dplyr::bind_rows(rows) %>%
    dplyr::left_join(PRIOR_SD_RHO, by = c("stock", "shifter")) %>%
    dplyr::mutate(ratio = sd_post / sigma_prior) %>%
    dplyr::transmute(
      domain, stock, shifter,
      sigma_prior, sigma_post = sd_post, ratio,
      mean_post, q5, q95,
      rhat, ess_bulk
    ) %>%
    dplyr::arrange(
      factor(domain, levels = c("main_envcoast", APP_E_DOMAINS_ORDER)),
      factor(stock,  levels = c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")),
      shifter
    )

  out_long <- file.path(APP_E_TBL_DIR, "appendix_e_sigma_ratios.csv")
  readr::write_csv(long, out_long)
  cat(sprintf("[appE-sigma] Escribi: %s  (%d filas)\n", out_long, nrow(long)))

  # Tabla paper-ready -- una fila por (stock, shifter), columnas por dominio
  wide <- long %>%
    dplyr::mutate(cell = sprintf("%.3f / %.3f (%.2f)",
                                 sigma_post, sigma_prior, ratio)) %>%
    dplyr::select(stock, shifter, domain, cell) %>%
    tidyr::pivot_wider(names_from = domain, values_from = cell) %>%
    dplyr::arrange(factor(stock,  levels = c("anchoveta_cs", "sardina_comun_cs", "jurel_cs")),
                   shifter)
  out_wide <- file.path(APP_E_TBL_DIR, "appendix_e_sigma_ratios_wide.csv")
  readr::write_csv(wide, out_wide)
  cat(sprintf("[appE-sigma] Escribi: %s\n", out_wide))

  # Diagnosticos: rhat, ess
  diag <- long %>%
    dplyr::group_by(domain) %>%
    dplyr::summarise(
      max_rhat   = max(rhat, na.rm = TRUE),
      min_ess    = min(ess_bulk, na.rm = TRUE),
      n_rho_bad  = sum(rhat > 1.01 | ess_bulk < 400, na.rm = TRUE),
      .groups = "drop"
    )
  out_diag <- file.path(APP_E_TBL_DIR, "appendix_e_diagnostics.csv")
  readr::write_csv(diag, out_diag)
  cat(sprintf("[appE-sigma] Escribi: %s\n", out_diag))

  # Forest plot
  long_pl <- long %>%
    dplyr::filter(domain != "main_envcoast") %>%
    dplyr::mutate(
      domain  = factor(domain,  levels = APP_E_DOMAINS_ORDER),
      stock   = factor(stock,   levels = c("anchoveta_cs", "sardina_comun_cs", "jurel_cs"),
                                labels = c("Anchoveta", "Sardina comun", "Jurel (n.i.)")),
      shifter = factor(shifter, levels = c("rho_sst", "rho_chl"),
                                labels = c("rho[SST]", "rho[log(CHL)]"))
    )
  p <- ggplot(long_pl,
              aes(x = mean_post, y = domain, color = domain)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey40") +
    geom_pointrange(aes(xmin = q5, xmax = q95), size = 0.4) +
    facet_grid(stock ~ shifter, scales = "free_x",
               labeller = labeller(stock = label_value,
                                   shifter = label_parsed)) +
    scale_color_manual(values = c("centro_sur_eez" = "#1f77b4",
                                  "offshore_ext"   = "#2ca02c",
                                  "se_pacific"     = "#d62728")) +
    labs(x = "Posterior mean (90% CI)", y = NULL,
         title = "Apendice E -- shifters ambientales por dominio del covariado de jurel",
         subtitle = "Anch/sard ven D1 (centro_sur_eez) en los 3 fits; solo jurel itera entre dominios") +
    theme_bw(base_size = 10) +
    theme(legend.position = "none",
          panel.grid.minor = element_blank(),
          strip.background = element_rect(fill = "grey95"))

  out_fig <- file.path(APP_E_FIG_DIR, "appendix_e_sigma_ratios.pdf")
  ggsave(out_fig, p, width = 7.5, height = 5.5, units = "in")
  cat(sprintf("[appE-sigma] Escribi: %s\n", out_fig))

  cat("\n[appE-sigma] Tabla wide:\n")
  print(wide, n = Inf)

  cat("\n[appE-sigma] Decision rule jurel:\n")
  jur <- long %>% dplyr::filter(stock == "jurel_cs",
                                domain %in% APP_E_DOMAINS_ORDER)
  print(jur %>% dplyr::select(domain, shifter, sigma_post, ratio,
                              mean_post, q5, q95, rhat))
  if (all(jur$ratio >= 0.85, na.rm = TRUE)) {
    cat("[appE-sigma] -> JUREL no-id ROBUSTO en los 3 dominios (ratio >= 0.85).\n")
  } else if (any(jur$ratio < 0.7, na.rm = TRUE)) {
    cat("[appE-sigma] -> ALERTA: jurel ratio < 0.7 en algun dominio. ",
        "Reframear claim de paper 1 a 'non-id en EEZ Centro-Sur'.\n")
  } else {
    cat("[appE-sigma] -> ZONA GRIS: ratios entre 0.7 y 0.85. Discutir caso.\n")
  }

  # Sanity: anch y sard ven el mismo covariado en los 3 fits, asi que sus rho
  # posteriors solo se mueven via Omega (chico). Si rho_anch o rho_sard se
  # corre mas de 0.5 SD posterior entre dominios, hay algo raro -- bandera.
  cat("\n[appE-sigma] Sanity anch/sard estabilidad cross-domain ",
      "(deberian ser ~iguales):\n")
  anchsard <- long %>%
    dplyr::filter(stock %in% c("anchoveta_cs", "sardina_comun_cs"),
                  domain %in% APP_E_DOMAINS_ORDER) %>%
    dplyr::group_by(stock, shifter) %>%
    dplyr::summarise(
      mean_min      = min(mean_post, na.rm = TRUE),
      mean_max      = max(mean_post, na.rm = TRUE),
      mean_range    = mean_max - mean_min,
      sigma_post_med = stats::median(sigma_post, na.rm = TRUE),
      n_post_sd     = mean_range / sigma_post_med,   # rango en SD posteriores
      .groups = "drop"
    )
  print(anchsard)
  bad_anchsard <- anchsard %>% dplyr::filter(n_post_sd > 0.5)
  if (nrow(bad_anchsard) > 0) {
    cat("[appE-sigma] -> ALERTA sanity: anch/sard rho se corren >0.5 SD ",
        "entre fits. Posible bug en armado de matrices SST_c/logCHL_c.\n")
    print(bad_anchsard)
  } else {
    cat("[appE-sigma] -> Sanity OK: anch/sard rho estables (<0.5 SD post) ",
        "across dominios.\n")
  }

  invisible(list(long = long, wide = wide, diag = diag,
                 jurel = jur, anchsard_sanity = anchsard))
}
