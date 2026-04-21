# =============================================================================
# FONDECYT -- 02_hindcast_check.R
#
# Tarea 3 del plan V2 (paper1_revision_plan.md sec.T3).
#
# Propósito: antes de montar el state-space Bayesiano (T4), verificar que el
# modelo bio estructural Schaefer, corrido con los priors puntuales del YAML
# (`official_assessments.yaml`) y la captura anual SERNAPESCA, reproduce la
# trayectoria observada de biomasa (BT o SSB) con un error razonable.
#
# Ley de movimiento (Schaefer, shape n = 2 -> Pella-Tomlinson con m=2):
#
#   B_{t+1} = B_t + r * B_t * (1 - B_t / K) - C_t,      con floor 0.01*K
#
# Criterio del plan:  mediana(|B_hat - B_obs| / B_obs) < 20%  -> pasa.
# Si falla, el plan enumera tres sospechosos (plan línea 226-229):
#   (1) unidades captura (SERNAPESCA) vs SSB/BT (IFOP / OROP-PS).
#   (2) B_0 del assessment corresponde a un año anterior al inicio de la serie
#       de captura (SERNAPESCA arranca 2000, SSB oficial arranca 1991/1997/1970).
#   (3) el assessment age-structured (SS3 / estadístico a la edad) no colapsa
#       limpio a biomasa agregada. Plan B: calibrar r, K por profile likelihood
#       manteniendo M fijo.
#
# A esto añadimos el sospechoso #4 que el plan anticipa explícitamente:
#   (4) jurel: captura SERNAPESCA es Chile-total, SSB oficial es range-wide
#       OROP-PS. Ver PEND-8 en el YAML. Harvest rate aparente queda en 4-5%
#       porque Chile pesca ~15% del stock global.
#
# Output:
#   - consola: tabla de errores por especie (mediana, p25, p75, RMSE%).
#   - data/bio_params/qa/hindcast_yaml_priors.png  (trayectorias B_hat vs obs)
#   - data/bio_params/qa/hindcast_grid_rk.png      (Plan B -- si run_grid=TRUE)
#   - tibble `hindcast_results` invisible devuelto por main().
#
# Uso interactivo:
#   options(structural_bio.run_main = TRUE)
#   source("R/07_structural_bio/02_hindcast_check.R")
#
# O llamando funciones:
#   source("R/07_structural_bio/02_hindcast_check.R")
#   res <- run_hindcast_all()
#   summarise_hindcast(res)
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(tibble)
  library(readr)
  library(ggplot2)
})

# Loaders hermanos -- source() estandar en Windows con locale no-UTF-8
# ignora el argumento encoding al leer los bytes. Workaround: leer el
# archivo como bytes crudos, declarar UTF-8, y eval(parse()).
source_utf8 <- function(file, envir = globalenv()) {
  con <- file(file, "rb")
  on.exit(close(con), add = TRUE)
  bytes <- readBin(con, what = "raw", n = file.info(file)$size)
  txt <- rawToChar(bytes)
  Encoding(txt) <- "UTF-8"
  eval(parse(text = txt, encoding = "UTF-8"), envir = envir)
  invisible(NULL)
}
source_utf8("R/07_structural_bio/01_load_official_params.R")
source_utf8("R/07_structural_bio/05_load_official_biomass.R")
source_utf8("R/07_structural_bio/06_load_catch_series.R")

# -----------------------------------------------------------------------------
# Mapeo stock_id de captura (SERNAPESCA) -> fuente de biomasa observada
# -----------------------------------------------------------------------------
#
# FUENTES DE BIOMASA (column `biomass_source`):
#   - "official": toma de official_biomass_series.csv (evaluaciones IFOP
#     age-structured).  Target = biomass_total_t (anchoveta_cs, sardina_cs).
#   - "acoustic": toma de acoustic_biomass_series.csv (cruceros IFOP RECLAS +
#     PELACES). Target = biomass_t. Usado para jurel_cs porque NO existe
#     evaluación oficial age-structured del jurel a escala centro-sur; la
#     biomasa acústica es la mejor observación disponible a esa escala.
#
# CAVEAT JUREL (2026-04-21 tarde — pivot arquitectural):
#   Hasta la mañana se usaba jurel_chile + jurel_orop_ps range-wide (PEND-8
#   ruta A). Se descartó porque el mismatch geográfico catch-vs-biomass
#   degradaba la identificación de r. Ahora se usa arquitectura CS consistente:
#   captura jurel_cs agregada desde SERNAPESCA raw (V-X + Los Ríos, ver
#   08_build_jurel_cs_catch.R) + biomasa acústica jurel_cs del crucero IFOP.
#   La serie acústica tiene gaps (2013-14, 2016, 2018-19, 2022, 2024) y dos
#   no-detecciones (2012 ~2.5 kt, 2015 = 0) que se manejan como missing en
#   el state-space T4, pero para el hindcast determinístico T3 se usan los
#   años con observación válida.
# -----------------------------------------------------------------------------

STOCK_MAP <- tibble::tribble(
  ~catch_id,          ~ssb_id,            ~biomass_source, ~ssb_unit_factor, ~target_col,        ~yaml_key,
  "anchoveta_cs",     "anchoveta_cs",     "official",      1,                "biomass_total_t",  "anchoveta_cs",
  "sardina_comun_cs", "sardina_comun_cs", "official",      1,                "biomass_total_t",  "sardina_comun_cs",
  "jurel_cs",         "jurel_cs",         "acoustic",      1,                "biomass_t",        "jurel_cs"
)

# -----------------------------------------------------------------------------
# Núcleo: simulador Schaefer determinístico
# -----------------------------------------------------------------------------
#' @param r   tasa de crecimiento intrínseca (yr^-1)
#' @param K   capacidad de carga (t)
#' @param B0  biomasa inicial (t)
#' @param catch_series vector de capturas anuales (t), longitud T
#' @param floor_frac  piso como fracción de K (default 0.01)
#' @return vector de B_t (t), longitud T, con B[1] = B0.
simulate_schaefer_hindcast <- function(r, K, B0, catch_series,
                                       floor_frac = 0.01) {
  Tn <- length(catch_series)
  B  <- numeric(Tn)
  B[1] <- B0
  for (t in seq_len(Tn - 1)) {
    g    <- r * B[t] * (1 - B[t] / K)
    B[t + 1] <- max(floor_frac * K, B[t] + g - catch_series[t])
  }
  B
}

# -----------------------------------------------------------------------------
# Ensambla inputs por stock (captura + obs + priors)
# -----------------------------------------------------------------------------
#' Carga observación de biomasa para un stock según `biomass_source` del mapa.
#' @return tibble con columnas (year, <target_col>).
load_biomass_for_stock <- function(row, ssb1) {
  if (row$biomass_source == "official") {
    sraw <- ssb1 %>%
      dplyr::filter(stock_id == row$ssb_id) %>%
      dplyr::arrange(year)
    sraw$ssb_t           <- sraw$ssb_t           * row$ssb_unit_factor
    sraw$biomass_total_t <- sraw$biomass_total_t * row$ssb_unit_factor
    return(sraw)
  }
  if (row$biomass_source == "acoustic") {
    ac_path <- file.path("data", "bio_params", "acoustic_biomass_series.csv")
    ac <- readr::read_csv(ac_path, show_col_types = FALSE) %>%
      dplyr::filter(species == row$ssb_id,
                    !is.na(biomass_t),
                    biomass_t > 0)   # no-detecciones (2015 = 0) van a missing
    # Si hay múltiples cruceros por año (RECLAS + PELACES), tomar la mediana
    # como índice estable (para jurel_cs hay un solo crucero/año, no-op).
    ac <- ac %>%
      dplyr::group_by(year) %>%
      dplyr::summarise(biomass_t = stats::median(biomass_t),
                       .groups = "drop") %>%
      dplyr::mutate(stock_id = row$ssb_id)
    return(ac)
  }
  stop("biomass_source desconocido: ", row$biomass_source)
}

build_hindcast_inputs <- function(
    params = load_official_assessments(),
    catch  = load_catch_annual(),
    ssb    = load_official_biomass()
) {
  ssb1 <- ssb %>%
    dplyr::filter(semester == 1) %>%
    dplyr::select(stock_id, year, ssb_t, biomass_total_t)

  purrr::map(seq_len(nrow(STOCK_MAP)), function(i) {
    row <- STOCK_MAP[i, ]
    p   <- params$priors[[row$yaml_key]]

    cap <- catch %>%
      dplyr::filter(stock_id == row$catch_id) %>%
      dplyr::select(year, catch_t) %>%
      dplyr::arrange(year)

    sraw <- load_biomass_for_stock(row, ssb1)

    merged <- dplyr::inner_join(cap, sraw, by = "year") %>%
      dplyr::mutate(obs = .data[[row$target_col]]) %>%
      dplyr::filter(!is.na(obs)) %>%
      dplyr::arrange(year)

    list(
      catch_id    = row$catch_id,
      ssb_id      = row$ssb_id,
      target_col  = row$target_col,
      years       = merged$year,
      C           = merged$catch_t,
      obs         = merged$obs,
      r           = p$r_prior_mean,
      K           = p$K_prior_mean_mil_t * 1e3,   # mil t -> t
      B0          = merged$obs[1],                # B_0 = obs año inicial overlap
      # priors rango para reportar contexto
      r_sd        = p$r_prior_sd,
      K_sd        = p$K_prior_sd_mil_t * 1e3
    )
  }) %>% setNames(STOCK_MAP$catch_id)
}

# -----------------------------------------------------------------------------
# Corre hindcast para un stock. Devuelve tibble largo con B_hat y B_obs.
# -----------------------------------------------------------------------------
run_hindcast_one <- function(inp) {
  Bhat <- simulate_schaefer_hindcast(
    r = inp$r, K = inp$K, B0 = inp$B0, catch_series = inp$C
  )
  tibble::tibble(
    stock_id    = inp$catch_id,
    ssb_source  = inp$ssb_id,
    target_col  = inp$target_col,
    year        = inp$years,
    catch_t     = inp$C,
    B_obs       = inp$obs,
    B_hat       = Bhat,
    err_t       = B_hat - B_obs,
    abs_err_pct = 100 * abs(err_t) / B_obs,
    r_used      = inp$r,
    K_used      = inp$K
  )
}

run_hindcast_all <- function(inputs = build_hindcast_inputs()) {
  purrr::map_dfr(inputs, run_hindcast_one)
}

# -----------------------------------------------------------------------------
# Resumen de errores por especie
# -----------------------------------------------------------------------------
summarise_hindcast <- function(res, threshold_pct = 20) {
  res %>%
    dplyr::group_by(stock_id, target_col) %>%
    dplyr::summarise(
      n_years      = dplyr::n(),
      yr_start     = min(year),
      yr_end       = max(year),
      median_err_p = stats::median(abs_err_pct, na.rm = TRUE),
      p25_err_p    = stats::quantile(abs_err_pct, 0.25, na.rm = TRUE),
      p75_err_p    = stats::quantile(abs_err_pct, 0.75, na.rm = TRUE),
      rmse_pct     = sqrt(mean((err_t / B_obs)^2, na.rm = TRUE)) * 100,
      B_obs_final  = dplyr::last(B_obs),
      B_hat_final  = dplyr::last(B_hat),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      passes_test  = median_err_p < threshold_pct
    )
}

# -----------------------------------------------------------------------------
# Plan B: grid search de (r, K) que mejor reproduce la trayectoria observada,
# manteniendo M fijo (implícito vía r -- no lo tocamos como prior separado
# porque Schaefer agregado no distingue M de r de forma identificable con
# una sola serie de biomasa).
#
# Es exploratorio, no sustituye el state-space Bayesiano (T4). Sirve para
# dos cosas:
#   (a) ver si el problema es de priors puntuales o de identificación estructural.
#   (b) informar priors moderadamente más informativos para T4.
# -----------------------------------------------------------------------------
grid_search_rk <- function(inp,
                           n_r   = 40,
                           n_K   = 40,
                           r_lo  = 0.2,
                           r_hi  = 2.5,
                           K_mult_lo = 1.05,
                           K_mult_hi = 6.0) {
  obs_max <- max(inp$obs, na.rm = TRUE)
  r_grid  <- seq(r_lo, r_hi, length.out = n_r)
  K_grid  <- seq(obs_max * K_mult_lo, obs_max * K_mult_hi, length.out = n_K)

  grid <- tidyr::expand_grid(r = r_grid, K = K_grid) %>%
    dplyr::mutate(
      median_err_p = purrr::pmap_dbl(list(r, K), function(r, K) {
        Bhat <- simulate_schaefer_hindcast(r, K, inp$B0, inp$C)
        stats::median(abs(100 * (Bhat - inp$obs) / inp$obs), na.rm = TRUE)
      })
    )

  best <- grid %>% dplyr::slice_min(median_err_p, n = 1)
  list(
    stock_id = inp$catch_id,
    grid     = grid,
    best     = best,
    r_yaml   = inp$r,
    K_yaml   = inp$K
  )
}

# -----------------------------------------------------------------------------
# Plots diagnósticos
# -----------------------------------------------------------------------------
plot_hindcast_trajectories <- function(res, out_path = NULL) {

  facet_labels <- c(
    anchoveta_cs      = "Anchoveta CS (target: BT oficial IFOP)",
    sardina_comun_cs  = "Sardina común CS (target: BT oficial IFOP)",
    jurel_cs          = "Jurel CS (target: biomasa acústica IFOP)"
  )

  p <- res %>%
    tidyr::pivot_longer(c(B_hat, B_obs), names_to = "series", values_to = "B") %>%
    dplyr::mutate(series = dplyr::recode(series,
                                         B_hat = "Schaefer hindcast (YAML priors)",
                                         B_obs = "Observado (IFOP/OROP)")) %>%
    ggplot(aes(x = year, y = B / 1e3,
               colour = series, linetype = series)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 1.8) +
    facet_wrap(~ stock_id, ncol = 1, scales = "free_y",
               labeller = as_labeller(facet_labels)) +
    scale_colour_manual(values = c("Schaefer hindcast (YAML priors)" = "#D55E00",
                                   "Observado (IFOP/OROP)"            = "#0072B2")) +
    labs(
      title    = "Hindcast Schaefer con priors YAML vs. observado oficial",
      subtitle = "Test T3 del plan V2 -- umbral mediana |err%| < 20%",
      x = "Año", y = "Biomasa (mil t)", colour = NULL, linetype = NULL
    ) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom")

  if (!is.null(out_path)) {
    dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
    ggsave(out_path, p, width = 8, height = 9, dpi = 150)
  }
  p
}

plot_grid_search <- function(grid_results, out_path = NULL) {
  df <- purrr::map_dfr(grid_results, function(g) {
    g$grid %>% dplyr::mutate(stock_id = g$stock_id)
  })
  best_df <- purrr::map_dfr(grid_results, function(g) {
    g$best %>% dplyr::mutate(stock_id = g$stock_id)
  })
  yaml_df <- purrr::map_dfr(grid_results, function(g) {
    tibble::tibble(stock_id = g$stock_id, r = g$r_yaml, K = g$K_yaml)
  })

  p <- ggplot(df, aes(x = r, y = K / 1e3, fill = pmin(median_err_p, 100))) +
    geom_raster() +
    geom_point(data = best_df, aes(x = r, y = K / 1e3),
               shape = 4, size = 3, stroke = 1.1, colour = "white", inherit.aes = FALSE) +
    geom_point(data = yaml_df, aes(x = r, y = K / 1e3),
               shape = 21, size = 3, fill = "yellow", colour = "black", inherit.aes = FALSE) +
    facet_wrap(~ stock_id, scales = "free", ncol = 1) +
    scale_fill_viridis_c(option = "magma", direction = -1,
                         name = "median |err %|\n(cap 100)") +
    labs(title    = "Plan B T3 -- grid search (r, K) que mejor reproduce BT observada",
         subtitle = "x best-fit  |  o YAML prior (r_prior_mean, K_prior_mean)",
         x = "r (yr^-1)", y = "K (mil t)") +
    theme_minimal(base_size = 11)

  if (!is.null(out_path)) {
    dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
    ggsave(out_path, p, width = 8, height = 10, dpi = 150)
  }
  p
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if (isTRUE(getOption("structural_bio.run_main", FALSE))) {

  QA_DIR <- file.path("data", "bio_params", "qa")
  dir.create(QA_DIR, showWarnings = FALSE, recursive = TRUE)

  cat(strrep("=", 70), "\n", sep = "")
  cat("T3 -- HINDCAST SCHAEFER con priors YAML vs SSB/BT oficial\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  inputs <- build_hindcast_inputs()

  # --- Parámetros usados por stock ---
  cat("Parámetros adoptados del YAML:\n")
  pars_tbl <- purrr::map_dfr(inputs, function(x) {
    tibble::tibble(
      stock       = x$catch_id,
      r           = x$r,
      r_sd        = x$r_sd,
      K_mil_t     = x$K / 1e3,
      K_sd_mil_t  = x$K_sd / 1e3,
      B0_mil_t    = x$B0 / 1e3,
      yr_range    = sprintf("%d-%d", min(x$years), max(x$years)),
      target      = x$target_col
    )
  })
  print(as.data.frame(pars_tbl), row.names = FALSE, digits = 3)

  # --- Hindcast + resumen ---
  res <- run_hindcast_all(inputs)
  summ <- summarise_hindcast(res)

  cat("\nResumen de errores hindcast (umbral plan: mediana |err%| < 20):\n")
  print(summ %>% dplyr::mutate(dplyr::across(
    c(median_err_p, p25_err_p, p75_err_p, rmse_pct), ~ round(.x, 1))) %>%
    dplyr::mutate(dplyr::across(c(B_obs_final, B_hat_final), ~ round(.x / 1e3, 0))) %>%
    as.data.frame(), row.names = FALSE)

  n_pass <- sum(summ$passes_test)
  cat(sprintf("\n-> %d de %d stocks pasan el umbral (<20%% mediana |err%%|).\n",
              n_pass, nrow(summ)))

  # --- Guardar plots ---
  plot_hindcast_trajectories(res, file.path(QA_DIR, "hindcast_yaml_priors.png"))
  cat("QA plot:", file.path(QA_DIR, "hindcast_yaml_priors.png"), "\n")

  # --- Plan B: grid search (r, K) ---
  run_grid <- isTRUE(getOption("structural_bio.run_grid", TRUE))
  if (run_grid) {
    cat("\n", strrep("-", 70), "\n", sep = "")
    cat("Plan B T3 (línea 229 del plan) -- grid search (r, K)\n")
    cat(strrep("-", 70), "\n", sep = "")

    gridres <- purrr::map(inputs, grid_search_rk)

    best_tbl <- purrr::map_dfr(gridres, function(g) {
      tibble::tibble(
        stock           = g$stock_id,
        r_yaml          = g$r_yaml,
        K_yaml_mil_t    = g$K_yaml / 1e3,
        r_best          = g$best$r,
        K_best_mil_t    = g$best$K / 1e3,
        median_err_best = g$best$median_err_p
      )
    })
    print(best_tbl %>% dplyr::mutate(dplyr::across(
      where(is.numeric), ~ round(.x, 2))) %>%
      as.data.frame(), row.names = FALSE)

    plot_grid_search(gridres, file.path(QA_DIR, "hindcast_grid_rk.png"))
    cat("QA plot:", file.path(QA_DIR, "hindcast_grid_rk.png"), "\n")
  }

  # --- Diagnóstico de sospechosos si el test falla ---
  if (!all(summ$passes_test)) {
    cat("\n", strrep("-", 70), "\n", sep = "")
    cat("FALLO T3 -- sospechosos según plan V2 sec.T3 (líneas 226-229):\n")
    cat(strrep("-", 70), "\n", sep = "")
    cat(
"(1) Unidades: catch SERNAPESCA en t, BT/SSB IFOP en t (anchoveta/sardina),\n",
"    ssb_t jurel OROP en MILES de t -- factor 1000 ya aplicado acá.\n",
"(2) B_0: acá se usa obs[1] del overlap (anchoveta 2000, sardina 2000,\n",
"    jurel 2000). El IFOP/OROP tiene historia antes, pero SERNAPESCA arranca\n",
"    2000. Si querés anclar B_0 más atrás, habría que tirar del PEND-9\n",
"    (captura pre-2000) o dejarlo como estado libre en el state-space T4.\n",
"(3) Assessment age-structured -> biomasa agregada: SS3/IFOP no colapsa\n",
"    limpio. La forma estructural de un Schaefer (sin reclutamiento explícito)\n",
"    subestima la capacidad de recuperación. Plan B (grid) muestra hasta\n",
"    dónde se puede mejorar con sólo (r, K); si el best-fit sigue > 20%%,\n",
"    la restricción es estructural, NO de calibración de priors.\n",
"(4) Jurel CS: catch SERNAPESCA V-X+LosRíos vs biomasa acústica CS. Los\n",
"    priors ahora vienen de la entrada `jurel_cs` del YAML (K=8000 mil t,\n",
"    r=0.35 +/-0.15), re-escalados respecto al rangewide SPRFMO. Si el\n",
"    hindcast sigue fallando con esta arquitectura CS consistente, el\n",
"    problema es ESTRUCTURAL (Schaefer determinístico no absorbe los pulsos\n",
"    de reclutamiento ni la variabilidad ambiental SST/CHL). Ese es el\n",
"    mandato de T3-bis (ver 09_stress_test_sst.R, PEND-11) y T4 Bayesiano.\n", sep = ""
    )
  }

  cat("\n", strrep("=", 70), "\n", sep = "")

  invisible(list(results = res, summary = summ, inputs = inputs))
}
