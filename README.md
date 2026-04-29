# SPF Harvest

**Climate variability and harvest decisions in Chile's Centro-Sur small pelagic fishery**

<!-- Badges -->
![R](https://img.shields.io/badge/R-%E2%89%A54.2-276DC3?logo=r)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-work%20in%20progress-orange)

## Overview

This repository contains the bioeconomic modeling framework developed under FONDECYT Iniciación for the Chilean Centro-Sur (CS) small pelagic fishery (SPF), composed of *Strangomera bentincki* (common sardine), *Engraulis ringens* (anchoveta), and *Trachurus murphyi* (jack mackerel).

The project is organized into **two papers**:

| Paper | Title | Status |
|---|---|---|
| **Paper 1** | Climate Change, Stock Productivity, and Fishing Effort | Draft ready |
| **Paper 2** | Optimal Quota Allocation under Climate Change: A Bioeconomic Approach | In progress |

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
end-of-century (2081–2100) climate regimes. Links to a negative
binomial model of annual fishing trips, estimated separately for the
artisanal and industrial fleets, and propagates the trip response
through the same ensemble × posterior cross-product. Reports formal
two-way variance decompositions (within-model posterior vs.
between-model CMIP6 spread) for both the productivity response
(Appendix F) and the fleet-level trip response (Appendix G).

**Key finding:** the coastal-upwelling pair (anchoveta and sardina
común) faces sharp long-run productivity declines under all six CMIP6
models considered (cross-model median −51% to −90% for anchoveta,
−79% to −99.9% for sardina común) while the local response of the
transzonal jack mackerel stock is not identified at the Centro-Sur
scale. Propagating the posterior through a Schaefer steady-state
biomass equation under historical average fishing pressure and through
the estimated negative binomial trip equation, the artisanal fleet
exhibits a cross-model posterior probability of portfolio loss above
0.95 under every CMIP6 scenario; the industrial fleet's loss
probability is 0.12, stable across scenarios, driven entirely by its
five-percent exposure to sardina común and partially insulated by 95%
allocation to jack mackerel. The distributional asymmetry between the
two fleets is governed by the interaction between portfolio composition
(differential exposure to the identified shifters) and the LMCA's
limited cross-sector quota transferability. The variance
decompositions in Appendices F and G quantify the relative
contribution of climate-ensemble vs. structural-posterior uncertainty
species-by-species and fleet-by-fleet, and explicitly identify the
narrow cross-model interquartile range observed for fleet-level trips
as a floor-effect saturation rather than as climate consensus.

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
│   ├── 01_data_cleaning/               # Raw data -> clean .rds
│   ├── 02_env_processing/              # NetCDF -> daily env grids
│   ├── 03_env_spatial/                 # Spatial operations
│   ├── 04_models/                      # Econometric estimation (SUR, NB)
│   ├── 05_students/                    # Student-led modules (Paper 2)
│   ├── 06_projections/                 # CMIP6 ensemble pipeline + Copernicus extended
│   │   ├── 01_cmip6_deltas.R                 # 6-model ensemble deltas (units-aware chlos)
│   │   ├── 00_sanity_check_cmip6.R           # Single-model sanity (legacy)
│   │   ├── 00b_sanity_check_ensemble.R       # Ensemble sanity (post-fix asserts)
│   │   ├── 06_extended_env_anomalies.R       # Copernicus extended anomalies for App E
│   │   ├── download_cmip6_ensemble.py        # Pangeo + ESGF fallback downloader
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
│       ├── 15_appendix_e_sigma_ratios.R               # σ_post/σ_prior across domains (App E)
│       ├── 16_appendix_f_variance_decomposition.R     # Var decomp for growth (App F)
│       └── 17_appendix_g_trips_variance_decomposition.R  # Var decomp for trips (App G)
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
| CMIP6 six-model ensemble | Projected SST, chlorophyll-a, and surface winds under SSP2-4.5 and SSP5-8.5: IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, MPI-ESM1-2-HR (downloaded via Pangeo + ESGF fallback) |

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
