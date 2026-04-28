# Cover letter — paper 1, MRE submission

**Status:** working draft v3 (post-portfolio×LMCA reframing), 2026-04-27. Plain-text working version; final-format conversion (PDF or DOCX) at submission time. All `[BRACKETED]` items are placeholders to fill in before submission.

**Note on versioning:** v1 (2026-04-27 AM) was framed for *Journal of the Association of Environmental and Resource Economists* (JAERE) and centred the contribution on Cowles-style structural identification as a methodological posture. v2 (2026-04-27 PM) reframed for *Marine Resource Economics* (MRE). v3 (this version) integrates the cross-paper reframing applied to the manuscript on 2026-04-27 evening: the SUR-comparative narrative has been removed throughout the manuscript and the contribution 3 has been reformulated around the *portfolio composition × LMCA quota architecture* mechanism. The cover letter mirrors that reframing.

---

[Submission date]

The Editor
*Marine Resource Economics*
[Editor name and address — fill at submission time]

Dear Editor,

I am pleased to submit the manuscript "Climate Change, Stock Productivity, and Fishing Effort in Chile's Multi-Species Small Pelagic Fishery" for consideration in *Marine Resource Economics*.

The paper develops an integrated bioeconomic analysis of Chile's Centro-Sur small pelagic fishery — anchoveta, sardina común, and jack mackerel — and quantifies the distributional consequences of climate change across the artisanal and industrial fleets that target them. The empirical strategy combines a Bayesian state-space model of stock dynamics, calibrated on official IFOP and SPRFMO assessments and disciplined by a transparent reduced-form stress-test protocol for prior elicitation, with a vessel-level negative binomial model of annual fishing trips. CMIP6 climate projections (IPSL-CM6A-LR; SSP2-4.5 and SSP5-8.5; mid- and end-of-century) are then propagated through the joint posterior to obtain comparative-statics objects on intrinsic stock productivity and fleet-level fishing effort. I believe the manuscript fits MRE's editorial scope along three dimensions:

**1. An integrated bioeconomic framework that bridges official stock assessments and a vessel-level effort model under climate forcing.** Biological priors $(r_i^0, K_i, \sigma_{\mathrm{proc},i}, \sigma_{\mathrm{obs},i})$ are adopted from the single-species IFOP and SPRFMO assessments; climate parameters $(\rho_i^{SST}, \rho_i^{CHL})$ — semi-elasticities of intrinsic stock productivity with respect to a one-degree Celsius SST anomaly and a one-log-point chlorophyll-a anomaly — are elicited via a deterministic Schaefer hindcast with bounded least squares (Appendix A) and updated within a full state-space likelihood; the resulting posterior on stock productivity is then linked to a vessel-level negative binomial trip equation estimated separately for the artisanal and industrial fleets. This pipeline preserves the institutional information embedded in the official assessments while adding a structural climate channel that is transportable to climate regimes outside the 2000–2024 estimation window — a property the paper's comparative-statics exercise needs because the projected SST anomalies under SSP5-8.5 end-of-century lie nine historical standard deviations beyond the estimation envelope.

**2. A direct distributional implication for the LMCA quota allocation regime through the portfolio composition channel.** The long-run distributional incidence of climate change across the artisanal and industrial fleets is governed by the interaction between (i) the differential exposure of each fleet's species portfolio to the identified climate parameters and (ii) the limited cross-sector transferability built into Chile's *Límite Máximo de Captura por Armador* (LMCA) regime. The artisanal fleet, concentrated in the two coastal-upwelling stocks (anchoveta and sardina común) for which both climate semi-elasticities are identified and economically large, bears a sharper long-run decline in harvest capacity than the industrial fleet, whose 95% allocation to jack mackerel insulates it from the local climate signal in the Centro-Sur sample. This finding bears directly on a live debate in Chilean fisheries policy on cross-sector quota transferability and on the design of TACs under shifting species productivity, and it extends the broader fishery portfolio literature on income diversification (Kasperski & Holland, 2013), regime-shift buffering (Cline, Schindler & Hilborn, 2017), and the role of institutional access constraints in limiting the realised benefits of diversification (Oken, Holland & Punt, 2021) to the climate-impact setting.

**3. Honest reporting of an identification failure as a substantive finding.** The jack mackerel shifters are not identified in the 2000–2024 sample — the posterior-to-prior standard-deviation ratio is essentially unity, against 0.4–0.8 for the two coastal-upwelling stocks. The paper reports this as a substantive finding consistent with the species' transboundary Southeast Pacific stock structure managed through SPRFMO, rather than as a model failure to be patched. The implication for policy is that climate adaptation for jack mackerel cannot be read off the Chilean Centro-Sur time series alone and must be assessed jointly with the SPRFMO stock assessment, which we leave to future work. Appendix E of the paper additionally reports a spatial-domain robustness check that confirms the non-identification result is not an artefact of the Centro-Sur EEZ averaging window.

Applying the identified parameters to CMIP6 projections, the paper reports comparative-statics declines in intrinsic productivity of 51% for anchoveta and 90% for sardina común under SSP2-4.5 mid-century, with the SSP5-8.5 end-of-century scenario read as a structural stress test under the maintained log-linear shifter. Translated through the trip equation under a Schaefer steady-state thought experiment, the posterior probability of portfolio loss exceeds 0.95 for the artisanal fleet under every scenario considered, against approximately 0.12 for the industrial fleet — an asymmetry that operates primarily through the differential exposure of each fleet's species portfolio to climate-driven stock dynamics, locked in by the LMCA's cross-sector transferability constraints, rather than through differential climate elasticities in the trip equation itself.

The paper is sized as a self-contained identification and projection contribution. A natural downstream extension uses the posterior reported here as a prior for a Stackelberg bi-level optimization in which the regulator chooses the time path of TACs and the fleets allocate effort across stocks under the climate-shifted law of motion; that exercise would deliver forward biomass trajectories with credible bands, complementing the comparative-statics treatment of the present paper. A second natural extension migrates the annual NB trip equation to a daily discrete choice specification with environmentally-informed species distribution models as proxies for local availability, following Quezada-Escalona, Tommasi, Kaplan, Muhling & Stohs (2026, *Ecological Economics*) for the U.S. West Coast Coastal Pelagic Species fishery. Both extensions are left to future work, and the posterior is archived in machine-readable form to facilitate downstream use by my own group or independent teams.

The manuscript is original work that has not been published elsewhere and is not currently under consideration at any other journal. The data and code necessary to replicate the analysis are available at [public GitHub or Zenodo DOI — fill at submission time]. I have no competing interests to declare. JEL classification: Q22 (Renewable Resources and Conservation: Fishery), Q54 (Climate; Natural Disasters; Global Warming), Q57 (Ecological Economics: Ecosystem Services; Biodiversity Conservation).

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

- **Word count.** Body of the letter (excluding the bracketed placeholders) is approximately 800 words. MRE does not specify a hard cover-letter length; this fits comfortably on 1.5 pages in 11pt with normal margins. If you want a tighter 1-page version, the cleanest cuts are (a) compressing claim 1 by referencing Appendix A directly without the parenthetical detail on bounded LS, and (b) removing the Schaefer-steady-state quantification in the empirical-magnitudes paragraph (the 0.95 vs 0.12 asymmetry) — both compress to ~620 words while preserving the headline.

- **Editor-in-Chief.** Verify the current EIC name at submission time. As of the most recent issue I have access to, MRE is edited by Frank Asche (UFL) and Atle G. Guttormsen (NMBU) as co-editors, but rotation happens periodically — confirm before addressing by name. If unsure, "The Editors" is acceptable.

- **MRE house preferences worth noting.** MRE is the natural home for fisheries-policy work that takes institutions seriously; the LMCA paragraph in claim 2 is doing the heavy lifting and is worth keeping verbatim. The journal also routinely publishes Bayesian state-space and bioeconomic optimisation papers (Kasperski 2015 is the closest precedent and is cited prominently in the manuscript), so the structural framing should not feel out of place. The portfolio-and-access-constraints angle (Cline 2017; Oken, Holland & Punt 2021; Holland & Kasperski 2016) is the natural literature into which the contribution embeds itself, and the MRE readership is well-positioned to receive that framing.

- **Suggested reviewers.** Pool to consider for MRE:
  - **Bioeconomic / multi-species:** Stephen Kasperski (NOAA), Daniel S. Holland (NOAA-NWFSC), Matthew Reimer (Michigan State), Martin D. Smith (Duke).
  - **Portfolio / diversification:** Kiva L. Oken (UW), Timothy J. Cline (USGS / Univ. of Montana), Daniel E. Schindler (UW) — Oken and Cline are now cited prominently in the paper; declare if conflict.
  - **Climate-fishery:** Christopher Free (UCSB), Olaf P. Jensen (UW–Madison), Alan Haynie (NOAA-AFSC), William Cheung (UBC) — Cheung and Free are cited in the paper, declare if conflict.
  - **Bayesian / state-space methodology:** James Thorson (NOAA-AFSC), André Punt (UW-SAFS), Mark Maunder (IATTC) — all cited in the paper for stock-assessment methodology, declare if conflict.
  - **Latin American fishery economics / institutional:** Julio Peña-Torres (UAH, Chile) — co-author conflict if you've worked with him recently; declare. Carlos Chávez (UDD, Chile) — also potential conflict via Dresdner et al. 2013 cite. Hugo Salgado (UTalca, Chile) — same caveat.
  - Identify any with co-authorship in the last five years, current grant collaborators, your PhD committee, or institutional ties at UdeC.

- **Self-citation disclosure.** The cover letter and manuscript now cite Quezada-Escalona, Tommasi, Kaplan, Muhling & Stohs (2026, *Ecological Economics*, 247, 109051). MRE's submission system may flag self-citations; that is fine — the cite is methodologically substantive (daily DCM with SDM availability proxies as the spatial extension of the present annual NB framework) and not gratuitous. If asked, the cite anchors a downstream-extension claim, not a foundational one.

- **Data/code DOI.** Plan to mint a Zenodo DOI from the GitHub release at submission time so the URL is persistent and citable. The current `Impact-of-Environmental-Variability-on-Harvest` repo is a reasonable basis but may want a curated `paper1-replication` subset to avoid shipping the paper 2 scaffold (when it exists) or the deprecated SUR code paths.

- **Originality declaration.** The wording above is standard for MRE; double-check the most recent version of MRE's submission guidelines for any required language about prior workshop or working-paper postings. If the paper has appeared as a working paper or in a conference proceedings (FAERE, AERE, AAEA, LACEA, IIFET, NAAFE), disclose that explicitly with the URL.

- **No paper 2.** This letter does not promise a sequel paper. Modularity is presented as a feature of the present submission, the posterior is archived for downstream use, and the Stackelberg extension is named only as future work — consistent with the anticipated reviewer reply.

- **LMCA framing.** The acronym is expanded on first occurrence with the Spanish name in italics, matching the convention in the abstract and Discussion paragraph 6. MRE house style accepts non-English regulatory terminology when properly introduced.

- **Why MRE over JAERE.** Decision rationale (2026-04-27): the manuscript's visual balance — three of four appendices biological, tables and figures dominantly bio, Methods bio-heavy — would read at JAERE as "stock assessment paper with an econ chapter" and risk being routed to ICES JMS at desk. MRE's cross-disciplinary readership (Kasperski, Reimer, Smith, Abbott, Sumaila already in the lit review) is the natural matching market. JAERE / ERE remain the targets for paper 2 (Stackelberg + welfare formal), where the methodological-econ contribution will be the primary deliverable.

- **Pending placeholders in the manuscript before submit.** Two appendices (E spatial robustness; F CMIP6 ensemble decomposition) are currently placeholders pending the corresponding analytical work. The cover letter claim 3 references Appendix E as if completed; finalise the spatial-robustness refit before submit, or soften that reference to "we plan to report" in the version that actually goes to MRE.
