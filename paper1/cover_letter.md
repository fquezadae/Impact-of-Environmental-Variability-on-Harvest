---
title: "Cover Letter — Marine Resource Economics"
author: "Felipe J. Quezada-Escalona"
date: "May 2026"
output:
  pdf_document:
    latex_engine: xelatex
    pandoc_args: ["--variable=fontsize:11pt"]
geometry: margin=1in
header-includes:
  - \usepackage{setspace}
  - \singlespacing
---

Felipe J. Quezada-Escalona\
Associate Professor, Department of Economics\
Universidad de Concepción\
Victoria 471, Concepción, Chile\
felipequezada@udec.cl

`r format(Sys.Date(), "%B %d, %Y")`

Editor-in-Chief\
*Marine Resource Economics*

Dear Editor:

I am pleased to submit the manuscript *Differential Climate Impacts on Fishing Effort in Chilean Small Pelagic Fisheries* for consideration as an Article in *Marine Resource Economics*.

The paper quantifies the distributional incidence of climate change on the artisanal and industrial fleets of Chile's largest fishery, the Central-South small pelagic complex (anchoveta, sardina común, and jack mackerel). It couples a Bayesian state-space model of multi-species stock dynamics, identified on official IFOP and SPRFMO assessment data over 2000–2024, with negative binomial trip equations estimated separately for the two sectors. Climate enters through two channels: an indirect biomass channel built from structural semi-elasticities $(\rho_i^{SST}, \rho_i^{CHL})$ and a direct weather channel from CMIP6 near-surface winds. Under a six-model CMIP6 ensemble spanning SSP2-4.5 and SSP5-8.5, projected fleet-level effort falls by 13–15% for the artisanal fleet but only 0.8–1.0% for the industrial fleet—an asymmetry of roughly fifteen to one. The mechanism is the interaction of differential portfolio exposure with the limited cross-sector transferability of Chile's statutory fractioning regime (Article 47 of the LGPA, revised under Ley N°21.752 of 2025). The empirical contribution is a structurally identified vector of climate semi-elasticities for an under-studied Southeast Pacific fishery, and the policy contribution is a counterfactual evaluation of the 2025 fractioning reform under climate stress that distinguishes redistributive from allocative effects.

The submission consists of two files: the main manuscript (`paper1_climate_projections.pdf`, 42 double-spaced manuscript pages, including title page, abstract, references, and tables) and an Online Appendix (`paper1_supplementary_materials.pdf`, 29 pp, organised in nine sections A–I that document Bayesian model diagnostics, spatial robustness of the jurel non-identification result, variance decompositions across the CMIP6 ensemble, descriptive evidence on multi-species permit portfolios, and the policy counterfactual under Ley N°21.752).

**Disclosure statement.** I am an Associate Professor in the Department of Economics at Universidad de Concepción, Chile, and have no academic, corporate, or other affiliations beyond this position relevant to the work. This research was funded by the Agencia Nacional de Investigación y Desarrollo (ANID), Government of Chile, through FONDECYT Iniciación project N°11250223; partial support was also provided by ANID through the INCAR2 Centro Interdisciplinario de Investigación para la Acuicultura Sustentable, project CIA250009. The funders had no role in study design, data collection and analysis, decision to publish, or preparation of the manuscript. I declare no conflicts of interest.

**Data and code provenance.** All analysis code is openly available at `https://github.com/fquezadae/Impact-of-Environmental-Variability-on-Harvest` and will be archived at acceptance as a versioned Zenodo release with a citable DOI. Public-domain data sources used in the analysis are the E.U. Copernicus Marine Service for historical environmental covariates, the CMIP6 archive (accessed through the Earth System Grid Federation) for climate projections, IFOP annual technical reports for anchoveta and sardina común stock-assessment biomass series, SPRFMO Scientific Committee reports for the transboundary jurel biomass and catch series, and SERNAPESCA quota control reports for the cesion-flow documentation in the Online Appendix. The vessel-level logbook records used in the trip-equation panel are accessed under the IFOP–Convenio Desempeño framework with restricted-access conditions; vessel identifiers have been anonymised, and aggregate-level processed data sufficient to reproduce all reported tables and figures are included in the replication repository. Qualified researchers may obtain access to the underlying logbook records under equivalent confidentiality agreements with IFOP.

This work has not been previously published nor is it under consideration elsewhere. I look forward to your editorial decision.

Sincerely,

Felipe J. Quezada-Escalona
