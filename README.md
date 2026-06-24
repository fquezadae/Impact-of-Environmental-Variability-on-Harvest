# Differential Climate Impacts on Fishing Effort in Chilean Small Pelagic Fisheries

**Replication package — submitted to *Marine Resource Economics* (June 2026)**

<!-- Badges -->
![R](https://img.shields.io/badge/R-%E2%89%A54.2-276DC3?logo=r)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-submitted%20to%20MRE%20(June%202026)-brightgreen)

## Overview

This repository is the **replication package** for the paper, developed under FONDECYT Iniciación for the Chilean Centro-Sur (CS) small pelagic fishery (SPF), composed of *Strangomera bentincki* (common sardine), *Engraulis ringens* (anchoveta), and *Trachurus murphyi* (jack mackerel):

> **"Differential Climate Impacts on Fishing Effort in Chilean Small Pelagic Fisheries"** — submitted to *Marine Resource Economics* (June 2026).

## Abstract

Climate-driven shifts in productivity reach fleets unevenly when species
portfolios differ and vessel range determines which stocks each fleet can
access. We measure this asymmetry for Chile's Central-South small pelagic
fishery (anchoveta, sardine, jack mackerel), under a fixed
industrial–artisanal allocation with active cessions. We couple a Bayesian
state-space stock-dynamics model fit to 2000–2024 assessments with a
vessel-level trip equation, with climate entering via biomass and weather
channels. Under a six-model CMIP6 ensemble, projected effort falls by
16–18 percent for the artisanal fleet but only 0.8–1.0 percent for the
industrial fleet — an asymmetry of seventeen to one, driven by artisanal
exposure to the two coastal stocks whose climate shifters are large and
identified. Because the artisanal fleet's restricted range prevents access
to offshore jack mackerel when coastal stocks collapse, policies that relax
technological constraints — vessel upgrading, port infrastructure, weather
services — may be more effective than reforms focused on quota allocation
alone.

**Keywords:** Bayesian state-space model; bioeconomic projection; Chilean small pelagic fishery; climate change; fishing effort; fleet heterogeneity; quota allocation.

**JEL:** Q22, Q54, Q57, Q58.

## Repository structure

```
.
├── paper/                             # Manuscript, appendices, Stan models
│   ├── paper1_climate_projections.Rmd  # Manuscript (R Markdown)
│   ├── sections/                       # Child Rmds wired into main
│   │   ├── results_identification.Rmd                # §4.1 (T4b-full rho posteriors + PPC adequacy)
│   │   ├── appendix_stress_tests.Rmd                 # Appendix A (stress tests + prior elicitation)
│   │   ├── appendix_predictive_diagnostics.Rmd       # Appendix B (PSIS-LOO / PSIS-LFO)
│   │   ├── appendix_posterior_diagnostics.Rmd        # Appendix C (posterior-predictive checks)
│   │   ├── appendix_convergence_diagnostics.Rmd      # Appendix D (R-hat / ESS for top-level T4b parameters)
│   │   ├── appendix_spatial_jurel.Rmd                # Appendix E (spatial robustness of jurel n.i.)
│   │   └── appendix_h_portfolio_and_counterfactual.Rmd  # Appendix F (inter-sectoral cessions; Tables F.1/F.2)
│   │       # appendix_variance_decomposition.Rmd and appendix_g_trips_variance_decomposition.Rmd
│   │       # are source-only (removed from the built supplement on 2026-06-17)
│   └── stan/                           # Compiled Stan programs for T4b
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
│   ├── 06_projections/                 # CMIP6 ensemble pipeline + Copernicus extended
│   │   ├── 01_cmip6_deltas.R                 # 6-model ensemble deltas (units-aware chlos)
│   │   ├── 01b_cmip6_enso_deltas.R           # ENSO Niño 3.4 deltas (App E)
│   │   ├── 00_sanity_check_cmip6.R           # Single-model sanity (legacy)
│   │   ├── 00b_sanity_check_ensemble.R       # Ensemble sanity (post-fix asserts)
│   │   ├── 06_extended_env_anomalies.R       # Copernicus extended anomalies for App E
│   │   ├── download_cmip6_ensemble.py        # Pangeo + ESGF fallback downloader (costero)
│   │   ├── download_cmip6_nino34.py          # Pangeo downloader for Niño 3.4 box (App E)
│   │   ├── download_copernicus_paper1_extended.py
│   │   ├── 02_project_and_predict.R          # Legacy V1 (deprecated)
│   │   ├── 03_project_biomass.R              # Legacy V1 (deprecated)
│   │   ├── 04_forward_simulation*.R          # Legacy V1 diagnostic (deprecated)
│   │   └── 05_sensitivity_sur_spec.R         # Legacy V1 diagnostic (deprecated)
│   ├── 07_structural_bio/              # Schaefer hindcast + official priors
│   └── 08_stan_t4/                     # Bayesian state-space (T4b, core models)
│       ├── _compstat_utils.R                          # Shared constants + scenario loader
│       ├── 04_fit_t4b_ind.R                           # No-shifter baseline
│       ├── 06_fit_t4b_omega.R                         # + residual covariance
│       ├── 08_fit_t4b_full.R                          # + SST/CHL shifters (leading model)
│       ├── 10_loo_t4b_compare.R                       # PSIS-LOO across specs
│       ├── 11_lfo_t4b_compare.R                       # PSIS-LFO across specs
│       ├── 12_growth_comparative_statics.R            # T5: r_eff under 6-model CMIP6 ensemble
│       ├── 13_trip_comparative_statics.R              # T7: Schaefer SS + NB → fleet trip response
│       ├── 14_refit_t4b_full_appendix_e.R             # T4b refit on alternative spatial domains
│       ├── 14b_fit_t4b_full_enso.R                    # T4b refit with basin-scale ENSO replacement (App E)
│       ├── 14c_fit_t4b_full_enso_joint.R              # T4b refit with all 3 shifters active for jurel (App E sensitivity)
│       ├── 15_appendix_e_sigma_ratios.R               # σ_post/σ_prior across domains (App E)
│       ├── 16_appendix_f_variance_decomposition.R     # Var decomp for growth (No included in paper)
│       ├── 17_appendix_g_trips_variance_decomposition.R  # Var decomp for trips (No included in paper)
│       ├── 18_power_calculation_enso.R                # Identification power for SST/CHL/ENSO (App E)
│       └── 19_project_jurel_enso_prior_propagation.R  # Prior-propagation envelope for r*_jurel (App E)
│
├── data/                               # Processed data (.rds)
│   ├── bio_params/                     # Official assessments (IFOP / SPRFMO)
│   ├── biomass/
│   ├── harvest/
│   ├── logbooks/                       # (gitignored — confidential IFOP microdata)
│   ├── outputs/t4b/                    # Stan fits + summaries
│   ├── ports/
│   ├── projections/                    # CMIP6 deltas + legacy SUR projections
│   └── trips/
│
├── figs/                               # Figures
├── tables/                             # Exported tables
│
├── bibliography.bib                    # Shared bibliography
├── chicago-author-date.csl            # Citation style (author-date)
└── knit.R                              # Render manuscripts
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
| NOAA-CPC `sstoi.indices` (ERSSTv5) | ENSO Niño 3.4 monthly index for the basin-scale shifter test of Appendix E |
| CMIP6 six-model ensemble | Projected SST, chlorophyll-a, surface winds, and Niño 3.4 SST under SSP2-4.5 and SSP5-8.5: IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, MPI-ESM1-2-HR (downloaded via Pangeo + ESGF fallback; Niño 3.4 box on a separate parallel pull) |

Raw data are not redistributed; see `data/README.md` for access instructions.

### Data not included in this repository (request to reproduce)

The repository ships every **processed** series the manuscript and the
projections need, so **knitting the PDF and reproducing the fleet-effort
projections require no external data** — a fresh clone is sufficient. The inputs
below are needed only to re-fit the Bayesian stock model or to rebuild the
pipeline from raw.

**To re-fit the stock model** (`R/08_stan_t4/08_fit_t4b_full.R`, needs cmdstan)
you need the two daily environmental grids under
`FONDECYT_DATA/Environmental/env/` (see `data/README.md`):

| File | What it is | How to obtain |
|---|---|---|
| `EnvCoastDaily_2012_2025_0.125deg.rds` | Daily coastal SST / CHL / wind grid, 2012–2025 | Request from the author, or rebuild from Copernicus via `R/02_env_processing/` |
| `EnvCoastDaily_2000_2011_0.25deg.rds` | Daily coastal grid, 2000–2011 (coarser resolution) | Same as above |

The projections do not need these grids either: the posterior draws ship as
`data/outputs/t4b/t4b_full_draws.rds`, so `R/08_stan_t4/13_trip_comparative_statics.R`
reproduces the trip tables offline (see **Reproducibility** above). Everything
the knit reads — `biomass_dt.rds`, `sernapesca_v2.rds`, `poisson_dt.rds`, the
CMIP6 deltas, the T4b posterior summary/draws, and the comparative-statics
tables — is already tracked here.

**To rebuild the full pipeline from raw**, you additionally need the
non-redistributable raw inputs documented in `data/README.md`:

- **IFOP logbooks** (vessel-level haul / catch / effort) — confidential, IFOP data-sharing agreement.
- **Raw SERNAPESCA landings** (`sernapesca_bd_desembarque_raw.csv`) — Ley 20.285 transparency request.
- **Environmental NetCDF** (GLORYS12 SST, Ocean-Colour CHL, ERA5 wind) — Copernicus Marine Service.
- **CMIP6 NetCDF ensemble** — Pangeo / ESGF.
- **Third-party technical reports** (IFOP / SPRFMO / SUBPESCA PDFs) — public, from each institution.

For the confidential logbooks or the environmental grids (needed only for the
stock-model re-fit or the raw rebuild — not for the knit or the projections),
email the author: **felipequezada@udec.cl**.

## Reproducibility

Requirements:

- **R ≥ 4.2** with packages: `dplyr`, `tidyr`, `data.table`, `tibble`,
  `readr`, `purrr`, `janitor`, `ggplot2`, `ggridges`, `scales`, `viridis`,
  `lavaan`, `sandwich`, `lmtest`, `kableExtra`, `stargazer`, `MASS`, `sf`,
  `openxlsx`, `ncdf4`, `cmdstanr`, `posterior`, `here`, `withr`.
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

# Render the paper
source("knit.R")
```

**Reproducing the fleet-effort projections from the shipped data alone.**
The vessel-year panel `data/trips/poisson_dt.rds` and the compact posterior
draws of the stock-dynamics model (`data/outputs/t4b/t4b_full_draws.rds` —
`r_base`, `K_nat`, `rho_sst`, `rho_chl` per stock) both ship with the
repository, so the trip fits and the comparative-statics tables regenerate
**without the raw IFOP logbooks, without cmdstan, and without the environmental
grids**:

```r
# Re-fit the four NB trip models from the shipped panel
source("R/04_models/refit_from_poisson_dt.R")

# Regenerate the trip comparative-statics tables (uses the shipped draws if the
# full Stan fit data/outputs/t4b/t4b_full_fit.rds is absent)
options(t6.run_main = TRUE)
source("R/08_stan_t4/13_trip_comparative_statics.R")
```

To regenerate the stock-dynamics posterior itself you need cmdstan and the two
environmental grids (request-only); run `R/08_stan_t4/08_fit_t4b_full.R`
(`seed = 2026`), which rewrites both the full fit and `t4b_full_draws.rds`. The
full `R/04_models/poisson_model.R` rebuilds the vessel-year panel from the raw
IFOP logbooks (`data/logbooks/`, confidential) and is likewise author-only.

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

For the basin-scale ENSO pipeline of Appendix E (also one-shot;
outputs cached in `data/bio_params/`, `data/cmip6/`, and
`data/outputs/t4b/`):

```r
# Historical ENSO Niño 3.4 from NOAA-CPC ERSSTv5
source("R/01_data/extract_oisst_nino34.R")

# CMIP6 Niño 3.4 deltas (after running download_cmip6_nino34.py)
source("R/06_projections/01b_cmip6_enso_deltas.R")

# Identification-power calculation (minimum-detectable elasticity)
options(power.run_main = TRUE)
source("R/08_stan_t4/18_power_calculation_enso.R")

# Basin-scale ENSO refit (replacement convention, lag 1)
options(t4b.enso.run_main = TRUE, t4b.enso.lag = 1L)
source("R/08_stan_t4/14b_fit_t4b_full_enso.R")
# Lag 2 sensitivity
options(t4b.enso.run_main = TRUE, t4b.enso.lag = 2L)
source("R/08_stan_t4/14b_fit_t4b_full_enso.R")

# Joint-shifter sensitivity (SST + CHL + ENSO active for jurel)
options(t4b.enso.joint.run_main = TRUE, t4b.enso.joint.lag = 1L)
source("R/08_stan_t4/14c_fit_t4b_full_enso_joint.R")

# Prior-propagation envelope for r*_jurel under SSP scenarios
source("R/08_stan_t4/19_project_jurel_enso_prior_propagation.R")
```

## Funding

This work is funded by **ANID--FONDECYT Iniciación** (Chile).

## Citation

> Quezada-Escalona, F. (2026). Differential Climate Impacts on Fishing Effort in Chilean Small Pelagic Fisheries. *Working paper, Universidad de Concepción* (submitted to *Marine Resource Economics*).

## Contact

Felipe Quezada-Escalona
Departamento de Economía, Universidad de Concepción
<felipequezada@udec.cl>

## License

Code is released under the MIT License. Data are subject to the licensing terms of the original providers.
