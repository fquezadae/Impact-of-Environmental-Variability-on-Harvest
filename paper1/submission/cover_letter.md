# Cover letter — paper 1, JAERE submission

**Status:** working draft v1, 2026-04-27. Plain-text working version; final-format conversion (PDF or DOCX) at submission time. All `[BRACKETED]` items are placeholders to fill in before submission.

---

[Submission date]

The Editor
*Journal of the Association of Environmental and Resource Economists*
[Editor name and address — fill at submission time]

Dear Editor,

I am pleased to submit the manuscript "Climate Change, Stock Productivity, and Fishing Effort in Chile's Multi-Species Small Pelagic Fishery" for consideration in the *Journal of the Association of Environmental and Resource Economists*.

The paper estimates the long-run productivity response of the three pelagic stocks of Chile's Centro-Sur fishery — anchoveta, sardina común, and jack mackerel — to CMIP6 climate scenarios within a Bayesian state-space framework, and uses the identified structural parameters to quantify the distributional impact of climate change across the artisanal and industrial fleets that target them. I believe the manuscript fits JAERE's editorial scope along three methodological lines:

**1. A transparent prior elicitation protocol via reduced-form stress tests.** The weakly informative priors on the climate shifters $(\rho_i^{SST}, \rho_i^{CHL})$ are derived from a deterministic Schaefer hindcast in which the biological parameters $(r_i^0, K_i)$ are fixed at the centres of the official IFOP and SPRFMO assessments and the shifters are estimated by bounded least squares on the same 2000–2024 sample. The resulting priors are then carried into a Bayesian state-space likelihood that re-estimates the shifters under full process and observation noise. The two-step protocol — documented in Appendix A and Table A.1–A.2 of the manuscript — is replicable and decouples the prior from the structural likelihood, which I view as a contribution beyond the empirical results of the paper.

**2. Cowles-style structural identification of the climate shifters, with a sign-reversal headline.** The shifters $(\rho_i^{SST}, \rho_i^{CHL})$ are interpreted as semi-elasticities of intrinsic stock productivity with respect to sea-surface temperature and log-chlorophyll-a anomalies. Their structural identification reverses the direction of the distributional asymmetry across the artisanal and industrial fleets that a reduced-form regression of growth increments on environmental anomalies would have implied. This contrast is the empirical headline of the paper and motivates Cowles-style structural inference as the appropriate econometric posture for fishery climate-impact assessment, against forecasting-oriented alternatives.

**3. Honest reporting of identification failures as substantive findings.** The jack mackerel shifters are not identified in the 2000–2024 sample — the posterior-to-prior standard-deviation ratio is essentially unity, against 0.4–0.8 for the two coastal-upwelling stocks. The paper reports this as a substantive finding consistent with the species' transboundary SPRFMO management, rather than as a model failure to be patched. A reduced-form specification would have produced a precisely estimated but structurally meaningless coefficient; the structural state-space correctly attributes the absence of local climate signal to non-identification.

Applying the identified shifters to CMIP6 projections (IPSL-CM6A-LR; SSP2-4.5 and SSP5-8.5; mid- and end-of-century), the paper reports comparative-statics declines in intrinsic productivity of 51% for anchoveta and 90% for sardina común under SSP2-4.5 mid-century, and stress-test magnitudes under SSP5-8.5 end-of-century that I read as structural extrapolations under the maintained log-linear shifter rather than as forecasts. Because the artisanal fleet's portfolio is concentrated in the sardina–anchoveta pair, it bears a sharper long-run harvest-capacity decline than the diversified industrial fleet — a direct implication for Chile's *Límite Máximo de Captura por Armador* (LMCA) regime under non-stationary climate.

The paper is sized as an identification contribution. A natural downstream extension uses the posterior reported here as a prior for a Stackelberg bi-level optimization in which the regulator chooses the time path of TACs and the fleets allocate effort across stocks under the climate-shifted law of motion; that exercise would deliver forward biomass trajectories with credible bands, complementing the comparative-statics treatment of the present paper. I leave it to future work, and the posterior is archived in machine-readable form to facilitate the extension by my own group or independent teams.

The manuscript is original work that has not been published elsewhere and is not currently under consideration at any other journal. The data and code necessary to replicate the analysis are available at [public GitHub or DOI — fill at submission time]. I have no competing interests to declare. JEL classification: Q22 (Renewable Resources and Conservation: Fishery), Q54 (Climate; Natural Disasters; Global Warming), Q57 (Ecological Economics: Ecosystem Services; Biodiversity Conservation).

[Suggested reviewers — optional. Three to five names with affiliations and email; identify any with a recent co-author or institutional conflict. Fill at submission time.]

Thank you for considering this submission. I look forward to your editorial decision.

Sincerely,

Felipe J. Quezada-Escalona
Departamento de Economía
Universidad de Concepción
Concepción, Chile
felipequezada@udec.cl

---

## Notes for Felipe (not part of letter)

- **Word count.** Body of the letter (excluding the bracketed placeholders) is approximately 580 words, which fits comfortably on a single page in 11pt with normal margins. If JAERE asks for tighter (≤500), the prior-elicitation paragraph (claim 1) is the easiest to compress: drop the bounded-LS detail and reference Appendix A directly. If looser, expand on (3) by linking the n.i. result to the SPRFMO assessment cycle.

- **Editor-in-Chief.** Verify the current EIC name at submission time; JAERE rotates editors and the last public listing I have access to may be stale. Don't address by name unless you can confirm.

- **Suggested reviewers.** JAERE accepts but does not require these. If you submit names, choose people working on (a) Bayesian state-space in fisheries (Punt, Methot, Thorson are obvious but probably overused), (b) climate-fishery economics (Free, Cheung, Sumaila in the broader space), or (c) Latin American fishery econometrics (a smaller pool — worth asking the FONDECYT panel for suggestions). Identify any conflicts (co-authors in the last five years, current grant collaborators, your PhD committee).

- **Data/code DOI.** Plan to mint a Zenodo DOI from the GitHub release at submission time so the URL is persistent and citable. The current `Impact-of-Environmental-Variability-on-Harvest` repo is a reasonable basis but may want a curated `paper1-replication` subset to avoid shipping the paper 2 scaffold (when it exists) or the deprecated SUR code paths.

- **Originality declaration.** The wording above is standard for JAERE; double-check the most recent version of JAERE's submission guidelines for any required language about prior workshop or working-paper postings. If the paper has appeared as a working paper or in a conference proceedings (FAERE, AERE, AAEA, LACEA), disclose that explicitly with the URL.

- **No paper 2.** This letter does not promise a sequel paper. Modularity is presented as a feature of the present submission, the posterior is archived for downstream use, and the Stackelberg extension is named only as future work — consistent with the anticipated reviewer reply.

- **LMCA framing.** The acronym is expanded on first occurrence with the Spanish name in italics, matching the convention in the abstract and Discussion paragraph 6. JAERE house style accepts non-English regulatory terminology when properly introduced.
