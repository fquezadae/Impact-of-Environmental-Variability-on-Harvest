# =============================================================================
# FONDECYT -- 04_forward_simulation.R
#
# REEMPLAZA la comparative statics de 03_project_biomass.R por una
# simulacion dinamica hacia adelante (2025-2100) del sistema SUR.
#
# Motivacion (ver paper1_revision_plan.md, Tarea 4):
#   El cap [0.2, 3.0] en H_alloc esconde una extrapolacion severa del
#   termino SST^2 del SUR. A deltas de +2.3C, SST_c^2 ~= 5.3 (vs rango
#   muestral ~0.25), y rho_SST2 = -56.5 produce -1508% en growth capacity.
#   Ese cap mecanicamente iguala las 4 barras del panel industrial en Fig 3.
#
# Solucion:
#   Simular el sistema recursivamente:
#     b_{i,t+1} = intercept_i + beta_i*(b_{i,t} - B_MEAN_i)
#                             + eta_i*(b_{i,t} - B_MEAN_i)^2
#                             + rho_sst_i*(sst_t - SST_MEAN)
#                             + rho_sst2_i*(sst_t - SST_MEAN)^2
#                             + rho_chl_i*(chl_t - CHL_MEAN)
#                             - h_{i,t}
#
#   donde sst_t se construye aplicando el delta ANUAL (o mensual agregado)
#   al observado historico ciclado -- preserva variabilidad interanual y
#   mantiene sst_c^2 en rango razonable.
#
#   Sanity bounds sobre biomasa (no sobre H_alloc):
#     floor = 0.1 * min_hist ;  techo = 2.0 * max_hist
#
# Parametros de modo:
#   - data_version: "v1" (actual) | "v2_sernapesca" (cuando llegue Tarea 5)
#   - mock_deltas:  TRUE para test con deltas sinteticos (antes de ensemble
#                   CMIP6 de Pangeo, Tarea 1)
#
# Outputs:
#   data/projections/biomass_trajectories.rds   -- tibble (model, scenario,
#       year, species, biomass, harvest)
#   data/projections/biomass_trajectories_summary.rds  -- mid- y end-century
#       % change por especie y escenario
#
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(lavaan)
  library(lubridate)
})

source("R/00_config/config.R")
select <- dplyr::select

# ------------------------------------------------------------------ config ----

FWD_CONFIG <- list(
  data_version  = "v1",                 # "v2_sernapesca" cuando llegue T5
  mock_deltas   = TRUE,                 # FALSE cuando Pangeo/T1 entregue ensemble
  start_year    = 2025,
  end_year      = 2100,
  scale_b       = 1e5,
  F_rule        = "F_hist",             # "F_hist" | "historical_mean"
                                        # F_hist: h = F * b (proporcional, realista bajo TAC MSY)
                                        # historical_mean: h fijo (aisla efecto ambiental)
  b0_source     = "mean_last5",         # "last" | "mean_last5" | "B_MEAN"
                                        # last: biomasa del ultimo anio (puede estar fuera de muestra)
                                        # mean_last5: promedio 5 anios recientes (suavizado)
                                        # B_MEAN: mean de la muestra del SUR (conservador)
  sur_spec      = "full",               # "full" | "no_sst2" | "no_eta" | "linear"
                                        # full:    con b_c^2 y sst_c^2
                                        # no_sst2: sin sst_c^2 (sensibilidad del plan, Tarea 4)
                                        # no_eta:  sin b_c^2 (densidad dep. solo lineal)
                                        # linear:  sin b_c^2 ni sst_c^2
  sanity_floor  = 0.1,                  # x min historico por especie
  sanity_ceil   = 2.0,                  # x max historico por especie
  species       = c("sardine", "anchoveta", "jurel"),
  # Ventanas de agregacion para el reporting (consistente con draft)
  window_mid    = 2041:2060,
  window_end    = 2081:2100,
  seed          = 20260420
)

set.seed(FWD_CONFIG$seed)

# ======================================================================
# 1. HELPERS: estimacion del SUR y extraccion de coeficientes
# ======================================================================

#' Construye el dataset del SUR siguiendo la misma logica de
#' 03_project_biomass.R. Retorna lista con data, medias de centrado y
#' objeto fit.
#'
#' @param sur_spec "full" | "no_sst2" | "no_eta" | "linear"
build_and_fit_sur <- function(data_version = "v1", sur_spec = "full") {

  # ---- cargar datos (switcheable por version) ----
  biomass <- readRDS("data/biomass/biomass_dt.rds")

  harvest_sfx <- if (data_version == "v2_sernapesca") "sernapesca_v3" else "sernapesca_v2"
  harvest_file <- sprintf("data/harvest/%s.rds", harvest_sfx)
  if (!file.exists(harvest_file)) {
    stop(sprintf("Harvest file not found for data_version='%s': %s",
                 data_version, harvest_file))
  }
  h_v2  <- readRDS(harvest_file)
  h_ser <- readRDS("data/harvest/sernapesca.rds")
  h_ifp <- readRDS("data/harvest/IFOP.rds")

  harvest <- h_v2 %>%
    left_join(h_ser, by = c("year", "specie")) %>%
    left_join(h_ifp, by = c("year", "specie"))

  # ---- environment anual (mismo path que 03_project_biomass.R) ----
  env_dt <- readRDS(paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"))

  env_00_11_path <- paste0(dirdata,
    "Environmental/env/2000-2011/EnvCoastDaily_2000_2011_0.25deg.rds")
  env_dt_00_11 <- if (file.exists(env_00_11_path)) readRDS(env_00_11_path) else NULL

  env_year_1 <- as.data.table(env_dt)[, .(
    sst  = mean(sst, na.rm = TRUE),
    chl  = mean(chl, na.rm = TRUE),
    wind = mean(speed_max, na.rm = TRUE)
  ), by = .(year = year(date))]

  env_year <- if (!is.null(env_dt_00_11)) {
    env_year_2 <- as.data.table(env_dt_00_11)[, .(
      sst  = mean(sst, na.rm = TRUE),
      chl  = mean(chl, na.rm = TRUE),
      wind = mean(speed_max, na.rm = TRUE)
    ), by = .(year = year(date))]
    rbind(env_year_2, env_year_1)
  } else {
    env_year_1
  }

  # ---- wide biomass + harvest + env (igual que 03_project_biomass.R) ----
  biomass_wide <- biomass %>%
    select(year, sardine_biomass, anchoveta_biomass,
           jurel_biomass_cs, jurel_cs_interp_primary) %>%
    mutate(jurel_main = jurel_cs_interp_primary)

  harvest_wide <- harvest %>%
    select(specie, year, total_harvest_sernapesca_v2_centro_sur) %>%
    pivot_wider(names_from = specie,
                values_from = total_harvest_sernapesca_v2_centro_sur,
                names_prefix = "h_") %>%
    janitor::clean_names()

  bhw <- left_join(biomass_wide, harvest_wide, by = "year") %>%
    left_join(as.data.frame(env_year), by = "year") %>%
    arrange(year) %>%
    mutate(
      sardine_t1    = lead(sardine_biomass),
      anchoveta_t1  = lead(anchoveta_biomass),
      jurel_main_t1 = lead(jurel_main),
      y_sardine     = sardine_t1    + h_sardina_comun,
      y_anchoveta   = anchoveta_t1  + h_anchoveta,
      y_jurel       = jurel_main_t1 + h_jurel
    )

  # ---- escalado y centrado ----
  scale_b <- FWD_CONFIG$scale_b
  sur_main <- bhw %>%
    filter(!is.na(y_sardine), !is.na(y_anchoveta), !is.na(y_jurel),
           !is.na(sardine_biomass), !is.na(anchoveta_biomass),
           !is.na(jurel_main), !is.na(sst), !is.na(chl)) %>%
    mutate(
      y_s = y_sardine   / scale_b, y_a = y_anchoveta / scale_b, y_j = y_jurel / scale_b,
      b_s = sardine_biomass / scale_b, b_a = anchoveta_biomass / scale_b, b_j = jurel_main / scale_b,
      b_s_c = b_s - mean(b_s), b_a_c = b_a - mean(b_a), b_j_c = b_j - mean(b_j),
      b_s_c2 = b_s_c^2, b_a_c2 = b_a_c^2, b_j_c2 = b_j_c^2,
      sst_c  = sst - mean(sst),
      chl_c  = chl - mean(chl),
      sst_c2 = sst_c^2,
      chl_c2 = chl_c^2
    )

  means <- list(
    SST_MEAN = mean(sur_main$sst), CHL_MEAN = mean(sur_main$chl),
    B_S_MEAN = mean(sur_main$b_s), B_A_MEAN = mean(sur_main$b_a), B_J_MEAN = mean(sur_main$b_j),
    scale_b  = scale_b
  )

  # ---- SUR: eleccion de especificacion ----
  rhs_by_spec <- list(
    full    = c("b_s_c + b_s_c2",  "sst_c + sst_c2", "chl_c"),
    no_sst2 = c("b_s_c + b_s_c2",  "sst_c",          "chl_c"),
    no_eta  = c("b_s_c",           "sst_c + sst_c2", "chl_c"),
    linear  = c("b_s_c",           "sst_c",          "chl_c")
  )
  if (!sur_spec %in% names(rhs_by_spec)) {
    stop(sprintf("sur_spec desconocido: %s", sur_spec))
  }

  # Para cada ecuacion, sustituir el prefijo de especie en los regresores
  build_eq <- function(lhs, prefix) {
    rhs_template <- rhs_by_spec[[sur_spec]]
    rhs <- gsub("b_s_", paste0("b_", prefix, "_"), rhs_template)
    sprintf("%s ~ 1 + %s", lhs, paste(rhs, collapse = " + "))
  }
  model_main <- paste(
    build_eq("y_s", "s"),
    build_eq("y_a", "a"),
    build_eq("y_j", "j"),
    sep = "\n"
  )
  cat(sprintf("  SUR spec: '%s'\n", sur_spec))

  fit_main <- sem(model_main, data = sur_main, estimator = "MLR")

  list(data = sur_main, bhw = bhw, fit = fit_main, means = means,
       harvest = harvest, biomass = biomass)
}

#' Extrae coeficientes del SUR a una estructura amigable para el loop.
#' Retorna: lista con intercept, beta, eta, rho_sst, rho_sst2, rho_chl
#' nombrados por especie ("sardine", "anchoveta", "jurel").
extract_sur_coefs <- function(fit) {
  pe  <- parameterEstimates(fit)

  eq_map <- c(y_s = "sardine", y_a = "anchoveta", y_j = "jurel")
  reg_map <- c(b_s_c = "beta",  b_a_c = "beta",  b_j_c = "beta",
               b_s_c2 = "eta",  b_a_c2 = "eta",  b_j_c2 = "eta",
               sst_c  = "rho_sst",
               sst_c2 = "rho_sst2",
               chl_c  = "rho_chl")

  slopes <- pe %>%
    filter(op == "~") %>%
    mutate(species = eq_map[lhs],
           param   = reg_map[rhs]) %>%
    select(species, param, est) %>%
    pivot_wider(names_from = param, values_from = est)

  intercepts <- pe %>%
    filter(op == "~1") %>%
    mutate(species = eq_map[lhs]) %>%
    select(species, intercept = est)

  coefs <- inner_join(intercepts, slopes, by = "species")

  # Defaults a 0 si el SUR no incluye el termino (spec no_eta, no_sst2, linear)
  zeroed <- function(col) if (col %in% names(coefs)) coefs[[col]] else rep(0, nrow(coefs))

  list(
    intercept = setNames(coefs$intercept,   coefs$species),
    beta      = setNames(zeroed("beta"),    coefs$species),
    eta       = setNames(zeroed("eta"),     coefs$species),
    rho_sst   = setNames(zeroed("rho_sst"), coefs$species),
    rho_sst2  = setNames(zeroed("rho_sst2"),coefs$species),
    rho_chl   = setNames(zeroed("rho_chl"), coefs$species)
  )
}

# ======================================================================
# 2. MOCK deltas (para test antes de que Pangeo/T1 entregue el ensemble)
# ======================================================================

#' Genera un tibble de deltas sinteticos que imita la estructura esperada
#' del ensemble CMIP6 (4 modelos x 2 escenarios x 2 ventanas).
#' Valores derivados de IPSL-CM6A-LR (draft) con perturbaciones plausibles.
build_mock_deltas <- function() {
  tribble(
    ~model,           ~scenario, ~window, ~sst_delta, ~chl_delta_ratio,
    # IPSL (cercano al draft actual)
    "IPSL-CM6A-LR",   "ssp245",  "mid",    0.8,       0.97,
    "IPSL-CM6A-LR",   "ssp245",  "end",    1.3,       0.95,
    "IPSL-CM6A-LR",   "ssp585",  "mid",    1.2,       0.93,
    "IPSL-CM6A-LR",   "ssp585",  "end",    2.3,       0.88,
    # GFDL-ESM4 (mid-of-the-road, sensibilidad menor)
    "GFDL-ESM4",      "ssp245",  "mid",    0.6,       0.98,
    "GFDL-ESM4",      "ssp245",  "end",    1.0,       0.97,
    "GFDL-ESM4",      "ssp585",  "mid",    0.9,       0.95,
    "GFDL-ESM4",      "ssp585",  "end",    1.8,       0.91,
    # MPI-ESM1-2-HR
    "MPI-ESM1-2-HR",  "ssp245",  "mid",    0.7,       0.97,
    "MPI-ESM1-2-HR",  "ssp245",  "end",    1.2,       0.95,
    "MPI-ESM1-2-HR",  "ssp585",  "mid",    1.1,       0.93,
    "MPI-ESM1-2-HR",  "ssp585",  "end",    2.1,       0.89,
    # CanESM5 (cota superior, sensibilidad alta)
    "CanESM5",        "ssp245",  "mid",    1.0,       0.96,
    "CanESM5",        "ssp245",  "end",    1.7,       0.93,
    "CanESM5",        "ssp585",  "mid",    1.6,       0.91,
    "CanESM5",        "ssp585",  "end",    3.1,       0.83
  )
}

# ======================================================================
# 3. CONSTRUIR SERIE AMBIENTAL FUTURA (ciclando observados + delta)
# ======================================================================

#' Para cada year futuro, asigna un year base historico ciclicamente y
#' aplica el delta. Esto preserva variabilidad interanual y mantiene
#' sst_c^2 en rango razonable (el delta se suma al observado, no al promedio).
#'
#' Los argumentos sst_delta y chl_ratio pueden ser escalares (delta constante
#' en el tiempo) o vectores de length(years) (delta time-varying, interpolado
#' entre mid-century y end-century).
#'
#' @param hist_env  tibble con year, sst, chl (anual)
#' @param sst_delta escalar o vector length(years): delta aditivo de SST (C)
#' @param chl_ratio escalar o vector length(years): delta multiplicativo de CHL
#' @param years     vector de years futuros
build_env_series <- function(hist_env, sst_delta, chl_ratio, years) {

  base_years <- sort(unique(hist_env$year))
  n_base <- length(base_years)
  n_yr   <- length(years)

  # Broadcasting: admitir escalares o vectores de length(years)
  if (length(sst_delta) == 1) sst_delta <- rep(sst_delta, n_yr)
  if (length(chl_ratio) == 1) chl_ratio <- rep(chl_ratio, n_yr)
  stopifnot(length(sst_delta) == n_yr, length(chl_ratio) == n_yr)

  tibble(
    year      = years,
    base_year = base_years[((seq_along(years) - 1) %% n_base) + 1],
    sst_delta = sst_delta,
    chl_ratio = chl_ratio
  ) |>
    left_join(hist_env %>% select(base_year = year, sst_base = sst, chl_base = chl),
              by = "base_year") |>
    mutate(
      sst = sst_base + sst_delta,
      chl = chl_base * chl_ratio
    ) |>
    select(year, sst, chl)
}

#' Interpola delta anual a partir de anchors (mid, end) del ensemble.
#' Anclas: 2025 -> 0 ; 2050 -> delta_mid ; 2090 -> delta_end.
#' Linear entre anclas, extrapolacion plana al final.
interpolate_delta_schedule <- function(years, delta_mid, delta_end,
                                       year_start = 2025,
                                       year_mid   = 2050,
                                       year_end   = 2090,
                                       type = c("additive", "multiplicative")) {
  type <- match.arg(type)
  baseline <- if (type == "additive") 0 else 1

  approx(x    = c(year_start, year_mid, year_end),
         y    = c(baseline,   delta_mid, delta_end),
         xout = years,
         rule = 2)$y   # rule=2: extrapola plano antes/despues
}

# ======================================================================
# 4. REGLA DE COSECHA (harvest rule) para el loop
# ======================================================================

#' Construye una trayectoria de harvest futura para cada especie.
#' Dos reglas disponibles:
#'
#'  "historical_mean": h_t = mean(h_obs_s) para todo t. Aisla efecto
#'                     ambiental puro (no deja que harvest reaccione a biomasa).
#'  "F_hist":          h_t = F_hist_s * b_t con F_hist_s = mean(h_obs_s / b_obs_s).
#'                     Proporcional: la cosecha escala con biomasa. Mas realista
#'                     para una TAC based on F_MSY, pero acopla harvest y biomasa.
#'
#' Retorna una funcion h_rule(t, b_t) -> vector named por especie.
build_harvest_rule <- function(bhw, rule = "historical_mean", scale_b = 1e5) {

  hist <- bhw %>%
    filter(!is.na(sardine_biomass), !is.na(h_sardina_comun),
           !is.na(anchoveta_biomass), !is.na(h_anchoveta),
           !is.na(jurel_main), !is.na(h_jurel)) %>%
    transmute(
      year,
      b_sardine    = sardine_biomass   / scale_b,
      b_anchoveta  = anchoveta_biomass / scale_b,
      b_jurel      = jurel_main        / scale_b,
      h_sardine    = h_sardina_comun   / scale_b,
      h_anchoveta  = h_anchoveta       / scale_b,
      h_jurel      = h_jurel           / scale_b
    )

  if (rule == "historical_mean") {
    h_bar <- c(
      sardine   = mean(hist$h_sardine,   na.rm = TRUE),
      anchoveta = mean(hist$h_anchoveta, na.rm = TRUE),
      jurel     = mean(hist$h_jurel,     na.rm = TRUE)
    )
    return(function(t, b_t) h_bar)
  }

  if (rule == "F_hist") {
    # Sum-weighted F (robusto a outliers en h/b individuales, vs mean(h/b))
    F_hat <- c(
      sardine   = sum(hist$h_sardine,   na.rm = TRUE) /
                  sum(hist$b_sardine,   na.rm = TRUE),
      anchoveta = sum(hist$h_anchoveta, na.rm = TRUE) /
                  sum(hist$b_anchoveta, na.rm = TRUE),
      jurel     = sum(hist$h_jurel,     na.rm = TRUE) /
                  sum(hist$b_jurel,     na.rm = TRUE)
    )
    # Cap a 0.9 (F > 1 no tiene sentido biologico, refleja error de estimacion de B)
    F_hat <- pmin(F_hat, 0.9)
    attr(F_hat, "rule") <- "F_hist"
    return(structure(function(t, b_t) F_hat * b_t,
                     F_hat = F_hat))
  }

  stop(sprintf("Unknown harvest rule: %s", rule))
}

# ======================================================================
# 5. SIMULACION FORWARD (loop principal)
# ======================================================================

#' Corre la simulacion recursiva para una trayectoria ambiental dada.
#'
#' @param coefs      salida de extract_sur_coefs()
#' @param means      lista con SST_MEAN, CHL_MEAN, B_*_MEAN, scale_b
#' @param env_series tibble year/sst/chl
#' @param b0         biomass inicial (vector named, en unidades ESCALADAS)
#' @param h_rule     funcion t, b_t -> h_t (en unidades ESCALADAS)
#' @param hist_range data.frame con species/min/max (escalados)
simulate_forward <- function(coefs, means, env_series, b0, h_rule, hist_range) {

  T_horizon <- nrow(env_series)
  species   <- names(coefs$intercept)

  B_MEAN <- c(
    sardine   = means$B_S_MEAN,
    anchoveta = means$B_A_MEAN,
    jurel     = means$B_J_MEAN
  )

  b_mat <- matrix(NA_real_, T_horizon, length(species),
                  dimnames = list(NULL, species))
  h_mat <- b_mat

  b_cur <- b0[species]

  for (t in seq_len(T_horizon)) {
    sst_c <- env_series$sst[t] - means$SST_MEAN
    chl_c <- env_series$chl[t] - means$CHL_MEAN

    h_t <- h_rule(t, b_cur)[species]
    h_mat[t, ] <- h_t

    b_c <- b_cur - B_MEAN

    # y_{i,t+1} = intercept + beta*b_c + eta*b_c^2 + rho_sst*sst_c
    #             + rho_sst2*sst_c^2 + rho_chl*chl_c
    # b_{i,t+1} = y_{i,t+1} - h_{i,t}
    y_next <- coefs$intercept +
              coefs$beta     * b_c +
              coefs$eta      * b_c^2 +
              coefs$rho_sst  * sst_c +
              coefs$rho_sst2 * sst_c^2 +
              coefs$rho_chl  * chl_c

    b_next <- y_next - h_t

    # Sanity bounds sobre biomasa (no sobre harvest allocation)
    b_next <- pmax(FWD_CONFIG$sanity_floor * hist_range$min[species],
              pmin(FWD_CONFIG$sanity_ceil  * hist_range$max[species], b_next))

    b_mat[t, ] <- b_next
    b_cur <- b_next
  }

  as_tibble(b_mat) |>
    mutate(year = env_series$year) |>
    pivot_longer(-year, names_to = "species", values_to = "biomass") |>
    left_join(
      as_tibble(h_mat) |>
        mutate(year = env_series$year) |>
        pivot_longer(-year, names_to = "species", values_to = "harvest"),
      by = c("year", "species")
    )
}

# ======================================================================
# 6. WRAPPER: correr el ensemble completo (modelos x escenarios)
# ======================================================================

run_ensemble <- function(sur_bundle, deltas, cfg = FWD_CONFIG) {

  coefs <- extract_sur_coefs(sur_bundle$fit)

  # historico anual (para base de ciclado y rango para sanity bounds)
  hist_env <- sur_bundle$data %>% select(year, sst, chl) %>% arrange(year)

  scale_b <- cfg$scale_b
  biomass_hist_scaled <- sur_bundle$bhw %>%
    transmute(year,
      sardine   = sardine_biomass   / scale_b,
      anchoveta = anchoveta_biomass / scale_b,
      jurel     = jurel_main        / scale_b)

  hist_range <- biomass_hist_scaled %>%
    pivot_longer(-year, names_to = "species", values_to = "b") %>%
    group_by(species) %>%
    summarise(min = min(b, na.rm = TRUE),
              max = max(b, na.rm = TRUE),
              .groups = "drop") %>%
    { setNames(list(min = setNames(.$min, .$species),
                    max = setNames(.$max, .$species)),
               c("min", "max")) }

  # b0 segun configuracion -- construccion robusta por especie
  last_year <- max(biomass_hist_scaled$year[complete.cases(biomass_hist_scaled)])

  get_b0 <- function(sp_col) {
    switch(cfg$b0_source,
      "last" = {
        biomass_hist_scaled %>%
          filter(year == last_year) %>%
          pull(!!sym(sp_col)) %>%
          as.numeric() %>%
          `[`(1)
      },
      "mean_last5" = {
        biomass_hist_scaled %>%
          filter(year > last_year - 5) %>%
          pull(!!sym(sp_col)) %>%
          as.numeric() %>%
          mean(na.rm = TRUE)
      },
      "B_MEAN" = {
        switch(sp_col,
          sardine   = sur_bundle$means$B_S_MEAN,
          anchoveta = sur_bundle$means$B_A_MEAN,
          jurel     = sur_bundle$means$B_J_MEAN)
      },
      stop(sprintf("b0_source desconocido: %s", cfg$b0_source))
    )
  }

  b0 <- c(
    sardine   = as.numeric(get_b0("sardine")),
    anchoveta = as.numeric(get_b0("anchoveta")),
    jurel     = as.numeric(get_b0("jurel"))
  )
  stopifnot(length(b0) == 3, all(is.finite(b0)),
            identical(names(b0), c("sardine", "anchoveta", "jurel")))

  cat(sprintf("  b0_source = '%s'  (last obs year = %d)\n",
              cfg$b0_source, last_year))

  # Diagnostico: b0 vs SUR sample range + contribucion del termino cuadratico.
  # Construccion posicional (no depende de names lookup).
  species_list <- c("sardine", "anchoveta", "jurel")
  b_cols <- c(sardine = "b_s", anchoveta = "b_a", jurel = "b_j")
  B_MEAN_vec <- c(sur_bundle$means$B_S_MEAN,
                  sur_bundle$means$B_A_MEAN,
                  sur_bundle$means$B_J_MEAN)

  b_min_vec <- sapply(species_list, function(sp) min(sur_bundle$data[[b_cols[sp]]]))
  b_max_vec <- sapply(species_list, function(sp) max(sur_bundle$data[[b_cols[sp]]]))

  b0_vec      <- as.numeric(b0[species_list])
  eta_vec     <- as.numeric(coefs$eta[species_list])
  b_c_vec     <- b0_vec - B_MEAN_vec
  quad_vec    <- eta_vec * b_c_vec^2
  pct_dev_vec <- 100 * b_c_vec / B_MEAN_vec
  in_sample   <- b0_vec >= b_min_vec & b0_vec <= b_max_vec

  diag_tbl <- tibble(
    species   = species_list,
    b0        = b0_vec,
    b_min     = unname(b_min_vec),
    b_max     = unname(b_max_vec),
    B_MEAN    = B_MEAN_vec,
    pct_dev   = pct_dev_vec,
    eta       = eta_vec,
    quad_term = quad_vec,
    in_sample = in_sample
  )
  cat("  b0 vs SUR sample (extrapolacion si in_sample = FALSE):\n")
  print(diag_tbl %>%
          mutate(across(c(b0, b_min, b_max, B_MEAN, pct_dev, eta, quad_term),
                        \(x) round(x, 2))) %>%
          as.data.frame(),
        row.names = FALSE)

  # Imprimir TODOS los coeficientes SUR por especie
  cat("\n  SUR coefficients (all):\n")
  coef_df <- tibble(
    species   = species_list,
    intercept = as.numeric(coefs$intercept[species_list]),
    beta      = as.numeric(coefs$beta[species_list]),
    eta       = as.numeric(coefs$eta[species_list]),
    rho_sst   = as.numeric(coefs$rho_sst[species_list]),
    rho_sst2  = as.numeric(coefs$rho_sst2[species_list]),
    rho_chl   = as.numeric(coefs$rho_chl[species_list])
  )
  print(coef_df %>% mutate(across(-species, \(x) round(x, 3))) %>% as.data.frame(),
        row.names = FALSE)

  # Harvest rule (antes del diagnostico primer step porque lo necesita)
  h_rule <- build_harvest_rule(sur_bundle$bhw, rule = cfg$F_rule, scale_b = scale_b)
  if (cfg$F_rule == "F_hist") {
    F_hat <- attr(h_rule, "F_hat")
    cat("\n  F_hat (historical exploitation rates):\n")
    print(round(F_hat, 3))
  } else {
    F_hat <- c(sardine = NA, anchoveta = NA, jurel = NA)
  }

  # Prediccion analitica del primer paso (t -> t+1) bajo climate constante
  # y harvest = F*b, para cada especie. Aisla si el problema es el primer
  # salto o una acumulacion a lo largo del tiempo.
  cat("\n  Primer step (t -> t+1) con climate = hist mean (env_c = 0):\n")
  step1 <- coef_df %>%
    mutate(
      b0     = b0_vec,
      b_c    = b_c_vec,
      y_pred = intercept + beta * b_c + eta * b_c^2,  # env_c = 0
      h      = F_hat[species] * b0,
      b_next = y_pred - h,
      delta  = b_next - b0,
      pct    = 100 * delta / b0
    ) %>%
    select(species, b0, y_pred, h, b_next, delta, pct)
  print(step1 %>% mutate(across(where(is.numeric), \(x) round(x, 2))) %>% as.data.frame(),
        row.names = FALSE)

  # Prediccion analitica del efecto ambiental end-century (sst_c = 2.3, chl ratio = 0.88)
  cat("\n  Contribucion ambiental end-century (sst_c=2.3, chl_c=-0.07 aprox):\n")
  sst_c_e <- 2.3; chl_c_e <- -0.07
  env_contrib <- coef_df %>%
    mutate(
      env_sst  = rho_sst  * sst_c_e,
      env_sst2 = rho_sst2 * sst_c_e^2,
      env_chl  = rho_chl  * chl_c_e,
      env_tot  = env_sst + env_sst2 + env_chl,
      as_pct_intercept = 100 * env_tot / intercept
    ) %>%
    select(species, env_sst, env_sst2, env_chl, env_tot, as_pct_intercept)
  print(env_contrib %>% mutate(across(where(is.numeric), \(x) round(x, 2))) %>% as.data.frame(),
        row.names = FALSE)

  years <- cfg$start_year:cfg$end_year

  # Deltas esperados: cada fila = (model, scenario, sst_delta_mid, sst_delta_end,
  # chl_delta_ratio_mid, chl_delta_ratio_end). Interpolamos linealmente
  # entre 2025 (delta=0) -> 2050 (mid) -> 2090 (end).
  expected_cols <- c("sst_delta_mid", "sst_delta_end",
                     "chl_delta_ratio_mid", "chl_delta_ratio_end")
  missing <- setdiff(expected_cols, names(deltas))
  if (length(missing)) {
    stop(sprintf("deltas falta columnas: %s", paste(missing, collapse = ", ")))
  }

  traj <- deltas %>%
    mutate(
      sst_schedule = pmap(list(sst_delta_mid, sst_delta_end),
        function(m, e) interpolate_delta_schedule(years, m, e, type = "additive")),
      chl_schedule = pmap(list(chl_delta_ratio_mid, chl_delta_ratio_end),
        function(m, e) interpolate_delta_schedule(years, m, e, type = "multiplicative")),
      env_series = map2(sst_schedule, chl_schedule,
        function(sd, cr) build_env_series(hist_env, sd, cr, years)),
      trajectory = map(env_series,
        function(es) simulate_forward(coefs, sur_bundle$means, es, b0, h_rule, hist_range))
    ) %>%
    select(model, scenario, trajectory) %>%
    unnest(trajectory)

  # Retornar trayectoria + b0 (para summarise_trajectories)
  list(traj = traj, b0 = b0)
}

# ======================================================================
# 7. SUMMARY (% change por ventana, comparable con Tabla 4/5 del draft)
# ======================================================================

summarise_trajectories <- function(traj, sur_bundle, b0, cfg = FWD_CONFIG) {

  # Dos baselines:
  #   b_hist: media historica desde 2012 (comparable con Tabla 4 del draft)
  #   b0:     stock state de partida de la simulacion (cambio de stock)
  scale_b <- cfg$scale_b
  b_hist <- sur_bundle$bhw %>%
    transmute(year,
      sardine   = sardine_biomass   / scale_b,
      anchoveta = anchoveta_biomass / scale_b,
      jurel     = jurel_main        / scale_b) %>%
    filter(year >= 2012) %>%
    pivot_longer(-year, names_to = "species", values_to = "b") %>%
    group_by(species) %>%
    summarise(b_hist = mean(b, na.rm = TRUE), .groups = "drop")

  b0_df <- tibble(species = names(b0), b0 = as.numeric(b0))

  traj %>%
    mutate(window = case_when(
      year %in% cfg$window_mid ~ "mid",
      year %in% cfg$window_end ~ "end",
      TRUE ~ NA_character_
    )) %>%
    filter(!is.na(window)) %>%
    group_by(model, scenario, window, species) %>%
    summarise(b_proj = mean(biomass, na.rm = TRUE), .groups = "drop") %>%
    left_join(b_hist, by = "species") %>%
    left_join(b0_df, by = "species") %>%
    mutate(pct_vs_hist = 100 * (b_proj - b_hist) / b_hist,
           pct_vs_b0   = 100 * (b_proj - b0)     / b0) %>%
    group_by(scenario, window, species) %>%
    summarise(
      med_vs_hist = median(pct_vs_hist),
      med_vs_b0   = median(pct_vs_b0),
      p10_vs_b0   = quantile(pct_vs_b0, 0.10),
      p90_vs_b0   = quantile(pct_vs_b0, 0.90),
      .groups = "drop"
    )
}

# ======================================================================
# 8. MAIN
# ======================================================================

if (isTRUE(getOption("fwd_sim.run_main", FALSE))) {

  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("FORWARD SIMULATION (reemplaza comparative statics de 03_project_biomass.R)\n")
  cat(strrep("=", 70), "\n", sep = "")
  cat("data_version :", FWD_CONFIG$data_version, "\n")
  cat("mock_deltas  :", FWD_CONFIG$mock_deltas, "\n")
  cat("sur_spec     :", FWD_CONFIG$sur_spec, "\n")
  cat("b0_source    :", FWD_CONFIG$b0_source, "\n")
  cat("F_rule       :", FWD_CONFIG$F_rule, "\n")
  cat("horizon      :", FWD_CONFIG$start_year, "-", FWD_CONFIG$end_year, "\n\n")

  cat("[1/4] Fitting SUR...\n")
  sur_bundle <- build_and_fit_sur(FWD_CONFIG$data_version, FWD_CONFIG$sur_spec)
  cat("      N =", nrow(sur_bundle$data),
      "  AIC =", round(AIC(sur_bundle$fit), 1), "\n")

  cat("[2/4] Building deltas (time-varying, interpolados mid<->end)...\n")
  deltas_raw <- if (FWD_CONFIG$mock_deltas) {
    cat("      (MOCK: 4 modelos x 2 escenarios x 2 ventanas)\n")
    build_mock_deltas()
  } else {
    # TODO: cuando Tarea 1 (Pangeo) entregue, cargar el ensemble real.
    readRDS("data/projections/cmip6_deltas_ensemble.rds")
  }

  # Pivotear a una fila por (model, scenario) con deltas mid y end.
  deltas <- deltas_raw %>%
    pivot_wider(id_cols = c(model, scenario),
                names_from = window,
                values_from = c(sst_delta, chl_delta_ratio))
  print(deltas)

  cat("\n[3/4] Running ensemble forward simulation...\n")
  ens <- run_ensemble(sur_bundle, deltas, FWD_CONFIG)
  traj <- ens$traj
  b0_used <- ens$b0
  cat("      trayectorias:", nrow(traj), "filas (",
      length(unique(traj$model)), "modelos x",
      length(unique(traj$scenario)), "escenarios x",
      length(unique(traj$year)), "anios x 3 especies)\n")

  cat("\n[4/4] Summary por ventana y escenario (% change relativo a b0 y a hist):\n")
  summary_tbl <- summarise_trajectories(traj, sur_bundle, b0_used, FWD_CONFIG)
  print(summary_tbl %>%
          mutate(across(c(med_vs_hist, med_vs_b0, p10_vs_b0, p90_vs_b0),
                        \(x) round(x, 1))) %>%
          as.data.frame(),
        row.names = FALSE)

  # ---- salvar ----
  dir.create("data/projections", showWarnings = FALSE, recursive = TRUE)
  saveRDS(traj,        "data/projections/biomass_trajectories.rds")
  saveRDS(summary_tbl, "data/projections/biomass_trajectories_summary.rds")

  cat("\nSaved:\n")
  cat("  data/projections/biomass_trajectories.rds\n")
  cat("  data/projections/biomass_trajectories_summary.rds\n")
  cat(strrep("=", 70), "\n")
}
