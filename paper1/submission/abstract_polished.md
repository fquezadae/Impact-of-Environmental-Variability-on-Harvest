# Abstract — polish v1 (2026-04-27)

**Working draft for review.** Not yet patched into `paper1_climate_projections.Rmd`. Once approved, the YAML frontmatter `abstract:` field at line 37 of the main Rmd is the only edit needed.

---

## Polished version (v2 — 2026-04-27, post Felipe round 1)

In Chile's multi-species small pelagic fishery — anchoveta, sardina común, and jack mackerel — climate change reshapes long-run stock productivity, but the direction of the distributional impact across the artisanal and industrial fleets depends on whether climate response parameters are identified structurally or read off reduced-form correlations. We identify a set of structural climate shifters $(\rho_i^{SST}, \rho_i^{CHL})$, interpretable as semi-elasticities of intrinsic stock productivity with respect to sea-surface temperature and log-chlorophyll-a anomalies, within a Bayesian state-space specification calibrated on official IFOP and SPRFMO assessments for 2000--2024. Priors are derived from a transparent reduced-form stress-test protocol over the same period, and a complementary negative binomial model captures annual fishing trips as a function of prices, vessel-level harvest allocations, weather, and regulatory closures, estimated separately for the artisanal and industrial fleets. Applying the identified shifters to CMIP6 projections (IPSL-CM6A-LR, SSP2-4.5 and SSP5-8.5; mid- and end-of-century), we report the comparative-statics change in intrinsic productivity as a full posterior: anchoveta's posterior median declines by 51\% under SSP2-4.5 mid-century, and by 89\% under SSP5-8.5 end-of-century read as a structural stress test under the log-linear shifter; sardina común declines by 90\% and effectively 100\%, respectively. The jack mackerel shifters are not identified — the posterior-to-prior standard-deviation ratio is essentially unity, against 0.4--0.8 for the coastal-upwelling stocks — consistent with the species' transboundary SPRFMO management. Because the artisanal fleet's portfolio is concentrated in the sardina--anchoveta pair, it bears a sharper long-run harvest-capacity decline than the industrial fleet, whose portfolio is more diversified. These results reverse the sign of the distributional asymmetry implied by a reduced-form reading of the same data, and carry direct implications for Chile's *Límite Máximo de Captura por Armador* (LMCA) regime under non-stationary climate.

---

## Round 1 changes (Felipe 2026-04-27)

- **Restored** the NB covariate list (prices, vessel-level harvest allocations, weather, regulatory closures) — referees see the trip-equation architecture from the abstract, not just from §3.
- **Dropped** the binomial Latin names (*Engraulis ringens*, *Strangomera bentincki*, *Trachurus murphyi*). JAERE is not a marine ecology journal; the Spanish common names + English jack mackerel are sufficient anchors. This is the "más biológico" content that earns the budget for the covariate list.
- **Confirmed** "non-stationary climate" in the closing line and *LMCA* with full Spanish expansion on first occurrence.

---

## What changed vs current abstract

| # | Change | Pre-empts which critique |
|---|--------|--------------------------|
| 1 | Opens with the headline contrast (structural ID vs reduced-form determines sign of distributional impact), instead of "We study how…" | Positioning |
| 2 | Adds "transparent reduced-form stress-test protocol" for the prior elicitation | Methodological contribution (cover letter) |
| 3 | SSP5-8.5 numbers framed as "structural stress test under the log-linear shifter" | Critique 1 (log-linear extrapolation) |
| 4 | Drops "in both cases the posterior probability of a negative response is effectively one" — redundant given the median magnitudes; saves 14 words for higher-value content | Word budget |
| 5 | Jurel n.i. quantified as "posterior-to-prior standard-deviation ratio is essentially unity, against 0.4--0.8 for the coastal-upwelling stocks" | Critiques 2 (N=25) and 3 (jurel n.i.) |
| 6 | Closes naming the LMCA regime explicitly (*Límite Máximo de Captura por Armador*) instead of "quota-allocation architecture" | Edit #8 of the consolidated list |
| 7 | "non-stationary climate" replaces "under climate change" in the closing line — sharper for an econometrics audience | JAERE positioning |

## What is preserved

- Three-stock common name + Latin name introduction (referees expect this).
- $(\rho_i^{SST}, \rho_i^{CHL})$ as semi-elasticities (the structural object).
- Bayesian state-space + IFOP/SPRFMO calibration.
- NB trip equation as complement.
- CMIP6 / IPSL-CM6A-LR / SSP2-4.5 + SSP5-8.5 / mid + end-century scope.
- Numerical headlines: −51\% / −89\% (anchoveta); −90\% / −100\% (sardina común).
- Portfolio asymmetry argument (artisanal more exposed via concentration in sardina--anchoveta pair).
- Sign-reversal headline against the reduced-form benchmark.

## What is dropped

- "as a function of prices, vessel-level harvest allocations, weather, and regulatory closures" — the trip-equation covariate list. Referees see the full specification in Section 3 anyway; the abstract just needs to signal the architecture.
- "in both cases the posterior probability of a negative response is effectively one" — the median magnitudes already make this point; saving the words.
- Closing phrase "under climate change" → "under non-stationary climate" (a one-word swap that signals the econometric framing).

## Open questions for Felipe

1. **Word budget vs information density.** Current draft is roughly the same length as the current abstract. Want me to compress to ~250 words by dropping one or two of (i) the prior-elicitation phrase, (ii) the σ-ratio quantification of jurel n.i., or (iii) the NB sentence? My recommendation is to keep all three — each pre-empts a specific JAERE referee concern and the cumulative weight of the abstract works for us.

2. **"non-stationary climate" vs "climate change" in the closing line.** The first phrasing is sharper for an econometrics-oriented JAERE referee (signals the time-series identification problem); the second is more familiar in policy framings. I'd keep "non-stationary climate" for JAERE and switch back to "climate change" if the eventual fallback is Ecological Economics.

3. **LMCA acronym in italics.** Current draft writes *Límite Máximo de Captura por Armador* (LMCA) with the Spanish phrase italicized. JAERE house style uses italics for non-English phrases on first occurrence; double-check at submission time.
