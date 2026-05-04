# SPF Harvest

**Climate variability and harvest decisions in Chile's Centro-Sur small pelagic fishery**

<!-- Badges -->
![R](https://img.shields.io/badge/R-%E2%89%A54.2-276DC3?logo=r)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-paper%201%20submission--ready%20(MRE%2C%20May%202026)-blue)

## Overview

This repository contains the bioeconomic modeling framework developed under FONDECYT Iniciación for the Chilean Centro-Sur (CS) small pelagic fishery (SPF), composed of *Strangomera bentincki* (common sardine), *Engraulis ringens* (anchoveta), and *Trachurus murphyi* (jack mackerel).

The project is organized into **two papers**:

| Paper | Title | Status |
|---|---|---|
| **Paper 1** | Differential Climate Impacts on Fishing Effort in Chilean Small Pelagic Fisheries | Submission-ready (target *Marine Resource Economics*, end May 2026) |
| **Paper 2** | Optimal Quota Allocation under Climate Change: A Bioeconomic Approach | In progress (target JAERE/ERE 2027–2028) |

## Paper 1: Climate projections

Identifies a set of structural climate shifters (ρ^SST, ρ^CHL) that
modulate the intrinsic growth rate of each stock, within a Bayesian
state-space specification (Schaefer transition + log-linear
shifter + log-normal observation equation) calibrated on the IFOP and
SPRFMO stock assessments. Evaluates the identified shifters under a
six-model CMIP6 ensemble (IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1,
UKESM1-0-LL, MPI-ESM1-2-HR) under SSP2-4.5 and SSP5-8.5 to obtain
posterior distributions of the long-run comparative-statics change in
each stock's intrinsic productivity under mid-century (2041–2060) and
end-of-century (2081–2100) climate regimes. Couples this with a
negative binomial model of annual fishing trips with year fixed
effects (absorbing the 2019 *estallido social* and the 2020–2022 COVID
period), estimated separately for the artisanal and industrial fleets.
Climate propagates to vessel effort through **two channels**: an
*indirect* channel via the structural biomass shifters, and a *direct*
channel via vessel-specific exposure to severe winds (computed from
each vessel's empirical CDF of historical wind speed at the
center-of-gravity of its operations, evaluated at the projected CMIP6
delta). Reports formal two-way variance decompositions (within-model
posterior vs. between-model CMIP6 spread) for both the productivity
response (Appendix F) and the fleet-level trip response (Appendix G).

**Key findings.**

1. The climate semi-elasticities are sharply *identified* for the two
   coastal-upwelling stocks (anchoveta and sardina común) and
   structurally *non-identified* for jack mackerel. Non-identification
   is documented with a **five-line evidence package** (Appendix E):
   (i) an identification-power calculation showing the
   minimum-detectable elasticity at 80% power on the available
   N = 24 sample is ~5× larger for jurel than for the coastal stocks,
   driven by a process-noise envelope ~5× wider; (ii) spatial-domain
   robustness across three alternative coastal windows; (iii)
   dual-source state-space augmenting the Centro-Sur with the Northern
   Chilean acoustic series (CS↔Norte log-correlation 0.88); (iv) a
   basin-scale refit replacing local SST/CHL with the ENSO Niño 3.4
   index (`σ_post/σ_prior = 0.98` at lag 1, `1.01` at lag 2); and
   (v) a joint-shifter sensitivity with all three covariates active for
   jurel (ratios 1.03 / 1.00 / 0.98). Across all five lines
   `σ_post/σ_prior` stays at or above 0.94 for the jurel shifters,
   ruling out spatial aggregation, sample size, basin-scale forcing
   modality, and joint-specification convention as alternative
   explanations. A prior-propagation envelope on `r*_jurel` under
   SSP5-8.5 end-of-century spans approximately three orders of
   magnitude on the productivity factor, confirming that any structural
   projection under the unidentified shifter would be non-informative
   for policy. Jack mackerel is therefore treated as `n.i.` in all
   manuscript tables and figures with `factor_B_jurel = 1` in the
   projections.

2. The two coastal stocks face sharp long-run productivity declines
   under every CMIP6 model considered (cross-model median −51% to
   −90% for anchoveta and −79% to −99.9% for sardina común,
   between mid-century SSP2-4.5 and end-of-century SSP5-8.5), with a
   floor effect for sardine in the worst-case window.

3. The fleet-level effort response is asymmetric: the **artisanal
   fleet contracts by 8.1–10.2%** while the **industrial fleet
   contracts by 0.7–1.1%**, an asymmetry of roughly **eleven to one**
   (marginal). Conditional on no portfolio collapse (`f^H_v > 0.5`)
   the asymmetry narrows to ~3.4:1. The artisanal fleet's
   probability of portfolio loss > 50% under SSP5-8.5 end-of-century
   is 0.99; the industrial fleet's is 0.12, partially insulated by
   its 95% allocation to the *n.i.* jurel stock. The distributional
   asymmetry is governed by the interaction between portfolio
   composition (differential exposure to the identified shifters and
   to severe winds) and the LMCA quota regime's limited cross-sector
   transferability.

4. Variance decompositions: 97–100% of the dispersion in projected
   fleet-level effort changes is *within-model* (posterior + vessel
   heterogeneity) rather than *between-model* CMIP6 spread. The
   narrow cross-model interquartile range in the headline table is a
   floor-effect saturation, not climate-model consensus.

## Paper 2: Bioeconomic optimization

Extends Paper 1 with trip-level restricted cost functions, an inverse almost ideal demand system (IADS), and numerical optimization following Kasperski & Holland (2013, 2016). Determines optimal quota paths and welfare impacts under climate scenarios.

## Repository structure

```
.
├── paper1/                             # Paper 1: Climate projections
│   ├── paper1_climate_projections.Rmd  # Manuscript (R Markdown)
│   ├── sections/                       # Child Rmds wired into main
│   │   ├── results_identification.Rmd                # §4.1 (T4b-full rho posteriors + PPC adequacy)
│   │   ├── appendix_stress_tests.Rmd                 # Appendix A (stress tests + prior elicitation)
│   │   ├── appendix_predictive_diagnostics.Rmd       # Appendix B (PSIS-LOO / PSIS-LFO)
│   │   ├── appendix_posterior_diagnostics.Rmd        # Appendix C (posterior-predictive checks)
│   │   ├── appendix_convergence_diagnostics.Rmd      # Appendix D (R-hat / ESS for top-level T4b parameters)
│   │   ├── appendix_spatial_jurel.Rmd                # Appendix E (spatial robustness of jurel n.i.)
│   │   ├── appendix_variance_decomposition.Rmd       # Appendix F (variance decomp for growth)
│   │   ├── appendix_g_trips_variance_decomposition.Rmd  # Appendix G (variance decomp for fleet trips)
│   │   └── results_loo_comparison.Rmd                # alt cut, not wired in main
│   ├── deprecated/                     # Archived V1 material (not knitted)
│   │   └── sur_benchmark_deprecated.Rmd  # SUR reduced-form benchmark (removed 2026-04-24)
│   └── stan/                           # Compiled Stan programs for T4b
│
├── paper2/                             # Paper 2: Bioeconomic optimization
│   └── paper2_bioeconomic_optimization.Rmd
│
├── R/                                  # Shared R code pipeline
│   ├── 00_config/config.R              # Paths, libraries, constants
│   ├── 00_run_all.R                    # Master pipeline
│   ├── 01_data/                        # Raw data ingestion
│   │   └── extract_oisst_nino34.R              # NOAA-CPC sstoi.indices → annual ENSO Niño 3.4 (App E)
│   ├── 01_data_cleaning/               # Raw data -> clean .rds
│   ├── 02_env_processing/              # NetCDF -> daily env grids
│   ├── 03_env_spatial/                 # Spatial operations
│   ├── 04_models/                      # Econometric estimation (SUR, NB)
│   ├── 05_students/                    # Student-led modules (Paper 2)
│   ├── 06_projections/                 # CMIP6 ensemble pipeline + Copernicus extended
│   │   ├── 01_cmip6_deltas.R                 # 6-model ensemble deltas (units-aware chlos)
│   │   ├── 01b_cmip6_enso_deltas.R           # ENSO Niño 3.4 deltas (App E.6)
│   │   ├── 00_sanity_check_cmip6.R           # Single-model sanity (legacy)
│   │   ├── 00b_sanity_check_ensemble.R       # Ensemble sanity (post-fix asserts)
│   │   ├── 06_extended_env_anomalies.R       # Copernicus extended anomalies for App E
│   │   ├── download_cmip6_ensemble.py        # Pangeo + ESGF fallback downloader (costero)
│   │   ├── download_cmip6_nino34.py          # Pangeo downloader for Niño 3.4 box (App E.6)
│   │   ├── download_copernicus_paper1_extended.py
│   │   ├── 02_project_and_predict.R          # Legacy V1 (deprecated)
│   │   ├── 03_project_biomass.R              # Legacy V1 (deprecated)
│   │   ├── 04_forward_simulation*.R          # Legacy V1 diagnostic (deprecated)
│   │   └── 05_sensitivity_sur_spec.R         # Legacy V1 diagnostic (deprecated)
│   ├── 07_structural_bio/              # Schaefer hindcast + official priors
│   └── 08_stan_t4/                     # Bayesian state-space (T4b, Paper 1 core)
│       ├── _compstat_utils.R                          # Shared constants + scenario loader
│       ├── 04_fit_t4b_ind.R                           # No-shifter baseline
│       ├── 06_fit_t4b_omega.R                         # + residual covariance
│       ├── 08_fit_t4b_full.R                          # + SST/CHL shifters (leading model)
│       ├── 10_loo_t4b_compare.R                       # PSIS-LOO across specs
│       ├── 11_lfo_t4b_compare.R                       # PSIS-LFO across specs
│       ├── 12_growth_comparative_statics.R            # T5: r_eff under 6-model CMIP6 ensemble
│       ├── 13_trip_comparative_statics.R              # T7: Schaefer SS + NB → fleet trip response
│       ├── 14_refit_t4b_full_appendix_e.R             # T4b refit on alternative spatial domains
│       ├── 14b_fit_t4b_full_enso.R                    # T4b refit with basin-scale ENSO replacement (App E.6)
│       ├── 14c_fit_t4b_full_enso_joint.R              # T4b refit with all 3 shifters active for jurel (App E.6 sensitivity)
│       ├── 15_appendix_e_sigma_ratios.R               # σ_post/σ_prior across domains (App E)
│       ├── 16_appendix_f_variance_decomposition.R     # Var decomp for growth (App F)
│       ├── 17_appendix_g_trips_variance_decomposition.R  # Var decomp for trips (App G)
│       ├── 18_power_calculation_enso.R                # Identification power for SST/CHL/ENSO (App E.1)
│       └── 19_project_jurel_enso_prior_propagation.R  # Prior-propagation envelope for r*_jurel (App E.6)
│
├── data/                               # Processed data (.rds)
│   ├── bio_params/                     # Official assessments (IFOP / SPRFMO)
│   ├── biomass/
│   ├── harvest/
│   ├── logbooks/
│   ├── outputs/t4b/                    # Stan fits + summaries
│   ├── ports/
│   ├── projections/                    # CMIP6 deltas + legacy SUR projections
│   └── trips/
│
├── figs/                               # Figures
├── tables/                             # Exported tables
├── slides/                             # Presentations
├── logo/                               # Institutional logos
├── archive/                            # Old manuscript + legacy code
│
├── bibliography.bib                    # Shared bibliography
├── apa.csl                             # Citation style
├── knit.R                              # Render manuscripts
└── libs/                               # Slide dependencies
```

## Data sources

| Source | Variables |
|---|---|
| SERNAPESCA | Landings, quota monitoring records, biological closures (vedas) |
| IFOP | Logbooks (haul coordinates, catch, effort); annual stock assessments (anchoveta and sardina común CS); biomass series used as the Stan likelihood |
| SPRFMO | Jack mackerel transboundary stock assessment (acoustic biomass series) |
| SUBPESCA | Veda calendar, annual TAC resolutions |
| Banco Central de Chile | FOB fishmeal price, IPC |
| CNE | Diesel prices by region |
| Copernicus Marine Service | SST (GLORYS12), chlorophyll-a (Ocean Colour L4 multi-sensor), wind (ERA5) |
| NOAA-CPC `sstoi.indices` (ERSSTv5) | ENSO Niño 3.4 monthly index for the basin-scale shifter test of Appendix E.6 |
| CMIP6 six-model ensemble | Projected SST, chlorophyll-a, surface winds, and Niño 3.4 SST under SSP2-4.5 and SSP5-8.5: IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, MPI-ESM1-2-HR (downloaded via Pangeo + ESGF fallback; Niño 3.4 box on a separate parallel pull) |

Raw data are not redistributed; see `data/README.md` for access instructions.

## Reproducibility

Requirements:

- **R ≥ 4.2** with packages: `dplyr`, `tidyr`, `data.table`, `tibble`,
  `readr`, `purrr`, `ggplot2`, `ggridges`, `scales`, `viridis`,
  `kableExtra`, `stargazer`, `MASS`, `lavaan`, `sf`, `openxlsx`,
  `ncdf4`, `cmdstanr`, `posterior`.
- **Python ≥ 3.10** (only for the CMIP6 download pipeline) with
  packages: `intake-esm`, `xarray`, `zarr`, `dask`, `fsspec`,
  `aiohttp`, `netCDF4`, `pyesgf`. Used by
  `R/06_projections/download_cmip6_ensemble.py` and
  `R/06_projections/download_copernicus_paper1_extended.py`.
- **CmdStan ≥ 2.35** (Stan backend for the T4b state-space model) with
  the LKJ correlation prior compiled in. Install via
  `cmdstanr::install_cmdstan()`.
- **TinyTeX** (or any LaTeX distribution that auto-installs missing
  packages) to render the manuscript. Install via
  `tinytex::install_tinytex()`.

```r
# Run the data pipeline
source("R/00_run_all.R")

# Render Paper 1
source("knit.R")
```

For the CMIP6 ensemble pipeline specifically (only needs to be run
once; outputs are cached in `data/cmip6/`):

```r
# Refresh CMIP6 deltas from the cached netCDFs
source("R/06_projections/01_cmip6_deltas.R")
source("R/06_projections/00b_sanity_check_ensemble.R")

# Re-run downstream comparative statics + variance decompositions
options(t5.run_main = TRUE)
source("R/08_stan_t4/12_growth_comparative_statics.R")
options(t6.run_main = TRUE)
source("R/08_stan_t4/13_trip_comparative_statics.R")
options(t5.run_main = FALSE, appf.run_main = TRUE)
source("R/08_stan_t4/16_appendix_f_variance_decomposition.R")
options(t6.run_main = FALSE, appg.run_main = TRUE)
source("R/08_stan_t4/17_appendix_g_trips_variance_decomposition.R")
```

For the basin-scale ENSO pipeline of Appendix E.6 (also one-shot;
outputs cached in `data/bio_params/`, `data/cmip6/`, and
`data/outputs/t4b/`):

```r
# 1. Historical ENSO Niño 3.4 from NOAA-CPC ERSSTv5
source("R/01_data/extract_oisst_nino34.R")

# 2. CMIP6 Niño 3.4 deltas (after running download_cmip6_nino34.py)
source("R/06_projections/01b_cmip6_enso_deltas.R")

# 3. Identification power calculation (Apéndice E.1 table)
options(power.run_main = TRUE)
source("R/08_stan_t4/18_power_calculation_enso.R")

# 4. T4b refit with basin-scale ENSO (replacement convention, lag 1)
options(t4b.enso.run_main = TRUE, t4b.enso.lag = 1L)
source("R/08_stan_t4/14b_fit_t4b_full_enso.R")
# Lag 2 sensitivity
options(t4b.enso.run_main = TRUE, t4b.enso.lag = 2L)
source("R/08_stan_t4/14b_fit_t4b_full_enso.R")

# 5. T4b refit with three shifters active for jurel (joint sensitivity)
options(t4b.enso.joint.run_main = TRUE, t4b.enso.joint.lag = 1L)
source("R/08_stan_t4/14c_fit_t4b_full_enso_joint.R")

# 6. Prior-propagation envelope for r*_jurel under SSP scenarios
source("R/08_stan_t4/19_project_jurel_enso_prior_propagation.R")
```

## Funding

This work is funded by **ANID--FONDECYT Iniciación** (Chile).

## Citation

> Quezada-Escalona, F. (2026a). Climate change, stock productivity, and fishing effort in Chile's multi-species small pelagic fishery. *Working paper, Universidad de Concepción.*

> Quezada-Escalona, F. (forthcoming). Optimal quota allocation under climate change in Chile's multi-species small pelagic fishery. *Working paper, Universidad de Concepción.*

## Contact

Felipe Quezada-Escalona
Departamento de Economía, Universidad de Concepción
<felipequezada@udec.cl>

## License

Code is released under the MIT License. Data are subject to the licensing terms of the original providers.
