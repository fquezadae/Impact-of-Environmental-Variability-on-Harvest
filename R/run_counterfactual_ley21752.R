## =============================================================================
## run_counterfactual_ley21752.R
##
## Computes the policy counterfactual under Ley N.21.752 (2025) versus the
## pre-2025 Article 47 LGPA fractioning regime, propagating the posterior of
## (rho^SST_s, rho^CHL_s) and the CMIP6 ensemble through the same productivity
## shifter pipeline used in Tables \ref{tab:growth_compstat} and
## \ref{tab:trip_compstat}.
##
## Output: tables/appendix_h_counterfactual_ley21752.csv (summary by stock and
##         regime, cross-model median + IQR + within-posterior 90% CI)
##         tables/appendix_h_counterfactual_ley21752_byModel.csv (granular)
##
## Felipe Quezada-Escalona / 2026-05-18
## =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
})

## ----- Project root -----------------------------------------------------------
## Resolve so that the script can be run from anywhere within the project.
root <- tryCatch(rprojroot::find_root(rprojroot::has_file(
  "Impact of Environment on Harvest.Rproj")), error = function(e) ".")
setwd(root)

## ----- Inputs -----------------------------------------------------------------
## 1) Per-model summary of stock productivity factor changes, written by the
##    main T5 pipeline. Has per-(stock, model, scenario, window) median and
##    within-posterior q05/q95 of pct_med = (r_eff/r0) - 1.
gcs <- readr::read_csv("tables/growth_comparative_statics_by_model.csv",
                       show_col_types = FALSE)

## 2) 2024 Cuotas Globales de Captura (CS V-Los Lagos), in tonnes. Source:
##    SERNAPESCA 2024 official quota table, cited as @SERNAPESCA2024-cuota
##    in the paper.
##
##    NB: jurel CS is decomposed into TWO sub-macrozones because Ley 21.752
##    assigns different artisanal shares to V-Los Rios (item 4, 30%) and
##    Los Lagos (item 5, 15%). The SERNAPESCA quota report aggregates
##    Los Rios-Los Lagos into a single 80,580 t block, so we treat that
##    block here as Los Lagos for the post-Ley share (15%, conservative
##    lower bound on the true sub-block share).
##
##    The downstream summary aggregates both jurel sub-rows into a single
##    "jurel_cs" stock row for the final summary CSV.
Q0_tonnes <- tibble::tribble(
  ~stock_id,                 ~Q0_t,
  "anchoveta_cs",            211343,
  "sardina_comun_cs",        290581,
  "jurel_cs_v_rios",         578641,   # Ley 21.752 item 4: ART 30%
  "jurel_cs_los_lagos",       80580    # Ley 21.752 item 5: ART 15%
)

## 3) Statutory artisanal shares of TAC, by regime and stock-sub-macrozone.
##    Pre-2025: Article 47 LGPA, per @SERNAPESCA2024-cuota.
##    Post-2025: Article 1 of Ley N.21.752, per @Ley21752-2025
##    (https://bcn.cl/x54WxT, promulgated 25-jun-2025, in force until 2040).
alpha_art <- tibble::tribble(
  ~stock_id,                 ~alpha_art47, ~alpha_ley752,
  "anchoveta_cs",            0.78,         0.90,
  "sardina_comun_cs",        0.78,         0.90,
  "jurel_cs_v_rios",         0.10,         0.30,
  "jurel_cs_los_lagos",      0.10,         0.15
)

## 3b) Mapping from sub-macrozone stock_id to the model's stock_id key in
##     growth_comparative_statics_by_model.csv (both jurel sub-rows draw on
##     the same posterior because the paper estimates a single jurel
##     elasticity for CS).
model_key <- c(
  anchoveta_cs       = "anchoveta_cs",
  sardina_comun_cs   = "sardina_comun_cs",
  jurel_cs_v_rios    = "jurel_cs",
  jurel_cs_los_lagos = "jurel_cs"
)

## 4) Jurel non-identification convention: hold (1 + Deltar/r0) = 1 for jurel
##    across all models (the paper's reporting convention, Section
##    \ref{sec:stock-dynamics}). The script supports a sensitivity in which
##    jurel uses its ENSO-prior-propagated envelope; set jurel_mode = "fixed"
##    for the paper's primary spec.
jurel_mode <- "fixed"   # "fixed" or "enso_propagated"

## ----- Build per-model long table --------------------------------------------
## Restrict to SSP5-8.5 end-of-century, which is the scenario reported in the
## appendix. To generalise to mid-century or SSP2-4.5, drop the filter.
SCEN <- "ssp585"; WIN <- "end"

## Expand the per-model posterior across the four sub-macrozone units.
## Both jurel sub-rows draw on the same posterior (model_key collapses both
## to "jurel_cs" before the join), then the artisanal share alpha_art and
## the sub-macrozone quota Q0_t differentiate them.
units <- tibble::tibble(
  stock_id      = names(model_key),
  model_stock   = unname(model_key)
) %>%
  left_join(Q0_tonnes, by = "stock_id") %>%
  left_join(alpha_art, by = "stock_id")

gcs_f <- gcs %>%
  filter(scenario == SCEN, window == WIN) %>%
  rename(model_stock = stock_id) %>%
  inner_join(units, by = "model_stock", relationship = "many-to-many")

## Productivity factor by model: (1 + pct_med) for the median, (1 + pct_q05)
## and (1 + pct_q95) for the within-posterior 90% envelope. Jurel sub-rows
## are both held at factor 1 under the non-identification convention.
is_jurel <- gcs_f$model_stock == "jurel_cs" & jurel_mode == "fixed"
gcs_f <- gcs_f %>%
  mutate(
    fact_med = ifelse(is_jurel, 1, 1 + pct_med),
    fact_q05 = ifelse(is_jurel, 1, 1 + pct_q05),
    fact_q95 = ifelse(is_jurel, 1, 1 + pct_q95)
  )

## ----- Artisanal absolute landing under each regime --------------------------
## L_art = alpha * (1 + Deltar/r0) * Q0
build_L <- function(alpha_col) {
  gcs_f %>%
    mutate(
      L_med = .data[[alpha_col]] * fact_med * Q0_t / 1000,  # in kt
      L_q05 = .data[[alpha_col]] * fact_q05 * Q0_t / 1000,
      L_q95 = .data[[alpha_col]] * fact_q95 * Q0_t / 1000
    )
}

L_art47  <- build_L("alpha_art47")  %>%
  mutate(regime = "Art47") %>%
  select(stock_id, model, regime, L_med, L_q05, L_q95)

L_ley752 <- build_L("alpha_ley752") %>%
  mutate(regime = "Ley21752") %>%
  select(stock_id, model, regime, L_med, L_q05, L_q95)

L_long <- bind_rows(L_art47, L_ley752)

## ----- Granular by-model output ----------------------------------------------
readr::write_csv(L_long,
  "tables/appendix_h_counterfactual_ley21752_byModel.csv")

## ----- Summary: cross-model med + IQR, within-posterior 90% CI ---------------
## - cross_med / cross_q25 / cross_q75: across the 6 CMIP6 models, of the
##   per-model posterior MEDIAN. This is the cross-model uncertainty axis.
## - within_q05 / within_q95: median across models of the per-model
##   posterior q05 and q95. This is the within-posterior 90% CI integrated
##   over the ensemble (same convention as Table \ref{tab:trip_compstat}).
##
## Aggregate the two jurel sub-rows (V-Los Rios + Los Lagos) into a single
## "jurel_cs" stock_id BEFORE summarising, so the appendix table reports
## one jurel row per regime -- matching Table \ref{tab:counterfactual-main}
## in the main text. Sub-macrozone-level numbers remain in the byModel CSV
## for downstream uses.
L_long_agg <- L_long %>%
  mutate(stock_id = ifelse(grepl("^jurel_", stock_id), "jurel_cs", stock_id)) %>%
  group_by(stock_id, model, regime) %>%
  summarise(
    L_med = sum(L_med),
    L_q05 = sum(L_q05),
    L_q95 = sum(L_q95),
    .groups = "drop"
  )

summ_stock <- L_long_agg %>%
  group_by(stock_id, regime) %>%
  summarise(
    cross_med  = median(L_med),
    cross_q25  = quantile(L_med, 0.25),
    cross_q75  = quantile(L_med, 0.75),
    within_q05 = median(L_q05),
    within_q95 = median(L_q95),
    n_models   = dplyr::n(),
    .groups = "drop"
  )

## Total artisanal landing across the three stocks: sum within (model, regime),
## then aggregate cross-model.
L_total_by_model <- L_long_agg %>%
  group_by(model, regime) %>%
  summarise(
    L_med = sum(L_med),
    L_q05 = sum(L_q05),
    L_q95 = sum(L_q95),
    .groups = "drop"
  )

summ_total <- L_total_by_model %>%
  group_by(regime) %>%
  summarise(
    stock_id   = "TOTAL_CS",
    cross_med  = median(L_med),
    cross_q25  = quantile(L_med, 0.25),
    cross_q75  = quantile(L_med, 0.75),
    within_q05 = median(L_q05),
    within_q95 = median(L_q95),
    n_models   = dplyr::n(),
    .groups = "drop"
  ) %>%
  select(stock_id, regime, cross_med, cross_q25, cross_q75,
         within_q05, within_q95, n_models)

summ_out <- bind_rows(summ_stock, summ_total) %>%
  arrange(factor(stock_id,
    levels = c("anchoveta_cs", "sardina_comun_cs", "jurel_cs", "TOTAL_CS")),
    regime)

readr::write_csv(summ_out, "tables/appendix_h_counterfactual_ley21752.csv")

## ----- Console summary -------------------------------------------------------
cat("\n=== Counterfactual under Ley 21.752 vs Art. 47 LGPA ===\n")
cat("Scenario:", SCEN, WIN, "| jurel mode:", jurel_mode, "\n\n")
print(summ_out %>%
  mutate(across(c(cross_med, cross_q25, cross_q75, within_q05, within_q95),
                ~ formatC(.x, format = "f", digits = 1))) %>%
  as.data.frame())

cat("\nFiles written:\n")
cat("  tables/appendix_h_counterfactual_ley21752.csv  (summary)\n")
cat("  tables/appendix_h_counterfactual_ley21752_byModel.csv  (granular)\n\n")

## ----- Optional: re-render Table \\ref{tab:counterfactual} for the appendix -
## The current static table in appendix_h_portfolio_and_counterfactual.Rmd is a
## plug-in median. To replace with this posterior-propagated version, the
## appendix table should be re-built from summ_out using kable + threeparttable
## (or kableExtra), reporting cross_med [cross_q25, cross_q75] for the central
## estimate and [within_q05, within_q95] for the within-posterior 90% CI.
##
## Example draft for the central artisanal absolute landing column:
##
##   ifelse(is.na(within_q05), "",
##          sprintf("%.1f [%.1f, %.1f] {%.1f, %.1f}",
##                  cross_med, cross_q25, cross_q75, within_q05, within_q95))
##
## Felipe: dime si quieres que reemplace la tabla LaTeX estatica del apendice
## por una version que se compute on-the-fly desde este CSV.
