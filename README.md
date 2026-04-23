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

Estimates a three-equation SUR model for stock dynamics and a negative binomial model for annual fishing trips. Combines these with CMIP6 projections (IPSL-CM6A-LR, SSP2-4.5 and SSP5-8.5) using the delta method to project climate impacts on fishing effort through direct (weather) and indirect (biomass) channels.

**Key finding:** Artisanal fleet effort increases (20--250%) due to sardine expansion under warming; industrial fleet effort declines (~22%) due to jack mackerel productivity loss.

## Paper 2: Bioeconomic optimization

Extends Paper 1 with trip-level restricted cost functions, an inverse almost ideal demand system (IADS), and numerical optimization following Kasperski & Holland (2013, 2016). Determines optimal quota paths and welfare impacts under climate scenarios.

## Repository structure

```
.
├── paper1/                             # Paper 1: Climate projections
│   ├── paper1_climate_projections.Rmd  # Manuscript (R Markdown)
│   ├── sections/                       # Child Rmds wired into main
│   │   ├── results_identification.Rmd        # §4.1 (T4b-full rho posteriors)
│   │   ├── appendix_predictive_diagnostics.Rmd  # Appendix B (LOO / LFO)
│   │   └── results_loo_comparison.Rmd        # alt cut, not wired in main
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
│   ├── 06_projections/                 # Deterministic SUR projections (legacy V1)
│   │   ├── 01_cmip6_deltas.R
│   │   ├── 02_project_and_predict.R
│   │   └── 03_project_biomass.R
│   ├── 07_structural_bio/              # Schaefer hindcast + official priors
│   └── 08_stan_t4/                     # Bayesian state-space (T4b, Paper 1 core)
│       ├── 04_fit_t4b_ind.R            # No-shifter baseline
│       ├── 06_fit_t4b_omega.R          # + residual covariance
│       ├── 08_fit_t4b_full.R           # + SST/CHL shifters (leading model)
│       ├── 10_loo_t4b_compare.R        # PSIS-LOO across specs
│       ├── 11_lfo_t4b_compare.R        # PSIS-LFO across specs
│       └── 12_growth_comparative_statics.R  # T5-minimal: r_eff under CMIP6
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
| IFOP | Logbooks (haul coordinates, catch, effort); manufacturing survey (prices) |
| SUBPESCA | Veda calendar, annual TAC resolutions |
| Banco Central de Chile | FOB fishmeal price, IPC |
| CNE | Diesel prices by region |
| Copernicus Marine Service | SST (GLORYS12), chlorophyll-a, wind (ERA5) |
| CMIP6 (IPSL-CM6A-LR) | Projected SST, CHL, wind under SSP2-4.5 and SSP5-8.5 |

Raw data are not redistributed; see `data/README.md` for access instructions.

## Reproducibility

Requirements: R >= 4.2, packages: `MASS`, `lavaan`, `sf`, `openxlsx`, `stargazer`, `dplyr`, `data.table`, `ncdf4`, `kableExtra`

```r
# Run the data pipeline
source("R/00_run_all.R")

# Render Paper 1
source("knit.R")
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
