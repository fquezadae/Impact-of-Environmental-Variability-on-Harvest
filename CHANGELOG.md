# Changelog

Notable changes to the project, in reverse chronological order.

## 2026-04-30 (paper1: direct weather channel, year FE, dual-jurel, MRE front matter & intro pivot)

This entry consolidates a single-day push that closes the manuscript for the
MRE submission target (end May 2026). All bullets refer to paper 1 unless
stated otherwise.

### Added — direct weather channel (vessel-specific, empirical CDF)

- Closes the inconsistency in §3.4: the manuscript had promised both an
  *indirect* (biomass) and a *direct* (weather) climate channel, but the
  T7 ensemble code was propagating only the indirect one. The direct
  channel now translates CMIP6 `Δuas`, `Δvas` deltas into vessel-specific
  `Δdays_bw` (bad-weather days) via each vessel's empirical CDF of historical
  wind speeds at the COG, evaluated at the 8 m/s threshold; the resulting
  vessel-level `Δdays_bw` is multiplied by `β_w^g` from the NB trip
  equation and combined multiplicatively with the indirect biomass factor.
- New helper: `R/08_stan_t4/_weather_channel_utils.R` (~280 lines, ASCII only).
  Implements: COG mapping for each vessel, historical and projected
  `days_bw` per CMIP6 grid cell, vessel-level `Δdays_bw` with file cache.
- Modified: `R/08_stan_t4/13_trip_comparative_statics.R`. Output schema
  extended with `delta_days_bw`, `factor_trips_ind` (indirect-only), and
  `factor_trips` (combined). Adds `t6_compute_factor_trips(beta_weather,
  vessel_delta_dbw)`.
- Modified: `R/08_stan_t4/_compstat_utils.R` — comment update flagging
  that `wind_speed` columns in the deltas CSV are now consumed by
  `_weather_channel_utils.R`.
- Caveat (documented in §5 7th caveat and Appendix G caption): CESM2 has
  no `uas/vas` data on the standard grid, so the direct channel is
  evaluated on the 5-model subset; the indirect channel uses all six
  models.

### Added — year fixed effects in the NB trip equation (primary spec)

- The primary trip equation now includes `factor(year)` to absorb
  aggregate non-climate shocks contemporaneous with the panel — most
  consequentially the *estallido social* of 2019 and the COVID-19 period
  2020–2022, which were contaminating the cross-year identification of
  `β_w^ART`.
- Magnitude effect on `β_w^ART`: halved from `-0.0018` (no FE) to
  `-0.0008` (with FE). Sensitivity comparison printed at the end of the
  estimation chunk (`sens_ind`, `sens_art` data frames). The relative
  trip projection `T_v^FUT / T_v^HIST` does not depend on the year-FE
  values themselves (they cancel in the ratio), so the comparative
  statics are robust to this choice.
- Modified: `R/04_models/poisson_model.R` — dataset construction
  unchanged, retains the documented `expand_grid` proxy 151/182 closure
  variable. The §5 5th caveat now cites the full regulatory chronology
  (D.Ex. 115/1998 + 5 modifications + 530/2016 + 137/2021 + 05/2024).
- Modified: `paper1/paper1_climate_projections.Rmd` chunks `est_poisson`
  and `tabla_poisson`. The NB table now omits year-FE coefficients via
  `omit = "factor\\\\(year\\\\)"` and reports the FE inclusion in the
  add-lines block. Three pseudo-R² are computed in the estimation chunk
  (McFadden, Cragg-Uhler/Nagelkerke, deviance R²); **Cragg-Uhler is the
  one displayed** (0.282 IND, 0.611 ART) as it is bounded on [0,1] and
  the most OLS-like for reviewers; the others are emitted via `message()`
  for diagnostic logging.
- §4.3.3 numbers updated end-to-end: ART −8.1% to −10.2% marginal,
  −2.1% to −2.7% conditional; IND −0.7% to −1.1% marginal, −0.7% to
  −0.8% conditional. Marginal asymmetry **~11:1**; conditional **~3.4:1**.
- §4.3.1 and §4.2 prose reformulated; the footnote that previously
  said `β_closures^ART` was "expected to become negative" was removed.

### Added — Appendix E.4 dual-source jack mackerel state-space (triple-evidence package)

- New Stan program: `paper1/stan/t4b_state_space_full_dualjurel.stan`
  (~280 lines). Augments the T4b-full model with a second observation
  equation for the jack mackerel Northern Chilean acoustic biomass
  series (IFOP, 2010–2024), sharing `ρ^SST_jurel` and `ρ^CHL_jurel` with
  the CS state. Driver: `R/08_stan_t4/08b_fit_t4b_full_dualjurel.R`.
- Source data: new `data/bio_params/catch_jurel_norte_chile.csv` (25 years
  × 5 northern Chilean regions, 3.34 Mt total over 2000–2024) and 14 new
  rows of `jurel_norte` appended to
  `data/bio_params/acoustic_biomass_series.csv`. CS↔Norte log-correlation
  is 0.88 over the 2010–2024 overlap.
- Outcome: identification of `(ρ^SST_jurel, ρ^CHL_jurel)` does **not**
  close. `σ_post/σ_prior ∈ {0.94, 0.99}`, well above the 0.7 threshold
  used for anchoveta and sardine. Confirms that the bottleneck is
  *structural*, not sample size.
- Manuscript: `paper1/sections/appendix_spatial_jurel.Rmd` extended with
  a new subsection "Dual-source extension" (after the spatial-domain
  table, ~line 260). The "Implication for the main claim" paragraph is
  reformulated to package three lines of evidence: (i) spatial-domain
  robustness across D1/D2/D3, (ii) dual-source CS+Norte fit, (iii)
  OROP-PS coherence (CS vs SPRFMO transzonal index, *r* = 0.11 over
  *N* = 17 overlapping years).
- Convention: jack mackerel is reported as `n.i.` in all manuscript
  tables and figures; raw CSV outputs preserve the numerical posteriors
  for reproducibility (see `project_jurel_ni_convention.md`).

### Changed — comparative statics post direct channel + year FE

- Table 5 (`tab:trip_compstat`) regenerated with both channels active
  and the year-FE NB. Cross-median across 6-model CMIP6 ensemble:
  - **Artisanal:** mid SSP2-4.5 −8.1% (cond −2.1%); end SSP5-8.5
    −10.2% (cond −2.7%). Pr(portfolio loss > 50%) = 0.95 / 0.99.
  - **Industrial:** mid SSP2-4.5 −0.7% (cond −0.7%); end SSP5-8.5
    −1.1% (cond −0.8%). Pr(portfolio loss > 50%) = 0.12.
  - Asymmetry: ~11:1 marginal, ~3.4:1 conditional.
- Appendix G (`appendix_g_trips_variance_decomposition`) re-run on the
  post-direct-channel output. Within-model variance now dominates at
  **97–100%** (was 96–100%) across all SSP × period × fleet cells; the
  floor-effect saturation message is unchanged. The narrow cross-IQR in
  Table 5 is *not* climate-model consensus — it is the
  fleet-mechanical floor `T → exp(−β_g · H^alloc_v)` once `f^H_v → 0`.

### Changed — front matter, intro, and section labels for MRE

- **Editorial target switched JAERE → MRE.** Decision date 2026-04-30
  PM late, post triple-evidence jurel + regulatory-chronology
  consolidation. Justification: bioeconomic content dominates and the
  identification-of-shifters narrative reads more naturally for MRE's
  resource-economics audience. ERE retained as Plan B. Paper 2 reserved
  for JAERE/ERE 2027–2028.
- **Title** changed to "Differential Climate Impacts on Fishing Effort
  in Chilean Small Pelagic Fisheries" (11 words; MRE limit is 6–12).
- **Abstract** rewritten to 140 words (MRE limit is 150). Closes with a
  policy implication on cross-sector quota transferability rules.
- **Running head** added via `fancyhdr`: "Asymmetric Climate Impacts on
  Fishing Effort" (45 chars). Headrule `0.4pt`, small-caps small font.
- **Author affiliation** now in `\thanks{}` footnote on the first page
  (associate professor + Department of Economics + Universidad de
  Concepción + mailing address Victoria 471 + email). Hyperlink markup
  removed because pandoc loads `hyperref` after `header-includes`, so
  `\href{}` was undefined at the point `\thanks` is processed; the email
  is autolinked by pandoc's `autolink_bare_uris` instead. The `\affil{}`
  short form retains "Universidad de Concepción".
- **Keywords** (7, alphabetical): Bayesian state-space model;
  Bioeconomic projection; Chilean small pelagic fishery; Climate change;
  Fishing effort; Fleet heterogeneity; Quota allocation. **JEL Codes:**
  Q22, Q54, Q57, Q58. Both blocks rendered below the abstract via new
  `\keywords{}` and `\jelcodes{}` commands defined in
  `header-includes`.
- **Introduction** rewritten in the MRE house style: 5 paragraphs, ~700
  words (was ~1,100 across 4 paragraphs). Structure: (i) policy hook on
  quota-allocation regimes calibrated under stationary climate as
  unscripted reallocation under fleet-asymmetric shocks; (ii) Chilean
  SPF setting with LMCA institutional detail; (iii) structural
  identification strategy (Cowles framing, two channels, CMIP6 ensemble);
  (iv) headline results (asymmetry 11:1, jurel n.i., 97–100% within);
  (v) roadmap. All citations preserved.
- Legacy hardcoded keywords block immediately above `# Introduction`
  removed (had 6 non-MRE keywords carried over from an earlier draft).
- Front matter YAML: `\fancyhead`, `\affil`, `\newcommand`, and other
  lines containing `:`, `[`, or `]` are now wrapped in double quotes
  with escaped backslashes to satisfy the YAML scanner (which had been
  parsing the email's `:` as a mapping separator).

### Changed — slides for ICES/PICES Small Pelagic Symposium (La Paz, 8 May 2026)

- `slides/slides_PICES.Rmd` updated to reflect the day's results:
  - "A negative binomial model" slide: NB equation now shows `α_y^g`
    year FE term; right panel rewritten as "Two channels to projections"
    (indirect via `ρ^SST, ρ^CHL → B → H^alloc`; direct via vessel CDF).
  - "What drives fisher participation" footnote: notes year-FE absorbs
    estallido + COVID and that `β_w^ART` halves with FE.
  - "Comparative statics — fleet asymmetry": table updated with
    marginal *and* conditional columns; ART −8.1%/−10.2% and
    −2.1%/−2.7%, IND −0.7%/−1.1% and −0.7%/−0.8%; Pr(portfolio loss).
    Asymmetry ~11:1 marg, ~3.4:1 cond.
  - **New slide** "Two channels: direct vs indirect" with a HTML
    decomposition table for end-century SSP5-8.5 (indirect ≈ −9.0pp +
    direct ≈ −1.2pp ART vs −1.0pp + −0.1pp IND).
  - "Appendix D — Why is jack mackerel n.i.?": restructured as the
    triple-evidence package (spatial-domain robustness, dual-source
    biomass, OROP-PS coherence).
  - "Appendix H — variance decomposition": 96% → **97–100% within**
    post-direct-channel.
  - Takeaways: ~9:1 → marginal **11:1**, conditional **3.4:1**, with
    explicit mention of both channels.

### Open econometric questions (documented; not changed)

- **Vessel fixed effects.** Considered and rejected: collinear with
  the vessel-time-invariant covariates (`log_bodega`, `TIPO_EMB`),
  breaks identification of `β_w` (which is largely cross-vessel × year
  in the artisanal panel), and would force an extreme reduction in
  effective sample for IND (N = 319 vessel-years across 40 vessels).
  See `project_open_questions_2026_04_30.md`.
- **Northern biomass in the likelihood for paper 1.** Considered and
  rejected. Including `B_jurel_norte` as a second observation in the
  state-space increases sample for the jurel CS state but does *not*
  change identification (Appendix E.4 confirms `σ_post/σ_prior` stays
  near 1). Reserved for paper 2's range-wide game-theoretic extension.

## 2026-04-29 PM tarde (paper1: SERNAPESCA v3 official catch series + IFOP panel sanity)

### Changed — catch series upgraded to SERNAPESCA v3 (all-gear official 2000-2024)

- `data/bio_params/catch_annual_cs_2000_2024.csv` regenerated from the
  SERNAPESCA `BD_desembarque.csv` database (transparency request
  AH010T0006857; filed 24 April 2025, responded 5 May 2025 via official
  letter DN-02040/2025, archived in
  `data/bio_params/refs/sernapesca_v3/ah010t0006857.pdf`). Replaces the
  v2 hybrid (SERNAPESCA 2000-2023 + IFOP-cerco 2024 placeholder).
- New generator: `R/01_data/99b_aggregate_catch_cs_from_sernapesca_v3.R`.
  Filters: regions V-X plus Ñuble (8 administrative regions); species
  Anchoveta / Sardina común / Jurel; agents Industrial + Artesanal
  (excludes Acuicultura and Fábrica). Path resolution tries 4
  candidate locations to support running from the local repo, the
  user's OneDrive raw archive, or the Cowork sandbox.
- New provenance directory: `data/bio_params/refs/sernapesca_v3/` with
  the official letter PDF (171 KB; tracked) and a `README.md`
  documenting the source files, request scope, processing pipeline,
  and citation block. The bulk CSVs/XLSX (~20 MB combined) are kept
  outside the repo for size; locations documented in the README.
- Diff v3 vs v2 across the 75 cells (3 stocks x 25 years): worst
  -0.0195% (172 t in 882 kt jurel 2024). Zero cells with |diff| > 1%.
  The IFOP-cerco placeholder for 2024 was ex-post nearly exact because
  purse-seine accounted for >99.5% of total Centro-Sur landings in 2024
  for the three target species. **No re-fit required:** T4b posteriors,
  NB trip equation, T5 / T7 / Apéndice F / Apéndice G are all
  unaffected at the reported precision.
- Manuscript Data and code availability statement (L757) updated to
  cite the SERNAPESCA transparency request explicitly and reference
  the new generator script. The deprecated v2 generator
  (`99_aggregate_catch_cs_from_xlsx.R`) is preserved for traceability
  but no longer the canonical path.

### Added — IFOP panel sanity vs SERNAPESCA vessel-level (auxiliary xlsx)

- Cross-validation of the trip-equation panel (`poisson_dt.rds`,
  built from IFOP logbooks) against the SERNAPESCA vessel-level
  pelagic landings (`AH010T0006857_*pelagicos_2012_2024.xlsx`,
  delivered as part of the same transparency request) for the
  2013-2024 Centro-Sur sample.
- **Industrial fleet** — coverage and composition match within
  tolerance: 40 IFOP vessels of 59 in SERNAPESCA (68% by count, >90%
  by catch); catch-weighted omega_jur 0.878 IFOP vs 0.857 SERNAPESCA
  (gap 2pp); aggregate jurel landings -10.3% (within sample noise).
  **No correction needed**.
- **Artisanal fleet** — the IFOP panel represents the purse-seine
  artisanal subset, not all-ART: 859 IFOP vessels of 2,689 in
  SERNAPESCA (32% by count, ~70% by catch). Catch-weighted aggregate
  omega_jur 0.021 IFOP vs 0.052 SERNAPESCA (factor 2.5x). The gap
  reflects a structural bimodality: 54% of SERNAPESCA-ART catch
  comes from vessel-years with zero jurel landings (purse-seine
  vessels targeting the anchoveta-sardine pair) and 46% from
  vessel-years with non-zero jurel (lampara, lines, fixed nets).
  IFOP logbooks cover the first segment systematically and the
  second segment only marginally. Filtering SERNAPESCA-ART by
  vessel-year catch threshold (50 / 100 / 200 / 500 / 1000 t) does
  *not* close the gap — confirms population mismatch rather than
  size mismatch.
- **Implication.** The panel's portfolio weights $\omega_{v,s}$
  correctly describe the purse-seine fleet that operates under the
  LMCA architecture. Smaller artisanal vessels using non-purse-seine
  gears (~30% of total CS artisanal landings; higher proportional
  jurel exposure) are not modeled in the trip equation but appear in
  the SERNAPESCA all-gear landings used as the biomass likelihood
  input. The fleet asymmetry of Table 5 is unchanged in direction;
  only the artisanal exposure is moderately attenuated (ART
  protection by the n.i. jurel anchor is roughly 3 percentage points
  larger in the broader all-ART universe).

### Manuscript edits

- §3.3.2 Total annual trips (after the "approximately 95% of observed
  fishing revenue" sentence): inserted the SERNAPESCA cross-validation
  paragraph with sample sizes and the explicit purse-seine restriction.
- §5 Discussion: added a sixth limitation paragraph documenting the
  panel-coverage caveat, parallel to the fifth (zone-only closure
  variable). Cites the SERNAPESCA cross-validation as confirming the
  panel's representativeness for the purse-seine artisanal subset and
  flags the all-gear sample-weighting extension as future work.
- §6 Data and code availability: catch-source citation upgraded to
  reference SERNAPESCA explicitly (request AH010T0006857) and the new
  generator script.



### Fixed — chlos units bug in `R/06_projections/01_cmip6_deltas.R`

- **Symptom (pre-fix).** `data/cmip6/deltas_ensemble.csv` reported
  `delta = 0` for `var = "logchl"` in 5 of 6 CMIP6 models
  (CESM2, CNRM-ESM2-1, GFDL-ESM4, MPI-ESM1-2-HR, UKESM1-0-LL); only
  IPSL-CM6A-LR carried non-zero chl deltas. Bug went undetected by the
  existing sanity check (`R/06_projections/00b_sanity_check_ensemble.R`)
  because `|delta| < log(2)` is satisfied vacuously when delta = 0.
- **Root cause.** `agg_year_mean()` applied a floor of `pmax(., 0.01)`
  before `log()` to handle below-detection cells. The floor is
  numerically valid in mg m-3 (the unit of chl in the Copernicus L4
  ocean colour product on which T4b's `logCHL_c` is identified). CMIP6
  publishes `chlos` in **kg m-3** (SI standard) for 5 of 6 ensemble
  models — IPSL is the exception, publishing in mg m-3. Realistic chl
  in kg m-3 (1e-7 to 1e-6) falls always below the floor of 0.01,
  saturating to `log(0.01) = -4.605` for every grid-cell-year, which
  drives `baseline_mean = future_mean` exactly and `delta = 0` per
  arithmetic identity.
- **Fix.** `read_cmip6_var()` now reads the `units` attribute of the
  `chlos` netCDF variable and converts to mg m-3 before downstream
  aggregation:
    `kg m-3 → x 1e6`,
    `g m-3 → x 1e3`,
    `mg m-3 → x 1` (no-op).
  Heuristic fallback for unrecognised units strings: if
  `median(|arr|) < 1e-3`, assume kg m-3 and apply x 1e6 (with warning);
  otherwise assume mg m-3. Each `chlos` file processed during a run now
  prints `[chlos units] <file>: units='<str>' -> x<scale> -> mg/m3`
  to console for audit.
- **Confirmation by run output.** Post-fix run (2026-04-29 PM) confirmed
  IPSL-CM6A-LR `units='mg m-3'` (x1, no conversion); the other five
  models `units='kg m-3'` (x1e6 each). `00b_sanity_check_ensemble.R`
  passed all asserts.
- **Numerical impact (cross-model summary, post-fix):**
    - `logchl ssp245 mid`: mean +0.005 +/- 0.038 (was 0 mechanical)
    - `logchl ssp245 end`: mean -0.022 +/- 0.052 (was 0 mechanical)
    - `logchl ssp585 mid`: mean +0.007 +/- 0.037 (was 0 mechanical)
    - `logchl ssp585 end`: mean -0.067 +/- 0.154, q05 = -0.297 (was 0)
  Cross-model q05 of -0.30 in SSP5-8.5 end-of-century is the most
  consequential change: combined with rho^CHL_anch = -2.3 it generates
  exp(0.69) ~ +99% offsets to the SST collapse in some posterior
  draws / models, and combined with rho^CHL_sard = +2.1 it deepens the
  sardine collapse.
- **Downstream re-runs required and executed:**
    - `R/08_stan_t4/12_growth_comparative_statics.R` (T5).
    - `R/08_stan_t4/13_trip_comparative_statics.R` (T7).
    - `R/08_stan_t4/16_appendix_f_variance_decomposition.R` (App F).
  T4b posteriors NOT refit (the bug was downstream of identification;
  shifters are unchanged).

### Refactored — `R/08_stan_t4/_compstat_utils.R` (new shared utilities)

- **Motivation.** T7 previously sourced the entire T5 script
  (`12_growth_comparative_statics.R`) to import `t5_load_scenarios()`
  and the `T5_*` constants. After the T5 ensemble rewrite, T5's main
  guard became default-TRUE for source(), so `source(T5)` from T7
  triggered a full T5 run as a side effect.
- **Solution.** Extracted shared symbols into a new module:
  `R/08_stan_t4/_compstat_utils.R`. Contents:
    - Constants: `COMPSTAT_DELTAS_CSV`, `COMPSTAT_STOCKS`,
      `COMPSTAT_STOCK_LABEL`, `COMPSTAT_SSPS`, `COMPSTAT_WINDOWS`,
      `COMPSTAT_SCENARIO_LABEL`, `COMPSTAT_NON_IDENTIFIED_STOCKS`.
    - Function: `compstat_load_scenarios()` returning the per-model
      scenario tibble `(model, scenario, window, scenario_key, DSST,
      DlogCHL)`.
- **Wiring.**
    - `12_growth_comparative_statics.R`: now sources
      `_compstat_utils.R`; `T5_*` constants are aliases of `COMPSTAT_*`;
      `t5_load_scenarios()` is a thin wrapper around
      `compstat_load_scenarios()`.
    - `13_trip_comparative_statics.R`: now sources `_compstat_utils.R`
      directly (no longer sources T5). `T6_*` constants are aliases.
    - `16_appendix_f_variance_decomposition.R`: unchanged; still sources
      T5 with the option-toggle pattern (preserves `t5_extract_draws`,
      `t5_compute_r_eff`).
    - `17_appendix_g_trips_variance_decomposition.R` (new, see below):
      sources `_compstat_utils.R` and `13_trip_comparative_statics.R`
      with `t6.run_main = FALSE`.

### Added — Step 3a: T5 ensemble (`12_growth_comparative_statics.R`)

- Rewrite of T5 to iterate over all 6 CMIP6 models in
  `data/cmip6/deltas_ensemble.csv`. T4b posteriors reused from disk
  (`data/outputs/t4b/t4b_full_fit.rds`); only the cross-join changes.
  Inner: 16,000 draws x 22 (model, ssp, window) combos x 3 stocks ~ 1M
  rows.
- **Within-model** summary: `(stock, model, ssp, window)` with median,
  q05, q95, prob_decline.
- **Cross-model** summary: `(stock, ssp, window)` with median across
  models of the within-model medians, q25/q75 (cross-IQR), and median
  of the within-model q05/q95 (within posterior CI).
- **Outputs:**
    - `tables/growth_comparative_statics.csv` — formatted, n.i. for
      jurel.
    - `tables/growth_comparative_statics_raw.csv` — numeric cross-model.
    - `tables/growth_comparative_statics_by_model.csv` — long, one row
      per `(stock, model, ssp, window)`.
    - `figs/t4b/growth_ridgeline_cmip6.png` — 3x4 facet, one ridge per
      CMIP6 model in each scenario-window.
- **Sanity +1°C:** anchoveta -64.7%, sardine -93.7% — matches paper-old
  (-65% / -94%) confirming rho_sst structural identification preserved.
- **Headline post-fix numbers:** anch SSP5-8.5 end cross-median -89.6%
  (Pr_decline 0.99, was 1.00 pre-fix mechanically); sardine SSP5-8.5
  end -99.9% (Pr_decline 1.00).

### Added — Step 3b: T7 ensemble (`13_trip_comparative_statics.R`)

- Complete rewrite of T7 to iterate over the CMIP6 ensemble. Pipeline:
    `r_eff[d, s, m, c] = r_base[d, s] * exp(rho_sst[d,s] * DSST[m,c]
                                           + rho_chl[d,s] * DlogCHL[m,c])`
    -> `B_star = K * (1 - F_hist / r_eff)`
    -> `factor_B = B_star / B_hist`  (jurel override = 1.0)
    -> `factor_H[d, v, m, c] = sum_s omega_v_s * factor_B[d, s, m, c]`
    -> `factor_trips[d, v, m, c] = exp(beta_H[fleet(v)] * H_alloc_hist[v]
                                       * (factor_H - 1))`.
- Memory-safe per-vessel loop preserved. Inner table 16K x 22 = 352K
  rows; total `factor_trips_dt` = 292M rows; runs in ~50s on a modern
  laptop.
- **Within-model summary** at `(fleet, model, ssp, window)` collapsed
  over `(draws x vessels within fleet)`: marginal/conditional medians,
  q05/q95, Pr_loss, factor_H stats.
- **Cross-model summary** at `(fleet, ssp, window)`: median across
  models of the within-model medians, cross-IQR, within-CI averaged
  across models. Mirrors the T5 ensemble summary structure exactly.
- **Pr(extinct)** also reported with within-model + cross-model
  decomposition by `(stock, ssp, window)`.
- **Outputs (5 tables):**
    - `paper1/tables/trip_comparative_statics.csv` — formatted paper.
    - `paper1/tables/trip_comparative_statics_raw.csv` — numeric
      cross-model.
    - `paper1/tables/trip_comparative_statics_by_model.csv` — long,
      one row per `(fleet, model, ssp, window)`.
    - `paper1/tables/trip_comparative_statics_extinct.csv` — Pr(extinct)
      cross-model.
    - `paper1/tables/trip_comparative_statics_extinct_by_model.csv` —
      Pr(extinct) by model.
- **Headline numbers (cross-model):** asymmetry ART/IND robust to
  ensemble — ART -8.6% to -9.5% marginal (Pr_loss 0.95-0.99); IND -0.9%
  marginal (Pr_loss 0.12 stable across all four scenarios). Cross-IQR
  ~0.1pp in many cells, formally identified as a floor effect (see
  Appendix G below).
- **Main guard default-FALSE** for T7 (heavy run, avoid accidental
  trigger). Run with `options(t6.run_main = TRUE)`.

### Added — Appendix G new (`17_appendix_g_trips_variance_decomposition.R`)

- New script and child Rmd for the variance decomposition of the
  fleet-level trip response, paralleling Appendix F's decomposition for
  growth. Two-way decomposition under the law of total variance:
    `Var_total(%Delta T_f) = E_m[Var_(d,v)(%Delta T_f | m, fleet)]
                           + Var_m[E_(d,v)(%Delta T_f | m, fleet)]`
  where m = CMIP6 model, d = T4b posterior draw, v = vessel within
  fleet.
- The within-model component pools posterior + vessel heterogeneity by
  design (paralelism with F + vessel heterogeneity is a fixed feature
  of the fleet that does not shrink with more data). A 3-way
  decomposition that separates the three sources is available in the
  same `factor_trips_dt` and noted in the script for reviewer requests.
- **Headline result.** The within-model component dominates: 96% of
  total variance for ART under SSP2-4.5 mid-century, saturating at
  100% under SSP5-8.5 end-of-century. For IND: 98% rising to 100%.
  Between-model is at most 4% in the SSP2-4.5 mid-century cells,
  numerically zero (to the nearest percent) in the remaining 6 cells.
- **Reading.** This is *not* CMIP6 ensemble agreement on the climate
  signal; it is the mechanical signature of floor-effect saturation of
  the underlying Schaefer biomass collapse — once `factor_H ~ 0`, the
  trip response converges to `exp(-beta * H_alloc)`, a quantity
  determined by fleet business mechanics rather than by climate
  magnitude. The narrow cross-IQR in Table 5 of the main results is
  thus formally identified as a floor effect, not as climate consensus.
- **Outputs:**
    - `tables/appendix_g_trips_variance_decomposition.csv` — formatted.
    - `tables/appendix_g_trips_variance_decomposition_raw.csv` —
      numeric.
    - `figs/t4b/appendix_g_trips_variance_decomposition.png` — stacked
      bars.
- **Manuscript wiring.**
    - `paper1/sections/appendix_g_trips_variance_decomposition.Rmd` new
      child, with prose using inline `r ...` to auto-resolve numbers
      from the raw CSV (zero hardcoded numbers; robust to re-runs).
    - `paper1/paper1_climate_projections.Rmd`: child include after
      Appendix F. Prose updates in §3.2, §3.4, §4.3.3 footnote, §5
      Discussion (caveats), and §6 Conclusions to reference Appendix G
      as the companion of F.

### Re-ran — Appendix F variance decomposition (post-chlos-fix)

- `R/08_stan_t4/16_appendix_f_variance_decomposition.R` re-run with the
  corrected chl deltas. Sardine decomposition virtually unchanged
  (climate-bottleneck robust at 77-91% between in three of four cells);
  anchoveta decomposition shifted in SSP5-8.5 end-of-century from
  88% / 12% (within / between) pre-fix to **97% / 3%** post-fix, with
  `sd_total` rising from 0.196 to 0.339 (+73%). The chl heterogeneity
  cross-model amplifies the within-variance via
  rho^CHL_anch * DlogCHL, which is a structural signal not present in
  the pre-fix run.
- **New caveat** in `appendix_variance_decomposition.Rmd`: a paragraph
  documenting the systematic mean-vs-median divergence between
  Appendix F (mean -83.1% for anch SSP5-8.5 end, required by the law
  of total variance) and Table 4 (median -89.6%, robust to the
  collapse tail). The gap is left-skew driven; both are valid; we
  report median in the headline table and mean in the variance
  decomposition by construction.

### Updated — main manuscript (`paper1_climate_projections.Rmd`)

- **Table 5 chunk** (`tripcompstat`, L642-720): rewritten to consume
  the new cross-model schema of `trip_comparative_statics_raw.csv`.
  Table preserves the 5-column structure (Fleet, Scenario, Pr loss,
  marginal, conditional) but the bands are now cross-model
  median + cross-IQR. Footnote updated with the floor-effect caveat
  cross-referencing Appendix G.
- **Body prose §4.3.2:** anch SSP2-4.5 mid 45 -> 51%, sard 80 -> 79%;
  ΔlogCHL qualifier expanded ("near zero in cross-model median, with
  non-trivial inter-model spread"); SSP5-8.5 end now mentions the
  q05 ΔlogCHL = -0.30; "0.99 rather than 1" caveat added with
  mechanistic explanation.
- **Discussion §5 second caveat:** new paragraph closing on the
  Appendix G reading — narrow cross-IQR is floor effect, not climate
  consensus; marginal information value of expanding the CMIP6
  ensemble for fleet-level trips is small relative to tightening the
  structural posterior or refining vessel heterogeneity.
- **Conclusions §6 contribution 2:** new sentence on Appendix G as
  companion decomposition.
- **Cosmetic fix:** `16{,}000` -> `$16{,}000$` in
  `appendix_variance_decomposition.Rmd` (math mode forces the curly
  braces to render as invisible groupers, producing `16,000` in the
  PDF).
- **Cross-references** in §3.2 (data) and §3.4 (projection-approach)
  updated to mention "Appendix F for stock-level productivity and
  Appendix G for fleet-level trips".

### Files added / modified summary

- New: `R/08_stan_t4/_compstat_utils.R`,
  `R/08_stan_t4/17_appendix_g_trips_variance_decomposition.R`,
  `paper1/sections/appendix_g_trips_variance_decomposition.Rmd`.
- Modified: `R/06_projections/01_cmip6_deltas.R`,
  `R/08_stan_t4/12_growth_comparative_statics.R`,
  `R/08_stan_t4/13_trip_comparative_statics.R`,
  `paper1/paper1_climate_projections.Rmd`,
  `paper1/sections/appendix_variance_decomposition.Rmd`.
- Regenerated outputs: `data/cmip6/deltas_ensemble.csv`,
  all `tables/growth_comparative_statics*.csv`,
  all `paper1/tables/trip_comparative_statics*.csv`,
  `tables/appendix_f_variance_decomposition*.csv`,
  `tables/appendix_g_trips_variance_decomposition*.csv`,
  `figs/t4b/growth_ridgeline_cmip6.png`,
  `figs/t4b/appendix_f_variance_decomposition.png`,
  `figs/t4b/appendix_g_trips_variance_decomposition.png`.

## 2026-04-27 (paper1: Appendix A stress tests + Appendix D convergence + double-numbering cleanup)

### Added — Appendix A (reduced-form stress tests + prior elicitation protocol)

- `paper1/sections/appendix_stress_tests.Rmd`: new child with heading
  `# Reduced-form stress tests and prior elicitation {#appendix-stress}`
  formalising the protocol used to elicit the priors on
  $(\rho_i^{SST}, \rho_i^{CHL})$. Four subsections:
  **Hindcast specification** (deterministic Schaefer with log-linear
  shifter on $r$, biological parameters $(r^0, K)$ fixed at IFOP/SPRFMO
  prior centres, bounded LS on $[-3, 3]^2$),
  **Cross-variant fit results** (Tabla \ref{tab:stress-mape}: median
  absolute percent error by stock × variant; finding: 0/3 stocks cross
  the 20% MAPE threshold under any linear shifter combination),
  **Identifiability diagnostic** (Pearson $r(\text{SST},\log\text{CHL}) = 0.030$
  rules out collinearity; jurel $\rho^{CHL}$ pins at $-3$ boundary;
  diagnostic motivates the move to Bayesian state-space with weakly
  informative priors), and
  **Translation to Bayesian priors** (Tabla \ref{tab:stress-priors}:
  $\mu_{\rho}$ from joint MLE rounded to one decimal, $\sigma_{\rho}=1.0$
  for all stocks; jurel vague $N(0,1)$; no hierarchical pooling because
  $\rho^{CHL}$ flips sign between anchoveta and sardina común).
  Reuses pre-computed outputs from `R/07_structural_bio/09_stress_test_sst.R`
  (`data/bio_params/qa/hindcast_sst_comparison.csv` and
  `hindcast_sst_trajectories.png`).
- `paper1/paper1_climate_projections.Rmd`: new child include
  `appendix-stress` added at the top of the
  `# (APPENDIX) Appendix {-}` block, ahead of B and C, so that Appendix A
  numbering matches the existing prose references at L230 (jurel
  observation structure) and L275 (prior elicitation protocol).
- Closes item L374 of the revision plan
  (`paper1/paper1_revision_plan.md`).

### Added — Appendix D (Markov-chain convergence diagnostics)

- `paper1/sections/appendix_convergence_diagnostics.Rmd`: new child
  with heading
  `# Markov-chain convergence diagnostics {#appendix-convergence}`.
  Reads `data/outputs/t4b/t4b_full_summary.csv` and reports the
  within-group worst case (max split-$\hat{R}$, min bulk- and tail-ESS)
  for each family of top-level parameters of the T4b-full posterior:
  $r_i^0$, $K_i$, $B_{i,0}$, $\sigma_{\text{proc},i}$,
  $\sigma_{\text{obs},i}$, $\rho_i^{SST}$, $\rho_i^{CHL}$, and the three
  unique off-diagonal elements of $\Omega$. All $N=24$ top-level
  parameters satisfy the conventional thresholds ($\hat{R} \leq 1.01$,
  bulk- and tail-ESS $\geq 400$). The worst case is at
  $\sigma_{\text{obs},3}$ (jack mackerel observation noise) with
  $\hat{R} = 1.009$ and tail-ESS = 936, attributable to the seven
  non-surveyed years and the two left-censored 2012 and 2015
  observations of the jack-mackerel series. The three primary
  identification parameters $(\rho_i^{SST}, \rho_i^{CHL})$ all attain
  $\hat{R} \leq 1.001$ and bulk-ESS above 8,300. Replaces the earlier
  textual claim of L275 with explicit numbers.
- `paper1/paper1_climate_projections.Rmd`: new child include
  `appendix-convergence` added after `appendix-posterior` in the
  appendix block (so the rendered order is A → B → C → D).
- `paper1/sections/appendix_posterior_diagnostics.Rmd`: tail paragraph
  reworded to point to the new Appendix D via
  `\ref{appendix-convergence}` (was previously a dangling reference to
  "the replication repository").
- Closes item L376 of the revision plan.

### Changed — Double-numbering removed from appendix subsections

`bookdown` numbers subsections under `\appendix` automatically (A.1,
A.2, B.1, …); the existing children carried hardcoded prefixes in their
`##` headings, producing rendered output of the form
"A.1 A.1 Hindcast specification". Prefixes removed throughout:

- `paper1/sections/appendix_stress_tests.Rmd`: 4 headings.
- `paper1/sections/appendix_predictive_diagnostics.Rmd`: 2 headings
  (`B.1 PSIS-LOO …`, `B.2 PSIS-LFO …`).
- `paper1/sections/appendix_posterior_diagnostics.Rmd`: 2 headings
  (`C.1 Smoothed biomass …`, `C.2 Year-level residuals`).

The label IDs (`#sec:appendix-stress-spec` etc.) and all
cross-references via `\ref{}` are unchanged.

### Changed — Stress-test figure regenerated in English

- `R/07_structural_bio/09_stress_test_sst.R`: facet panels relabelled
  from `anchoveta_cs / jurel_cs / sardina_comun_cs` to
  `Anchoveta / Sardina común / Jack mackerel` and forced into
  biological order (anchoveta → sardina común → jack mackerel, no longer
  alphabetical). Series legend translated:
  `Observado / Baseline (sin env) / + SST restringido / + CHL restringido / + SST & CHL restringido`
  → `Observed / Baseline (no shifter) / + SST / + log CHL / + SST and log CHL`,
  matching the column headers of Tabla \ref{tab:stress-mape}. Title
  and subtitle removed (the figure caption already describes the
  content). Axes: `Año / Biomasa (mil t)` → `Year / Biomass (thousand t)`.
- `data/bio_params/qa/hindcast_sst_trajectories.png` re-saved with the
  English layout; pixel dimensions unchanged (10×11 in @ 150 dpi).

## 2026-04-24 — later (paper1: long-run trip comparative statics + Appendix C + Schaefer clarification)

### Added — Step B: long-run trip comparative statics (§4.4)

- `R/08_stan_t4/13_trip_comparative_statics.R`: new script that
  propagates the T4b-full posterior through a Schaefer steady-state
  biomass equation under historical average fishing pressure and
  through the negative binomial trip equation to obtain vessel-level
  and fleet-level responses of annual trips to CMIP6 climate regimes.
  Pipeline:
  `r_eff → B_star = K*(1 - F_hist/r_eff) → factor_B → factor_H = Σ_s ω_vs · factor_B_s`
  → `factor_trips = exp(β_H[fleet(v)] · H_alloc_hist[v] · (factor_H - 1))`.
  The semi-elasticity form reflects that `H_alloc_vy` enters the NB in
  levels, not logs. Jurel treated as non-identified by convention
  (`factor_B_jur = 1.0`). Stock vessel-level realized catch shares
  (`omega`) constructed on the fly from `H_33` / `H_114` / `H_26`
  columns in `data/trips/poisson_dt.rds`. Three outputs aggregated
  over posterior draws × vessels within fleet: (i) marginal median of
  %Δ trips (all draws), (ii) `Pr(f_H < 0.5)` as portfolio-loss
  probability, (iii) conditional median restricted to non-collapse
  draws. Outputs: `paper1/tables/trip_comparative_statics.csv`,
  `trip_comparative_statics_raw.csv`, and
  `trip_comparative_statics_extinct.csv`.
- `paper1/paper1_climate_projections.Rmd` §4.4 "Implications for
  fleet-level effort": new chunk `tripcompstat` producing
  `tab:trip_compstat` with the three-column layout
  (Pr-loss / %Δ-marginal / %Δ-conditional) by Fleet × Scenario.
- **§4.4 narrative rewrite**: three new paragraphs replacing the
  previous qualitative "Implications for fleet-level effort"
  subsection. Reports: (i) artisanal fleet portfolio loss probability
  above 0.95 under every CMIP6 scenario, (ii) asymmetry ART/IND of
  9:1 in marginal trips decomposed into ~1.0 probability of portfolio
  collapse × ~1.0 conditional elasticity ratio, and (iii) three
  caveats on Schaefer steady-state thought experiment, the baseline
  non-equilibrium of the 2000–2024 window (`f_H ≈ 1.015` under zero
  climate delta), and the observational equivalence between "jurel
  climate-decoupled" and "forcing outside the Centro-Sur box".

### Added — Appendix C (posterior-predictive checks)

- `paper1/sections/appendix_posterior_diagnostics.Rmd`: new child
  with heading `# Posterior-predictive checks {#appendix-posterior}`.
  Two sections: **C.1** overlays posterior median + 90% band of
  smoothed latent biomass against observed SSB for the three stocks
  (`figs/t4b/t4b_full_smooth_vs_obs.png`), with median 90% band width
  ≈ 20% of the mean; **C.2** shows standardised year-level residuals
  by stock (`figs/t4b/t4b_full_residuals.png`) with first-order
  autocorrelation below 0.2 in absolute value for all three stocks.
  Trace plots and R-hat values referred to the replication repository.
- `paper1/paper1_climate_projections.Rmd`: new child include
  `appendix-posterior` added under the existing
  `# (APPENDIX) Appendix {-}` marker, after `appendix-predictive`.
- `paper1/sections/results_identification.Rmd` (§4.1): the previously
  commented `Posterior-predictive adequacy` paragraph (L207–225) is
  now activated and points to `\ref{fig:ppc-smooth-vs-obs}`,
  `\ref{fig:ppc-residuals}`, and
  `Appendix \ref{appendix-posterior}`.

### Changed — §3.3 Schaefer clarification (structural alignment with Stan)

- **§3.3 Stock dynamics**: replaced "Pella–Tomlinson surplus-production
  function" with "Schaefer surplus-production function" throughout,
  consistent with `paper1/stan/t4b_state_space_full.stan` which
  implements `g = r_t * B * (1 - B/K)` (the `θ = 1` special case).
  New justification sentence: *"Schaefer is adopted as the θ = 1
  specialization of the Pella–Tomlinson family on identifiability
  grounds: the shape parameter θ is notoriously weakly identified
  with N = 25 annual observations per stock"*, citing
  `@hilbornWalters1992` and `@maunderPunt2013` (new entries in
  `paper1/bibliography.bib`).
- **Equation 1 (eq:law-of-motion)**: simplified from the Pella–Tomlinson
  form `r·B·[1 − (B/K)^θ]` to the Schaefer form `r·B·(1 − B/K)`. The
  parameter tuple `(r_i^0, K_i, θ_i, σ_proc,i, σ_obs,i)` reduced to
  `(r_i^0, K_i, σ_proc,i, σ_obs,i)` throughout §3.1, §3.3, and related
  discussion.
- **`results_loo_comparison.Rmd` L3**: `"three nested specifications
  of the Pella–Tomlinson state-space model"` → `"... of the Schaefer
  state-space model"`. Residual detected in post-B.3.5 audit (C.1).

### Added — bibliography

- `paper1/bibliography.bib`: two new entries.
  - `hilbornWalters1992`: Hilborn & Walters, *Quantitative Fisheries
    Stock Assessment*, Chapman and Hall 1992, ISBN 978-0-412-02271-5.
    No DOI (multiple reprints with different DOIs; ISBN suffices).
  - `maunderPunt2013`: Maunder & Punt, *A review of integrated analysis
    in fisheries stock assessment*, Fisheries Research 142 (2013)
    61–74, doi 10.1016/j.fishres.2012.07.025 (DOI verified).

### Fixed — knit-breaking issues encountered and resolved

- **`tab:trip_compstat` row gap between Artisanal and Industrial
  fleets**: `booktabs` injects `\addlinespace` every five rows by
  default, which produced a spurious gap between rows 5 and 6 of the
  eight-row table. Fixed by passing `linesep = ""` to the `kable()`
  call.
- **`\ref{identification}` literal text inside `kableExtra::footnote`**:
  the reference inside the `tab:trip_compstat` footnote rendered as
  `\ref{identification}` in the PDF because `footnote(escape = TRUE)`
  strips the backslash. Replaced with plain prose
  (*"consistent with the identification discussion in the Results
  section"*) — same gotcha already documented in the earlier
  `tab:growth_compstat` footnote.
- **`HOLD_position` vs `hold_position`**: briefly introduced
  `latex_options = c("HOLD_position")` in the `tripcompstat` chunk,
  which emits `\begin{table}[H]` and requires `\usepackage{float}` in
  the preamble (not loaded in this repo). Reverted to
  `hold_position`; the `linesep = ""` fix alone eliminated the gap.

### Fixed — manuscript integrity (late audit, C.1)

- No residual mentions of `Pella–Tomlinson`, `θ_i`, or `shape parameter`
  outside the intentional justification sentence in §3.3. Confirmed by
  `grep` across `paper1_climate_projections.Rmd` and all child sections.

## 2026-04-24 — morning (paper1: Cowles pivot executed, SUR benchmark removed)

### Changed — manuscript rewrites (paper1/paper1_climate_projections.Rmd)

- **Abstract**: rewritten to reflect the Cowles-style structural
  identification. Previous version reported SUR + NB results with
  artisanal +20--250% / industrial -22% under caps [0.2, 3.0]; new
  version reports posterior medians of Δr/r0 under CMIP6 (anchoveta
  -51% to -89%, sardina -90% to -100%, jurel n.i.) and reverses the
  distributional sign: the artisanal fleet is *more* exposed via its
  concentration in the sardina–anchoveta pair, not less.
- **§1 Introduction (contribution paragraph)** and **§3 opener**:
  rephrased around Bayesian state-space identification of
  (ρ^SST, ρ^CHL) semi-elasticities; reduced-form SUR language removed.
- **§3.3 Stock dynamics** (`{#sec:stock-dynamics}`): rewritten with
  Pella–Tomlinson transition + log-linear climate shifter +
  log-normal observation equation as the primary apparatus. Old
  equations `eq1`, `eq2`, `eq2b` removed; new `eq:law-of-motion`,
  `eq:shifter`, `eq:obs` introduced.
- **§3.1 Observation structure for jack mackerel Centro-Sur biomass**
  (renamed from `Imputation of missing jack mackerel biomass`):
  describes the 16 uncensored + 2 censored + 7 latent structure of
  the Stan likelihood. Gamma-GLM imputation procedure no longer used
  by the structural model; only the correlations of CS with the
  Northern and SPRFMO series are retained as descriptive context,
  flagged explicitly as suggestive not conclusive given `N = 7`.
- **§3.4 Projection approach**: indirect channel re-described as
  evaluation of the identified shifter at the posterior of
  (ρ^SST, ρ^CHL); old SUR comparative-statics phrasing removed.
- **§4.4 Climate change projections** (`{#projections}`): completely
  rewritten. V1 chunks deleted (`biomassprojections` with
  `tab:biomass_proj`, `decompositiontable` with `tab:decomposition`,
  `projfigure` with the stacked bar plot, `load_projections` with
  the V1 RDS imports). New `growthcompstat` chunk reads
  `paper1/tables/growth_comparative_statics.csv` and builds
  `tab:growth_compstat`. New `growthridgeline` chunk includes
  `figs/t4b/growth_ridgeline_cmip6.png` as the ridge-plot of
  Δr/r0 under CMIP6. Subsection "Implications for fleet-level effort"
  made qualitative (forward simulation of biomass trajectories and
  the decomposition of trips by channel deferred to the companion paper).
- **Discussion** and **Conclusions**: rebuilt around the structural
  identification of shifters and the non-identification of
  ρ_jurel_SST, ρ_jurel_CHL as a substantive result. Caveats updated
  to reflect the new aparatus (log-linear extrapolation, 25-year
  time series, propagation of process/observation noise).

### Removed — SUR reduced-form benchmark

- **§4.1 "Stock biomass model"** with all SUR estimation chunks
  (`database_for_biomass_est`, `sur_data`, `sur_estimation`,
  `sur_robustness_specs`, `build_table_helper`,
  `model_selection_table`, `SUR_results`), the `fix_stargazer_notes`
  wrapper usages, and the narrative that interpreted the SUR
  coefficients. Result: ~470 lines lighter.
- **Appendix "Additional robustness checks"** with the three SUR
  robustness panel chunks (`SUR_rob_panel_A`, `SUR_rob_panel_B`,
  `SUR_rob_interactions`) and their narrative. Result: the main Rmd
  appendix now contains only Predictive diagnostics (LOO + LFO).
- **Cap `[0.2, 3.0]`** on harvest allocation scaling and all language
  around it. The cap mechanically masked explosive forward-simulation
  behaviour of the SUR reduced form and is incompatible with the
  structural specification.

### Added — archival

- `paper1/deprecated/sur_benchmark_deprecated.Rmd`: complete archive
  of the removed SUR block (§4.1 and the three robustness panels),
  with a deprecation header explaining the three reasons for removal
  (forward simulation explodes with β ≥ 1; qualitative contradiction
  with T4b-full on sardine thermal response; "observed-jurel-only"
  robustness redundant with state-space missingness handling). The
  file is not knitted as part of the paper build but preserves the
  code for referee response if needed.

### Fixed — knit-breaking issues introduced and resolved in the same session

- Paths inside `knitr::include_graphics()` must be relative to the
  `.tex` directory (`paper1/`), not to `here::here()`. Convention
  used in this repo is `../figs/...`. Wrong path (`paper1/figs/...`
  resolves to `paper1/paper1/figs/...` at LaTeX time) truncates the
  PDF silently at the graphic and leaves `??` in every unresolved
  cross-reference downstream.
- `\ref{...}` and `\texttt{...}` cannot appear inside
  `kableExtra::footnote(general = ..., escape = FALSE)` because
  pandoc strips the backslash. Rewrote the offending table footnote
  in plain prose (for cross-refs) and with `escape = TRUE` plus
  Unicode for the technical notation (for file paths and math).
- `lmroman9-regular` and `lmroman10-regular` do not contain glyphs
  for ≤ (U+2264), ρ (U+03C1), ₀ (U+2080). Replaced all three with
  ASCII (`<=`, `rho`, `0`) inside the `growthcompstat` footnote and
  in the two children. Δ (U+0394), × (U+00D7), − (U+2212) render
  correctly and were kept.

## 2026-04-23 (paper1: T5-minimal comparative statics + identification section wired)

### Added

- `R/08_stan_t4/12_growth_comparative_statics.R`: new script (T5
  minimal) that applies the T4b-full shifter `r_eff = r_base *
  exp(rho_sst*DSST + rho_chl*DlogCHL)` over the CMIP6 IPSL-CM6A-LR
  deltas (SSP2-4.5, SSP5-8.5 × mid/end century) and reports median
  plus 90% band per stock × scenario. CHL delta is converted from
  multiplicative ratio to log-anomaly to match the Stan
  parameterization (`logCHL_c` in `paper1/stan/t4b_state_space_full.stan`).
  Jurel reported as "n.i." (non-identified) in the formatted table
  and excluded from the ridgeline; the companion
  `*_raw.csv` preserves raw numbers for traceability. Sanity check at
  `+1 C, DCHL=0` recovers `-65% anch, -94% sard` at the posterior
  median, matching the magnitudes quoted in
  `sections/results_identification.Rmd`. Outputs:
  `tables/growth_comparative_statics{,_raw}.csv`,
  `figs/t4b/growth_ridgeline_cmip6.png`.
- `paper1/paper1_climate_projections.Rmd`: wired two child chunks to
  the main Rmd — `results-identification` (child
  `paper1/sections/results_identification.Rmd`) inserted at the
  top of `# Results` as section 4.1, and `appendix-predictive`
  (child `paper1/sections/appendix_predictive_diagnostics.Rmd`) at
  the end of the Appendix as Appendix B. Child paths are written
  relative to the project root because `opts_knit$set(root.dir =
  here::here())` shifts the working directory from `paper1/` to
  the project root.

### Fixed

- `paper1/sections/results_identification.Rmd`: replaced two
  `\ref{sec:projections}` with `\ref{projections}` to match the
  actual section anchor `{#projections}` in the main Rmd. Also
  commented-out the "Posterior-predictive adequacy" subsection with
  an HTML comment block + TODO — its two `\ref{fig:ppc-*}` target
  labels live in a future Appendix C
  (`appendix_posterior_diagnostics.Rmd`) that has not been wired
  yet; leaving them live produced `??` in the PDF.
- `paper1/sections/results_identification.Rmd` and
  `paper1/sections/appendix_predictive_diagnostics.Rmd`: replaced
  LaTeX math commands inside `kableExtra::footnote(general = ...,
  threeparttable = TRUE)` with Unicode equivalents. Pandoc+citeproc
  strips the backslash commands from `$...$` math inside table
  footnotes (body-text math renders fine), so
  `$\widehat{\text{ELPD}}$`, `$\hat{R}$`, `$\hat{k}$`, `$^{\circ}$C`,
  `$\times$`, `$\sigma_{\text{post}}/\sigma_{\text{prior}}$`, and
  `$t_{\text{cut}}$` were rendering as garbled unicode-italic letter
  sequences (e.g. `𝐷𝑒𝑙𝑡𝑎𝑤𝑖𝑑𝑒ℎ𝑎𝑡𝑡𝑒𝑥𝑡𝐸𝐿𝑃𝐷`). Replaced with
  `Δ ELPD`, `R-hat`, `Pareto-k`, `°C`, `×`, `σ_post/σ_prior`,
  `t_cut` respectively. Fix affects footnotes of Table 1
  (`tab:rho-posteriors`), Table B.1 (`tab:loo-appendix`), and
  Table B.2 (`tab:lfo-appendix`).

## 2026-04-20 (paper1: NB table rendering + manuscript comments + bibliography review)

### Fixed

- `paper1/paper1_climate_projections.Rmd`: the `tabla_poisson` chunk
  failed silently because `stargazer` does not recognize
  `MASS::glm.nb` objects — the error was emitted as a LaTeX comment
  (`% Error: Unrecognized object type`) and the table disappeared
  from the PDF. Workaround: fit a Poisson GLM with the same formula
  (already computed for the LR test), replace its `$coefficients`
  with the NB coefficients, and pass the shell object to `stargazer`
  with clustered SEs supplied externally via `se = list(...)`.
  `stargazer` treats it as a GLM and prints the NB point estimates;
  the LR test statistic is reported in the notes so the reader knows
  the reported estimates come from NB, not Poisson.
- `paper1/paper1_climate_projections.Rmd`: renamed the chunk label
  from `poisson_results` to `poissonresults` (no underscore) — the
  underscore in the chunk name was being injected by bookdown into
  the caption as `(\#tab:poisson_results)` raw text, triggering
  math-mode errors (`Missing $ inserted`). Cross-references now
  resolve.
- `paper1/paper1_climate_projections.Rmd`: fixed the `omit.stat`
  argument in `stargazer` — replaced the invalid statistic names
  `c("f", "deviance", "null.deviance")` with the NB-compatible
  `c("ll", "aic", "bic", "res.dev", "null.dev")`. The invalid names
  were raising `% Error: Unknown statistic in 'omit.stat' argument`
  and dropping the whole table.
- `paper1/paper1_climate_projections.Rmd` YAML: added
  `keep_tex: true` to the `bookdown::pdf_document2` output block so
  stargazer/LaTeX errors (which surface as `%`-commented lines in
  the `.tex`) can be diagnosed directly.
- `bibliography.bib`: replaced the phantom `Arcos2001-jq` entry with
  the real paper — Arcos, Cubillos & Núñez (2001), "The jack
  mackerel fishery and El Niño 1997–98 effects off Chile", Progress
  in Oceanography 49(1–4):597–617, DOI
  `10.1016/S0079-6611(01)00043-X`. Previous entry had an
  unverifiable title/journal and no usable DOI.
- `bibliography.bib`: replaced the phantom `Aufhammer2018` entry.
  The previous entry had a fabricated title ("Quantifying climatic
  and weather impacts on health in the presence of adaptation"),
  wrong journal (Annals of the NYAS), and a DOI
  (`10.1111/nyas.13625`) that resolves to an unrelated cancer
  immunotherapy paper (verified via CrossRef). Replaced with
  Auffhammer (2018), "Quantifying Economic Damages from Climate
  Change", Journal of Economic Perspectives 32(4):33–52, DOI
  `10.1257/jep.32.4.33` — contextually consistent with how the
  citation is used in §3.3 (adaptation caveat on climate
  projections). Citation key kept as `Aufhammer2018` (single f) to
  avoid touching the `.Rmd`; the `author` field carries the correct
  "Auffhammer" spelling that pandoc will render.

### Changed

- `paper1/paper1_climate_projections.Rmd` Discussion: removed the
  self-congratulatory "novel contribution" framing around the
  direct-vs-indirect channel decomposition. The decomposition is
  mechanically straightforward given the structural model; presenting
  it as a methodological innovation was oversold. Replaced with a
  neutral lead-in that keeps the substantive finding (indirect
  channel dominates).
- `paper1/paper1_climate_projections.Rmd` Discussion: replaced the
  forced Birkenbach et al. (2020) citation (about catch-share
  reforms in the US groundfish fishery — not a close fit to the
  multi-species portfolio argument being made) with Kasperski &
  Holland (2013, PNAS), which is the canonical reference for
  portfolio diversification reducing revenue variability in
  fisheries. The argument in the paragraph now reads more cleanly
  as an application of the portfolio-theory logic to the Chilean
  SPF context.

### Bibliography review

- Full verification pass over the 31 unique citation keys used in
  `paper1_climate_projections.Rmd`. Two phantom citations found and
  fixed (`Arcos2001-jq`, `Aufhammer2018`, above). Remaining 29
  entries checked against their DOIs/URLs; all verified.

### Fixed (tables 2 & 3 width overflow)

- `paper1/paper1_climate_projections.Rmd`: tables 2 (SUR) and 3
  (NB trips) rendered wider than the text block because stargazer
  emits each note as `\multicolumn{N}{l}{...}`, which is a single
  unwrappable line. The longest note dictated the tabular width and
  pushed the final column off the page (especially visible on the
  Artisanal column of Table 3 and the Jack mackerel column of
  Table 2). Added a helper `fix_stargazer_notes()` in the setup
  chunk that post-processes `capture.output(stargazer(...))` and
  converts stargazer's in-tabular notes into a `threeparttable` /
  `tablenotes` environment. Concretely, it (a) wraps the tabular
  with `\begin{threeparttable}...\end{threeparttable}`, (b) strips
  the `\multicolumn{N}{l}{...} \\` rows that came after the last
  `\hline`, and (c) re-emits their content as `\item` lines inside
  `\begin{tablenotes}[flushleft]`. With this structure the notes
  wrap to the *natural* width of the tabular (the width dictated
  by the data rows) rather than forcing the tabular to expand.
  An earlier fix using `\multicolumn{N}{p{0.95\linewidth}}{...}`
  was discarded because it pinned the notes column to a fixed
  fraction of the line width, which in turn forced the tabular to
  that same width — making narrow tables *wider* than necessary.
  Applied to both `SUR_results` and `tabla_poisson` chunks.
  Requires `\usepackage{threeparttable}` in the YAML header
  (already present, line 31).
  - Follow-up fix: the extraction regex initially anchored on
    `^\\multicolumn{...}` and therefore missed stargazer's actual
    output format, where each note row begins with a label column
    (e.g. `\textit{Note:}  & \multicolumn{3}{l}{...} \\`). The
    anchor was loosened to `^.*\\multicolumn{...}` so any prefix
    before `\multicolumn` is tolerated. The old "Note:" column
    label is now prepended inline to the first `\item` inside
    `tablenotes` (as `\textit{Note:} $^{*}$p<0.1; ...`), which
    removes the empty left column that previously created a large
    blank gap between "Note:" and the note text.
  - Extended the helper to the three appendix robustness tables:
    `SUR_rob_panel_A`, `SUR_rob_panel_B`, and `SUR_rob_interactions`.
    All three used the same `notes.append = FALSE, notes.align = "l"`
    stargazer configuration and therefore suffered from the same
    "Note:" column artifact. Each chunk is now wrapped in
    `capture.output(...)` → `fix_stargazer_notes()` → `cat(...)`
    so the appendix tables render with the same clean
    `threeparttable` layout as tables 2 and 3.

## 2026-04-18 (follow-up 2: manuscript consistency pass)

### Changed

- `paper1/paper1_climate_projections.Rmd`: consolidated the
  delta-method projection methodology into Section 3.3 (Data and
  methodology). Previously, the section labelled
  `{#projection-approach}` contained only a one-paragraph caveat
  (interannual vs decadal), while Section 3.2 cross-referenced it for
  methodological detail; the actual delta-method description sat in a
  `### Projection methodology` subheading inside Section 4.3 (Results).
  Moved the two methodology paragraphs and the "two channels" framing
  paragraph from 4.3.1 to 3.3, deleted the 4.3.1 subheading, and
  replaced the top of Section 4.3 with a single-sentence pointer back
  to §3.3. The `\ref{projection-approach}` cross-reference from §3.2
  now resolves to the actual methodology.
- `paper1/paper1_climate_projections.Rmd`: trimmed duplication between
  Introduction and Section 2. Removed the fleet-split detail ("In
  Chile, jack mackerel is predominantly harvested by the industrial
  purse-seine fleet…") from the Introduction's third paragraph since
  it is covered in Section 2's Management regime subsection. Removed
  the "94% of total national fish landings" figure and the 3-species
  enumeration from the opener of Section 2; both are already in
  Introduction paragraph 2. Section 2 now opens with the
  latitudinal-zone structure, which is what it contributes beyond the
  Introduction.
- `paper1/paper1_climate_projections.Rmd`: added a Discussion
  paragraph interpreting the <5% direct weather channel as a
  substantive finding rather than a null result — implies that
  climate adaptation policy should focus on quota allocation /
  transferability (institutional) rather than port infrastructure,
  vessel reinforcement, or weather-indexed insurance (operational).
  Conditional on the IPSL wind projection; flagged for revision under
  multi-model ensembles.
- `paper1/paper1_climate_projections.Rmd`: promoted the `days_closed_vy`
  caveat from a footnote in Results to a fourth explicit limitation in
  Discussion. The closure variable currently varies only across
  regulatory zones (151 vs 182 days), so the positive coefficient for
  the artisanal fleet reflects locational heterogeneity rather than a
  causal effect of exposure to closed days.
- `paper2/paper2_bioeconomic_optimization.Rmd`: updated the sample
  description for the SUR model from "N = 23 annual observations
  (2000–2022)" to "N = 23 annual observations covering the 2000–2024
  sample (one observation lost to the lead structure)", consistent
  with the biomass series used in paper1.

### Fixed

- `paper1/paper1_climate_projections.Rmd`: removed an inline
  `<!-- TODO: add to bibliography.bib ... @Lam2016 ... -->` block from
  the Discussion. The `@Lam2016` entry was already present in
  `bibliography.bib` (line 33); the TODO was stale.

## 2026-04-18 (follow-up: Rmd cleanup)

### Changed

- Consolidated all `library()` calls in `paper1_climate_projections.Rmd`
  into the `directorio` setup chunk. Removed 18 scattered `library()`
  calls from individual chunks. The setup chunk now loads: `dplyr`,
  `tidyr`, `data.table`, `tibble`, `janitor`, `ggplot2`, `scales`,
  `viridis`, `lavaan`, `sandwich`, `lmtest`, `stargazer`, `kableExtra`.
  Replaced a generic `library(tidyverse)` with the specific packages
  actually used (`dplyr`, `tidyr`, `tibble`, `ggplot2`). Removed
  `library(knitr)` (implicitly available during knit).
- Replaced `library(MASS)` with namespaced calls `MASS::glm.nb(...)` in
  the `est_poisson` chunk. MASS is no longer attached to the search
  path, so it cannot mask `dplyr::select`.
- Reverted the three defensive `dplyr::select(...)` calls (in chunks
  `biomassprojections`, `decompositiontable`, `projfigure`) back to
  plain `select(...)` — no longer needed once MASS is unloaded.

### Fixed

- Resized Figure 3 (`projfigure` chunk) so it fits the page width.
  Changed `fig.width=8, fig.height=5` → `fig.width=6.5, fig.height=4`
  and added `out.width='100%'`. Previously the figure overflowed the
  text width at 11pt with 1in margins.

## 2026-04-18

### Fixed
- `paper1/paper1_climate_projections.Rmd` now knits end-to-end from a fresh R
  session. Several compounding issues were resolved.

#### R Markdown — chunk evaluation

- Added `knitr::opts_knit$set(root.dir = here::here())` to the `directorio`
  setup chunk so relative paths in later chunks resolve from the project
  root, not from `paper1/`. This removes the dependency on the Windows
  junctions (`paper1/data`, `paper1/figs`, `paper1/tables`, etc.) which
  are not portable across machines or preserved by git.
- Centralised core library loads (`dplyr`, `tidyr`, `data.table`) in the
  `directorio` chunk. Previously `arrange()`, `filter()`, and `data.table`
  syntax (`.()`, `by=`, `dcast`, `:=`) were used in chunks that did not
  load the corresponding packages — it worked interactively only because
  the user's R session happened to have them already loaded.
- Replaced three `select(...)` calls with `dplyr::select(...)` in the
  chunks `biomassprojections`, `decompositiontable`, and `projfigure`.
  These run after `library(MASS)` (loaded in the `est_poisson` chunk),
  which masks `dplyr::select` with `MASS::select`.

#### R Markdown — YAML & pandoc

- Changed `bibliography: bibliography.bib` → `bibliography: ../bibliography.bib`
  and `csl: apa.csl` → `csl: ../apa.csl`. Pandoc resolves these paths
  relative to the Rmd, and `paper1/bibliography.bib` / `paper1/apa.csl`
  are broken junction stubs (plain text files on non-Windows systems).

#### R Markdown — figures

- Changed `include_graphics("figs/env_data_map.pdf")` →
  `include_graphics("../figs/env_data_map.pdf", error = FALSE)` in the
  `figEnvData` chunk. The relative path is resolved by xelatex from the
  location of the `.tex` file (`paper1/`), so `..` correctly reaches the
  project root. `error = FALSE` disables knitr's pre-flight existence
  check, which otherwise runs from the chunk's working directory (project
  root, due to `opts_knit$set(root.dir = ...)`) where `../figs/` would
  point outside the project.

#### Environment

- Migrated local LaTeX distribution from MiKTeX 2.9 (pre-2019, could not
  install new packages because its repository is too old) to TinyTeX.
  Install command: `tinytex::install_tinytex(force = TRUE)`. TinyTeX
  lives at `%APPDATA%/TinyTeX` and auto-installs LaTeX packages as
  xelatex requests them.

### Known issues / follow-ups

- Figure 3 renders wider than the page width in the compiled PDF. Needs
  `out.width` / `fig.width` adjustment.
- The `paper1/` subdirectory contains Windows junctions (`data`, `figs`,
  `logo`, `R`, `tables`, `bibliography.bib`, `apa.csl`) that do not
  travel well via git. Consider replacing all remaining uses with
  `here::here()` or relative paths from `paper1/`, and deleting the
  junctions from the repo.
- 13 scattered `library(...)` calls remain inside individual chunks.
  Consolidating them into the `directorio` chunk would make dependencies
  obvious at the top of the Rmd. Candidates: `ggplot2`, `scales`,
  `viridis`, `janitor`, `lavaan`, `stargazer`, `MASS`, `sandwich`,
  `lmtest`, `knitr`, `kableExtra`.
- `library(MASS)` masks `dplyr::select`. Safer to call `MASS::glm.nb()`
  directly without attaching MASS.

### Added
- `data/harvest/` and `data/biomass/` output directories populated by
  running `R/01_data_cleaning/harvest_data.R` and
  `R/01_data_cleaning/biomass_data.R` in order. These directories (and
  the `.rds` files inside) are excluded from git per `.gitignore`.
