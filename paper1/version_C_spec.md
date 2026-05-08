# Version C: Bioeconomic Model with Endogenous Quota-Binding Regime

**Project:** Climate Change, Stock Productivity, and Fishing Effort in Chile's Multi-Species Small Pelagic Fishery (FONDECYT Iniciación 11250223)

**Author:** Felipe J. Quezada-Escalona, Universidad de Concepción

**Repository:** `D:/GitHub/Impact-of-Environmental-Variability-on-Harvest`

---

## 1. Motivation

We follow Kasperski (2015) in modeling annual fishing trips as a count process that depends on output prices, vessel-level allocated harvest, aggregate quota, vessel characteristics, and operating conditions. Kasperski's framework is calibrated for the Alaska multi-species fishery, where individual transferable quota (ITQ) enforcement is sufficiently tight that vessel-level realized harvest equals allocated quota by construction; under those conditions, the legal TAC is binding by definition and quota is the active constraint on harvest in every year.

The Chilean small pelagic fishery (SPF) of the Centro-Sur deviates from this benchmark. Historical episodes of stock collapse — anchoveta classified as collapsed through 2018 and jack mackerel overexploited until 2018 — generated multi-year periods in which realized harvest fell below the legal TAC because biomass capacity, not the regulatory cap, was the active constraint. Under climate-induced biomass collapse projected for SSP5-8.5 end-of-century, this regime becomes more frequent rather than less.

Version C extends Kasperski (2015) with a single methodological modification: the quota-binding regime is determined endogenously by the data, not assumed. Realized harvest is bounded above by the minimum of the legal TAC and the biomass-feasible harvest, and the regime that binds in any given (species, year) is an output of the model rather than an input.

## 2. Single extension relative to Kasperski (2015)

| Margin | Kasperski (2015) | Version C |
|---|---|---|
| Vessel-level allocated harvest | $h_{vg,s}=\omega_{vs}\bar{Q}_{sy}$ (assumes binding) | $H^{opp}_{vy,s}=\omega_{vs}\min(\bar{Q}_{sy},\bar{u}_sB_{sy})$ (endogenous) |
| Quota-binding regime | Maintained by ITQ enforcement | Determined by data through the $\min$ operator |
| All other features | Identical | Identical |

The $\min$ operator handles binding endogenously: if $\bar{Q}_{sy}<\bar{u}_sB_{sy}$, the legal cap is the active constraint (quota-binding regime); if $\bar{u}_sB_{sy}<\bar{Q}_{sy}$, biomass is the active constraint (biology-binding regime). Both regimes are observed in the historical Chilean SPF data and both are projected under CMIP6 climate scenarios.

## 3. Model specification

### 3.1 Stock dynamics (unchanged)

Bayesian state-space Schaefer specification with structural climate shifters:

$$B_{i,t+1}=B_{i,t}+r_{i,t}B_{i,t}\!\left(1-\frac{B_{i,t}}{K_i}\right)-C_{i,t}+\varepsilon_{i,t}$$

$$r_{i,t}=r_i^0\exp\!\big(\rho_i^{SST}(SST_{t-1}-\overline{SST})+\rho_i^{CHL}(\log CHL_{t-1}-\overline{\log CHL})\big)$$

Posterior of $(\rho_i^{SST},\rho_i^{CHL})$ identified for anchoveta and sardina común; non-identified for jurel CS (held at prior mean). Specification, priors, and identification details unchanged from current Paper 1.

### 3.2 Negative binomial trip equation (Kasperski-aligned with single extension)

Following Kasperski (2015) Eq. (17), with regressor vector $U_{vy}=[p_{sy},H^{opp}_{vy,s},\bar{Q}_{sy},\mathbf{Z}_v,\mathbf{O}_{vy}]$:

$$T_{vy}\sim NB(\mu_{vy},\phi),\qquad \mu_{vy}=\exp\!\Big(\beta_0+\sum_s\beta_p^s p_{sy}+\sum_s\beta_h^s H^{opp}_{vy,s}+\sum_s\beta_q^s\bar{Q}_{sy}+\boldsymbol{\gamma}'\mathbf{Z}_v+\boldsymbol{\delta}'\mathbf{O}_{vy}+\eta_y\Big)$$

with vessel-level feasible-opportunity harvest by species:

$$H^{opp}_{vy,s}=\omega^{hist}_{vs}\cdot\min\!\big(\bar{Q}_{sy},\;\bar{u}_sB_{sy}\big)$$

estimated separately for $f\in\{IND,ART\}$ with vessel-clustered SEs and year fixed effects $\eta_y$. Coefficients are species-specific, matching the dimensionality of Kasperski's vector $\beta_g$ with $3n+M+k+1$ parameters.

Three remarks on identification:

1. *On endogeneity of $H^{opp}$.* As in Kasperski, the regressor is constructed as the product of historical share $\omega^{hist}_{vs}$ (predetermined) and the realized opportunity $\min(\bar{Q}_{sy},\bar{u}_sB_{sy})$ (predetermined to the year-$y$ trip decision under the convention that quotas and biomass are announced before vessels plan annual effort). No instrumentation is required.

2. *On year fixed effects and the identification of $\beta_q^s$.* Year fixed effects absorb $\bar{Q}_{sy}$ when it varies only by year (no cross-vessel variation). In our specification $\bar{Q}_{sy}$ is allocated by region (V, VIII, IX, XIV, X for artisanal; V–IX and XIV–X for industrial), so within-year cross-region variation persists and $\beta_q^s$ is identifiable. If regional variation is too thin in some species-years, $\beta_q^s$ may be set to zero with $\bar{Q}_{sy}$ entering only through $H^{opp}_{vy,s}$.

3. *On the coefficient interpretation.* $\beta_h^s$ identifies the elasticity of trips to vessel-level *opportunity* for species $s$, accounting for whether the active constraint in year $y$ is the legal cap or biomass capacity. $\beta_p^s$ identifies the direct price elasticity holding opportunity fixed.

### 3.3 Inverse demand (from Ricardo's module)

$$\log p_{sy}=\sum_{s'}\gamma_{ss'}\log H_{s'y}+\gamma_H\log P^{FOB}_y+\epsilon_{sy}$$

Pending finalization with IAIDS structure; see `R/05_students/base_datos_precios.R`.

### 3.4 Cost function (pending from student, July 2026)

Quadratic restricted cost function with conditional input demands; structure already specified in Section 4 of the manuscript.

## 4. Empirical diagnostic of the historical binding regime

Required preliminary step. Compute the regime classification for each (species, year, sector) cell:

```r
# pseudocode — to be implemented in R/04_models/regime_diagnostic.R
library(dplyr)

regime_diag <- harvest_data |>
  group_by(year, species, sector) |>
  summarise(
    H_realized = sum(harvest),
    Q_legal    = TAC[1],
    B_year     = biomass[1],
    util       = H_realized / Q_legal,
    biom_rate  = H_realized / B_year,
    .groups    = "drop"
  ) |>
  mutate(
    regime = case_when(
      util >= 0.85 & biom_rate <  0.4 ~ "quota_binding",
      util <  0.85 & biom_rate >= 0.3 ~ "biology_binding",
      TRUE ~ "ambiguous"
    )
  )
```

Report a table of regime fractions by species × sector × decade. The empirical pattern justifies the Version C extension: if the share of biology-binding cells is non-trivial (expected $>20\%$ for anchoveta pre-2018 and jurel late 2000s), the standard Kasperski specification mis-identifies $\beta_h^s$ by treating quota as the universal constraint.

### 4.1 Decision criterion: when Version C is necessary

The diagnostic output of Section 4 determines whether the Version C extension is empirically justified or whether the standard Kasperski specification (Version A) suffices. The decision rule is:

| Biology-binding share | Recommended path | Rationale |
|---|---|---|
| $\geq 20\%$ of cells | **Adopt Version C as primary specification.** | Substantial fraction of historical observations were biology-binding; the assumption of universal quota-binding mis-identifies $\beta_h^s$ and biases the projection of climate impacts. |
| $5\%$–$20\%$ | **Adopt Version A as primary; report Version C as robustness in appendix.** | Version C extension is marginal but defensible given the heterogeneity of regime conditions across the sample. Sensitivity reported alongside main results. |
| $< 5\%$ | **Adopt Version A pure (Kasperski direct), drop Version C.** | The legal TAC was the active constraint in essentially all observations; the $\min$ operator is decorative and should not be carried into the manuscript. Cite Kasperski (2015) directly without methodological extension. |

Interpretation guidance for the species-sector breakdown:

- *Anchoveta CS pre-2018:* expected biology-binding share $>50\%$ given the documented collapsed-status classification through 2018.
- *Jurel CS late 2000s (2009–2014):* expected biology-binding share $>30\%$ given the documented overexploited classification and stock collapse.
- *Sardina común throughout sample:* expected $<10\%$ biology-binding given the relatively stable MSY-class status.
- *Anchoveta and jurel post-2020:* expected $<10\%$ biology-binding given recovered stock status.

A reasonable expectation for the pooled diagnostic is between 15% and 30% biology-binding cells, placing the analysis in the upper half of the (5%–20%) bracket or in the ($\geq 20\%$) bracket. The Version C extension is therefore likely justified, but the empirical test must be run before committing to the implementation.

The diagnostic also informs the framing of the manuscript abstract:

> *If $\geq 20\%$ biology-binding:* "We extend Kasperski (2015) with an endogenous quota-binding regime motivated by an empirical diagnostic showing that X% of historical species-year-sector cells were biology-binding under the maintained ITQ-style construction. The extension corrects a mis-specification that propagates into the projection of climate impacts."
> *If 5%–20% biology-binding:* "We follow Kasperski (2015) directly and report sensitivity to an endogenous quota-binding regime as robustness in Appendix X."
> *If $<5\%$ biology-binding:* "We follow Kasperski (2015) directly. The maintained assumption of binding quota is empirically supported by the observation that X% of historical species-year-sector cells exhibit quota-utilisation rates above 0.85."

The framing question is therefore answered by the diagnostic, not by prior assumption.

## 5. Calibration of $\bar{u}_s$

The maximum exploitation rate $\bar{u}_s$ is the empirical analog of $F_{MSY}/B_{MSY}$ for each species. Two routes:

- *Direct calibration:* $\bar{u}_s$ as the 90th–95th percentile of $H_{sy}/B_{sy}$ over quota-binding observations identified in Section 4.
- *External calibration:* $\bar{u}_s$ from IFOP single-species stock assessments (anchoveta, sardina común) and SPRFMO assessments (jurel).

Prefer external calibration when available; otherwise use direct calibration as fallback. Report sensitivity of main results to a $\pm 20\%$ perturbation of $\bar{u}_s$ as robustness.

## 6. Social planner optimization

Programme:

$$\max_{\{\bar{Q}_{sy}\}_{s,y}}\;\sum_{y=1}^{Y}\rho^{y-1}\!\left[\sum_s P_s(\mathbf{H}_y,P^{FOB}_y)H_{sy}-\sum_v C_v(h_{vy},T_{vy}\mid\mathbf{Z}_v,\mathbf{O}_{vy})\right]$$

subject to:

1. *Realised aggregate harvest (endogenous binding):* $H_{sy}=\min(\bar{Q}_{sy},\bar{u}_sB_{sy})$
2. *Vessel-level harvest (Kasperski-style fixed shares):* $h_{vy,s}=\omega^{hist}_{vs}\cdot H_{sy}$
3. *NB trip equation evaluated at equilibrium:* $T_{vy}=\exp(\hat\beta_0+\sum_s\hat\beta_p^s p_{sy}+\sum_s\hat\beta_h^s\omega^{hist}_{vs}H_{sy}+\cdots)$
4. *Stock dynamics (SUR):* $B_{i,t+1}=B_{i,t}+r_{i,t}B_{i,t}(1-B_{i,t}/K_i)-H_{i,t}+\varepsilon_{i,t}$
5. *Inverse demand:* $P_{sy}=D_s^{-1}(\mathbf{H}_y,P^{FOB}_y)$
6. *Non-negativity and biological floors:* $\bar{Q}_{sy}\geq 0$, $B_{sy}\geq B^{min}_s$

Control vector dimension: $S\times Y=3\times 25=75$.

Solve with `optim(L-BFGS-B)` with bounds for each (climate scenario, CMIP6 model) combination. Skeleton present in chunk `modelo npv` of current manuscript; needs to be updated to incorporate the $\min$ operator on harvest and the species-specific $\hat\beta_h^s$ from the re-estimated NB.

## 7. Outputs

For each climate scenario × CMIP6 model combination:

- $\boxed{\bar{Q}^*_{sy}}$ — optimal TAC by species-year (planner choice).
- $\boxed{H^*_{sy}=\min(\bar{Q}^*_{sy},\bar{u}_sB^*_{sy})}$ — realised aggregate harvest.
- $\boxed{h^*_{vy,s}=\omega^{hist}_{vs}H^*_{sy}}$ — realised vessel-level harvest.
- $\boxed{T^*_{vy}}$ — optimal trips by vessel-year; aggregate to fleet $T^*_{f,y}=\sum_{v\in f}T^*_{vy}$.
- $\boxed{B^*_{sy}}$ — equilibrium biomass trajectory.
- $\boxed{P^*_{sy}}$ — equilibrium prices.
- $\boxed{\pi^*_{vy}}$ — vessel profit; aggregate to fleet and discount to NPV.
- *Regime classification:* fraction of $(s,y)$ cells in `quota_binding` vs `biology_binding` regime under each climate scenario. This is the central novel result.

## 8. Comparison panels

Report side-by-side specifications for the central results table:

| Specification | Allocated harvest | Quota regime |
|---|---|---|
| **Version A (Paper 1, current)** | $H^{alloc}_{vy}=\sum_s\omega_{vs}\bar{Q}_{sy}$ | Assumed binding |
| **Version C (Paper 2, proposed)** | $H^{opp}_{vy,s}=\omega_{vs}\min(\bar{Q}_{sy},\bar{u}_sB_{sy})$ | Endogenous (data-driven) |

Version C nests Version A: in the limit $\bar{u}_s\to\infty$ (biomass never binds), $H^{opp}\to\omega\bar{Q}$ and the two specifications coincide. The empirical departure between them is the share of biology-binding cells in the sample and in the projection.

## 9. Implementation plan

| Step | Description | Estimated time | Output file |
|---|---|---|---|
| 1 | Empirical diagnostic of historical binding regime | 1–2 days | `R/04_models/regime_diagnostic.R` + diagnostic table |
| 2 | Calibrate $\bar{u}_s$ from external assessments and binding-only subsample | 1 day | constants in `R/00_config/config.R` |
| 3 | Re-estimate NB by fleet with species-specific $\beta_h^s, \beta_p^s, \beta_q^s$ and $H^{opp}_{vy,s}$ regressor | 1–2 days | updated `R/04_models/poisson_model.R` |
| 4 | Forward-simulation loop with endogenous binding via $\min$ operator | 2–3 days | `R/05_optimization/forward_sim_versionC.R` |
| 5 | Social planner optimization wrapper and CMIP6 ensemble loop | 2–3 days | `R/05_optimization/planner_solve.R` |
| 6 | Comparison panels Version A vs C across 4 climate scenarios | 1–2 days | manuscript tables and figures |

Total: approximately 1.5 weeks of dedicated work, conditional on (i) cost module from student being available, and (ii) inverse demand module from Ricardo being available. If either is pending, use interim point-estimate approximations.

## 10. Headline framing for the paper

> We follow Kasperski (2015) in specifying a multi-species bioeconomic framework for the Chilean small pelagic fishery, with one methodological extension: the quota-binding regime is determined endogenously through the $\min$ operator $H^{opp}_{vy,s}=\omega_{vs}\min(\bar{Q}_{sy},\bar{u}_sB_{sy})$, motivated by historical episodes of stock collapse in the Centro-Sur fishery that fall outside the Alaska ITQ context for which Kasperski's specification is calibrated. The extension nests the original specification as the limiting case in which biomass never binds, and converts the historically maintained assumption of quota-binding into an empirically testable regime classification.

## 11. References

- Kasperski, S. (2015). Optimal multi-species harvesting in ecologically and economically interdependent fisheries. *Environmental and Resource Economics*, 61(4), 517–557.
- Free, C.M. et al. (2019). Impacts of historical warming on marine fisheries production. *Science*, 363(6430), 979–983.
- Hilborn, R., & Walters, C.J. (1992). *Quantitative Fisheries Stock Assessment*. Chapman and Hall.
- Maunder, M.N., & Punt, A.E. (2013). A review of integrated analysis in fisheries stock assessment. *Fisheries Research*, 142, 61–74.

---

*Document prepared for delegation via Cowork. All mathematical conventions match the current Paper 1 manuscript at `D:/GitHub/Impact-of-Environmental-Variability-on-Harvest/manuscript.Rmd`.*
