# Anticipated Reviewer Reply — Paper 1

**Status:** working document, drafted 2026-04-27. Internal use to (i) shape the cover letter and abstract, (ii) drive a short list of pre-emptive edits to the main text and Discussion, (iii) be adapted into the actual response-to-reviewers document if/when JAERE returns reviews.

**Scope:** four anticipated criticisms, ordered from most likely to least likely:

1. Log-linear extrapolation of the climate shifter into out-of-sample SST anomalies.
2. Inferential validity with a 25-year time series.
3. Non-identification of the jack mackerel shifters.
4. Absence of a forward simulation with credible bands on biomass trajectories.

For each, we record (a) the reviewer's likely concern in their own voice, (b) a substantive response anchored in specific tables, sections, and appendices of the manuscript, and (c) a pre-emptive edit recommended for the main text or Discussion.

All section, table, and figure references match the labels in the current draft of `paper1_climate_projections.Rmd` and its child appendices.

---

## 1. Log-linear extrapolation of the climate shifter

### 1.1 Anticipated reviewer concern

> "The shifters $\rho_i^{SST}, \rho_i^{CHL}$ are estimated from interannual variation over 2000--2024 with $\hat\sigma_{SST}\approx 0.26\,^{\circ}\mathrm{C}$ and applied to CMIP6 anomalies that reach $+2.3\,^{\circ}\mathrm{C}$ under SSP5-8.5 end-of-century. That is roughly nine in-sample standard deviations of forcing, projected through a log-linear functional form that the data simply cannot adjudicate beyond the historical envelope. The headline projections of $-89\%$ for anchoveta and $-100\%$ for sardina común are therefore artifacts of the maintained log-linear assumption, not findings about the climate response of these stocks."

### 1.2 Response

This concern is the dominant source of projection uncertainty and we treat it as such. Three points address the substance.

**(i) The paper claims comparative statics, not point forecasts, and the claim is calibrated to the extrapolation distance.** Eq.~\eqref{eq:shifter} is a structural specification of how $r_i^0$ shifts with environmental anomalies; under it, Table~\ref{tab:growth_compstat} reports the comparative-statics change in intrinsic productivity, $\Delta r_i^\star / r_i^0$, evaluated at the projected mean anomaly under each scenario. The Discussion (paragraph 4) explicitly acknowledges that the SSP5-8.5 end-of-century scenario lies "nearly an order of magnitude outside the estimation window" and frames the projected magnitudes as "indicative of the direction and relative scale of impacts across stocks rather than as precise point forecasts." We do not interpret the SSP5-8.5 end-of-century numbers as a forecast; we report them as a structural-form thought experiment.

**(ii) The relative ranking across stocks (sardina $>$ anchoveta $>$ jurel n.i.) is the substantive result and is robust to a wide class of monotone shifter functions.** The contribution of the paper is the identified contrast: sardina común carries roughly twice the SST semi-elasticity of anchoveta and an opposite-signed CHL response, while the jurel shifter is not identified. This contrast is set by the *sign and relative magnitude* of $\rho_i^{SST}, \rho_i^{CHL}$, not by the log-linear functional form per se. Any monotone shifter consistent with the same posterior signs would deliver the same comparative-statics ranking; only the magnitude depends on log-linearity. The reduced-form alternative discussed in Section~\ref{identification} (a SUR of growth increments on environmental anomalies) reverses the sign of the distributional asymmetry across fleets, which is the headline of the paper. That reversal does not hinge on the extrapolation distance.

**(iii) The log-linear functional form is, if anything, a *lower-bound* statement of stock loss for warm-water-averse species.** Metabolic-theory and thermal-tolerance arguments in the climate-fisheries literature [@Cheung2010; @Free2019] imply that biological productivity responses to temperature are typically concave-saturating with sign changes near species-specific thermal optima. For a stock whose realized historical range is below its thermal optimum (anchoveta, sardina común — coastal-upwelling species in the Humboldt Current), extrapolating a log-linear shifter beyond the estimation window will *under-predict* the productivity decline at high anomalies relative to a regime-shift specification with thermal collapse. The log-linear form therefore biases our headline magnitudes toward zero, not away from it; readers who view our SSP5-8.5 end-of-century numbers as alarmist should understand that an explicitly non-linear specification would produce sharper declines, not milder ones, for the two coastal-upwelling stocks.

**(iv) For SSP2-4.5 mid-century, the extrapolation is moderate.** Table~\ref{tab:env_projections} reports a projected SST anomaly of $+0.8\,^{\circ}\mathrm{C}$, which is approximately three in-sample standard deviations of forcing — outside the realized envelope but well within a plausible range under any monotone smooth shifter. The corresponding projected median productivity changes ($-51\%$ anchoveta, $-90\%$ sardina común) should be read as the central comparative-statics finding. The SSP5-8.5 end-of-century numbers are best understood as a structural-form stress test and we are happy to flag them as such in the abstract and table caption.

### 1.3 Pre-emptive edit

In Discussion paragraph 4, after the sentence ending "indicative of the direction and relative scale of impacts across stocks rather than as precise point forecasts," insert one additional sentence noting the lower-bound argument: "The log-linear shifter is a maintained simplification; thermal-tolerance arguments imply that for stocks operating below their thermal optimum the implied productivity response under high warming will if anything be *under-stated* by the log-linear form, so the projected magnitudes for SSP5-8.5 end-of-century should be read as conservative within the class of monotone shifter functions consistent with the identified posterior signs."

In Table~\ref{tab:growth_compstat} caption, add: "Under SSP2-4.5 mid-century, the implied SST anomaly lies $\sim 3$ in-sample standard deviations of forcing outside the realized 2000--2024 envelope; under SSP5-8.5 end-of-century it lies $\sim 9$ standard deviations outside. The latter scenario is reported as a structural-form stress test under the maintained log-linear shifter."

In the abstract, change "Anchoveta's median intrinsic productivity is projected to decline by 51\% under SSP2-4.5 mid-century and by 89\% under SSP5-8.5 end-of-century" to "Anchoveta's median intrinsic productivity is projected to decline by 51\% under SSP2-4.5 mid-century, and by 89\% under SSP5-8.5 end-of-century when the log-linear shifter is applied as a structural stress test."

---

## 2. Inferential validity with $N=25$

### 2.1 Anticipated reviewer concern

> "The full state-space specification carries 21 stock-level parameters plus a $3\times 3$ Cholesky factor for process correlation. With 25 annual observations the model is over-parameterized and the posterior is dominated by the priors that are themselves derived from the same 25-year sample via reduced-form stress tests. The 'identification' reported in Table~\ref{tab:rho-posteriors} may simply be reproducing the prior."

### 2.2 Response

This concern collapses two issues that need to be separated: whether the priors are appropriately constructed, and whether the posterior is updated by the data conditional on those priors.

**(i) The prior is not derived from the same likelihood.** Appendix A documents that the priors on $\rho_i^{SST}, \rho_i^{CHL}$ come from a *deterministic Schaefer hindcast* with $(r_i^0, K_i)$ fixed at the centres of the official IFOP and SPRFMO assessments and $(\rho_i^{SST}, \rho_i^{CHL})$ estimated by bounded least squares on $\log B_{i,t+1} - \log B_{i,t}$ — explicitly not the state-space likelihood used in Section~\ref{sec:stock-dynamics}. Table~\ref{tab:stress-priors} maps the bounded-LS point estimates into independent normal priors $\mathcal{N}(\hat\rho_{i}^{LS}, 1.0)$, with the prior standard deviation set deliberately wide ($\sigma=1.0$ on a parameter whose posterior standard deviation turns out to be on the order of $0.4$--$0.8$) to avoid double-counting. The state-space likelihood operates on the same biomass series but through a different functional form (full process noise, observation noise, latent state) that the deterministic hindcast cannot fit.

**(ii) The posterior is empirically updated for the two coastal-upwelling stocks.** Table~\ref{tab:rho-posteriors} reports $\sigma_{\text{post}}/\sigma_{\text{prior}}$ explicitly for each shifter. For anchoveta we have $\sigma_{\text{post}}/\sigma_{\text{prior}} \approx 0.43$ on $\rho^{SST}$ and $\approx 0.83$ on $\rho^{CHL}$, and for sardina común $\approx 0.44$ and $\approx 0.74$ respectively. The data are tightening the posterior by 17--57\% relative to the prior — modest, as expected from $N=25$, but unambiguously informative. The 90\% credible intervals shift in location relative to the prior centre as well, in both directions: anchoveta $\rho^{SST}$ moves from prior mean $-2.3$ to posterior mean $-1.06$ (data attenuates the prior toward zero), while anchoveta $\rho^{CHL}$ moves from prior mean $-2.3$ to posterior mean $-3.64$ (data sharpens the prior in the same direction). The likelihood is doing real work, and it is not doing it monotonically — confirming that the data and prior are not collinear by construction.

**(iii) For jurel, $\sigma_{\text{post}}/\sigma_{\text{prior}} \approx 1.0$, and we report this directly as the identification failure.** This is the test the reviewer is asking us to apply, and we apply it. Jurel is the case in which the posterior reproduces the prior, and we treat that fact as a substantive result rather than try to obscure it. See Section~\ref{identification} and Discussion paragraph 2.

**(iv) Convergence diagnostics rule out the alternative reading that the chain is mixing on a flat prior surface.** Appendix~D reports $\max \hat R = 1.009$ and $\min \mathrm{ESS}_{\text{bulk}} = 1{,}370$ across the top-level parameters of the full specification, with the primary parameters $\rho_i^{SST}, \rho_i^{CHL}$ all $\hat R \le 1.001$ and $\mathrm{ESS}_{\text{bulk}} > 8{,}300$. A chain mixing on a near-flat posterior surface would not deliver these numbers; the geometry of the posterior is doing real work in the sampler.

**(v) The 25-observation horizon is standard for Bayesian fishery assessment in this region.** The official IFOP assessments for anchoveta and sardina común and the SPRFMO assessment for jack mackerel use comparable annual horizons. Our state-space specification is more parsimonious than either of the official models, since we estimate only the climate-shifter component while taking $(r_i^0, K_i)$ from those assessments through informative priors. The assessment-adoption strategy is precisely what allows a 25-year sample to identify a small structural object.

### 2.3 Pre-emptive edit

In Section~\ref{identification}, add one sentence after the introduction of $\sigma_{\text{post}}/\sigma_{\text{prior}}$ in Table~\ref{tab:rho-posteriors}: "A posterior-to-prior ratio strictly less than one indicates that the likelihood has refined the prior; a ratio at unity indicates the data carry no local information about the parameter beyond what the prior already encodes."

In Discussion caveat 3 (the $N=25$ point), insert a forward reference: "The posterior-to-prior standard-deviation ratios reported in Table~\ref{tab:rho-posteriors} provide a direct empirical check that the data update the prior for anchoveta and sardina común, while leaving the jurel shifters at the prior — the latter being the basis of our non-identification finding."

---

## 3. Jack mackerel non-identification as a substantive finding

### 3.1 Anticipated reviewer concern

> "The model fails to identify climate response for one of the three species. Either the specification is wrong for jurel, or jurel should be dropped from the analysis. Reporting a non-result in the headline of a paper is a methodological choice that needs more justification than the manuscript currently offers."

### 3.2 Response

The Discussion (paragraph 2) and Conclusions already frame the non-identification as substantive; the methodological case is sharper than the current text makes it.

**(i) Non-identification is informative about the data-generating process.** A reduced-form specification — say, an OLS regression of $\log B_{t+1} - \log B_t$ on $\mathrm{SST}_t$ and $\log\mathrm{CHL}_t$ — would deliver a precisely estimated coefficient for jurel, because it would project all unexplained variation onto the available covariates regardless of whether those covariates carry any climate signal for that species. The state-space specification, in contrast, *partitions* unexplained variation between climate forcing $(\rho_i)$, process noise $(\sigma_{\text{proc},i})$, observation noise $(\sigma_{\text{obs},i})$, and cross-stock process correlation $(\Omega)$. The likelihood reports $\sigma_{\text{post}}/\sigma_{\text{prior}} \approx 1$ for jurel because, conditional on the prior on $(r^0, K)$ from SPRFMO and the observed biomass series, climate forcing is the channel through which the data refuse to commit. That refusal is information.

**(ii) The substantive interpretation lines up with the biology and the management regime.** Jack mackerel is a transboundary, highly migratory species managed at the SPRFMO range-wide scale, and Centro-Sur biomass dynamics are driven partly by migration in and out of the regional grid — a process that the paper's Schaefer law of motion treats as part of $\sigma_{\text{proc},3}$, not as a function of local SST. The non-identification of $\rho_3^{SST}, \rho_3^{CHL}$ is the econometric signature of that biological fact.

**(iii) Dropping jurel would be the wrong response.** The paper's headline is the *fleet-level distributional asymmetry* set by differential exposure of artisanal and industrial portfolios to identified shifters. Dropping jurel would remove the species that anchors the industrial fleet's portfolio diversification (Table~\ref{tab:trip_compstat}), and would eliminate the contrast that makes the asymmetry result interpretable. We need to model jurel; what we do not need to do is force a coefficient on its climate response that the data does not support.

**(iv) Policy corollary.** Climate adaptation for jurel cannot be assessed from the Centro-Sur time series and must be evaluated jointly with the SPRFMO assessment. This is already in Discussion paragraph 2 and is the subject of the companion paper.

### 3.3 Pre-emptive edit

In the abstract, the existing sentence "The jack mackerel shifters are not identified in the 2000--2024 sample, a finding consistent with the stock's transboundary SPRFMO management" is good but understated. Replace with: "The jack mackerel shifters are not identified in the 2000--2024 sample — the posterior-to-prior standard-deviation ratio is essentially unity, in contrast to the 0.4--0.8 range for the two coastal-upwelling stocks — a finding consistent with the species' transboundary SPRFMO management and a methodological dividend of the structural state-space specification over reduced-form alternatives that would have delivered a precisely estimated but structurally meaningless coefficient."

In Section~\ref{identification}, after the rho-posteriors table, add one sentence reinforcing the methodological dividend: "We report this result as substantive: the structural specification correctly attributes the absence of local climate signal to non-identification rather than to an artefactually precise reduced-form coefficient, which is the econometric value-added of Cowles-style identification in this setting."

---

## 4. Absence of a forward simulation with credible bands

### 4.1 Anticipated reviewer concern

> "Comparative statics at steady state assumes infinite adjustment time. Real climate change is a finite trajectory, so transient dynamics matter — and the paper does not deliver a forward simulation of biomass paths under CMIP6 trajectories with credible bands. The 'distributional asymmetry' result therefore ignores the time profile of impacts, which is where the policy bite actually lives."

### 4.2 Response

This is a fair point on the analytical scope and the response is one of explicit modularity rather than substantive defense.

**(i) The contribution of paper 1 is the structural identification of $(\rho_i^{SST}, \rho_i^{CHL})$, not the forward simulation.** This separation is deliberate and explicit. The Cowles tradition cited in the Introduction frames identification as a precondition for policy use: a parameter must be identified before its application to counterfactual scenarios is interpretable. The body of the paper delivers the identification (Section~\ref{identification}, Table~\ref{tab:rho-posteriors}, Appendix~A for the prior elicitation, Appendix~B for model selection via PSIS-LOO, Appendix~D for convergence). The comparative-statics application in Table~\ref{tab:growth_compstat} is the simplest check that the identified parameters carry economic content.

**(ii) The identified posterior is archived in a form that supports forward simulation as a downstream exercise.** The full Stan fit of $(r_i^0, K_i, \rho_i^{SST}, \rho_i^{CHL}, \Omega, \sigma_{\text{proc},i}, \sigma_{\text{obs},i})$ is reported in the supplementary materials, allowing any subsequent dynamic analysis — biomass trajectories under time-varying CMIP6 paths, optimal TAC choice under climate uncertainty, fleet-level effort responses with 90\% credible bands — to take the present posterior as its prior. The natural form of that downstream exercise is a Stackelberg bi-level optimization in which the regulator chooses the time path of TACs and the artisanal and industrial fleets allocate effort across stocks under the climate-shifted law of motion. We flag this as future work in the Conclusions and emphasize that the modular design preserves the option for that work to be conducted by independent teams: the prior elicitation, the identification, and the dynamic policy evaluation each carry their own econometric and numerical burdens, and bundling them sacrifices the transparency of the structural identification step that this paper makes its contribution.

**(iii) Modularity is standard practice in econometric work that uses an estimated structural object downstream.** Identification papers and policy-evaluation papers are routinely separated when the identification step is itself non-trivial — see, for example, the production function literature (identification papers feeding misallocation papers) or the demand estimation literature (BLP-style identification feeding merger simulations). Paper 1 stops at the identification claim because the identification claim is the contribution.

**(iv) Bundling forward simulation into paper 1 would compromise both contributions.** The state-space identification deserves its own treatment because the prior elicitation protocol (Appendix~A), the LOO model selection (Appendix~B), the posterior-predictive checks (Appendix~C), and the convergence diagnostics (Appendix~D) collectively make a methodological case for adopting Cowles-style structural inference in fishery climate-impact assessment. Folding a Stackelberg forward simulation into the same paper would relegate this methodological case to a methods section, and the structural-vs.-reduced-form contrast that the paper's empirical headline rests on would lose its salience.

### 4.3 Pre-emptive edit

In the Conclusions, the existing sentence "A first extension is to incorporate trip-level cost functions and an inverse demand system to enable full numerical optimization of quota paths under climate change, following the complete @Kasperski2015-jm approach" is true but too vague. Replace with: "A natural extension uses the posterior of $(r_i^0, K_i, \rho_i^{SST}, \rho_i^{CHL}, \Omega)$ identified here as a prior for a Stackelberg bi-level optimization, in which the regulator chooses the time path of TACs and the artisanal and industrial fleets allocate effort across stocks under the climate-shifted law of motion. That exercise would deliver the full forward biomass trajectories under CMIP6 anomaly paths with 90\% credible bands, complementing the comparative-statics treatment of the present paper. We leave it to future work; the posterior reported here is archived in machine-readable form to facilitate that extension."

In the cover letter, lead with this modularity as a feature without claiming a sequel paper exists: paper 1 establishes the structural identification of the climate shifters under a transparent prior elicitation protocol, and the identified posterior is reusable for downstream dynamic analyses by the present authors or by independent teams. JAERE values structural identification papers as standalone contributions, and bundling forward simulation into the same manuscript would dilute the methodological case the paper makes for Cowles-style structural inference in fishery climate-impact assessment.

---

## Cross-cutting points for the cover letter

Beyond responding to the four anticipated criticisms, the cover letter should foreground three positioning claims that JAERE will recognize as fitting the slot of the journal:

1. **Methodological contribution.** The prior elicitation protocol via the deterministic hindcast stress test (Appendix~A → Table~\ref{tab:stress-priors}) is the kind of replicable procedure JAERE has historically valued — a translation of reduced-form descriptive statistics into informative priors for a Bayesian state-space likelihood, with clean separation of the two estimation steps.

2. **Cowles-style structural inference applied to a climate-fishery question.** The contrast between the identified posterior of $(\rho_i^{SST}, \rho_i^{CHL})$ and the reduced-form SUR alternative discussed in Section~\ref{identification} is the methodological payoff: the structural posterior reverses the sign of the fleet-level distributional asymmetry that the reduced-form would imply. JAERE referees in environmental econometrics will understand this immediately.

3. **Honest reporting of identification failures.** The non-identification of the jurel shifters is a feature of the structural specification, reported as such, and used to anchor the policy claim that climate adaptation for transboundary species cannot be read off local time series. This is the kind of honest reporting that distinguishes the paper from forecast-oriented contributions in the same literature.

JEL classification: Q22 (Renewable Resources and Conservation: Fishery), Q54 (Climate; Natural Disasters; Global Warming), Q57 (Ecological Economics: Ecosystem Services; Biodiversity Conservation).

---

## Pre-emptive edits — consolidated short list

For the next stage of T9 polish, the edits that emerge from the above are:

| # | Location | Edit |
|---|----------|------|
| 1 | Abstract | Soften SSP5-8.5 phrasing to "structural stress test under the log-linear shifter"; sharpen jurel n.i. as "posterior-to-prior ratio at unity, in contrast to 0.4--0.8 for coastal stocks" |
| 2 | Discussion ¶4 (extrapolation) | Add lower-bound argument: log-linear under-states warm-water-averse decline relative to thermal-tolerance specifications |
| 3 | Discussion caveat 3 ($N=25$) | Forward-reference the $\sigma_{\text{post}}/\sigma_{\text{prior}}$ column in Table~\ref{tab:rho-posteriors} as the empirical update test |
| 4 | Section~\ref{identification} | One sentence defining $\sigma_{\text{post}}/\sigma_{\text{prior}}$; one sentence on Cowles methodological dividend after the rho-posteriors table |
| 5 | Conclusions ¶3 | Rewrite the Kasperski reference to explicitly point at companion paper with forward sim + bands |
| 6 | Table~\ref{tab:growth_compstat} caption | Note the $\sim 3\sigma$ vs $\sim 9\sigma$ extrapolation distance for SSP2-4.5 vs SSP5-8.5 |
| 7 | Cover letter | Lead with three positioning claims (prior elicitation protocol, Cowles structural ID, honest reporting of n.i.); JEL Q22/Q54/Q57 |
| 8 | Discussion ¶6 (quota policy) | Name the *Límite Máximo de Captura por Armador* (LMCA) explicitly as the regulatory regime the paper engages with, and add one sentence connecting the climate-driven divergence in stock productivity (Table~\ref{tab:growth_compstat}) to a divergent loss of effective quota value across the artisanal-industrial divide *under a rule with limited cross-fleet transferability*. Stops short of quantifying deadweight loss (which would require modelling endogenous quota market clearing — out of scope for paper 1). |

These edits are textual, do not require re-running any code, and should consume on the order of one focused half-day of work.

---

## Note on framing trade-off (JAERE vs. Ecological Economics)

A third-party suggestion (Gemini, 2026-04-27) raised the alternative of organizing the paper around an explicit "LMCA design failure $\to$ deadweight loss" frame, which would target Ecological Economics rather than JAERE.

We do not adopt that pivot here. The reasons are:

- **Quantifying deadweight loss requires endogenous quota market clearing**, which in turn requires modelling the artisanal and industrial fleets as constrained optimizers facing the LMCA's transferability rules. That is the body of the Stackelberg bi-level model contemplated for downstream work, not an edit to the present paper. Bundling it in is not "polish" but new content.

- **JAERE accepts the present framing.** Structural identification of climate shifters + comparative-statics implications + portfolio-driven distributional asymmetry = a Cowles-style structural inference paper, which is the slot JAERE has historically occupied for this kind of work. The methodological contribution is not in the policy evaluation but in the identification protocol.

- **The LMCA is still mentioned, just not centred.** Edit #8 above names the regulatory regime explicitly so that policy-oriented readers (including referees) can connect the result to the standing institutional question, without forcing the paper to deliver a welfare-loss number it does not have the machinery to deliver.

If JAERE rejects and the natural fallback turns out to be Ecological Economics rather than ERE, this is the framing pivot to revisit — at that point the deadweight-loss machinery would already have been developed for paper 2 and could be back-imported. Today, with paper 2 still at the conceptual stage and the v3 catch dependency unresolved, holding the present paper to its identification claim is the lower-risk path.
