# SPF Harvest

**Climate variability and harvest decisions in Chile's Centro-Sur small pelagic fishery**

<!-- Badges -->
![R](https://img.shields.io/badge/R-%E2%89%A54.2-276DC3?logo=r)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-work%20in%20progress-orange)

## Overview

This repository contains the bioeconomic modeling framework developed under FONDECYT Iniciación project on the Chilean Centro-Sur (CS) small pelagic fishery (SPF), composed of *Strangomera bentincki* (common sardine), *Engraulis ringens* (anchoveta), and *Trachurus murphyi* (jack mackerel).

Building on the Kasperski (2015) multi-species harvesting framework and augmented with environmental covariates, the project estimates the economic and biological interrelations governing harvest decisions, species substitution, and ex-vessel price formation. The estimated structural equations are used to simulate fleet-level responses and welfare impacts under alternative climate scenarios (SSP2-4.5, SSP5-8.5), informing adaptation pathways for Chilean fishers and fishing communities.

## Research question

*How are fishing decisions, aggregate catch levels, and ex-vessel prices affected under alternative climate scenarios in the Chilean SPF?*

## Model structure

The model is modular. Each module is estimated independently and later integrated into a common simulation core.

| Module | Specification | Status |
|---|---|---|
| Stock biomass | Seemingly Unrelated Regressions (SUR) on own biomass, SST, SST², CHL | Complete |
| Fishing trips | Negative Binomial count model, fleet-specific (IND, ART) | Complete |
| Cost function | To be specified (student-led) | In progress |
| Ex-vessel prices | Panel FE with Driscoll-Kraay SE; OLS and IV-FE side by side | In progress |
| Climate projections | Delta-method bias correction (CMIP6 IPSL-CM6A-LR vs. Copernicus baselines) | Pipeline available |

## Repository structure

```
R/
├── 00_config/config.R              # Paths, libraries, constants
├── 00_run_all.R                    # Master pipeline
│
├── 01_data_cleaning/               # Raw data → clean .rds
│   ├── harvest_data.R              # SERNAPESCA + IFOP harvest records
│   ├── logbook_data.R              # IFOP logbooks (trip records)
│   ├── biomass_data.R              # Stock biomass + interpolation
│   └── tac_processing.R            # TAC allocation by species/region
│
├── 02_env_processing/              # NetCDF → daily env grids
│   ├── load_glorys.R               # SST, salinity, currents (GLORYS12)
│   ├── load_wind.R                 # Wind speed/direction (hourly → daily)
│   ├── load_chl.R                  # Chlorophyll-a (ocean colour)
│   └── merge_env_data.R            # Merge to common 0.125° grid
│
├── 03_env_spatial/                 # Spatial operations on env data
│   ├── dist_coast_env_data.R       # Distance-to-coast
│   └── obtain_env_by_ports.R       # Port-buffer extraction
│
├── 04_models/                      # Econometric estimation
│   └── poisson_model.R             # Trip count + harvest allocation
│
├── 05_students/                    # Student-led modules
│   ├── base_datos_costos.R         # Trip reconstruction from logbooks
│   └── base_datos_precios.R        # Ex-vessel prices database
│
└── archive/                        # Legacy and reference code
```

## Data sources

| Source | Variables |
|---|---|
| SERNAPESCA | Landings, quota monitoring records |
| IFOP | Logbooks (haul coordinates, catch, effort); PRECIO and PROCESO sheets of the manufacturing survey |
| SUBPESCA | Veda calendar, annual TAC resolutions |
| Banco Central de Chile | FOB fishmeal price series, IPC |
| CNE | Diesel prices by region |
| Copernicus Marine Service | SST, salinity, currents (GLORYS12); chlorophyll-a (Ocean Colour L4); wind (ERA5) |
| CMIP6 (IPSL-CM6A-LR) | Historical and projected SST, O₂, CHL, wind, salinity under SSP2-4.5 and SSP5-8.5 |

The study area covers CS regions (V, VI, VII, VIII, IX, X, XIV, XVI). Raw data are not redistributed; see `data/README.md` for access instructions.

## Reproducibility

Requirements:

- R ≥ 4.2
- Core packages: `MASS`, `lavaan`, `sf`, `openxlsx`, `writexl`, `stargazer`, `dplyr`, `data.table`, `ncdf4`
- Optional: Python ≥ 3.10 with `openpyxl` (Excel inspection), `xarray` and `cdsapi` (Copernicus downloads)

To reproduce the main results:

```r
# 1. Clone the repo and set the working directory to its root
# 2. Populate data/raw/ (see data/README.md for access instructions)
# 3. Run the master pipeline
source("R/00_run_all.R")
```

Individual modules can be executed after sourcing `R/00_config/config.R`.

## Manuscript

The main manuscript is developed in R Markdown (`manuscript.Rmd`). The target journals are *Environmental and Resource Economics* (ERE) and *Marine Resource Economics* (MRE). Robustness checks are reported in the appendices.

## Funding

This work is funded by **ANID–FONDECYT Iniciación** (Chile).

## Citation

If you use this code, please cite:

> Quezada-Escalona, F. (forthcoming). Climate variability and harvest decisions in Chile's Centro-Sur small pelagic fishery. *Working paper, Universidad de Concepción.*

A `CITATION.cff` file is included for automated citation export.

## Contact

Felipe Quezada-Escalona
Departamento de Economía, Universidad de Concepción
<felipequezada@udec.cl>

## License

Code is released under the MIT License. See `LICENSE` for details. Data are subject to the licensing terms of the original providers.
