# Changelog

Notable changes to the project, in reverse chronological order.

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
