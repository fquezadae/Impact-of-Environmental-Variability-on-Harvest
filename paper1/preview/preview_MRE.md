---
title: "Differential Climate Impacts on Fishing Effort in Chilean Small Pelagic Fisheries"
subtitle: "PROSE-ONLY PREVIEW (R chunks stripped)"
author: "Felipe J. Quezada-Escalona"
---

\keywords{Bayesian state-space model; Bioeconomic projection; Chilean small pelagic fishery; Climate change; Fishing effort; Fleet heterogeneity; Quota allocation}

\jelcodes{Q22, Q54, Q57, Q58}



*[R code chunk omitted]*


# Introduction

Climate change is reshaping the productivity of marine fisheries, but the incidence of this reshaping across fleet segments is rarely uniform. Quota-allocation regimes that codify the relative shares of industrial and small-scale fleets were typically designed under stationary-climate assumptions, so a fleet-asymmetric productivity shock acts as an unscripted reallocation of harvest rights. Whether such regimes should anticipate this reallocation depends on the projected magnitude and asymmetry of fleet-level effort responses under credible climate scenarios---a quantity the empirical literature has yet to deliver for most major multi-species fisheries.

We provide that quantity for the Chilean small pelagic fishery (SPF), the largest fishery in the country at nearly 94\% of total Chilean landings in 2019 [@SUBPESCA2020]. The SPF is dominated by three species---anchoveta (\emph{Engraulis ringens}), sardine (\emph{Strangomera bentincki}), and jack mackerel (\emph{Trachurus murphyi})---that share habitat and are coupled through trophic and market linkages [@Alheit2004; @Arancibia2019-FIPA]. It is managed through an allocation regime, the LMCA (\emph{Límite Máximo de Captura por Armador}), that fixes industrial-versus-artisanal shares with limited cross-sector transferability. Because the two segments target different species portfolios, a stock-asymmetric climate shock translates directly into a fleet-asymmetric effort response. Cross-country evidence places Chile among the most exposed major fishing nations: @Cheung2010 project a 6--13\% decline in maximum catch potential by mid-century under SRES A1B, and the Southeast Pacific remains one of the least-studied regions for the economic impacts of climate change on fisheries [@sumaila2011]. To our knowledge, no existing study for Chile combines multi-species stock dynamics with vessel-level effort responses under projected climate scenarios.^[The only empirical study of Chilean fisher behavior using discrete choice modeling that we are aware of is @Pena-Torres2017-gn, which analyses how the El Niño--Southern Oscillation (ENSO) affects location choices in the jack mackerel fishery.]

Our bioeconomic framework couples a Bayesian state-space model of multi-species stock dynamics to a vessel-level negative binomial trip equation. The stock dynamics model, calibrated on official IFOP and SPRFMO assessments for 2000--2024, identifies a vector of climate shifters that modulate the intrinsic growth rate of each stock. The shifters are interpretable as semi-elasticities of stock productivity with respect to sea-surface temperature and log-chlorophyll-a anomalies, and---because they enter the law of motion as coefficients on exogenous climate forcings---are transportable to climate regimes outside the 2000--2024 estimation envelope. The trip equation, estimated separately for the industrial and artisanal fleets with year fixed effects that absorb aggregate non-climate shocks (notably the 2019--2020 social and pandemic disruptions), maps prices, allocated harvest, weather, and regulatory closures into annual fishing effort. Climate reaches fleet-level effort through two channels: an *indirect biomass channel* via the climate shifters, and a *direct weather channel* via vessel-specific exposure to severe winds. We evaluate the framework at CMIP6 projections from a six-model ensemble (IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, MPI-ESM1-2-HR) under SSP2-4.5 and SSP5-8.5, at mid-century (2041--2060) and end-of-century (2081--2100), separating cross-model and within-posterior uncertainty explicitly.

We obtain three sets of results. First, the projected fleet-level effort response is sharply asymmetric: the artisanal fleet contracts by 8.1--10.2\% across CMIP6 scenarios, while the industrial fleet contracts by only 0.7--0.9\%, a ratio of roughly eleven to one. This asymmetry arises from the interaction between each fleet's species-portfolio exposure to climate forcing and the limited cross-sector transferability built into the LMCA. The mechanism is consistent with the broader portfolio literature on income diversification and risk in fisheries [@Kasperski2013-jz; @Cline2017-dp] and with evidence that institutional access constraints limit the realized benefits of diversification [@Oken2021-of]. Because fisher adaptation responses are themselves heterogeneous and context-dependent [@Zhang2011-wv; @Jardine2020-um], the policy reading is clear: the design of cross-sector transferability rules within the LMCA is a first-order margin for attenuating disproportionate fleet-level impacts. Second, the long-run change in intrinsic productivity is large and negative for anchoveta and sardine---the two coastal upwelling stocks targeted disproportionately by the artisanal fleet---with floor effects for sardine under SSP5-8.5 end-of-century. Third, the climate shifters are sharply identified for these two stocks but not for jack mackerel, the species that anchors the industrial fleet's portfolio. We document the jack mackerel null with a triple-evidence package (spatial-domain robustness, dual-source biomass, and OROP-PS coherence) and treat it consistently throughout. A within-versus-between variance decomposition (Appendix \ref{appendix-trips-ensemble}) shows that 97--100\% of the projected dispersion in fleet-level effort change is within-posterior rather than across CMIP6 models, so the asymmetry conclusion is robust to the climate-model uncertainty that dominates analogous projections at the stock-productivity level.

The remainder of the paper is organized as follows. Section \ref{the-small-pelagic-fishery-in-chile} describes the institutional and ecological setting of the Chilean SPF. Section \ref{methods} presents the data, the stock-dynamics model, the trip equation, and the CMIP6 projection design (Section \ref{projection-approach}). Section \ref{results} reports the identified climate shifters, the comparative-statics projections of stock productivity, and the projections of fleet-level effort (Section \ref{projections}). Section \ref{sec:discussion} discusses policy implications and limitations; Section \ref{conclusions} concludes.

# The small pelagic fishery in Chile

The Centro-Sur Chilean coast lies within the Humboldt Current System, an eastern boundary upwelling system in which prevailing southerly winds drive cold, nutrient-rich deep water to the surface near the coast. This wind-driven upwelling sustains one of the most productive marine ecosystems in the world, and the three target species of the Chilean small pelagic fishery---anchoveta, sardina común, and jack mackerel---occupy this productive coastal corridor. Climate change affects this system through two main pathways: warming of the surface ocean, which the species perceive directly through their thermal envelope, and changes in the wind-driven upwelling regime, which modulate nutrient supply and therefore primary productivity at the base of the food web. We capture the first pathway through the sea-surface temperature shifter $\rho^{SST}$ and the second through the chlorophyll-a shifter $\rho^{CHL}$.

The Chilean small pelagic fishery is structured into two latitudinal zones with distinct species composition and fleet activity. In the northern zone, competition is largely between anchoveta and jack mackerel; in the Central-South region (Regions V--X and XIV), all three species play a major role. The Central-South is therefore the most relevant setting for studying species interactions and potential substitution within a multispecies management framework, and it is the focus of this paper.
<!-- Early bioeconomic characterizations of the Chilean pelagic fishery focused on the northern zone under an aggregated Gordon-Schaefer framework [@Aliaga2001]; a comparable integrated analysis for the Central-South zone, which couples multi-species stock dynamics with environmental drivers, has so far been absent. -->

The jack mackerel fishery was initially concentrated in northern Chile but shifted to Central-South Chile in the mid-1980s, where the main fishing grounds have traditionally operated within 50 nautical miles of the coast [@Pena-Torres2017-gn]. Landings of the three species have historically been destined primarily for the reduction industry: between 1987 and 2004, approximately 85\% of jack mackerel landings were processed into fishmeal and fish oil [@Pena-Torres2017-gn]. The main ports servicing the SPF today include San Antonio, Tomé, Talcahuano, San Vicente, Coronel, Lota, and Corral. Sardine and anchoveta are harvested as a mixed fishery in the Central-South region: the two species share habitat and gear, making differentiation at the point of capture effectively impossible [@dresdner2013].

## Stock status

Central-South anchoveta was classified as collapsed through 2018, shifted to overexploited in 2019, and has been fished within maximum sustainable yield (MSY) limits since 2020. Sardine has generally remained within MSY limits, except in 2021 and 2023 when it was classified as overexploited. Jack mackerel was overexploited until 2018 and has since been harvested within MSY limits.

## Management regime

The Chilean SPF is managed through an annual Total Allowable Catch (TAC, \emph{Cuota Global}) divided between the industrial and artisanal sectors, with small shares reserved for research and contingency. The TAC is further subdivided by region and season, and unused quotas can be reassigned within the fishing year. Anchoveta and sardine are regulated as a mixed-species fishery: each species has its own quota, but substitution between them is permitted.

Since 2013, the industrial sector has operated under an individual transferable quota (ITQ) system known as Transferable Fishing Licenses (\emph{Licencias Transables de Pesca}, LTP). Class A licenses were allocated on the basis of historical catches, while Class B licenses (up to 15\% of the industrial fraction) are allocated through sealed-bid first-price auctions that began in 2015. @peña_torres_2022_MRE document that these auctions have exhibited low participation, limited ability to reflect economies of scale, and signs of coordinated bidding. The artisanal sector operates under a regulated freedom-to-fish regime, with regional TACs allocated through the \emph{Régimen Artesanal de Extracción} (RAE) by area, vessel size, landing site, or fisher organization.

Biological closures (\emph{vedas}) are a central regulatory instrument for sardine and anchoveta. In the Central-South region, reproductive closures run from July--October in regions IX--XIV and from August--October in regions V--VIII, while recruitment closures run from January to February across all regions. In total these yield 151 closed days per year in regions V--VIII and 182 closed days in regions IX--XIV. Jack mackerel has no seasonal biological closures.


*[R code chunk omitted]*



*[R code chunk omitted]*



*[R code chunk omitted]*



# Methods {#methods}

Our empirical approach proceeds in three stages. First, we identify a multi-species stock dynamics model using a Bayesian state-space specification on the latent biomass of each stock, with a Schaefer surplus-production function whose intrinsic growth rate is modulated by an interpretable climate shifter. Second, we estimate a negative binomial model for annual fishing trips---separately for the artisanal and industrial fleets---as a function of prices, harvest allocations, weather, and regulatory closures. Third, we evaluate the identified shifters under CMIP6 projections from a six-model ensemble to assess how climate change will reshape the long-run productivity of each stock and, through the trip equation, the fleet-level allocation of fishing effort, separating cross-model and within-model uncertainty explicitly.


## Historical data

We use data requested from the Chilean Fisheries Development Institute
(Instituto de Fomento Pesquero, IFOP) covering the 2013--2024 period. The
dataset includes trip-level microdata with detailed records on
vessel identifiers, departure and arrival times, vessel capacity, fleet
and gear type, ports of departure and landing, fishery codes, haul
timing and location, species composition, retained catch, and trip
activity. We also requested annual information on stock
abundance and vessel landings by port, county, region, country, and
species. Finally, we use ex-vessel prices reported monthly or annually
by port, county, region, country, and species. These prices reflect
payments from processing plants to fishers at the point of first sale
and are obtained through IFOP's landing surveys, which do not
necessarily cover all market transactions.

Environmental covariates are obtained from the E.U. Copernicus Marine Service Information, accessed through the Copernicus Marine Toolbox API. Salinity, sea surface temperature, and current speed and direction come from the Global Ocean Physics Reanalysis (GLORYS12V1), which provides data at 1/12° horizontal resolution with 50 vertical levels [@GLORYS12V1]. Surface wind speed and direction are taken from the Global Ocean Hourly Reprocessed Sea Surface Wind and Stress from Scatterometer and Model dataset, at 0.125° horizontal resolution and hourly frequency [@WIND_GLO_PHY]. Chlorophyll-a concentrations come from the Global Ocean Colour dataset at $\sim$4 km horizontal resolution [@GlobColour]. All environmental data were retrieved daily (hourly for winds) for the 2013--2024 period, covering the Chilean Exclusive Economic Zone (EEZ) between 32°S and 41°S (Figure \@ref(fig:figEnvData)).


#### Observation structure for jack mackerel Centro-Sur biomass {-}

Over the 2000--2024 estimation window (25 years), the IFOP hydroacoustic assessment of jack mackerel in Centro-Sur Chile provides 16 years with a point estimate of spawning biomass and two additional years (2012, 2015) in which biomass fell below the assessment's lower detection limit and enters the likelihood as a left-censored observation at that limit. The remaining seven years were either not surveyed or lacked sufficient information for a stock-assessment run; in the state-space specification of Section \ref{sec:stock-dynamics}, these years carry no observation and their latent biomass $B_{\text{jurel},t}$ is identified dynamically through the Schaefer transition equation, together with the stock-specific priors on $(r^{0}, K, \sigma_{\text{proc}}, \sigma_{\text{obs}})$ adopted from the IFOP and SPRFMO assessments and on $(\rho^{SST}, \rho^{CHL})$ adopted from the reduced-form stress tests of Appendix \ref{appendix-stress}.

Two external series---jack mackerel biomass from the Northern acoustic zone (Arica--Iquique--Antofagasta, available since 2010) and the SPRFMO transzonal spawning biomass index for the Southeast Pacific---were considered as auxiliary information. The Northern series correlates with the Centro-Sur (CS) series at $r = 0.82$ over $N = 7$ overlapping years, while the SPRFMO index correlates with CS at $r = 0.11$ over $N = 17$ overlapping years. We treat these numbers as suggestive rather than conclusive: a seven-point Pearson correlation is at best descriptive, but the contrast in sign and magnitude is consistent with a Centro-Sur stock unit that shares short-run dynamics with the Northern Chilean assessment and is only weakly coupled to the SPRFMO-scale aggregate. Neither external series enters the structural model's likelihood---as a prior or as an observation---to avoid introducing information about coastal climate forcing through the indirect route of Northern or transzonal biomass.


*[R code chunk omitted]*


## Future climate data

Climate projections for SST, chlorophyll-a, and near-surface wind speed are obtained from the CMIP6 archive using a six-model ensemble (IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, MPI-ESM1-2-HR), selected to span the CMIP6 equilibrium climate sensitivity distribution. We use monthly outputs for two future scenarios: SSP2-4.5 (moderate) and SSP5-8.5 (high emissions). Section \ref{projection-approach} describes the projection horizons, baseline period, and delta-method procedure used to translate CMIP6 outputs into our empirical models. The per-model decomposition of projection uncertainty appears in Appendix \ref{appendix-ensemble} for stock-level intrinsic productivity and in Appendix \ref{appendix-trips-ensemble} for fleet-level trips.

## Econometric models

### Stock dynamics {#sec:stock-dynamics}

We model the interannual dynamics of each stock $i \in \{\text{anchoveta}, \text{sardina común}, \text{jack mackerel}\}$ as a Bayesian state-space process on the latent biomass $B_{i,t}$, driven by a Schaefer surplus-production function whose intrinsic growth rate is modulated by the physical climate. We adopt Schaefer as the $\theta = 1$ specialization of the Pella--Tomlinson family on identifiability grounds: the shape parameter $\theta$ is notoriously weakly identified with $N = 25$ annual observations per stock, and imposing $\theta = 1$ is a standard identification device in the small-pelagic literature [@hilbornWalters1992; @maunderPunt2013]. The law of motion is

\begin{equation}
B_{i,t+1} \;=\; B_{i,t} + r_{i,t}\, B_{i,t}\!\left(1 - \frac{B_{i,t}}{K_i}\right) \;-\; C_{i,t} \;+\; \varepsilon_{i,t},
\qquad \varepsilon_{i,t} \sim \mathcal{N}\!\big(0,\, \sigma_{\text{proc},i}^2\big),
\label{eq:law-of-motion}
\end{equation}

where $C_{i,t}$ is the observed annual catch, $K_i$ is the stock-specific carrying capacity, and $\sigma_{\text{proc},i}$ is the standard deviation of the stochastic recruitment innovation. Climate enters the dynamics through a log-linear shifter on the intrinsic growth rate,

\begin{equation}
r_{i,t} \;=\; r_i^{0}\, \exp\!\Big(\, \rho_i^{SST}\, (SST_{t-1} - \overline{SST})
\;+\; \rho_i^{CHL}\, (\log CHL_{t-1} - \overline{\log CHL}) \,\Big),
\label{eq:shifter}
\end{equation}

so $\rho_i^{SST}$ and $\rho_i^{CHL}$ are the semi-elasticities of stock productivity with respect to a one-degree Celsius SST anomaly and a one-log-point chlorophyll-a anomaly, respectively. The vector $(\rho_i^{SST}, \rho_i^{CHL})_{i=1}^3$ is the central object of interest in Section \ref{identification}. Because these parameters enter the law of motion as coefficients on exogenous climate forcings, they are invariant to the joint historical distribution of $(SST, B, C)$ and therefore transportable to climate regimes outside the 2000--2024 estimation sample. This transportability matters because the comparative-statics exercise of Section \ref{projections} evaluates the climate shifter at projected SST anomalies that lie several historical standard deviations beyond the estimation envelope.

Latent biomass is linked to the official survey-based estimates of spawning stock biomass $B_{i,t}^{\text{obs}}$---published by IFOP for anchoveta and sardina común in Centro-Sur Chile and by SPRFMO for jack mackerel---through a log-normal measurement equation,

\begin{equation}
\log B_{i,t}^{\text{obs}} \;=\; \log B_{i,t} \,+\, u_{i,t}, \qquad u_{i,t} \sim \mathcal{N}\!\big(0,\, \sigma_{\text{obs},i}^2\big).
\label{eq:obs}
\end{equation}

Environmental conditions are summarized annually by sea surface temperature (SST) and chlorophyll-a concentration (CHL), averaged over the Centro-Sur region within the Chilean EEZ and lagged one year to respect the pre-determined ordering of environmental forcing relative to year-$t$ biomass. The choice of these two covariates follows a large biological literature that identifies thermal regime and primary productivity as the dominant local drivers of small-pelagic dynamics in the Humboldt Current System [@Axbard2016; @cahuin2009; @Yáñez2014; see @cheung2008; @jennings2008].

We estimate the state-space specification by Bayesian inference for two reasons standard in the small-sample fishery literature. First, with $N = 25$ annual observations per stock, joint identification of the biological parameters $(r^{0}_i, K_i)$ and the climate shifters $(\rho^{SST}_i, \rho^{CHL}_i)$ requires the prior information embedded in the IFOP and SPRFMO single-species assessments to avoid degenerate likelihood maxima at the boundary of the parameter space; Appendix \ref{appendix-stress} demonstrates this boundary problem explicitly. Second, posterior credible intervals provide a natural framework for propagating uncertainty in the shifters through to the comparative-statics exercise of Section \ref{projections}. Estimation is implemented in Stan via Hamiltonian Monte Carlo. Priors on the biological parameters $(r_i^{0}, K_i, \sigma_{\text{proc},i}, \sigma_{\text{obs},i})$ are adopted from the IFOP and SPRFMO single-species assessments. Priors on the climate shifters $(\rho_i^{SST}, \rho_i^{CHL})$ are weakly informative normal densities centred at the point estimates of an independent stress-test regression of biomass growth increments on SST and log-CHL anomalies, with unit standard deviation (see Appendix \ref{appendix-stress} for the full prior elicitation protocol). We estimate three nested specifications of increasing flexibility: (i) species-independent dynamics without climate shifters (``ind''), (ii) the same with a cross-stock residual covariance $\Omega$ (``omega''), and (iii) the full model augmented with the climate shifter of Eq. \eqref{eq:shifter} (``full''). The posterior of the ``full'' specification is our primary object of interpretation; the nested predictive comparison is relegated to Appendix \ref{appendix-predictive}. All reported posteriors are based on four independent Hamiltonian Monte Carlo chains of 2,000 post-warmup iterations each, evaluated against standard convergence diagnostics. The Gelman--Rubin statistic $\hat{R}$ (which compares within-chain to between-chain variance and should be close to one if chains have mixed) is below 1.01 for all top-level parameters, and the effective sample size---in both the bulk and the tails of the posterior---exceeds 400 for all top-level parameters, indicating that posterior summaries are not contaminated by autocorrelation between adjacent draws. These thresholds are conventional in the applied Bayesian literature; see Appendix \ref{appendix-convergence} for the convergence diagnostics by parameter family. The seven jack mackerel Centro-Sur years without a survey estimate enter the likelihood as unobserved latent biomass states, identified only through the Schaefer transition equation; two further years (2012 and 2015) enter through a log-normal censored-observation term at the stock-assessment detection limit. All associated uncertainty propagates directly into the posterior of $(\rho_{\text{jurel}}^{SST}, \rho_{\text{jurel}}^{CHL})$, so no imputation step is embedded in the Stan likelihood.

Three features of the state-space formulation in Eq. \eqref{eq:law-of-motion}--\eqref{eq:obs} are material for this paper. First, it separates process noise $\sigma_{\text{proc}}$ from observation noise $\sigma_{\text{obs}}$, which is essential given the documented coefficient-of-variation of acoustic and egg-production surveys in this fishery. Second, it enforces a pre-determined ordering between year-$(t-1)$ environmental forcing and year-$t$ latent biomass, ruling out contemporaneous feedback into the climate covariates. Third, it yields structural climate semi-elasticities $(\rho^{SST}_i, \rho^{CHL}_i)$ that are invariant to the joint historical distribution of $(SST, B, C)$ and therefore transportable to climate regimes outside the 2000--2024 estimation window. This transportability is essential because the comparative-statics exercise of Section \ref{projections} evaluates the climate shifter at projected SST anomalies several historical standard deviations beyond the estimation envelope.

Figure \@ref(fig:biomass) shows that anchoveta, sardina común, and jack mackerel exhibit distinct biomass trajectories over the 2000--2024 window, with no evidence of strong interannual co-movement across species once scale differences are accounted for. Harvest pressure is visibly associated with these fluctuations; jack mackerel in particular experienced an abrupt decline during the late 2000s, consistent with the combined effects of intense fishing and unfavorable environmental conditions.


*[R code chunk omitted]*



### Total annual trips

We model the annual number of fishing trips taken by vessel $v$ in year $y$ as a count process following @Kasperski2015-jm. Because the available logbook data record only purse-seine operations, the unit of observation is a vessel--year. We estimate separate effort models for the industrial and artisanal fleets, allowing fishing activity to respond differently to economic conditions and regulatory constraints across sectors. This specification explicitly accommodates technological heterogeneity across fleet segments, reflecting differences in vessel capacity, operating scale, and production technology. A complementary approach, used in @Quezada2026-cp for the U.S. West Coast Coastal Pelagic Species fishery, models daily participation and target-species choice through a discrete choice framework with species distribution models as proxies for daily availability. The annual NB specification we adopt here is the natural counterpart in a setting where vessel-year is the operational unit at which TACs are allocated under the LMCA, and where daily logbook coverage is too sparse to support a daily DCM for the Centro-Sur Chilean SPF over the 2013--2024 window.

The baseline specification is a Poisson model:

\begin{equation}
T_{vy} \sim \text{Poisson}(\lambda_{vy}), \qquad 
\lambda_{vy} = \exp\!\left(U_{vy}'\beta\right),
\label{eq:poisson_trips}
\end{equation}

where $T_{vy}$ denotes the total number of purse-seine trips recorded for vessel $v$ in year $y$. Given substantial overdispersion in the data---the variance-to-mean ratio of $T_{vy}$ is 22.4 for the artisanal fleet and 4.9 for the industrial fleet---we estimate a negative binomial (NB) model, which nests the Poisson as a special case. A likelihood ratio test strongly rejects the Poisson restriction for both fleets ($p < 0.001$).

The vector of explanatory variables $U_{vy}$ includes output prices by species, vessel-level allocated harvest, fixed vessel characteristics, and operating conditions:

\begin{equation}
U_{vy}=\big[p_{sy},\, H^{alloc}_{vy},\, Z_v,\, O_{vy}\big].
\label{eq:U_trips}
\end{equation}

Output prices $p_{sy}$ are species-specific ex-vessel prices paid by processing plants to fishers, obtained from IFOP's manufacturing survey and deflated to constant 2018 pesos using the consumer price index from the Central Bank of Chile. Following @dresdner2013, prices are measured as annual averages over peak fishing months to reflect the economically relevant conditions faced by vessels when planning annual effort.

Because the model aims to characterize vessels' effort responses to changes in prices, quotas, and environmental conditions within the small pelagic fishery, we restrict attention to SPF trips recorded in logbooks. These trips account for approximately 95\% of observed fishing revenue and therefore capture the primary economic margin through which vessels adjust annual effort. Cross-validation against the SERNAPESCA vessel-level landings database (transparency request AH010T0006857; 2013--2024 Centro-Sur) confirms that the resulting panel is representative of the purse-seine artisanal segment. For the industrial fleet, the panel covers 40 of 59 registered vessels (68\% by count) and aggregate landings within $-10\%$ of the SERNAPESCA all-gear total, with portfolio-weighted catch composition matching SERNAPESCA aggregates within two percentage points across the three target species. For the artisanal fleet, the panel covers 859 of 2{,}689 registered vessels (32\% by count) but accounts for approximately $70\%$ of total Centro-Sur artisanal landings of the three species, reflecting the concentration of catch in the larger purse-seine vessels for which logbook submission is mandatory. Smaller artisanal vessels using non-purse-seine gears (lampara, lines) operate outside the LMCA quota architecture and are not modeled in the trip equation; they appear in the SERNAPESCA aggregate landings used as the likelihood input for the biomass state-space model.

Quota shares do not enter Eq. \eqref{eq:poisson_trips} directly. Instead, shares translate annual TACs into vessel-level allocated harvests. Let $\omega_{vs}^r$ denote vessel $v$'s historical share of landings of species $s$ within its administrative region $r$ (for artisanal vessels) or regulatory zone (for industrial vessels), computed over the full sample period. Given the effective TAC $\bar{Q}_{sy}^r$ for species $s$ in year $y$ and region $r$---obtained from SERNAPESCA quota monitoring records and reflecting all inter-fleet transfers and adjustments---vessel-level allocated harvest is:

\begin{equation}
H^{alloc}_{vy,s}=\omega_{vs}^r\,\bar{Q}_{sy}^r,
\qquad
H^{alloc}_{vy}=\sum_{s} H^{alloc}_{vy,s}.
\label{eq:Halloc}
\end{equation}

Each vessel is assigned to its administrative region based on its modal departure port in the logbook records. Artisanal TACs are assigned at the regional level (regions V, VIII, IX, XIV, X), while industrial TACs follow the regulatory zone structure established by SUBPESCA (zones V--IX and XIV--X for jack mackerel; zone V--X for sardine and anchoveta). This regional construction introduces cross-sectional variation in $H^{alloc}_{vy}$ that reflects the heterogeneous quota environments faced by vessels operating in different parts of the Centro-Sur fishery.

The vector $Z_v$ contains time-invariant vessel characteristics, including hold capacity (log of cubic meters) and vessel type. Hold capacity determines the physical constraint on catch per trip and proxies for vessel scale.

The vector $O_{vy}$ captures operating and regulatory constraints that vary across both vessels and years. Unlike the environmental variables in the stock dynamics model, which reflect biological productivity (SST, chlorophyll-a), the variables in the trip equation capture conditions that affect the *feasibility* of fishing operations. Two vessel--year variables are constructed using each vessel's center of gravity (COG)---the catch-weighted centroid of its haul locations over the sample period. First, the number of adverse-weather days is computed as the count of days per year in which wind speed exceeds 8 m/s at the environmental grid point nearest to the vessel's COG.\footnote{The wind threshold of 8 m/s corresponds approximately to Beaufort scale 5, at which purse-seine operations become difficult for artisanal vessels. We selected this threshold via AIC comparison across 8, 10, and 12 m/s cut-offs on the trip-equation fit.} Second, the number of days closed for biological closures (\textit{vedas}) is assigned based on the regulatory zone corresponding to the vessel's COG latitude. In the Centro-Sur region, sardine and anchoveta face seasonal closures for reproduction (August--October in regions V--VIII; July--October in regions IX--XIV) and recruitment (January--February in all regions), yielding 151 and 182 closed days per year, respectively. Jack mackerel has no biological closures.

Quota prices are not included explicitly in the trip equation. Instead, the economic scarcity of quota is captured implicitly through aggregate TAC levels and vessel-level allocated harvest.

Trips, harvest, and prices may be jointly determined within the year, implying potential endogeneity in reduced-form trip regressions. The purpose of Eq. \eqref{eq:poisson_trips}, however, is not causal identification but rather to provide an empirically grounded behavioral relationship that maps changes in prices, quotas, and environmental conditions into expected fishing effort under projected climate scenarios.



## Projection approach {#projection-approach}

We assess the impact of climate change on the Chilean small pelagic fishery through two channels: (i) a *direct weather channel*, in which projected changes in wind speed alter the number of bad-weather days that constrain fishing operations and thus enter the negative binomial trip equation; and (ii) an *indirect biomass channel*, in which projected changes in SST and CHL modify each stock's intrinsic productivity $r_{i,t}$ through the climate shifter $(\rho_i^{SST}, \rho_i^{CHL})$ of Eq. \eqref{eq:shifter} and, in turn, the law of motion in Eq. \eqref{eq:law-of-motion}.

Climate projections are derived from a six-model CMIP6 ensemble---IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, and MPI-ESM1-2-HR---under two Shared Socioeconomic Pathways: SSP2-4.5 (moderate emissions) and SSP5-8.5 (high emissions). The ensemble was selected to span the CMIP6 distribution of equilibrium climate sensitivity. We apply the delta method [@Burke2015; @Free2019] independently to each model, which preserves the observed interannual variability and fine-scale spatial structure from satellite records while imposing the climate-change signal from CMIP6. For each model and variable, the delta is computed as the difference (additive for SST and wind speed) or, for chlorophyll-a, the difference of natural logarithms (so that the resulting $\Delta \log\text{CHL}$ enters the shifter on its native estimation scale), between the CMIP6 future climatology and a spliced historical baseline that combines the CMIP6 historical run for 2000--2014 with the SSP2-4.5 run for 2015--2024 (CMIP6 historical runs end in 2014, so the splice is required to match the 2000--2024 estimation window of the structural model). For CESM2, which lacks chlorophyll under SSP2-4.5 in the NCAR CMIP6 catalogue, we splice the historical 2000--2014 segment with the SSP5-8.5 2015--2024 segment for chlorophyll only; the two scenarios are virtually indistinguishable in the near term and the substitution preserves CESM2's contribution to SSP5-8.5 chlorophyll deltas. We consider two future time windows: mid-century (2041--2060) and end-of-century (2081--2100). Comparative statics are then reported integrating over both the structural-parameter posterior and the cross-model dimension of the ensemble; the variance decomposition of the resulting projection uncertainty is reported in Appendix \ref{appendix-ensemble} for stock-level intrinsic productivity and in Appendix \ref{appendix-trips-ensemble} for fleet-level trips.

For the direct weather channel, monthly wind speed deltas from CMIP6 are applied additively to the daily wind speed observations at each vessel's center of gravity (COG) over 2013--2024, and bad-weather days (wind speed exceeding 8 m/s) are recounted vessel by vessel under each scenario; the resulting $\Delta\text{days}_{bw}$ enters the NB trip equation through the estimated semi-elasticity $\beta_{\text{weather}}$, retaining vessel-level heterogeneity in baseline weather exposure. Although the cross-model median CMIP6 wind anomaly is modest (below $+0.5$ m/s under SSP5-8.5 end-of-century), the historical daily wind distribution at the COG sits sufficiently close to the 8 m/s threshold that the cross-vessel median $\Delta\text{days}_{bw}$ rises by $+10$ days under SSP2-4.5 mid-century and $+23.5$ days under SSP5-8.5 end-of-century. Note that uas and vas are missing from the CESM2 archive in the CMIP6 DRS for this period, so the direct channel is computed from the five remaining ensemble members (CNRM-ESM2-1, GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, UKESM1-0-LL) while the indirect biomass channel retains the full six-member ensemble where SST and chlorophyll deltas are available. For the indirect biomass channel, we evaluate the climate shifter of Eq. \eqref{eq:shifter} at the posterior draws of $(\rho_i^{SST}, \rho_i^{CHL})$ from the full state-space specification, taking $\Delta SST$ and $\Delta \log CHL$ as the scenario- and window-specific CMIP6 anomalies relative to the 2000--2024 estimation baseline. This yields a full posterior distribution over $r_{i,t}^{\star} / r_i^{0}$ under each climate regime---a long-run comparative-statics object, in the sense that it describes the steady-state productivity of each stock under a counterfactual climate, not a year-by-year forecast of biomass. Forward simulation of biomass and catch trajectories under endogenous harvest rules is left to future work; the posterior reported here is archived to facilitate that extension.

As @Kasperski2015-jm note, multi-species bioeconomic frameworks are well suited to long-horizon projections of fish populations rather than to intra-annual management responses. Because our empirical models are estimated on interannual variability rather than decadal trends, the projections reported here capture the mechanical effect of changed environmental conditions on stock productivity and trip counts, while holding prices, quotas, and adaptive behaviour by fishers and managers fixed at historical levels [@Aufhammer2018]. They provide a useful benchmark for the direction and magnitude of climate impacts, with the understanding that behavioural responses may attenuate or amplify these effects over time.

# Results


<!-- ====== inlined: paper1/sections/results_identification.Rmd ====== -->

## Identification of climate shifters {#identification}

The central econometric object of this paper is the vector of
stock-specific *climate shifters*
$\{ \rho_i^{SST}, \rho_i^{CHL} \}_{i=1}^{3}$, which modulate the intrinsic
growth rate of each stock as

$$
r_{i,t} \;=\; r_i^{0} \, \exp\!\big(\, \rho_i^{SST} \,(SST_{t-1} - \overline{SST})
\;+\; \rho_i^{CHL} \,(\log CHL_{t-1} - \overline{\log CHL}) \,\big).
$$

These shifters admit a clean economic reading: $\rho_i^{SST}$ is the
semi-elasticity of the stock's intrinsic productivity $r_i$ with respect to
a sea-surface temperature anomaly of one degree Celsius, and similarly
$\rho_i^{CHL}$ is the semi-elasticity with respect to a log-point of
chlorophyll-a anomaly (a common proxy for primary productivity at the
base of the food web). They are the structural parameters that couple the
biological law of motion $B_{i,t+1} = B_{i,t} + g_i(B_{i,t}, X_{t}) - C_{i,t}
+ \varepsilon_{i,t}$ to the physical climate, and are therefore the
quantities that must be identified for the long-run projections of
Section \ref{projections} to have meaning as *comparative statics under
climate change* rather than as out-of-sample forecasts.

We adopt weakly informative priors on $\rho_i^{SST}, \rho_i^{CHL}$ derived
from independent reduced-form stress tests (Appendix A) and let the 2000--2024
biomass series update them. Table \ref{tab:rho-posteriors} reports the
posterior means, 90\% credible intervals, and the posterior-to-prior
standard deviation ratio, which measures how much the data refine each
parameter relative to the prior.


*[R code chunk omitted]*


The pattern of identification is itself informative and organises the
economic interpretation of the paper. Three facts stand out.

First, for the two coastal upwelling stocks---anchoveta and sardina
común---both climate shifters are identified with substantial precision.
The posterior 90\% credible intervals exclude zero for all four parameters,
and the standard deviation ratios fall between $0.43$ and $0.83$,
indicating that the 2000--2024 biomass series refines the priors
materially. For anchoveta, a one-degree positive SST anomaly is associated
with a semi-elasticity of $\rho^{SST}_{\text{anch}} = -1.06$
(CI $[-1.79, -0.38]$); for sardina común, the corresponding semi-elasticity
is more than twice as large, $\rho^{SST}_{\text{sard}} = -2.75$
(CI $[-3.46, -2.02]$). Evaluated at one historical standard deviation of
the SST anomaly series (estimation-sample $\hat{\sigma}_{SST} =
0.26\,^{\circ}\text{C}$ over 2000--2024), a thermal shock of that magnitude
lowers the intrinsic growth rate of anchoveta by approximately 24\%
($1 - e^{-1.06 \cdot 0.26}$) and that of sardina by approximately 51\%
($1 - e^{-2.75 \cdot 0.26}$) relative to the climatological mean. Under a
policy-relevant warming signal of $+1\,^{\circ}\text{C}$, comparable to
mid-century CMIP6 SSP2-4.5 projections for the Chilean coastal zone, the
implied declines are 65\% for anchoveta and 94\% for sardina, although
$+1\,^{\circ}\text{C}$ lies approximately four historical standard
deviations outside the estimation window and these projections therefore
rely on the log-linear extrapolation embedded in the shifter function.
Either way, the magnitudes are economically first-order for a fishery whose
Centro-Sur TAC is in the low hundred-thousand-tonne range. The narrow
historical SST variance ($\hat{\sigma}_{SST} = 0.26\,^{\circ}\text{C}$)
also explains, mechanically, why the one-step-ahead forecasting test of
Appendix B fails to discriminate between the climate-augmented and the
climate-free specifications: within the estimation window the annual
climate signal is small relative to the stochastic process innovation
$\sigma_{\text{proc}}$, yet accumulates to economically consequential
levels only over decadal horizons.

Second, the two coastal stocks respond to chlorophyll-a with **opposite
signs**: $\rho^{CHL}_{\text{anch}} = -3.64$ (CI $[-5.01, -2.25]$) versus
$\rho^{CHL}_{\text{sard}} = +2.17$ (CI $[+0.96, +3.37]$). At one historical
standard deviation of $\log CHL$ ($\hat{\sigma}_{\log CHL} = 0.095$, a
primary-productivity anomaly of roughly 10\%), a positive CHL shock lowers
anchoveta growth by approximately 29\% while raising sardina growth by
approximately 23\%. This is a reduced-form footprint of the well-documented trophic asymmetry between the two species, summarised here for the non-specialist reader. Chlorophyll-a is a satellite-observable proxy for phytoplankton biomass, the primary producers at the base of the marine food web. Pulses of high chlorophyll-a indicate periods of strong primary productivity, typically driven by coastal upwelling that brings nutrient-rich deep water to the surface. Sardina común feeds directly on small phytoplankton and benefits from these pulses, so its productivity rises with chlorophyll-a anomalies. Anchoveta, by contrast, feeds on larger zooplankton whose populations are themselves preyed upon by small phytoplankton-feeders; when the food web is dominated by small primary producers, the zooplankton biomass that anchoveta relies on is suppressed, and anchoveta productivity falls. The opposite-signed semi-elasticities of $\rho^{CHL}_{\text{anch}}$ and $\rho^{CHL}_{\text{sard}}$ identified in Table \ref{tab:rho-posteriors} are consistent with this trophic asymmetry and are not a statistical artefact. The economic implication is
first-order for this paper: the artisanal fleet, which lands both
species, is not simply "climate-exposed"; it is exposed to **within-target
heterogeneity** in the sign of climate effects. A warming-and-greening
regime therefore does not translate into a uniform shock on the artisanal
sector, but into a substitution across species that the current
quota-allocation rules, indexed by species, cannot fully absorb.

Third, and in marked contrast, **neither SST nor CHL shifters are identified
for jack mackerel**. The posterior standard deviations $\sigma_{\text{post}}$
are indistinguishable from the prior scale ($\sigma_{\text{post}}/\sigma_{\text{prior}}
\approx 1$), the posterior means lie near zero, and the credible intervals
straddle zero in both directions. This is the expected result under the
null hypothesis that jack mackerel productivity at the Centro-Sur scale is
not locally coupled to the Chilean coastal upwelling regime---which is
biologically sensible given its transboundary Southeast Pacific stock
structure managed through SPRFMO. Econometrically, the model correctly
reports non-identification rather than producing a spurious coefficient,
which is a strength of the Bayesian state-space approach with structurally
informed priors: the data can either move the prior or, as here, confirm
that they are silent about it. This is the econometric dividend of
Cowles-style structural identification in fishery climate-impact
assessment: the structural posterior reports the absence of local
climate signal where a reduced-form benchmark would have produced an
artefactually precise but structurally meaningless coefficient, which
would then propagate into climate projections as if it were information.

The non-identification result for jack mackerel is robust to the choice of spatial domain, biomass record, and forcing modality. Appendix \ref{appendix-spatial} reports five complementary tests of this null. First, refits of the full specification under three nested coastal domains (Centro-Sur EEZ, offshore-extended, regional Southeast Pacific) leave the posterior-to-prior standard-deviation ratio of $(\rho^{SST}_{\text{jurel}}, \rho^{CHL}_{\text{jurel}})$ in $0.998$--$1.014$. Second, augmenting the biomass record with a Northern Chilean acoustic series under a common elasticity moves the ratio only to $0.94$--$0.99$, ruling out a sample-size explanation. Third, replacing the local shifters with the basin-scale ENSO Niño 3.4 index---the climatic driver identified by the qualitative literature on this transboundary species (@Arcos2001-jq; @Pena-Torres2017-gn)---returns a posterior-to-prior ratio of $0.98$ at lag one and $1.01$ at lag two (Table \ref{tab:rho-posteriors}, ENSO row), even though the in-sample dispersion of the basin-scale shifter is approximately twice that of the coastal counterpart and the prior is deliberately tighter (Appendix \ref{sec:appendix-spatial-power}). Fourth, a joint specification with all three shifters active for jack mackerel simultaneously returns ratios near unity for all three coefficients ($1.03$ on local SST, $1.00$ on local $\log$ CHL, $0.98$ on basin-scale ENSO), a sensibility check that addresses the standard referee question. Fifth, an attempt to incorporate the SPRFMO regional assessment series fails on coherence grounds, indicating the broader geographic aggregate is not integrable with the Centro-Sur record under a single shifter. The convergence of these five tests rules out the conjecture that the non-identification is an artefact of spatial aggregation, sample size, mis-specified forcing scale, or joint-specification convention; the relevant climate forcing for the Centro-Sur jack mackerel stock operates at margins of behaviour, location, and phenology that are not captured in the elasticity of structural productivity at the annual aggregation considered here, consistent with its transboundary SPRFMO management.

Figure \ref{fig:rho-forest} visualises the posterior--prior updating as a
forest plot.

\begin{figure}[!htbp]
\centering
\includegraphics[width=0.75\textwidth]{../figs/t4b/t4b_full_rho_shifters.png}
\caption{Posterior and prior distributions of the climate shifters
$\rho_i^{SST}, \rho_i^{CHL}$ by stock. Anchoveta and sardina común show
substantial posterior updating with narrow credible intervals excluding
zero; jack mackerel posteriors coincide with the weakly informative
prior centred at zero.}
\label{fig:rho-forest}
\end{figure}

### Identification versus short-run prediction

The identified shifters are structural parameters rather than reduced-form
correlations: they measure an invariant biological mechanism linking ocean
state to stock productivity, and they enter the law of motion as
coefficients on exogenous climate inputs. This structural reading is what
licenses their use as projection inputs under climate regimes outside the
2000--2024 estimation sample; reduced-form correlations, by contrast,
would require the joint distribution of $(SST, B, C)$ to remain stationary
into the projection horizon, which is precisely the assumption the climate
scenarios are designed to violate. Their economic value lies in
**long-run comparative statics**: given a projected climate regime
$X_t^{\star}$ for the period 2040--2100 drawn from the CMIP6 ensemble,
the intrinsic productivity under that regime is
$r_i^{\star} = r_i^{0} \exp(\rho_i^{SST} \Delta SST_t + \rho_i^{CHL}
\Delta \log CHL_t)$, and the expected steady-state biomass, harvest, and
fleet-level effort follow mechanically. This is the channel through
which the paper translates physical climate change into distributional
outcomes in Section \ref{projections}.

Crucially, identification of $\rho$ does **not** imply superior short-run
predictive power. A leave-future-out cross-validation at the one-year
horizon (Appendix B) shows that the fully climate-augmented specification
improves one-step-ahead log predictive density by only
$\Delta\widehat{\text{ELPD}}_{\text{LFO}} \approx 0.4$ over a
climate-free Schaefer baseline, a statistically unresolved difference.
This is not a failure; it is precisely what should occur when the
process-noise variance $\sigma_{\text{proc}}$ is large relative to
year-to-year climate innovations. Annual climate variability
contributes little to *next-year nowcasts* but accumulates systematically
over decadal horizons, and the shifters $\rho_i$ are the parameters that
quantify that accumulation. A robustness comparison using PSIS-LOO is
reported in Appendix \ref{appendix-predictive}
(Table \ref{tab:loo-appendix}) and confirms that the full
specification is preferred as an in-sample description of the dynamics
($\Delta\widehat{\text{ELPD}}_{\text{LOO}} = 14.59$, SE $= 4.93$); the
LOO and LFO results are complementary diagnostics of, respectively,
identification-through-fit and forecasting-on-new-data, and the paper
relies on the former for the economic interpretation.

### Posterior-predictive adequacy

A stock-by-stock comparison of the smoothed latent biomass $B_{i,t}$
against the observed SSB series (Figure \ref{fig:ppc-smooth-vs-obs})
shows that the identified model reproduces the historical trajectory
within a median 90\% posterior band width of approximately 20\% of the
mean. Residuals are roughly Gaussian and contain no detectable
autocorrelation at one-year lag (Figure \ref{fig:ppc-residuals}).
Posterior-predictive diagnostics are reported in
Appendix \ref{appendix-posterior}; Markov-chain convergence
diagnostics for all top-level parameters are reported in
Appendix \ref{appendix-convergence}.

<!-- ====== end inlined: paper1/sections/results_identification.Rmd ====== -->



## Total annual trips {#sec:tripresults}


*[R code chunk omitted]*




*[R code chunk omitted]*


Table \ref{tab:poisson_results} reports the negative binomial estimates separately for each fleet segment. The specification includes year fixed effects, which absorb aggregate shocks affecting both fleets contemporaneously---most notably the 2019 social outbreak (\emph{estallido social}) and the 2020--2022 COVID-19 period---and identify the structural coefficients $\beta_H$ (allocated harvest) and $\beta_{\text{weather}}$ (bad-weather days) from within-year cross-vessel variation. Without year fixed effects, $\hat{\beta}_{\text{weather}}^{\text{ART}}$ is approximately twice as large in magnitude, reflecting the contemporaneous correlation between high-wind years and the social/pandemic shocks. The year-FE specification is therefore the basis for the climate projections in Section \ref{projections}; the relative trip projection $T^{\text{FUT}}_v / T^{\text{HIST}}_v$ does not depend on the year-FE values themselves, which cancel in the ratio.


*[R code chunk omitted]*


The coefficient on allocated harvest is positive and highly significant in both fleets, confirming that vessels with larger quota allocations undertake more trips per year. This variable provides the key linkage between the trip equation and the simulation framework: changes in regional TACs translate into vessel-level effort adjustments through the quota-share mechanism.

The two fleets differ markedly in price responsiveness. For the industrial fleet, the jack mackerel price is positive and significant ($p < 0.01$), consistent with this fleet's primary orientation toward jack mackerel. Sardine and anchoveta prices have no detectable effect on industrial effort, reflecting the limited participation of industrial vessels in the sardine--anchoveta fishery. For the artisanal fleet, the sardine price is positive and significant ($p < 0.01$), consistent with sardine being the dominant target species for artisanal vessels in the Centro-Sur region. The anchoveta-price coefficient is negative and significant; this counterintuitive sign likely reflects simultaneity: years of low anchoveta availability generate both higher prices (through the inverse-demand channel) and fewer trips (through reduced catch opportunities), producing a negative reduced-form correlation. As noted above, the purpose of this equation is not causal identification but rather to provide an empirically grounded mapping for the simulation, in which prices are determined endogenously by the inverse-demand module.

Hold capacity is not significant for the industrial fleet, where vessels are relatively homogeneous in scale, but it is positive and significant for the artisanal fleet. Among artisanal vessels, larger hold capacity is associated with more annual trips, consistent with larger vessels being more commercially active and better able to sustain operations across varying conditions.

The environmental and regulatory variables show distinct patterns across fleets. For the artisanal fleet, adverse weather days carry a negative and statistically distinguishable coefficient, indicating that, controlling for year-specific aggregate conditions, vessels operating in grids with more days of wind speeds above 8 m/s undertake fewer fishing trips. For the industrial fleet, adverse weather is not significant, consistent with larger vessels being better equipped to operate under rough conditions. Biological closure days are strongly negative for the industrial fleet, representing the largest effect in the model, consistent with the industrial fleet's dependence on access during open seasons. For the artisanal fleet, the positive coefficient on closure days does not admit a causal interpretation: under the year-fixed-effects specification, $\beta_{\text{closure}}$ is identified solely from the cross-zone differential between regions V-VIII (151 days) and IX-XIV (182 days) of the proxy variable described in Appendix \ref{appendix-stress} and discussed at length in the regulatory-history caveat of Section \ref{sec:discussion}. The positive sign therefore reflects locational heterogeneity in artisanal fishing intensity between the two regulatory zones (the southern zone IX-XIV contains both more nominal closure days and more concentrated artisanal effort per vessel, and the cross-sectional comparison cannot disentangle the two), not the causal effect of closures on trips. Constructing a year-by-year closure variable with within-zone temporal variation that would identify the causal effect requires reconciling the nominal regulatory ceilings of the D.Ex. 115/1998 and 530/2016 chain with the actual realised closure days reported in the SUBPESCA Indicadores Biológicos portal from 2019 onwards, a non-trivial data-engineering task discussed in Section \ref{sec:discussion} and reserved for follow-up work.

Vessel-type dummies capture residual heterogeneity in fleet composition. Among artisanal vessels, larger vessel categories (L, BRV) are associated with substantially fewer trips relative to the baseline, reflecting differences in trip duration and operational patterns across vessel classes.



## Climate change projections {#projections}

The projection methodology is summarized in Section \ref{projection-approach}. Under each scenario and time window, we translate CMIP6-derived environmental deltas into (i) changes in bad-weather days that enter the trip equation (direct channel) and (ii) posterior draws of the stock-specific effective growth rate $r_{i,t}^{\star}$, obtained by evaluating the identified climate shifter of Eq. \eqref{eq:shifter} at the projected SST and log-CHL anomalies (indirect channel).

### Projected environmental changes

Table \ref{tab:env_projections} summarizes the projected environmental changes for the Centro-Sur study area, reported as cross-model medians with the inter-model interquartile range (IQR) in brackets. Chlorophyll-a is reported as a percentage change, $\%\Delta\text{CHL} = (\exp(\Delta\log\text{CHL}) - 1)\times 100$, computed per model and then summarised across the ensemble; the structural model is fitted on $\Delta\log\text{CHL}$ and that scale is used in all downstream calculations (Section \ref{projection-approach}). Sea-surface temperature warms by a cross-model median of $+0.7$ to $+2.4\,^{\circ}$C depending on the scenario, with the strongest warming under SSP5-8.5 end-of-century and an inter-model spread that grows with the forcing. The chlorophyll-a signal is small in magnitude relative to the cross-model spread: the cross-model median of $\%\Delta\text{CHL}$ is close to zero in every scenario--window pair while individual models disagree on the sign, reflecting the well-documented inter-model disagreement on primary-productivity changes under climate forcing in CMIP6. Near-surface wind speed increases modestly under all scenarios (cross-model median $+0.1$ to $+0.4$ m/s), with a larger increase under SSP5-8.5 end-of-century than the single-model IPSL projection on which an earlier version of this paper was based; the inter-model IQR remains comparable to the median. While these mean wind changes are small, they translate into a substantial increase in the number of bad-weather days exceeding the 8 m/s operability threshold (cross-vessel median $+10$ to $+23.5$ days/year, see Section \ref{projection-approach}) because the historical daily wind distribution at vessel COGs sits sufficiently close to the threshold that a small upward shift in the mean displaces a non-negligible mass of the upper tail past it. The implications for fleet-level trips are quantified in Table \ref{tab:trip_compstat} and are first-order for the artisanal fleet.


*[R code chunk omitted]*


### Comparative statics on intrinsic stock productivity

Table \ref{tab:growth_compstat} reports the comparative-statics object $\Delta r_i^{\star} / r_i^{0}$ obtained by evaluating the identified climate shifter at the CMIP6 ensemble deltas of Table \ref{tab:env_projections} and integrating over the posterior of $(\rho_i^{SST}, \rho_i^{CHL})$ under the full state-space specification. For each scenario--window pair we compute the within-model posterior of $\Delta r_i^{\star}/r_i^{0}$ for each CMIP6 model in turn and then summarise the resulting set of model-level distributions along two distinct axes: the cross-model median and inter-quartile range (IQR) of the model-level posterior medians, which captures inter-model climate uncertainty, and the median across models of the within-model 90\% posterior credible interval, which captures structural uncertainty about $(\rho_i^{SST}, \rho_i^{CHL})$ holding the climate forcing fixed. The two intervals are reported separately because they have different policy implications and a separate variance decomposition is reported in Appendix \ref{appendix-ensemble}. Jack mackerel is reported as non-identified (``n.i.'') because its shifter posterior coincides with the weakly informative prior (Section \ref{identification}), so that projecting its productivity under future climate regimes would merely propagate prior uncertainty rather than transmit evidence from the 2000--2024 sample. A forward bioeconomic simulation for jack mackerel, combining the Centro-Sur stock with the SPRFMO transboundary assessment, is left to future work.


*[R code chunk omitted]*



*[R code chunk omitted]*


The magnitudes are economically first-order for a Centro-Sur fishery whose combined TAC is in the low hundred-thousand-tonne range. Under the moderate SSP2-4.5 mid-century scenario (cross-model median $+0.74\,^{\circ}$C; $\Delta\log\text{CHL}$ near zero in the cross-model median, with non-trivial inter-model spread), the cross-model median of anchoveta's intrinsic productivity declines by $51\%$ and sardina común's by $79\%$, with posterior probability of negative impact equal to one in both cases. Under the high-emissions SSP5-8.5 end-of-century scenario (cross-model median $+2.39\,^{\circ}$C, $\Delta\log\text{CHL}$ cross-model median $-0.013$ with $5$th-percentile of $-0.30$ across models) the cross-model medians deepen to $-90\%$ and $-99.9\%$ respectively, and the entire $90\%$ credible interval of sardine's response lies below zero in every model of the ensemble; the anchoveta cross-model probability of decline is $0.99$ rather than $1$ because under a small fraction of (model, draw) pairs a sufficiently negative $\Delta\log\text{CHL}$ combined with $\rho^{CHL}_{\text{anch}}<0$ offsets the SST-driven collapse. The identified signs confirm the qualitative reading of the shifters in Section \ref{identification}: both coastal stocks respond negatively to SST, but sardina común carries roughly twice the SST semi-elasticity of anchoveta, and its CHL semi-elasticity is of the opposite sign, so that the compound response---negative thermal shock combined with negative primary-productivity shock---is sharper for sardina than for anchoveta.

The comparative-statics exercise is a long-run object rather than a year-by-year forecast. It describes the steady-state intrinsic productivity of each stock under a counterfactual climate, *holding fixed* the law of motion and the fishery's regulatory regime. The shifters $(\rho_i^{SST}, \rho_i^{CHL})$ enter the law of motion as coefficients on exogenous climate forcings, which makes them invariant to the joint distribution of $(SST, B, C)$ and therefore evaluable at climate regimes outside the estimation window---in particular, at an SST anomaly of $+2.3^{\circ}$C that lies roughly nine historical standard deviations beyond the 2000--2024 mean. A purely correlational specification would not license this extrapolation.

### Implications for fleet-level effort

Table \ref{tab:trip_compstat} translates the comparative-statics object on intrinsic stock productivity in Table \ref{tab:growth_compstat} into a comparative-statics object on fleet-level annual trips, by propagating each posterior draw through the Schaefer steady-state biomass equation under historical average fishing pressure and through the negative binomial trip equation of Section \ref{sec:tripresults}. Vessel-level responses are aggregated to the fleet level as medians over posterior draws and over vessels within fleet, weighted by each vessel's realized catch composition over the 2012--2024 estimation window.


*[R code chunk omitted]*


The posterior probability of portfolio loss---defined as a reduction of more than fifty percent in the composition-weighted biomass factor $f^H_v$ relative to the 2000--2024 historical baseline---exceeds 0.95 for the artisanal fleet under every CMIP6 scenario considered and reaches 0.99 under SSP5-8.5 end-of-century. For the industrial fleet, the loss probability is a stable 0.12 across all four scenarios, driven entirely by its five-percent exposure to sardina común; the remaining 95\% of its historical portfolio is allocated to jack mackerel, whose climate shifter is treated as non-identified in Section \ref{identification}. The asymmetry in loss probability between the two fleets is first-order and stable across climate pathways, approximately eight-fold across all four scenarios.

Decomposing the fleet-level trip response isolates the channels through which this asymmetry operates. The \emph{marginal} posterior median of $\%\Delta$ trips, computed over all posterior draws, ranges from $-8.1\%$ (SSP2-4.5 mid) to $-10.2\%$ (SSP5-8.5 end) for the artisanal fleet and from $-0.7\%$ to $-0.9\%$ for the industrial fleet across the same scenarios---a ratio of roughly eleven to one at end-of-century. The \emph{conditional} posterior median, computed over the subset of posterior draws in which $f^H_v \geq 0.5$, isolates the climate-elasticity component from the portfolio-collapse component and ranges from $-2.1\%$ to $-2.7\%$ for the artisanal fleet and from $-0.6\%$ to $-0.8\%$ for the industrial fleet, a conditional ratio of roughly three-and-a-half to one. Two complementary mechanisms generate this asymmetry. First, the indirect biomass channel transmits the climate signal asymmetrically through differences in portfolio composition: the artisanal fleet is concentrated in the two coastal-upwelling stocks whose climate shifters $(\rho^{SST}_i, \rho^{CHL}_i)$ are both identified and economically large, while $95\%$ of the industrial fleet's historical portfolio sits in jack mackerel, whose Centro-Sur shifter is not identified and is therefore held at the climatological mean in the projection. Second, the direct weather channel transmits the climate signal asymmetrically through differences in fleet-level weather sensitivity: the negative binomial trip equation estimates $\hat{\beta}_{\text{weather}}^{\text{ART}} = -0.0008$ (statistically distinguishable from zero) and $\hat{\beta}_{\text{weather}}^{\text{IND}} = -0.0001$ (statistically indistinguishable from zero), so the projected $+10$ to $+23.5$ days of additional bad weather per year translate into a $-0.7\%$ to $-1.9\%$ contribution to the artisanal trip response and a contribution close to zero for the industrial fleet, consistent with the size-dependent weather tolerance of the two segments. Both $\hat{\beta}_{\text{weather}}$ estimates are obtained from the negative binomial specification with year fixed effects (Section \ref{sec:tripresults}), which absorbs the aggregate shocks of the 2019 social outbreak and the 2020--2022 COVID period; without year fixed effects, $\hat{\beta}_{\text{weather}}^{\text{ART}}$ is approximately twice as large in magnitude, indicating that the contemporaneous correlation between high-wind years and the social/pandemic shocks would otherwise inflate the estimated weather elasticity. The LMCA's limited cross-sector transferability locks this dual exposure---portfolio composition under the indirect channel and weather sensitivity under the direct channel---into differential losses of harvest capacity, echoing the portfolio mechanism documented for U.S. West Coast and Alaskan fisheries by @Kasperski2013-jz and the regime-shift buffering documented by @Cline2017-dp: segments with narrower species portfolios face systematically higher exposure to species-specific shocks, climate-driven or otherwise, and institutional access constraints of the type imposed by the LMCA can limit the realized benefits of diversification [@Oken2021-of].

Three caveats qualify this thought experiment. First, the Schaefer steady-state comparative statics holds fishing pressure fixed at the 2000--2024 historical average; any regulatory response that lowered $F$ in the face of falling productivity would attenuate both the loss probability and the marginal trip response reported here. Quantifying that regulatory margin requires a forward simulation of the biomass process under endogenous harvest rules---most prominently the LTP cap on industrial quota transferability and the annual SUBPESCA revision of TACs in response to in-year biomass signals---which we leave to future work and which would reuse the posterior reported here. Second, the 2000--2024 observation window was not itself in Schaefer equilibrium under $F_{\text{hist}}$; the pipeline's internal consistency check, obtained by evaluating the comparative statics at $\Delta SST = 0$ and $\Delta \log CHL = 0$, yields a median $f^H_v$ of approximately 1.015 rather than 1.000, reflecting a mild historical depletion from equilibrium. The scenario results in Table \ref{tab:trip_compstat} should therefore be read as responses \emph{relative to the baseline steady-state} rather than relative to the 2000--2024 observed trajectory. Third, the jack mackerel shifter is treated as non-identified. Two interpretive points should precede the empirical evidence. First, the result is a null on \emph{local identification}, not on biological climate sensitivity: the available 25-year window provides only 16 informative annual observations of Centro-Sur spawning biomass against a historical SST envelope of $\hat{\sigma}_{SST} \approx 0.26\,^{\circ}\text{C}$, so any climate response of moderate magnitude operating at scales broader than the Centro-Sur biological domain would lie below the threshold of statistical detection in this sample regardless of its true magnitude. Second, complementary empirical evidence on jack mackerel documents that climate forcing does operate on the species at scales beyond local coastal anomalies: @Pena-Torres2017-gn report ENSO-driven shifts in jack mackerel location choices in the Chilean fishery, and @Arcos2001-jq describe SPRFMO-scale stock dynamics consistent with broad-basin forcing, so the absence of an identifiable Centro-Sur shifter should not be read as evidence of climate insensitivity. With these interpretive caveats noted, three complementary tests reported in Appendix \ref{appendix-spatial} converge on the same null and rule out the most natural mechanical explanations for it---insufficient spatial extent, insufficient sample size, and poor source aggregation. Re-fitting the state-space on three nested spatial domains for the environmental aggregation (Centro-Sur EEZ, offshore-extended, regional Southeast Pacific) yields posterior-to-prior standard deviation ratios of $0.998$--$1.014$ for both $\rho^{SST}_{\text{jurel}}$ and $\rho^{CHL}_{\text{jurel}}$, indistinguishable from unity in every domain (Section \ref{sec:appendix-spatial-results}). A dual-source extension that augments the likelihood with the Northern Chilean acoustic series under a common climate elasticity---an assumption motivated by the $0.88$ log-scale correlation between the Centro-Sur and Northern series across overlapping years---reduces the ratios only to $0.94$--$0.99$, well above the threshold for material identification (Section \ref{sec:appendix-spatial-dual}). A separate exploratory attempt to incorporate the SPRFMO range-wide assessment (OROP-PS, encompassing Chile, Peru, Ecuador and the adjacent high-seas area) fails on coherence grounds, with multimodal posterior support and unsatisfactory chain mixing, indicating that the broader geographic aggregate is not integrable with the Centro-Sur record under a single shifter. The convergence of these three tests indicates a genuinely flat shifter \emph{within the Centro-Sur biological domain}, consistent with the most natural reading of the null in light of @Pena-Torres2017-gn and @Arcos2001-jq: that the relevant climatic drivers for jack mackerel operate at spatial scales beyond those captured by local Chilean SST and chlorophyll anomalies. The industrial fleet's apparent climate protection in Table \ref{tab:trip_compstat} therefore rests on a null about local identification that cannot be sharpened within the Centro-Sur identification strategy, even with the dual-source extension; the appropriate setting in which to discriminate between local decoupling and broader-scale forcing mechanisms is a range-wide SPRFMO analysis with explicit cross-stock spillover, which we also leave to future work.

# Discussion {#sec:discussion}

Our results reveal a substantial asymmetry in how climate change affects different segments of Chile's small pelagic fishery. The asymmetry is governed by the differential exposure of each fleet's species portfolio to the identified climate parameters under the LMCA's limited cross-sector transferability. The two coastal upwelling stocks targeted by the artisanal fleet---anchoveta and sardina común---both respond negatively to warming, with sardina común carrying roughly twice the SST semi-elasticity of anchoveta and an opposite-signed CHL response. The industrial fleet, by contrast, is diversified across these two coastal stocks and the transboundary jack mackerel stock, whose local productivity is *not* identified in the 2000--2024 sample. The artisanal fleet, concentrated in the sardina--anchoveta pair, is therefore the segment whose long-run harvest capacity is most exposed to the CMIP6 climate signal under the current LMCA architecture. This finding aligns with the broader literature on heterogeneous climate impacts within fleets [@sumaila2011; @Free2019] and underscores that aggregate projections can mask first-order distributional consequences inside the same fishery.

The non-identification of $(\rho_{\text{jur}}^{SST}, \rho_{\text{jur}}^{CHL})$ at the Centro-Sur scale is itself a substantive result rather than a nuisance, but its policy reading depends on a careful distinction between \emph{non-identification} and \emph{no climate effect}. The two are easily conflated by specifications that force a point estimate onto every regressor regardless of how informative the data are about it. Appendix \ref{appendix-spatial} reports five converging tests of this distinction, all consistent with the absence of an identifiable shifter for jack mackerel within the $2000$--$2024$ Centro-Sur biomass record: (i) varying the spatial aggregation of the coastal shifters across three nested domains $\mathcal{D}_1 \subset \mathcal{D}_2 \subset \mathcal{D}_3$ leaves the posterior-to-prior ratios in $0.998$--$1.014$; (ii) augmenting the biomass record with a Northern Chilean acoustic series under a common elasticity moves the ratio only to $0.94$--$0.99$; (iii) replacing the coastal shifters with the basin-scale ENSO Niño 3.4 index returns a ratio of $0.98$ at lag one and $1.01$ at lag two; (iv) a joint specification with all three shifters active for jack mackerel simultaneously returns ratios of $1.03$ on local SST, $1.00$ on local $\log$ chlorophyll, and $0.98$ on basin-scale ENSO; and (v) an attempt to incorporate the SPRFMO regional assessment series fails on coherence grounds. Existing empirical evidence on jack mackerel documents that climate does affect the species at scales broader than local coastal anomalies---@Arcos2001-jq on intrusion of the $15\,^{\circ}$C isotherm during the $1997$--$98$ El Niño, @Pena-Torres2017-gn on ENSO-driven shifts in location choices in the Chilean fishery---but each of these documents climatic effects on \emph{margins} (location choice, range distribution, spawning timing, phenological response) that are not necessarily captured in the elasticity of structural productivity at an annual aggregate. The convergence of five independent tests on this null at the Centro-Sur scale points to a structural rather than aggregation-driven limitation of the available record: closing the identification gap will require either a longer biomass record or a basin-scale assessment with explicit cross-stock spillover, not a different choice of spatial aggregation, biomass source, basin-scale shifter, or joint-specification convention within the present record. We accordingly hold $r^{*}_{\text{jurel}}$ fixed in the projections of Tables \ref{tab:growth_compstat} and \ref{tab:trip_compstat}, and report the resulting fleet-level elasticities under that constraint. A prior-propagation sensitivity reported in Appendix \ref{sec:appendix-spatial-enso} computes the $90\%$ predictive interval of the jack mackerel productivity factor by combining the posterior of $\rho_{\text{jur}}^{ENSO}$ with the CMIP6 ensemble of basin-scale temperature deltas; the interval spans approximately three orders of magnitude under SSP$5$-$8.5$ end-of-century ($[0.05, 19.5]$ on the productivity factor), confirming that the prior-propagated projection is not informative for policy and that the fixed-$r^{*}$ convention is the defensible reporting choice.

The two channels through which climate change reaches fleet-level effort operate on very different scales and on different segments of the fleet. The direct weather channel is small in mean wind anomaly---the cross-model median CMIP6 increase in near-surface wind speed is below $+0.5$ m/s even under SSP5-8.5 end-of-century---but the historical daily wind distribution at vessel COGs sits sufficiently close to the 8 m/s operability threshold that additional bad-weather days exceed twenty per year on average under SSP5-8.5 end-of-century. This translates into a $-0.7\%$ to $-1.9\%$ marginal contribution to the artisanal trip response and a contribution indistinguishable from zero for the industrial fleet, reflecting the differential weather sensitivity captured by $\hat{\beta}_{\text{weather}}$. The indirect biomass channel dominates the response in absolute terms for both fleets but operates entirely through portfolio composition, so the asymmetry it generates is intrinsic to the LMCA's allocation of stocks across segments. Climate adaptation policy in the Centro-Sur therefore needs to address both margins. The indirect channel calls for reform of the institutional architecture that mediates portfolio exposure---quota allocation rules, cross-fleet transferability, and the design of TACs under shifting species productivity. The direct channel calls for operational measures targeted at the artisanal segment specifically, such as expanded port infrastructure, vessel reinforcement programs, or weather-indexed insurance, which are first-order for that fleet but redundant for the industrial purse-seine fleet. This conclusion is based on the CMIP6 monthly wind ensemble; downscaled regional climate models that resolve extreme wind events could only raise the weight of the direct channel further.

The species-level productivity projections deserve careful interpretation. The log-linear form of the climate shifter in Eq. \eqref{eq:shifter} is identified from interannual variation over 2000--2024, during which the realised range of SST anomalies was narrow ($\hat{\sigma}_{SST} \approx 0.26\,^{\circ}\text{C}$). CMIP6 anomalies under SSP5-8.5 end-of-century reach roughly $+2.3\,^{\circ}$C, nearly an order of magnitude outside the estimation window, so the corresponding posterior of $\Delta r_i^{\star}/r_i^{0}$ leans heavily on the log-linear extrapolation embedded in the shifter function. We regard the projected magnitudes as indicative of the direction and relative scale of impacts across stocks rather than as precise point forecasts. The log-linear shifter is a maintained simplification: thermal-tolerance arguments in the climate-fisheries literature [@Cheung2010; @Free2019] imply that for stocks operating below their thermal optimum, a log-linear specification, if anything, *under-states* the productivity response under high warming. The projected magnitudes for SSP5-8.5 end-of-century should therefore be read as conservative within the class of monotone shifter functions consistent with the identified posterior signs. A non-parametric extension of the shifter, or pooled identification across multiple Humboldt-Current datasets, is the natural direction in which to relax this assumption.

Several caveats apply to the present analysis. First, the projections hold ex-vessel prices and management rules constant at historical levels, implying that the long-run responses capture the mechanical effect of changed environmental and biological conditions without accounting for endogenous price adjustments or adaptive management. @sumaila2011 note that reduced fish supply under climate change could increase prices, partially offsetting revenue losses from lower catches, while @Lam2016 project sizable changes in global fisheries revenues by the 2050s once price responses and cross-country trade are accounted for. Incorporating an inverse demand system and numerical optimization of quota paths is a natural extension to capture these equilibrium adjustments. Second, although our projections integrate over a six-model CMIP6 ensemble, the cross-model spread in chlorophyll-a remains substantial: the cross-model median of $\Delta \log\text{CHL}$ is close to zero in all scenario--window pairs while the inter-model dispersion is comparable in magnitude to the median, reflecting the well-documented disagreement among Earth system models on the direction and magnitude of primary productivity changes [@sumaila2011]. The variance decomposition reported in Appendix \ref{appendix-ensemble} shows that, for the sardine projection, the between-model component accounts for $77$--$91$\% of total projection variance under three of the four scenario--window pairs, so the residual ensemble uncertainty on this stock is large despite the multi-model integration. The fleet-level trip projections in Table \ref{tab:trip_compstat}, by contrast, exhibit narrow cross-model interquartile ranges that should not be read as climate consensus: the corresponding decomposition reported in Appendix \ref{appendix-trips-ensemble} attributes $97$--$100$\% of the total variance in $\Delta T_f / T_f^{(0)}$ to the within-model component (posterior pooled with vessel heterogeneity within fleet), reflecting a floor-effect saturation in which the Schaefer steady-state biomass collapse drives the trip response into a fleet-specific plateau independent of the climate magnitude. The substantive implication is that the marginal information value of expanding the CMIP6 ensemble for fleet-level trip projections is small relative to that of tightening the structural posterior on $(\rho^{SST}_s, \rho^{CHL}_s)$ or refining the description of vessel heterogeneity in $(\omega_{v,s}, H^{\text{alloc}}_v)$; what governs the heterogeneity in trip outcomes across vessels and fleets is not which CMIP6 model is correct---given that all of them imply portfolio collapse for the two coastal stocks---but the differential economic exposure to that collapse imposed by historical catch composition and quota allocation. Third, the shifters are identified on a 25-year time series and, while the state-space specification propagates process-noise and measurement-noise uncertainty into the posterior, its ability to detect non-linearities in the climate response is limited. The posterior-to-prior standard-deviation ratios reported in Table \ref{tab:rho-posteriors} provide a direct empirical check that the data update the prior for anchoveta and sardina común (ratios in the $0.43$--$0.83$ range), while leaving the jurel shifters at the prior (ratios essentially equal to one)---the latter being the basis of our non-identification finding. Fourth, our models do not explicitly incorporate risk preferences or production risk, which may play a role in shaping fleet-level responses to environmental variability [@Kasperski2013-jz; @Sethi2014-bn]. Fifth, the biological-closure variable in the trip equation is coded as a zonal proxy with no within-year temporal variation, set to the nominal regulatory ceiling of the reproductive closure regime under the relevant SUBPESCA decrees: the V-VIII zone receives 151 days and the IX-XIV zone receives 182 days throughout the panel. The underlying regulatory chronology is in fact non-trivial---D.Ex. 115/1998 governed the closure regime through July 2016 with annual modifications (D.Ex. 1661/2009 establishing 21 August to 21 October as the standing period, with year-specific adjustments in D.Ex. 705/2010, 796/2012, 747/2013, and 598/2015); D.Ex. 530/2016 then introduced a referential period of 6 July to 31 October with a fixed core (3 August to 4 October) and dynamic windows triggered by weekly IGS/PHA biological indicators; D.Ex. 137/2021 refined the indicator thresholds; and D.Ex. 05/2024 superseded the 530/2016 decree---and the actual realised closure days reported by the SUBPESCA Indicadores Biológicos portal range from $98$ (in $2019$) to $230$ (in $2024$) across regions and years. Constructing a year-by-year closure variable that reconciles the nominal regulatory regime with the actual realised closure days reported in the portal (available from $2019$ onward) and with auxiliary recruitment-closure decrees not regulated by the reproductive-closure chain documented above is a non-trivial data-engineering task that we leave to follow-up work; for the present paper the zonal proxy captures the structural V-VIII / IX-XIV differential ($31$ days) that, under the year-fixed-effects specification of Section \ref{sec:tripresults}, is the variation that identifies $\beta_{\text{closure}}$. Sixth, the trip equation panel is constructed from IFOP logbook records and is therefore representative of the purse-seine fleet that operates under the LMCA quota architecture; smaller artisanal vessels using non-purse-seine gears (lampara, lines) operate outside the logbook system. Cross-validation against the SERNAPESCA vessel-level landings database confirms that the panel's portfolio weights $\omega_{v,s}$ match the SERNAPESCA aggregate within two percentage points for the industrial fleet and within three percentage points (catch-weighted) for the purse-seine artisanal subset that the panel represents. The non-purse-seine artisanal segment, which accounts for approximately $30\%$ of total Centro-Sur artisanal landings and exhibits a higher proportional exposure to jack mackerel, is not modeled here; a sample-weighting extension that incorporates that segment is left to future work. The biomass likelihood, by contrast, is constructed from SERNAPESCA all-gear landings and is unaffected by this restriction. Seventh, the direct weather channel is constructed from five of the six CMIP6 ensemble members because CESM2 does not publish near-surface wind components (uas, vas) in the CMIP6 DRS for the relevant scenarios and time windows; CESM2 contributes to the indirect biomass channel through SST and chlorophyll deltas (six members in SSP5-8.5, five in SSP2-4.5 by the chlorophyll restriction noted in Section \ref{projection-approach}) but enters the direct channel with $\Delta\text{wind} = 0$ by construction. The contribution of CESM2 to the cross-model spread of fleet-level trips therefore flows entirely through the indirect channel, which is the dominant source of variance in any case under the floor-effect saturation documented in Appendix \ref{appendix-trips-ensemble}.

The finding that climate change creates winners and losers within the same fishery has direct implications for quota-allocation policy. Chile's current regime---the *Límite Máximo de Captura por Armador* (LMCA)---allocates quotas separately for the artisanal and industrial sectors and limits transferability across fleet segments. Under such a rule, the climate-driven divergence in stock productivity reported in Table \ref{tab:growth_compstat} translates one-to-one into a divergent loss of effective quota value across the artisanal--industrial divide: this is a feature of the allocation rule, not of the climate signal alone. If the long-run productivity of the coastal-upwelling pair declines by the magnitudes reported in Table \ref{tab:growth_compstat}, the relative value of artisanal quotas---heavily concentrated in those stocks---could fall substantially, motivating reforms to the LMCA that would allow more flexible cross-sector transfers. This echoes the portfolio literature on fishery diversification [@Kasperski2013-jz; @Cline2017-dp], which shows that access to a broader species portfolio reduces revenue variability and buffers communities against abrupt regime shifts. @Oken2021-of further document that institutional access constraints---such as limits on transferability of fishing rights---can substantially reduce the realized benefits of diversification. This is precisely the channel through which the LMCA's cross-sector restrictions translate into amplified climate exposure for the artisanal segment. Secure, transferable rights across fleet segments would facilitate adaptation to climate-driven shifts in species composition [@Holland2016-rj].

# Conclusions

This paper estimates a multi-species bioeconomic model for Chile's small pelagic fishery and quantifies the long-run productivity response of each stock to CMIP6 climate scenarios, together with the resulting fleet-level effort response. We contribute to the literature in three ways. First, we link a Bayesian state-space model of stock dynamics---calibrated on official IFOP and SPRFMO assessments---to negative binomial trip equations estimated separately for the artisanal and industrial fleets, and we show that the direction of the distributional asymmetry across fleets is governed by the interaction between portfolio composition and the LMCA's limited cross-sector transferability. The artisanal segment bears the sharper long-run loss because its historical landings are concentrated in the two stocks whose climate sensitivities are identified and economically large. This finding extends the portfolio mechanism of @Kasperski2013-jz and @Cline2017-dp to the climate-impact setting and to a quota regime---the LMCA---that constrains the cross-sector reallocation of fishing rights, consistent with the access-constraint argument of @Oken2021-of. Second, we identify a vector of climate shifters $(\rho_i^{SST}, \rho_i^{CHL})$ that modulate each stock's intrinsic growth rate; the shifters are interpretable as semi-elasticities of stock productivity with respect to thermal and primary-productivity anomalies and are sharply identified for the two coastal-upwelling stocks. Third, we evaluate the bioeconomic framework under a six-model CMIP6 ensemble (IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, MPI-ESM1-2-HR) for SSP2-4.5 and SSP5-8.5 and report comparative-statics implications for both stock productivity and fleet-level effort. A variance decomposition (Appendices \ref{appendix-ensemble} and \ref{appendix-trips-ensemble}) shows that, once the Schaefer steady-state collapse saturates the portfolio for the two coastal stocks, the within-model component (posterior pooled with vessel heterogeneity) accounts for essentially the entire total variance in fleet-level trips, so the policy-relevant uncertainty in the trip projections lies on the within-model side rather than in disagreement across CMIP6 models.

Our projections indicate that the long-run productivity of the coastal-upwelling pair---anchoveta and sardina común---is poised to decline sharply under all CMIP6 scenarios considered. Sardina común is consistently more exposed than anchoveta, and the SSP5-8.5 end-of-century scenario essentially eliminates the intrinsic productivity of sardina común at the Centro-Sur scale. The Centro-Sur jack mackerel stock, by contrast, does not provide sufficient information to identify a local climate response in the 2000--2024 sample, consistent with its transboundary SPRFMO management. These results suggest that management policies focused on aggregate effort levels may miss important heterogeneity across fleets and species, and that climate adaptation in this fishery will need to address the uneven distribution of impacts through the quota-allocation architecture rather than through operational margins alone.

Several extensions to the present framework are natural. A first extension uses the posterior of $(r_i^0, K_i, \rho_i^{SST}, \rho_i^{CHL}, \Omega)$ identified here as a prior for a Stackelberg bi-level optimization, in which the regulator chooses the time path of TACs and the artisanal and industrial fleets allocate effort across stocks under the climate-shifted law of motion. That exercise would deliver full forward biomass trajectories under CMIP6 anomaly paths with 90\% credible bands, complementing the comparative-statics treatment in the present paper, and would follow the complete @Kasperski2015-jm approach with trip-level cost functions and an inverse-demand system. We leave it to future work; the posterior reported here is archived in machine-readable form to facilitate that extension. The spatial dimension of effort allocation is another natural extension, connecting the multi-species model to the location-choice literature [e.g., @Dupont1993-jn; @Smith2005-us; @Hicks2020-mz], since the geographic distribution of species availability is likely to shift under warming. A direct route for this spatial extension is to migrate the annual NB trip equation to a daily discrete choice specification with environmentally informed species distribution models (SDMs) as proxies for local availability, following the approach of @Quezada2026-cp for the U.S. West Coast Coastal Pelagic Species fishery. SDMs for the Chilean Humboldt Current System are an active area of development in IFOP and academic collaborations; once available at sufficient spatial resolution for anchoveta, sardina común, and jack mackerel, they would allow the present framework to capture daily and within-port heterogeneity in fishing-effort responses to climate-driven shifts in availability. Finally, incorporating risk preferences and production risk---through, for example, random-coefficient models---would provide a richer characterization of how fishers respond to the increased environmental variability projected under climate change [@Kasperski2013-jz].

# Acknowledgments {-}

The author thanks Andrea Araya, Karen Walker, and Carola Hernández (Instituto de Fomento Pesquero, IFOP) for providing access to the trip-level logbook data and for responding to detailed methodological questions about its structure during data preparation. The author also thanks IFOP institutionally for granting access to the data through the Convenio Desempeño framework, and SPRFMO for publishing the JJM stock-assessment outputs used to construct the jack mackerel transboundary biomass and catch series referenced in Section 3.1. Comments from participants at internal seminars of the Environment for Development (EfD) Chile network and from the audience at the ICES/PICES Working Group on Small Pelagic Fish improved earlier versions of this manuscript. The author bears sole responsibility for any remaining errors.

# Funding {-}

Quezada-Escalona acknowledges funding from the Agencia Nacional de Investigación y Desarrollo (ANID), Government of Chile, through FONDECYT Iniciación project N° 11250223. Partial support was also provided by ANID through the INCAR2 (Centro Interdisciplinario de Investigación para la Acuicultura Sustentable) project CIA250009. The funders had no role in study design, data collection and analysis, decision to publish, or preparation of the manuscript.

# Data and code availability {-}

All code required to replicate the analysis is openly available at \url{https://github.com/fquezadae/Impact-of-Environmental-Variability-on-Harvest} and will be archived at submission time as a versioned Zenodo release with a citable DOI. Environmental covariates are obtained from publicly available sources --- the E.U. Copernicus Marine Service Information for the historical period (DOIs in references) and the CMIP6 archive accessed through the Earth System Grid Federation for the projection period. Stock-assessment biomass series are obtained from the Instituto de Fomento Pesquero (IFOP) annual technical reports for anchoveta and sardina común (Centro-Sur Chile) and from the South Pacific Regional Fisheries Management Organisation (SPRFMO) Scientific Committee reports for jack mackerel (transboundary). Annual catch (landings) series for 2000--2024 are obtained from the Servicio Nacional de Pesca y Acuicultura (SERNAPESCA) official desembarque database, covering all gears (industrial and artisanal), through a transparency request (AH010T0006857) filed under Chile's Ley 20.285 in April 2025; aggregation and filtering to the Centro-Sur scale (regions V--X plus Ñuble) are reproducible from the source CSV via the script \texttt{R/01\_data/99b\_aggregate\_catch\_cs\_from\_sernapesca\_v3.R}. The vessel-level trip and landings microdata used to estimate the negative binomial trip equation were obtained from IFOP under a Convenio Desempeño data-sharing agreement; these data are confidential at the vessel level and cannot be redistributed publicly, but are available to qualified researchers under equivalent agreements with IFOP. Vessel identifiers used in this paper have been anonymised before any code or output was archived. The replication repository contains aggregate-level processed data sufficient to reproduce all reported tables and figures.

# Repository

The source code for this project is available at \url{https://github.com/fquezadae/Impact-of-Environmental-Variability-on-Harvest}.


# References

<div id="refs"></div>


# (APPENDIX) Appendix {-}


<!-- ====== inlined: paper1/sections/appendix_stress_tests.Rmd ====== -->

# Reduced-form stress tests and prior elicitation {#appendix-stress}

This appendix formalises the protocol used to elicit the prior densities
on the climate shifters $(\rho_i^{SST}, \rho_i^{CHL})$ that enter the
state-space specification of Section \ref{sec:stock-dynamics}. The
protocol has two purposes. First, it documents an independent,
reduced-form fit of the deterministic Schaefer hindcast augmented with
SST and log-CHL forcings; this fit motivates the choice of prior centres
and standard deviations. Second, it serves as a diagnostic for the
identifiability of $(\rho_i^{SST}, \rho_i^{CHL})$ under a non-Bayesian
point estimator, which we use to justify the recourse to a Bayesian
state-space specification with weakly informative priors rather than to
a maximum-likelihood treatment of the structural model.

## Hindcast specification {#sec:appendix-stress-spec}

For each stock $i \in \{\text{anchoveta}, \text{sardina común}, \text{jack mackerel}\}$ we estimate a deterministic Schaefer hindcast over the 2000--2024 estimation window,

\begin{equation}
\hat B_{i,t+1} \;=\; \hat B_{i,t} \,+\, r_{i,t}\, \hat B_{i,t}\!\left(1 - \frac{\hat B_{i,t}}{K_i}\right) \,-\, C_{i,t},
\qquad \hat B_{i,t_0} = B_{i,t_0}^{\text{obs}},
\label{eq:stress-law}
\end{equation}

with the climate-modulated growth rate

\begin{equation}
r_{i,t} \;=\; r_i^{0} \exp\!\Big( \rho_i^{SST}\, (SST_{t-1} - \overline{SST}) \;+\; \rho_i^{CHL}\, (\log CHL_{t-1} - \overline{\log CHL}) \Big).
\label{eq:stress-shifter}
\end{equation}

The biological parameters $(r_i^{0}, K_i)$ are held at the centres of the
stock-specific priors elicited from the official IFOP and SPRFMO
single-species assessments (anchoveta: $r_i^{0} = 0.6$,
$K_i = 2{,}200$~kt; sardina común: $r_i^{0} = 0.9$,
$K_i = 3{,}000$~kt; jack mackerel: $r_i^{0} = 0.35$,
$K_i = 8{,}000$~kt). Catches $C_{i,t}$ are observed and identical to
those used in the structural likelihood. The shifters
$(\rho_i^{SST}, \rho_i^{CHL})$ are estimated by bounded least squares on
the box $[-3, 3]^2$, minimising the median absolute percent prediction
error,

\begin{equation*}
\text{MAPE}_i(\rho_i^{SST}, \rho_i^{CHL}) \;=\; \operatorname{median}_t \left| \frac{\hat B_{i,t} - B_{i,t}^{\text{obs}}}{B_{i,t}^{\text{obs}}} \right|.
\end{equation*}

We estimate four nested variants for each stock: a base case with
$\rho_i^{SST} = \rho_i^{CHL} = 0$, two univariate cases that activate
SST or log-CHL alone, and a joint case that activates both. The
variants are not nested in an econometric sense; the comparison is
purely descriptive of how much hindcast error each shifter can absorb.
We adopt a $20\%$ MAPE threshold as a conventional benchmark for
acceptable deterministic hindcast performance in the small-pelagic
literature; this threshold plays no role in the structural likelihood
and is used here solely to summarise the cross-variant comparison.

## Cross-variant fit results {#sec:appendix-stress-results}

Table \ref{tab:stress-mape} reports the median absolute percent error
of the deterministic hindcast for each stock and each variant.


*[R code chunk omitted]*


The headline finding is that no variant brings any of the three stocks
below the $20\%$ MAPE threshold. The two coastal-upwelling stocks
benefit from activating SST: anchoveta moves from a base error of
$95.9\%$ to $30.8\%$ once $\rho_i^{SST}$ is allowed to vary, and
sardina común from $98.5\%$ to $23.1\%$. The further activation of
log-CHL improves both stocks marginally---to $26.6\%$ and $20.5\%$,
respectively---but neither closes the threshold. Activating log-CHL on
its own delivers essentially no improvement, in line with the absence
of contemporaneous correlation between the two environmental forcings
(see below). Jack mackerel hindcast errors remain in the
$44$--$49\%$ range across all variants, with no shifter variant
distinguishably better than the base.

The bounded least-squares coefficients of the joint variant deliver an
internally coherent biological reading for the two coastal-upwelling
stocks. For anchoveta, both shifters carry negative point estimates of
similar magnitude ($\rho_{\text{anch}}^{SST} \approx -2.3$,
$\rho_{\text{anch}}^{CHL} \approx -2.3$), consistent with a stock whose
short-run productivity is depressed by both warming and high
chlorophyll-a anomalies. For sardina común, the SST shifter is also
negative ($\rho_{\text{sard}}^{SST} \approx -2.0$) but the log-CHL
shifter switches sign relative to anchoveta
($\rho_{\text{sard}}^{CHL} \approx +2.1$), consistent with the warm-water,
mesotrophic affinity that distinguishes sardina from anchoveta in the
Humboldt-Current biological literature. For jack mackerel, the SST
shifter is small and positive ($\rho_{\text{jurel}}^{SST} \approx +0.6$)
and the log-CHL shifter is pinned at the lower boundary of the
admissible box, $\rho_{\text{jurel}}^{CHL} = -3$; we interpret the
boundary solution as a failure of point identification rather than as
a finding of strong climate forcing. Figure \ref{fig:stress-traj}
displays the hindcast trajectories under each variant alongside the
observed series.

\begin{figure}[!htbp]
\centering
\includegraphics[width=0.95\textwidth]{../data/bio_params/qa/hindcast_sst_trajectories.png}
\caption{Deterministic Schaefer hindcast trajectories under each
shifter variant, by stock. Solid line: observed biomass; dashed lines:
hindcast under base (no shifter), $+$SST only, $+\log$CHL only, and
joint $+$SST$+\log$CHL specifications. The joint specification
delivers the lowest median absolute percent error for the two
coastal-upwelling stocks; jack mackerel is essentially insensitive to
the shifter activation. Biological parameters $(r_i^{0}, K_i)$ are
fixed at the centres of the official IFOP/SPRFMO priors.}
\label{fig:stress-traj}
\end{figure}

## Identifiability diagnostic {#sec:appendix-stress-diag}

Two independent diagnostics support the use of weakly informative priors
on $(\rho_i^{SST}, \rho_i^{CHL})$ in the structural model rather than a
direct maximum-likelihood treatment.

First, the two environmental forcings are statistically orthogonal over
the 2000--2024 sample. The Pearson correlation between annual
Centro-Sur SST and log-CHL anomalies is $r = 0.030$ (two-sided
$p = 0.888$, $N = 25$). Collinearity between regressors therefore plays
no role in the difficulty of identifying the shifters; a variance
inflation diagnostic on the joint specification of
Eq. \eqref{eq:stress-shifter} returns values close to one for both
covariates. The coexistence of an essentially zero linear correlation
between the regressors and the wide cross-variant gap between
hindcast errors must therefore reflect features of the
non-linear-recursive law of motion in
Eq. \eqref{eq:stress-law}, not features of the design matrix.

Second, the joint MLE for jack mackerel binds at the lower boundary of
the admissible box. Across the 2000--2024 sample the climate
sensitivity of the Centro-Sur stock cannot be resolved within a
deterministic single-species hindcast: catches and the seven
non-surveyed years dominate the trajectory and the climate signal is
not separately identifiable from process and observation noise
absorbed into the residual. This pattern recurs in the initial fit of
the structural state-space specification reported in
Section \ref{identification}, where the marginal posterior of
$(\rho_{\text{jurel}}^{SST}, \rho_{\text{jurel}}^{CHL})$ tracks the
prior with no information added by the data. The structural model is
therefore the natural setting for jack mackerel: the absence of
information is correctly reported as a wide marginal posterior, rather
than as a boundary point estimate that a maximum-likelihood algorithm
would deliver. For the two coastal stocks, the joint MLE returns
interior solutions but with standard errors that are not separately
informative without an explicit accounting of process and observation
noise; the Bayesian state-space specification with priors elicited
from this hindcast addresses both limitations within a single
inferential framework.

## Translation to Bayesian priors {#sec:appendix-stress-priors}

The priors on $(\rho_i^{SST}, \rho_i^{CHL})$ used in the state-space
likelihood of Section \ref{sec:stock-dynamics} are reported in
Table \ref{tab:stress-priors}. For each coastal stock, the prior centre
is taken from the joint MLE of Section \ref{sec:appendix-stress-results},
rounded to one decimal place; for jack mackerel, where the joint MLE
binds at the boundary, the prior is centred at zero and is
deliberately uninformative. All priors are independent normal
densities with unit standard deviation, which is wide enough to allow
the structural likelihood to update the centre by more than one full
unit of semi-elasticity in either direction within a single posterior
standard deviation. We do not impose hierarchical pooling across
stocks: the sign reversal of $\rho_i^{CHL}$ between anchoveta and
sardina común is biologically interpretable and would be erased by a
pooled prior with a common hyper-mean.


*[R code chunk omitted]*


The interpretation of the resulting posterior is straightforward. For
the two coastal stocks, a posterior centred close to the prior centre
with a posterior standard deviation appreciably below one is evidence
that the structural state-space likelihood confirms the reduced-form
hindcast point estimate; a posterior shifted by more than one prior
standard deviation indicates that the structural model has extracted
information that the deterministic hindcast misses, most plausibly by
disentangling process noise from observation noise. For jack mackerel,
a posterior that essentially reproduces the prior is the correct
report of an absence of identifying information at the Centro-Sur
scale, as discussed in Section \ref{identification}.
<!-- ====== end inlined: paper1/sections/appendix_stress_tests.Rmd ====== -->



<!-- ====== inlined: paper1/sections/appendix_predictive_diagnostics.Rmd ====== -->

# Predictive diagnostics {#appendix-predictive}

This appendix reports two out-of-sample diagnostics for the three nested
state-space specifications (T4b-ind, T4b-omega, T4b-full). The two
criteria answer different questions and are included precisely because
they do not always agree:

- **PSIS-LOO** measures how well each specification *describes* the observed
  2000--2024 biomass series after penalising for the model's effective
  dimensionality. It is informative for the in-sample identification
  reported in Section \ref{identification}, because a specification that
  misses systematic variation will be penalised.
- **PSIS-LFO** at the one-year horizon measures the true forecasting
  accuracy on withheld future observations. It is informative for whether
  the identified shifters translate into tangible *next-year* predictive
  gains over a climate-free baseline.

Because the paper uses the estimated shifters for long-run comparative
statics under CMIP6 regimes, rather than for near-term forecasting, it is
LOO that carries the primary identification-supporting role; LFO is
reported as an honesty check against the possibility that the shifters
are simply fitting idiosyncratic in-sample noise.

## PSIS-LOO cross-validation

We compute Pareto-smoothed importance sampling leave-one-out
cross-validation [@Vehtari2017-qe] with moment matching applied to
observations whose Pareto-$\hat{k}$ diagnostic exceeded 0.7. Results
are summarised in Table \ref{tab:loo-appendix}.


*[R code chunk omitted]*


The full specification attains the highest predictive density by a wide
margin, outperforming T4b-omega by
$\Delta\widehat{\text{ELPD}}_{\text{LOO}} = 18.02$ (SE $5.59$) and the
environment-free T4b-ind by
$\Delta\widehat{\text{ELPD}}_{\text{LOO}} = 14.59$ (SE $4.93$). Both gaps
exceed three standard errors. Notably, T4b-omega (covariance-rich but
climate-free) underperforms T4b-ind: introducing a residual cross-stock
correlation matrix without climate shifters is penalised by LOO. The
interpretation consistent with the identification results of
Section \ref{identification} is that the cross-stock residual correlation
captured by T4b-omega is a statistical footprint of shared climate
forcing rather than evidence of direct biological interaction; once SST
and CHL enter the growth equation explicitly (T4b-full), the marginal
value of $\Omega$ collapses.

A stock-by-stock decomposition (Figure \ref{fig:loo-pareto-k}) confirms
that the LOO gains of T4b-full are concentrated in the two coastal
pelagics: per-stock ELPD improves by $+4.68$ for anchoveta and $+9.12$
for sardina relative to T4b-ind, whereas the three specifications are
statistically indistinguishable for jack mackerel. The effective number
of parameters $\hat{p}_{\text{loo}} \approx 58$--$65$ is large relative
to $N = 68$, as expected for a state-space model with one latent state
per observation-year; this is similar across the three specifications
and therefore does not confound the pairwise comparison, but it does
motivate the additional forecasting test of Section B.2.

\begin{figure}[!htbp]
\centering
\includegraphics[width=0.80\textwidth]{../figs/t4b/loo_t4b_pareto_k.png}
\caption{Per-observation Pareto-$\hat{k}$ values after moment matching,
by model and stock. Dashed line: $\hat{k} = 0.5$; solid line: reliability
threshold $\hat{k} = 0.7$. Crosses denote censored jack-mackerel
observations.}
\label{fig:loo-pareto-k}
\end{figure}

## PSIS-LFO at one-year horizon

The leave-future-out diagnostic refits each specification on data through
year $t_{\text{cut}}$ and evaluates the log predictive density of the
biomass observations at $t_{\text{cut}} + 1$. We use five origin points,
$t_{\text{cut}} \in \{2011, 2014, 2017, 2020, 2022\}$, spanning the
second half of the estimation window. One-step-ahead marginal predictive
densities are obtained in closed form from the posterior draws of each
truncated fit, applying the log-space Schaefer step of the model and the
marginal predictive variance $\sigma_{\text{proc}}^2 + \sigma_{\text{obs}}^2$
stock by stock. For the two censored jack-mackerel targets (2012 and 2015)
the predictive contribution is the corresponding log-CDF tail term.
Table \ref{tab:lfo-appendix} reports the sum of one-step ELPD across the
five origins and three stocks (14 evaluation points per model, of which
two are censored).


*[R code chunk omitted]*


In sharp contrast to the LOO ranking, the three specifications are
statistically indistinguishable in LFO: the spread between the best and
worst model is only $1.36$ ELPD units over 14 target points (mean
$0.10$ per target). Restricting attention to the 12 uncensored targets---
that is, excluding the two jack-mackerel censored years whose predictive
contribution is dominated by a common log-CDF tail term---the differences
shrink further, to less than $0.3$ ELPD per model pair. Figure
\ref{fig:lfo-elpd-path} displays the per-target trajectory of the one-step
ELPD by stock.

\begin{figure}[!htbp]
\centering
\includegraphics[width=0.80\textwidth]{../figs/t4b/lfo_t4b_elpd_path.png}
\caption{One-step-ahead predictive log density by target year and stock,
across the three state-space specifications. Dashed line at $\text{ELPD}=0$
marks the threshold above which the model predicts the withheld observation
better than an uninformative uniform density over a one-log-unit interval.}
\label{fig:lfo-elpd-path}
\end{figure}

The LOO-LFO divergence is not a contradiction but a feature of the
research design. As noted in Section \ref{identification}, the historical
SST anomaly has standard deviation
$\hat{\sigma}_{SST} = 0.26\,^{\circ}\text{C}$, small relative to the
process-noise standard deviation
$\hat{\sigma}_{\text{proc}} \in \{0.17, 0.23, 1.22\}$ across the three
stocks. Year-to-year climate innovations therefore contribute little to
a one-year-ahead nowcast, even when the structural coupling between
climate and biological productivity is strong. The same coupling
accumulates over decadal horizons, which is the scale at which the
paper's projections operate and the scale at which the identified
$\rho_i$ are economically consequential. Stated differently, LOO
confirms that T4b-full captures systematic structure that the simpler
specifications miss (because it must explain observed 2000--2024
dynamics), while LFO confirms that the added structure is not an
artefact of overfitting to short-run noise (because it yields no
one-year advantage). The two diagnostics jointly support the structural
interpretation of the shifters adopted in the main text.
<!-- ====== end inlined: paper1/sections/appendix_predictive_diagnostics.Rmd ====== -->



<!-- ====== inlined: paper1/sections/appendix_posterior_diagnostics.Rmd ====== -->

# Posterior-predictive checks {#appendix-posterior}

This appendix reports posterior-predictive diagnostics of the T4b-full
state-space specification that is adopted as the primary object of
interpretation in Section \ref{identification}. Two checks are shown:
(i) a stock-by-stock comparison of the smoothed latent biomass against
the observed survey-based estimates, and (ii) the associated year-level
residuals. The goal is to verify that the climate-augmented
specification reproduces the historical trajectory of each stock
without systematic misfit in the sign, timing, or amplitude of
fluctuations, and that the year-level residuals contain no detectable
autocorrelation that would undermine the log-normal independence
assumption embedded in the measurement equation (\ref{eq:obs}).

## Smoothed biomass versus observed SSB

Figure \ref{fig:ppc-smooth-vs-obs} overlays the posterior median and the
90\% credible band of the smoothed latent biomass $B_{i,t}$ against the
official survey-based observations of spawning stock biomass for each of
the three stocks. The smoothed band has a median width of approximately
20\% of the corresponding posterior mean, tightening over years with
direct IFOP or SPRFMO observation and widening across the seven jack
mackerel Centro-Sur years for which no survey point estimate is
available (the latent biomass in those years is identified dynamically
through the Schaefer transition equation together with the two censored
observations in 2012 and 2015; see Section \ref{sec:stock-dynamics}).

\begin{figure}[!htbp]
\centering
\includegraphics[width=0.95\textwidth]{../figs/t4b/t4b_full_smooth_vs_obs.png}
\caption{Smoothed latent biomass $B_{i,t}$ of the T4b-full specification
against the official survey-based estimates. Solid line: posterior
median; shaded band: 90\% credible interval. Points: observed SSB from
IFOP (anchoveta, sardina común) and the IFOP hydroacoustic assessment
(jack mackerel Centro-Sur). Crosses denote the two censored jack
mackerel observations (2012, 2015) that enter the likelihood at the
assessment's lower detection limit.}
\label{fig:ppc-smooth-vs-obs}
\end{figure}

## Year-level residuals

Figure \ref{fig:ppc-residuals} shows the standardised residuals
$(\log B_{i,t}^{\text{obs}} - \log \hat{B}_{i,t})/\hat{\sigma}_{\text{obs},i}$
by stock and year. The three residual series are roughly centred at
zero, with no visible trend and no systematic sign alignment across
stocks. The sample first-order autocorrelation is below 0.2 in absolute
value for all three stocks (anchoveta CS, sardina común CS, jack
mackerel CS), consistent with the log-normal measurement-error
structure of the model. The corresponding observation-error standard
deviations $\hat{\sigma}_{\text{obs},i}$ are of the same order as the
survey coefficients of variation reported by IFOP and SPRFMO
($\approx 15$--25\% across species), supporting the calibration of the
priors adopted in Section \ref{sec:stock-dynamics}.

\begin{figure}[!htbp]
\centering
\includegraphics[width=0.95\textwidth]{../figs/t4b/t4b_full_residuals.png}
\caption{Standardised year-level residuals of the T4b-full specification
by stock. Horizontal line at zero. The first-order autocorrelation is
below 0.2 in absolute value for all three stocks.}
\label{fig:ppc-residuals}
\end{figure}

Markov-chain convergence diagnostics for all top-level parameters
($\hat{R}$ and effective sample sizes) are reported separately in
Appendix \ref{appendix-convergence}.
           
<!-- ====== end inlined: paper1/sections/appendix_posterior_diagnostics.Rmd ====== -->



<!-- ====== inlined: paper1/sections/appendix_convergence_diagnostics.Rmd ====== -->

# Markov-chain convergence diagnostics {#appendix-convergence}

This appendix reports the mixing and effective-sample-size diagnostics
of the four Hamiltonian Monte Carlo chains used to obtain the posterior
of the T4b-full specification reported in
Section \ref{identification}. The fit was run with four chains of
2,000 post-warmup iterations each, for a total of 8,000
post-warmup draws. The non-centred parameterisation of $(r_i^{0}, K_i, B_{i,0})$
combined with a Lewandowski--Kurowicka--Joe prior on the cross-stock
correlation matrix $\Omega$ delivers chains that mix well across all
top-level quantities; in particular, the two parameters most prone to
non-identification in this class of state-space models---the process
noise $\sigma_{\text{proc},i}$ and the observation noise
$\sigma_{\text{obs},i}$---both satisfy the standard convergence
thresholds. We report the within-group worst case (maximum split-$\hat{R}$
and minimum bulk- and tail-ESS) for each family of top-level parameters
in Table \ref{tab:convergence}.


*[R code chunk omitted]*


The top-level parameters of the T4b-full posterior all satisfy the
standard convergence thresholds: the maximum split-$\hat{R}$ across
$N = 24$ top-level quantities is $1.009$, attained for the jack-mackerel
observation noise $\sigma_{\text{obs},3}$, and the minimum bulk- and
tail-ESS are $1{,}370$ and $936$ respectively, again attained at
$\sigma_{\text{obs},i}$ where the observation likelihood interacts with
the seven non-surveyed years of the jack-mackerel series and with the
two left-censored observations of 2012 and 2015. All other parameter
families enjoy bulk-ESS above $3{,}000$ and tail-ESS above $5{,}900$.
The three climate-shifter components of primary interest---
$(\rho_i^{SST}, \rho_i^{CHL})$---attain $\hat{R} \leq 1.001$ and bulk-ESS
above $8{,}300$ across all stocks, so the identification results of
Section \ref{identification} are not driven by under-mixed chains.

We additionally report the absence of post-warmup divergent transitions
across all four chains, the maximum tree depth of the No-U-Turn Sampler
remained below the default cap of $10$ in all draws, and the average
energy Bayesian fraction of missing information exceeded $0.5$ on every
chain---each of these auxiliary diagnostics is available in the
underlying Stan fit object archived at
\texttt{data/outputs/t4b/t4b\_full\_fit.rds}. Taken together with
Table \ref{tab:convergence}, the diagnostic battery supports the
posterior summaries reported in the main text.
<!-- ====== end inlined: paper1/sections/appendix_convergence_diagnostics.Rmd ====== -->




<!-- ====== inlined: paper1/sections/appendix_spatial_jurel.Rmd ====== -->

# Spatial robustness of the jack mackerel non-identification result {#appendix-spatial}

The non-identification of $(\rho_{\text{jurel}}^{SST}, \rho_{\text{jurel}}^{CHL})$
reported in Section \ref{identification} admits two readings that are
observationally equivalent in the main specification. Under the first
reading, jack mackerel productivity at the Centro-Sur scale is not coupled
to Chilean coastal-upwelling forcing, so the data carry no information
about the shifters and the posterior reproduces the prior. Under the
second reading, the species' productivity *is* coupled to environmental
forcing, but at a spatial scale broader than the Centro-Sur EEZ used to
construct the SST and log-CHL covariates of the main specification; the
forcings averaged over the EEZ then act as a noisy proxy for the
relevant signal and the shifter posteriors are diluted accordingly.
Anchoveta and sardina común are residents of the Centro-Sur upwelling
system and the Centro-Sur aggregation is biologically natural for them;
jack mackerel, by contrast, has a transboundary Southeast Pacific stock
structure and undertakes seasonal migrations into subtropical waters
beyond the EEZ, so the second reading cannot be ruled out without a
direct test. This appendix supplies that test.

## Identification power and the magnitude of the jack mackerel non-result {#sec:appendix-spatial-power}

A natural prior question, raised by the close-to-prior posteriors of
$(\rho_{\text{jurel}}^{SST}, \rho_{\text{jurel}}^{CHL})$ in the main
specification, is whether the result reflects an absent climate signal
or a sample with insufficient power to recover one. We answer this by
deriving the minimum-detectable shifter magnitude implied by the
sample size, the residual noise of the state-space model, and the
sample dispersion of the candidate climate covariates. Linearising the
Schaefer transition equation of Section \ref{sec:stock-dynamics} in
log-differences gives, for each stock $i$,

\begin{equation}
\log B_{i,t+1} - \log B_{i,t}
\;\approx\;
\alpha_{i} - \beta_{i}\,(B_{i,t}/K_i)
\;+\; \rho_{i}^{X}\, X_{t-1} \;+\; \varepsilon_{i,t},
\qquad
\varepsilon_{i,t} \sim \mathcal{N}\!\big(0,\, \sigma_{i,\text{resid}}^{2}\big),
\label{eq:appE-power-linapprox}
\end{equation}

where $X$ is a candidate shifter and
$\sigma_{i,\text{resid}} = \sqrt{\sigma_{i,\text{proc}}^{2} + 2\,\sigma_{i,\text{obs}}^{2}}$
is the state-space envelope on the differenced log-biomass. With the
posterior medians of $\sigma_{\text{proc}}$ and $\sigma_{\text{obs}}$
reported in the main specification, $\sigma_{i,\text{resid}}$ takes the
values $0.28$ (anchoveta), $0.25$ (sardine), and $1.28$ (jack mackerel),
the latter being approximately $4.6$ times the average of the two
coastal stocks. Under (\ref{eq:appE-power-linapprox}) the OLS-equivalent
standard error of $\rho_{i}^{X}$ on a sample of $N=24$ lag-one
observations satisfies
$\mathrm{SE}(\hat{\rho}_{i}^{X})
\approx \sigma_{i,\text{resid}} \,/\, \big[\mathrm{sd}(X)\sqrt{N - K}\big]$,
with $K=3$ regressors. The minimum shifter magnitude detectable at
$80\%$ power for a two-sided $90\%$ credible interval is then

\begin{equation}
|\rho_{i}^{X}|_{\min}
\;=\; \big(t_{0.95,\,N-K} + z_{0.80}\big)\,\mathrm{SE}(\hat{\rho}_{i}^{X})
\;\approx\; 2.56\,\mathrm{SE}(\hat{\rho}_{i}^{X}),
\label{eq:appE-rho-min}
\end{equation}

a quantity that any fixed-effect-style identification of $\rho$ must
exceed in absolute value to deliver a credible interval that excludes
zero with probability at least $0.80$ under the data-generating process
implied by the posterior of the main fit. Table \ref{tab:appE-power}
reports $|\rho|_{\min}$ for the three stocks and three candidate
shifters: SST and $\log$~CHL aggregated over the Centro-Sur EEZ
($\mathcal{D}_1$ in the spatial-robustness exercise below), and the
basin-scale ENSO Niño 3.4 index used in
Section \ref{sec:appendix-spatial-enso}.

\begin{table}[t]
\centering
\caption{Minimum shifter magnitude $|\rho|_{\min}$ detectable at
$80\%$ power on the $2000$--$2024$ sample, by stock and candidate
covariate. $\sigma_{\text{resid}}$ is the state-space envelope
$\sqrt{\sigma_{\text{proc}}^{2} + 2\sigma_{\text{obs}}^{2}}$ evaluated
at the posterior medians of the main specification. The implied
posterior-to-prior standard-deviation ratio in the third-to-last column
combines the OLS standard error with the prior $\rho \sim
\mathcal{N}(0, 0.5)$ adopted for the ENSO refit; the last column
combines it with the wider prior $\mathcal{N}(0, 1.5)$ used for the
SST/CHL shifters in the main specification. A ratio at or below $0.70$
is the informal threshold for material identification.}
\label{tab:appE-power}
\begin{tabular}{llccccc}
\toprule
Stock & Shifter & $\mathrm{sd}(X)$ & $\sigma_{\text{resid}}$ &
$|\rho|_{\min}$ & $\sigma_{\text{post}}/\sigma_{\text{prior}}$ &
$\sigma_{\text{post}}/\sigma_{\text{prior}}$ \\
      &         &                  &                          &
              & at $\mathcal{N}(0,0.5)$ & at $\mathcal{N}(0,1.5)$ \\
\midrule
Anchoveta     & SST $\mathcal{D}_1$       & $0.257$ & $0.277$ & $0.60$ & $0.43$ & $0.15$ \\
Anchoveta     & $\log$ CHL $\mathcal{D}_1$ & $0.098$ & $0.277$ & $1.58$ & $0.78$ & $0.38$ \\
Anchoveta     & ENSO Niño 3.4              & $0.549$ & $0.277$ & $0.28$ & $0.22$ & $0.07$ \\
\addlinespace[2pt]
Sardine       & SST $\mathcal{D}_1$       & $0.257$ & $0.247$ & $0.54$ & $0.39$ & $0.14$ \\
Sardine       & $\log$ CHL $\mathcal{D}_1$ & $0.098$ & $0.247$ & $1.41$ & $0.74$ & $0.34$ \\
Sardine       & ENSO Niño 3.4              & $0.549$ & $0.247$ & $0.25$ & $0.19$ & $0.07$ \\
\addlinespace[2pt]
Jack mackerel & SST $\mathcal{D}_1$       & $0.257$ & $1.277$ & $\mathbf{2.78}$ & $\mathbf{0.91}$ & $0.59$ \\
Jack mackerel & $\log$ CHL $\mathcal{D}_1$ & $0.098$ & $1.277$ & $\mathbf{7.28}$ & $\mathbf{0.98}$ & $0.88$ \\
Jack mackerel & ENSO Niño 3.4              & $0.549$ & $1.277$ & $\mathbf{1.30}$ & $\mathbf{0.71}$ & $0.32$ \\
\bottomrule
\end{tabular}
\end{table}

The substantive readings of the table are three. First, jack mackerel's
process-noise envelope is approximately five times that of the two
coastal stocks. Whatever process is generating the larger residual
variance for jack mackerel---transboundary recruitment pulses, episodic
non-detections, range shifts beyond the EEZ---it directly inflates the
magnitude of any climate semi-elasticity that the data could in
principle resolve. Second, with that residual envelope and the
$0.26\,^{\circ}\text{C}$ in-sample dispersion of the Centro-Sur SST
covariate, the minimum SST semi-elasticity detectable for jack mackerel
at $80\%$ power on a $24$-year sample is $|\rho|_{\min} \approx 2.78$,
which corresponds to a multiplicative effect on $r$ of approximately
$\exp(2.78 \cdot 0.26) \approx 2.1$ for a one-standard-deviation
positive SST anomaly---outside any range that the bioclimatic
literature on the species would deem structurally plausible. The
posterior-to-prior ratio of $0.91$ for SST under the wide
$\mathcal{N}(0, 1.5)$ prior of the main specification, and $0.98$ for
$\log$~CHL, therefore reflect the *mechanical* implication of a thick
process-noise envelope and a thin in-sample dispersion of the
covariates, rather than evidence of an absent climate signal. Third,
the basin-scale ENSO Niño 3.4 index has approximately twice the
in-sample dispersion of the Centro-Sur SST covariate
($\mathrm{sd} = 0.55\,^{\circ}\text{C}$ versus $0.26$), which mechanically
lowers $|\rho|_{\min}$ for jack mackerel from $2.78$ on Centro-Sur SST
to $1.30$ on Niño 3.4, and lowers the implied
$\sigma_{\text{post}}/\sigma_{\text{prior}}$ from $0.91$ to $0.71$ under
a common $\mathcal{N}(0, 0.5)$ prior. The basin-scale shifter sits
deliberately at the threshold for material identification: if the
true elasticity of jack mackerel productivity on ENSO Niño 3.4 is of
moderate magnitude---in the range $1$ to $1.5$ that the qualitative
literature on transboundary forcing would suggest---a sample of $N=24$
years on the available biomass record has approximately $80\%$ power to
recover it. The refit of Section \ref{sec:appendix-spatial-enso} below
implements that test directly.

The OLS-equivalent calculation of (\ref{eq:appE-rho-min}) is a
\emph{lower bound} on the variance of the full state-space posterior
rather than a point estimate, because it ignores integration over the
structural priors on $(r^{0}, K)$, the between-stock covariance
$\boldsymbol{\Omega}$, and the censored observation contribution to
the jack mackerel likelihood. Empirically, the analytic ratios
reported in Table \ref{tab:appE-power} understate the corresponding
state-space ratios by approximately $5$--$15\,$pp for the coastal
shifters of anchoveta and sardine, where the data move the posterior
substantially. For jack mackerel the divergence is larger: the
$\sigma_{\text{post}}/\sigma_{\text{prior}}$ for $\rho_{\text{jur}}^{ENSO}$
under the basin-scale refit of Section \ref{sec:appendix-spatial-enso}
is $0.979$ (lag-one) and $1.014$ (lag-two sensitivity), against the
analytic $0.71$ of Table \ref{tab:appE-power}. The gap reflects the
flat-likelihood regime: when the data carry essentially no
information on the shifter, the posterior is close to the prior,
the structural-prior integration is the dominant remaining source of
variance, and the OLS-equivalent surrogate (which conditions on the
remaining structural parameters) is most optimistic. The qualitative
\emph{ordering} across rows of Table \ref{tab:appE-power} is preserved
under the full state-space refit; the absolute magnitude of $|\rho|_{\min}$
on jack mackerel should be read as a lower bound and the substantive
implication---that any plausible structural elasticity for jack mackerel
on Centro-Sur SST or basin-scale ENSO is below the threshold for
detection on the available record---is reinforced rather than weakened.

## Spatial domains and environmental aggregation {#sec:appendix-spatial-domains}

We construct three nested spatial domains for the aggregation of SST and
log-CHL anomalies, ordered from the Centro-Sur EEZ used in the main
specification outwards to the regional Southeast Pacific:

\begin{align}
\mathcal{D}_1 &= \{\text{lat} \in [-42^{\circ}, -32^{\circ}],\;
                  \text{lon} \in [-75^{\circ}, -70^{\circ}]\}
                  &&\text{(Centro-Sur EEZ; main specification)} \nonumber \\
\mathcal{D}_2 &= \{\text{lat} \in [-41^{\circ}, -32^{\circ}],\;
                  \text{lon} \in [-85^{\circ}, -65^{\circ}]\}
                  &&\text{(offshore-extended)} \nonumber \\
\mathcal{D}_3 &= \{\text{lat} \in [-45^{\circ}, -20^{\circ}],\;
                  \text{lon} \in [-90^{\circ}, -65^{\circ}]\}
                  &&\text{(regional Southeast Pacific)} \nonumber
\end{align}

The third domain spans the geographic range over which Chilean
hydroacoustic surveys and the SPRFMO regional assessment locate the
adult jack mackerel stock; the second domain extends $\mathcal{D}_1$
westward to capture the offshore migration band documented in the
SPRFMO biological literature. Both Copernicus baselines are
re-downloaded from `cmems_mod_glo_phy_my_0.083deg_P1M-m` (GLORYS12
reanalysis, surface depth slice $0.49$--$1.55$~m) and
`cmems_obs-oc_glo_bgc-plankton_my_l4-multi-4km_P1M` (Ocean Colour
multi-sensor, L4) over the bounding box
$\text{lon} \in [-90^{\circ}, -65^{\circ}],\;
 \text{lat} \in [-56^{\circ}, -20^{\circ}]$, covering all three
domains. Within each domain $\mathcal{D}_d$, monthly fields are
aggregated to a single monthly time series by cosine-of-latitude area
weighting,

\begin{equation}
\overline{x}_{d,m} \;=\;
\frac{\sum_{(i,j) \in \mathcal{D}_d} \cos(\phi_j)\, x_{m,i,j}}
     {\sum_{(i,j) \in \mathcal{D}_d} \cos(\phi_j)},
\label{eq:appE-spatial-mean}
\end{equation}

with $\phi_j$ the latitude of the $j$-th grid cell and the sum over
non-missing cells. Annual SST is the unweighted average of the twelve
monthly weighted means; annual log-CHL is the natural logarithm of the
unweighted average of the twelve monthly weighted CHL means. Each
annual series is centred by its $2000$--$2024$ within-domain mean,
matching the centring convention of the main specification of Section
\ref{sec:stock-dynamics}. The three domains share the same temporal
support and centring window, so cross-domain differences in the
shifter posteriors are attributable solely to the spatial extent of
the aggregation.

The three SST series are highly but imperfectly correlated across the
2000--2024 estimation window (Pearson $r = 0.77$ between $\mathcal{D}_1$
and $\mathcal{D}_2$, $r = 0.94$ between $\mathcal{D}_2$ and
$\mathcal{D}_3$, $r = 0.76$ between $\mathcal{D}_1$ and
$\mathcal{D}_3$); the imperfect correlation between $\mathcal{D}_1$
and the broader domains is consistent with the well-known dynamical
decoupling between the coastal-upwelling band and the open subtropical
ocean. Annual CHL series are more uniformly correlated across domains
($r$ between $0.80$ and $0.91$), reflecting the basin-scale ENSO
imprint on primary productivity. Annual mean SST rises monotonically
from $14.4\,^{\circ}\text{C}$ in $\mathcal{D}_1$ to
$17.0\,^{\circ}\text{C}$ in $\mathcal{D}_3$, and annual mean CHL falls
monotonically from $1.32$ to $0.26$~mg~m$^{-3}$, consistent with the
coastal--subtropical productivity gradient.

## Refit specification {#sec:appendix-spatial-spec}

We refit the full state-space specification of Section
\ref{sec:stock-dynamics} under a stock-specific environmental
forcing, in which the SST and log-CHL covariates are allowed to vary
across stocks rather than entering as a single shared series. Let
$\widetilde{SST}_{i,t}$ and $\widetilde{\log CHL}_{i,t}$ denote the
annual covariates faced by stock $i$ at time $t$. The shifter equation
of Section \ref{sec:stock-dynamics} generalises to

\begin{equation}
r_{i,t} \;=\; r_i^{0} \,
\exp\!\Big( \rho_i^{SST}\, \widetilde{SST}_{i,t-1}
        \;+\; \rho_i^{CHL}\, \widetilde{\log CHL}_{i,t-1} \Big),
\label{eq:appE-shifter}
\end{equation}

and reduces exactly to the main specification when
$\widetilde{SST}_{i,t} = SST_t$ and
$\widetilde{\log CHL}_{i,t} = \log CHL_t$ for all $i$. We exploit the
generalisation to refit the model three times, indexed by the spatial
domain $d \in \{1, 2, 3\}$ assigned to jack mackerel; in every refit
anchoveta and sardina común retain the Centro-Sur EEZ aggregation
($d = 1$), since this is the spatial scale that matches their
documented habitat:

\begin{equation}
\widetilde{SST}_{i,t}^{(d)} \;=\;
\begin{cases}
\overline{SST}_{1,t} & \text{if } i \in \{\text{anchoveta},\,\text{sardina}\}, \\
\overline{SST}_{d,t} & \text{if } i = \text{jack mackerel},
\end{cases}
\label{eq:appE-design}
\end{equation}

and analogously for $\widetilde{\log CHL}_{i,t}^{(d)}$. All other
elements of the likelihood---priors, biomass and catch series,
observation and process noise structure, multivariate residual
covariance $\Omega$---are held identical to the main specification.
Each refit is sampled with eight HMC chains of $2{,}000$ post-warmup
iterations at \texttt{adapt\_delta} $= 0.99$ and \texttt{max\_treedepth}
$= 14$, matching the main specification. The refit reduces to the
main specification when $d = 1$ up to small differences attributable
to the spatial averaging convention (the main specification uses an
unweighted spatial mean over the EEZ taken from a daily 0.083$^{\circ}$
GLORYS field; this appendix uses the cosine-weighted mean of the
monthly P1M-m product), which provides an internal consistency check
on the spatial-averaging pipeline.

## Posterior identification across domains {#sec:appendix-spatial-results}

Table \ref{tab:appE-sigma} reports the posterior-to-prior standard
deviation ratio of each shifter under each domain assignment for jack
mackerel, alongside the corresponding ratio in the main specification
of Section \ref{identification}. Figure \ref{fig:appE-forest} displays
the posterior means and 90\% credible intervals.


*[R code chunk omitted]*


\begin{figure}[!htbp]
\centering
\includegraphics[width=0.92\textwidth]{../figs/appendix_e_sigma_ratios.pdf}
\caption{Posterior means and 90\% credible intervals of the climate
shifters under each spatial domain assigned to jack mackerel.
Anchoveta (top row) and sardina común (middle row) retain the
Centro-Sur EEZ ($\mathcal{D}_1$) aggregation in every refit; only the
jack mackerel covariate (bottom row) varies across rows within each
panel. The bottom-row credible intervals are essentially indistinguishable
across $\mathcal{D}_1$, $\mathcal{D}_2$, and $\mathcal{D}_3$ and span
the prior $\mathcal{N}(0, 1)$ on both shifters; the top and middle rows
are visually identical, confirming that the change in jack mackerel's
covariate has no material spillover into the anchoveta or sardina
posteriors via the residual covariance $\Omega$.}
\label{fig:appE-forest}
\end{figure}

Three findings emerge. First, the posterior-to-prior standard
deviation ratio for both jack mackerel shifters lies between $0.998$
and $1.014$ across $\mathcal{D}_1$, $\mathcal{D}_2$, and
$\mathcal{D}_3$, indistinguishable from unity in every domain.
Posterior means lie within $0.45$ standard deviations of the prior
centre and the 90\% credible intervals span the prior support
symmetrically: the regional Southeast Pacific aggregation
($\mathcal{D}_3$), which encompasses the geographic range of the
SPRFMO-managed adult stock, fails to inform the shifter posteriors no
less than the Centro-Sur EEZ aggregation. The non-identification of
jack mackerel's climate sensitivity at the Centro-Sur scale is
therefore not an artefact of mismatched spatial aggregation; it is a
structural feature of the available data on the resource as managed.

Second, the anchoveta and sardina común shifter posteriors are stable
across the three refits. The posterior means move by less than
$0.03$~standard deviations of the posterior across all four shifters,
well below the natural Monte Carlo noise threshold of $0.5$ posterior
standard deviations. This confirms that the multivariate coupling
between the three stocks via the residual covariance $\Omega$ does not
transmit the change in jack mackerel's covariate into the
identification of the coastal-upwelling shifters; the matrix structure
of Eq. \eqref{eq:appE-design} succeeds in isolating the spatial
robustness test to jack mackerel without contaminating the rest of the
posterior.

Third, the consistency check between the $\mathcal{D}_1$ refit of this
appendix and the main specification of Section \ref{identification}
falls within tolerance. The posterior mean of
$\rho_{\text{anch}}^{CHL}$ moves from $-3.64$ in the main
specification to $-3.05$ in the $\mathcal{D}_1$ refit, and that of
$\rho_{\text{anch}}^{SST}$ from $-1.06$ to $-0.77$; the corresponding
movements for sardina común are smaller ($+2.17$ to $+2.10$ for CHL,
$-2.75$ to $-2.67$ for SST). These differences reflect the change in
spatial-averaging convention---unweighted daily EEZ mean from the
operational reanalysis cache versus cosine-weighted monthly P1M-m
mean---rather than any model change, and they preserve the sign and
the qualitative magnitude of all six identified shifters. Jack mackerel
ratios coincide to within Monte Carlo noise across the two pipelines,
as expected of a non-identified parameter.

## Dual-source extension: Centro-Sur and Northern Chilean acoustic series {#sec:appendix-spatial-dual}

The spatial robustness test of Sections \ref{sec:appendix-spatial-spec}
and \ref{sec:appendix-spatial-results} varies the geographic extent of
the environmental covariate while preserving a single biomass series
(the Centro-Sur acoustic record). A complementary test instead
preserves a single environmental specification per region and adds a
second biomass series from the Northern Chilean hydroacoustic record
(RECLAS Norte, IFOP, $14$ observations $2010$--$2024$ excluding $2022$).
This extension exploits the high empirical correlation between the
Centro-Sur and Northern Chilean acoustic series over the seven
overlapping years with positive observations in both ($2010$--$2012$,
$2017$, $2020$--$2021$, $2023$): Pearson $r = 0.82$ on the raw scale
and $r = 0.88$ on the log scale, consistent with the two series
indexing partially overlapping ventures of a single biological
range-wide stock.

We extend the state-space of Eq. \eqref{eq:law-of-motion} with a
second jack mackerel state $B^{N}_{t}$ that evolves under
Schaefer dynamics with its own carrying capacity $K^{N}$, base
productivity $r_{\text{jurel}}^{0,N}$, and process noise
$\sigma^{N}_{\text{proc}}$, and which is forced by an environmental
series aggregated over a Northern Chilean EEZ domain
$\mathcal{D}_4 = \{\text{lat} \in [-30^{\circ}, -18^{\circ}],\;
\text{lon} \in [-75^{\circ}, -65^{\circ}]\}$. The climate shifters
$(\rho_{\text{jurel}}^{SST}, \rho_{\text{jurel}}^{CHL})$ are
constrained to be common across the two states, the empirical
identification assumption being that the climate elasticity of the
biological stock is uniform across its Chilean range while the
realised forcings differ by domain. Catch in the Northern state is
set to the IFOP-SERNAPESCA aggregate landings of jack mackerel from
regions XV (Arica-Parinacota), I (Tarapacá), II (Antofagasta), III
(Atacama) and IV (Coquimbo), which match the bounding box of
$\mathcal{D}_4$. The Centro-Sur priors for the Centro-Sur state are
identical to the main specification; priors for the Northern state's
biological parameters are calibrated to the median of the Northern
acoustic series with the same coefficients of variation as in the
Centro-Sur specification.

The cosine-weighted spatial means of SST and CHL over $\mathcal{D}_4$
correlate with the Centro-Sur EEZ ($\mathcal{D}_1$) at
$r = 0.67$ for SST and $r = 0.46$ for log-CHL across the $2000$--$2024$
window---substantially below the biomass correlation reported above and
than the SST/CHL correlations among $\mathcal{D}_1$, $\mathcal{D}_2$
and $\mathcal{D}_3$ in Section \ref{sec:appendix-spatial-domains}. The
two regional surface-forcing regimes are therefore modestly distinct,
which the model accommodates by allowing a separate environmental
input per state while constraining the elasticity to be common.

Under this extension the posterior-to-prior standard deviation ratio
for the jack mackerel shifters falls to $0.94$ for $\rho^{SST}$ and
$0.99$ for $\rho^{CHL}$, a marginal reduction relative to the
$0.998$--$1.014$ range of the spatial robustness refits of Table
\ref{tab:appE-sigma}, and well above the $0.7$ threshold below
which the posterior could be said to depart materially from the
prior. The eight HMC chains converge with no divergent transitions
and treedepth-satisfactory transitions; rank-normalised split $\hat{R}$
is below $1.01$ for the climate shifters, although a marginally
elevated $\hat{R} = 1.01$ for $\sigma^{N}_{\text{proc}}$ and a
sample-wide $E$-BFMI of $0.26$ (below the nominal threshold of
$0.30$) indicate that the Northern state has limited identifying
information beyond the prior, consistent with the modest sample size
of the Northern series ($N = 14$) and the shifter non-identification
itself. The biological parameters of the Northern state recover
plausible posterior means---$r^{0,N}_{\text{jurel}} = 0.42$ and
$K^{N}_{\text{jurel}} = 7{,}300$~kt---well within the Centro-Sur
posterior support, providing weak independent corroboration of the
range-wide stock structure assumption.

A separate exploratory attempt to incorporate the SPRFMO regional
assessment series for jack mackerel (OROP-PS, available 1970--2024
covering Chile, Peru and Ecuador together with the adjacent
high-seas area) under the same common-elasticity constraint produced
incompatible likelihood signals between the SPRFMO aggregate and the
Centro-Sur series, with multimodal posterior support and
unsatisfactory chain mixing. This is consistent with the broader
geographic span of the OROP-PS assessment encompassing biological
sub-populations whose dynamics are not co-determined by Chilean
coastal forcing; we therefore retain the dual-source extension at
the Chilean spatial scale and report the OROP-PS attempt only as a
methodological note in the Discussion.

## Basin-scale shifter test: the ENSO Niño 3.4 index {#sec:appendix-spatial-enso}

The Centro-Sur, offshore-extended, and regional Southeast Pacific
domains of Section \ref{sec:appendix-spatial-results} all aggregate
*coastal-band* environmental fields. None probes the basin-scale
forcing regime that the existing biological literature on jack
mackerel has identified as the natural climatic driver: ENSO-mediated
modulation of Pacific stratification, location-choice behaviour, and
recruitment phenology
(@Arcos2001-jq; @Pena-Torres2017-gn).
A direct test on a basin-scale shifter is therefore a substantive
robustness exercise for the non-identification result, and one that
the spatial-extension refits of Section \ref{sec:appendix-spatial-results}
do not deliver because each $\mathcal{D}_d$ averages local SST and
$\log$~CHL anomalies whose variance is too small to identify a
plausible elasticity for jack mackerel (Table \ref{tab:appE-power}).

We construct the ENSO Niño 3.4 index as the annual mean of monthly
ERSSTv5 sea-surface temperature averaged over the canonical
$5^{\circ}$N--$5^{\circ}$S, $170^{\circ}$W--$120^{\circ}$W box
(NOAA Climate Prediction Center, file `sstoi.indices`,
ERSSTv5-derived). Following the centring convention of the main
specification, the annual series is centred on its $2000$--$2024$
sample mean to deliver an anomaly $\widetilde{\text{ENSO}}_{t}$ in
$^{\circ}$C, comparable in scale to the SST $\mathcal{D}_1$ shifter
of the main specification. Two features of the historical series are
relevant for what follows. First, the in-sample dispersion is
$\mathrm{sd}(\widetilde{\text{ENSO}}) = 0.55\,^{\circ}$C, approximately
twice that of the Centro-Sur SST shifter
($0.26\,^{\circ}$C); the larger dispersion is mechanical---basin
averages sample longer-wavelength variability than coastal
upwelling-band averages---and translates directly into a smaller
minimum-detectable elasticity (Table \ref{tab:appE-power}). Second,
the contemporaneous correlation between $\widetilde{\text{ENSO}}$ and
the Centro-Sur SST shifter is $0.37$, while the lag-one
correlation---the relevant moment for the recursive Schaefer
specification---is $0.09$. The basin-scale and coastal shifters are
therefore close to orthogonal at the lag exploited by the dynamic
identification, eliminating any concern that the basin-scale test
is mechanically picking up the coastal anomaly.

We refit the state-space model under a stock-specific covariate
structure that *replaces* the Centro-Sur shifters for jack mackerel
with the basin-scale ENSO index, while preserving the coastal
shifters for anchoveta and sardine:

\begin{align}
r_{\text{anch},t}  &= r_{\text{anch}}^{0}\,
  \exp\!\big( \rho_{\text{anch}}^{SST}\, \widetilde{SST}_{1,t-1}
            + \rho_{\text{anch}}^{CHL}\, \widetilde{\log CHL}_{1,t-1} \big),\nonumber \\
r_{\text{sard},t}  &= r_{\text{sard}}^{0}\,
  \exp\!\big( \rho_{\text{sard}}^{SST}\, \widetilde{SST}_{1,t-1}
            + \rho_{\text{sard}}^{CHL}\, \widetilde{\log CHL}_{1,t-1} \big),\nonumber \\
r_{\text{jur},t}   &= r_{\text{jur}}^{0}\,
  \exp\!\big( \rho_{\text{jur}}^{ENSO}\, \widetilde{\text{ENSO}}_{t-1} \big).
  \label{eq:appE-enso-spec}
\end{align}

The replacement convention is implemented at the prior level: the
coefficients on Centro-Sur SST and $\log$~CHL for jack mackerel
receive a tight prior $\mathcal{N}(0, 0.01)$ that pins them to zero,
and the corresponding covariate columns are set to zero in the data
matrix as a second layer of insulation. The prior on
$\rho_{\text{jur}}^{ENSO}$ is set at $\mathcal{N}(0, 0.5)$,
deliberately tighter than the wide $\mathcal{N}(0, 1.5)$ on the
coastal shifters of the main specification: with
$\mathrm{sd}(\widetilde{\text{ENSO}}) = 0.55$, a prior elasticity at
the upper end of $\mathcal{N}(0, 0.5)$ implies a one-standard-deviation
multiplicative effect on $r$ of $\exp(0.5 \cdot 0.55) \approx 1.32$,
which spans the qualitative range that the basin-scale literature
documents and rules out the implausible far tails. The implied
identification threshold on the posterior-to-prior ratio is
$\sigma_{\text{post}}/\sigma_{\text{prior}} \le 0.70$, which the power
calculation of Section \ref{sec:appendix-spatial-power} places exactly
at the data-implied boundary for moderate elasticities. The remaining
priors and the sampler configuration (eight chains of $4{,}000$
post-warmup draws, $\mathrm{adapt\_delta} = 0.99$,
$\mathrm{max\_treedepth} = 14$) match the spatial-robustness refits
of Section \ref{sec:appendix-spatial-spec}.

The principal specification with lag-one ENSO Niño 3.4 forcing yields a
posterior median for $\rho_{\text{jur}}^{ENSO}$ of
$-0.022$ with $90\%$ credible interval
$[-0.81,\,0.80]$ and
posterior standard deviation $0.490$, implying
$\sigma_{\text{post}}/\sigma_{\text{prior}} = 0.979$.
The lag-two sensitivity returns
$+0.021$ with ratio
$1.014$. The anchoveta and sardine
posteriors of $(\rho^{SST}, \rho^{CHL})$ move by less than $0.03$
posterior-standard-deviations relative to the main specification,
confirming that the stock-specific covariate replacement does not
contaminate the identification of the coastal shifters.

The basin-scale shifter, like the spatial-extension refits of Section
\ref{sec:appendix-spatial-results} and the dual-source extension of
Section \ref{sec:appendix-spatial-dual}, is therefore unable to
resolve a non-zero productivity response for jack mackerel within the
$2000$--$2024$ Centro-Sur biomass record, even with twice the
in-sample dispersion of the coastal shifters and a deliberately tight
prior. We read the four-way convergence---spatial-domain refits,
dual-source extension, SPRFMO regional-scale coherence failure, and
the present basin-scale test---as evidence of a genuinely flat
identification rather than an artefact of any one specification
choice. The biological readings of @Arcos2001-jq, @Pena-Torres2017-gn remain consistent with the appendix result: each
documents climatic effects on jack mackerel at *margins* (location
choice, range distribution, spawning timing) that are not necessarily
captured in the elasticity of structural productivity at an annual
aggregate. Section \ref{sec:appendix-spatial-implication} updates the
implication for the main claim accordingly. Tables
\ref{tab:growth_compstat} and \ref{tab:trip_compstat} of the
main text retain the convention that $r^{*}_{\text{jurel}}$ is held
fixed in the projections and the implications for the harvest
elasticity are reported with the corresponding caveat.

A natural sensitivity to the replacement convention of
(\ref{eq:appE-enso-spec}) is to relax the pinning of
$\rho_{\text{jur}}^{SST}$ and $\rho_{\text{jur}}^{CHL}$ and refit the
specification with all three shifters active for jack mackerel
simultaneously, allowing the data to discriminate between the
basin-scale ENSO forcing and the local Centro-Sur SST and chlorophyll
anomalies. Such a refit is well-conditioned at $N=24$ lag-one
observations because the three covariates are close to orthogonal at
the dynamically-relevant lag: the pairwise lag-one correlations are
$\mathrm{cor}(\widetilde{SST}_{1,t-1},\,\widetilde{\log CHL}_{1,t-1})
= 0.03$,
$\mathrm{cor}(\widetilde{\text{ENSO}}_{t-1},\,\widetilde{SST}_{1,t-1})
= 0.09$, and
$\mathrm{cor}(\widetilde{\text{ENSO}}_{t-1},\,\widetilde{\log CHL}_{1,t-1})
= 0.18$, so the joint identification of three
elasticities does not run into the multicollinearity floor that
would otherwise make a three-shifter specification on $24$
observations indefensible.

The joint refit returns
$\rho_{\text{jur}}^{SST} = +0.455$ ($90\%$ CI $[-1.26,\,+2.14]$;
$\sigma_{\text{post}}/\sigma_{\text{prior}} = 1.03$),
$\rho_{\text{jur}}^{CHL} = -0.098$ ($90\%$ CI $[-1.77,\,+1.55]$;
ratio $1.00$), and
$\rho_{\text{jur}}^{ENSO} = -0.029$ ($90\%$ CI $[-0.82,\,+0.79]$;
ratio $0.98$). All three posterior-to-prior ratios exceed $0.97$,
indicating that the data carry no information on any of the three
shifters even when they compete for likelihood weight in a single
specification. The basin-scale ENSO posterior is essentially
identical to its single-shifter counterpart of
Section \ref{sec:appendix-spatial-enso}---confirming the orthogonality
diagnosis above---and the two coastal shifters return ratios slightly
above unity, which under flat-likelihood regimes reflects the
posterior-broadening contribution of the integration over the
structural priors $(\log r^{0}_{\text{jur}}, \log K_{\text{jur}})$
and the between-stock covariance $\boldsymbol{\Omega}$ rather than a
material posterior expansion. The anchoveta and sardine posteriors of
$(\rho^{SST}, \rho^{CHL})$ are unchanged relative to the main
specification, as expected: the joint refit only affects jack mackerel
through its diagonal entry of the covariate matrix.

The joint sensitivity therefore strengthens rather than weakens the
non-identification result. A reviewer who would accept the
three-shifter joint specification as the primary identification test
would still arrive at the same conclusion: at the Centro-Sur scale on
the $2000$--$2024$ acoustic record, neither local upwelling-band SST
or chlorophyll nor basin-scale ENSO carries a posterior mode
distinguishable from the prior. The structural reading is unaltered:
the climate sensitivity of jack mackerel productivity at the available
spatial and temporal aggregation is not resolvable from these data
under any of the candidate forcings considered in this appendix.

## Implication for the main claim {#sec:appendix-spatial-implication}

The main-text claim that the climate sensitivity of jack mackerel
cannot be sharply resolved from the available $2000$--$2024$
Centro-Sur biomass record is robust across five complementary tests
of spatial scale, sample structure, and forcing modality. First, the
spatial robustness refit of Sections \ref{sec:appendix-spatial-spec}
and \ref{sec:appendix-spatial-results} varies the environmental
aggregation across $\mathcal{D}_1$, $\mathcal{D}_2$, and
$\mathcal{D}_3$ while holding the biomass record fixed: the
posterior-to-prior ratios remain in $0.998$--$1.014$ across all three
domains. Second, the dual-source extension of Section
\ref{sec:appendix-spatial-dual} adds a second biomass series from the
Northern Chilean acoustic record under a common climate elasticity,
exploiting the $0.88$ log-scale correlation between the two Chilean
series: the ratios fall only to $0.94$--$0.99$. Third, the basin-scale
test of Section \ref{sec:appendix-spatial-enso} replaces the local
shifters with the ENSO Niño 3.4 index under a deliberately tighter
prior $\mathcal{N}(0, 0.5)$, returning a posterior-to-prior ratio of
$0.98$ at lag one and $1.01$ at lag two. Fourth, a joint specification
with all three shifters active for jack mackerel simultaneously
returns ratios of $1.03$ on local SST, $1.00$ on local $\log$
chlorophyll, and $0.98$ on basin-scale ENSO, despite the three
covariates being close to orthogonal at the dynamically-relevant lag
($\mathrm{cor}$ pairwise $\le 0.18$). Fifth, an attempt to
incorporate the SPRFMO regional assessment series fails on coherence
grounds, indicating that the broader geographic aggregate is not
integrable with the Centro-Sur record under a single shifter. The
convergence of these five tests indicates a genuinely flat
identification of the shifter for jack mackerel within the Centro-Sur
biological domain, not an artefact of insufficient spatial extent,
insufficient sample size, mis-specified forcing scale, or poor source
aggregation.

For policy purposes this distinction matters: closing the
identification gap will require either a longer biomass record or a
direct biological measurement of the relevant scale, not a different
choice of spatial aggregation, biomass source, basin-scale shifter, or
joint-specification convention within the existing record. The
natural extension is the range-wide SPRFMO-scale analysis with
explicit cross-stock spillover and spatially-resolved environmental
forcing, which we leave to future work.
<!-- ====== end inlined: paper1/sections/appendix_spatial_jurel.Rmd ====== -->



<!-- ====== inlined: paper1/sections/appendix_variance_decomposition.Rmd ====== -->

# Decomposition of projection uncertainty across the CMIP6 ensemble {#appendix-ensemble}

The comparative statics reported in Section \ref{projections} integrate
over two distinct sources of uncertainty: the posterior of the structural
shifters $(\rho^{SST}_s, \rho^{CHL}_s)$ given the historical record, and
the spread of climate-forced trajectories across the CMIP6 ensemble.
Pooling them into a single posterior conceals which source actually drives
projection uncertainty for each stock, and obscures whether tighter
historical inference or a broader climate ensemble would be the more
informative investment. This appendix decomposes the total variance of
the projected percentage change in effective intrinsic growth,
$\Delta r^*_s / r^{(0)}_s$, into a within-model (posterior) component and
a between-model (climate-ensemble) component using the law of total
variance.

## Decomposition

Let $X_{s,m,d}$ denote the percentage change in $r_s$ implied by climate
model $m$ and posterior draw $d$ under a fixed scenario--window pair
$(SSP, w)$. The total variance of $X$ across $(m, d)$ admits the
decomposition

\begin{equation}
\underbrace{\mathrm{Var}_{(m,d)}(X_{s,\cdot,\cdot})}_{\text{total}}
\;=\;
\underbrace{\mathbb{E}_m\!\left[\mathrm{Var}_d(X_{s,m,\cdot} \mid m)\right]}_{\text{within-model (posterior)}}
\;+\;
\underbrace{\mathrm{Var}_m\!\left[\mathbb{E}_d(X_{s,m,\cdot} \mid m)\right]}_{\text{between-model (climate)}}
\label{eq:appF-decomp}
\end{equation}

The first term is the average posterior variance of $\Delta r^*_s / r^{(0)}_s$
within a model: it captures uncertainty about the structural elasticities
$\rho_s$ given the historical record, holding the climate forcing fixed.
The second term is the variance across CMIP6 models of the within-model
posterior means: it captures uncertainty about the magnitude of the
climate forcing itself, holding the structural posterior fixed at its
within-model mean. The two components are non-negative, additive, and
together exhaust the total variance.

We compute Equation \eqref{eq:appF-decomp} by Monte Carlo from the
T4b-full posterior ($16{,}000$ draws) crossed with the six-model CMIP6
ensemble described in Section \ref{projections}. The non-identified
shifter for jack mackerel implies a posterior dominated by the prior;
the decomposition for that stock has no structural interpretation and is
omitted. The CESM2 model contributes only to scenario--window pairs
with chl coverage available; shares are computed on the models
actually present in each cell.

## Results

Table \ref{tab:appF-decomp} reports the decomposition for the four
scenario--window pairs.


*[R code chunk omitted]*


The decomposition reveals a sharp contrast between the two identified
stocks. For *sardine*, the between-model component dominates the
total variance in three of the four scenario--window pairs (between $77$
and $91\%$ of total variance). The within-model posterior of
$\rho^{SST}_{\text{sard}}$ is tight enough that the bottleneck on the
projection is not the structural inference but disagreement among the
CMIP6 models on the magnitude of warming and chl change. Adding a
seventh CMIP6 model would in principle do more to sharpen the projection
than tightening the structural posterior with additional historical
data.

For *anchoveta*, the within-model component is comparable to or larger
than the between-model component across all scenarios, and reaches
$97\%$ of the total variance under SSP5-8.5 by end-of-century. This
reflects a wider posterior on $\rho^{SST}_{\text{anch}}$ together with
the larger between-draw heterogeneity that ensemble chl deltas induce
once chl is on a comparable scale across models: the historical record
from 2000 to 2024 has identified the anchoveta shifter less precisely
than the sardine shifter, consistent with the wider $90\%$ credible
interval in the structural Section \ref{identification}, and the
nontrivial cross-model spread of $\Delta\log\text{CHL}$ under SSP5-8.5
end-of-century combines with $\rho^{CHL}_{\text{anch}} < 0$ to widen
the within-model distribution further. The bottleneck on the anchoveta
projection is therefore the structural posterior; tightening the
historical inference would do more for the anchoveta projection than
expanding the ensemble.

The single exception in the table is *sardine* under SSP5-8.5
end-of-century, where the within share rises to $59\%$. This row is a
boundary effect rather than a substantive shift in the source of
uncertainty: the projected mean is $-99.5\%$ and the total $SD$ is
$0.010$, so the distribution is essentially pinned at the lower bound
of $-100\%$. Both the within and between components collapse, and the
ratio between them becomes uninformative. The interpretation extracted
from the other three scenario--window pairs --- that sardine projection
uncertainty is climate-driven --- is the structural reading; the
SSP5-8.5 end-of-century cell is reported for completeness but should be
read with the floor effect in mind.

The means reported in Table \ref{tab:appF-decomp} differ slightly from
the medians reported in Table \ref{tab:growth_compstat} of the main
results section because the within-model distribution of
$\Delta r^*_s / r^{(0)}_s$ is left-skewed: posterior draws in which the
stock collapses pull the median down, while posterior draws in which
chl-driven offsets attenuate the SST collapse pull the mean up. The
gap is largest for anchoveta under SSP5-8.5 end-of-century (mean
$-83.1\%$ vs.\ median $-89.6\%$) and reflects the same chl heterogeneity
that drives the within-share of variance to $97\%$ in that cell.

Figure \ref{fig:appF-decomp} visualises the decomposition as stacked
shares of total variance.

\begin{figure}[!ht]
\centering
\includegraphics[width=0.85\textwidth]{figs/t4b/appendix_f_variance_decomposition.png}
\caption{Variance decomposition of $\Delta r^*_s / r^{(0)}_s$ across
the CMIP6 ensemble. Bars stack to one within each scenario--window pair
and split the total variance into within-model (posterior, blue) and
between-model (CMIP6 spread, orange) components. Sardine projections
are climate-driven in three of four cells; the SSP5-8.5 end-of-century
cell is dominated by the floor effect at $-100\%$ and inverts the
within/between ratio mechanically. Anchoveta projections are
posterior-driven, particularly under SSP5-8.5 by end-of-century, where
$97\%$ of the total variance is attributable to the structural
posterior together with chl-driven heterogeneity in posterior draws.
Jack mackerel omitted (non-identified shifter).}
\label{fig:appF-decomp}
\end{figure}

The substantive implication for projection-uncertainty management is
species-specific. Investments that would shrink the projection
uncertainty most are different for the two stocks: a longer or more
informative survey series for the anchoveta SST shifter would shrink
its within-model component, while the sardine projection requires
either a larger CMIP6 ensemble or a defensible procedure for weighting
the existing ensemble (an emergent-constraint approach, for instance,
which we do not pursue here). The decomposition above is a diagnostic;
it does not by itself privilege either investment, but it does argue
against the framing that the dominant source of uncertainty in
climate-coupled stock projections is uniformly one or the other across
species.
<!-- ====== end inlined: paper1/sections/appendix_variance_decomposition.Rmd ====== -->



<!-- ====== inlined: paper1/sections/appendix_g_trips_variance_decomposition.Rmd ====== -->

# Decomposition of trip-level projection uncertainty across the CMIP6 ensemble {#appendix-trips-ensemble}

The fleet-level comparative statics on trips reported in
Section \ref{sec:tripresults} (Table \ref{tab:trip_compstat}) integrate
over three sources of uncertainty: the posterior of the structural
shifters $(\rho^{SST}_s, \rho^{CHL}_s)$ given the historical record,
the heterogeneity of catch composition $(\omega_{v,s})$ and historical
quota allocation $(H^{\text{alloc}}_v)$ across vessels within fleet,
and the spread of climate-forced trajectories across the CMIP6 ensemble.
This appendix decomposes the total variance of the projected percentage
change in fleet-level annual trips, $\Delta T_f / T_f^{(0)}$, into a
within-model component (posterior uncertainty pooled with vessel
heterogeneity within fleet) and a between-model component (CMIP6
ensemble spread), using the law of total variance. It is the
companion to Appendix \ref{appendix-ensemble} and answers a different
diagnostic question: *whether the narrow cross-model interquartile
range observed for fleet-level trip responses in
Table \ref{tab:trip_compstat} reflects climate consensus or a
floor-effect saturation of the underlying biomass collapse.*

## Decomposition

Let $X_{f,m,d,v}$ denote the percentage change in annual trips for
vessel $v$ in fleet $f$ implied by climate model $m$ and posterior draw
$d$ under a fixed scenario--window pair $(SSP, w)$. The total variance
of $X_{f,\cdot,\cdot,\cdot}$ across $(m, d, v)$ admits the decomposition

\begin{equation}
\underbrace{\mathrm{Var}_{(m,d,v)}(X_{f,\cdot,\cdot,\cdot})}_{\text{total}}
\;=\;
\underbrace{\mathbb{E}_m\!\left[\mathrm{Var}_{(d,v)}(X_{f,m,\cdot,\cdot} \mid m)\right]}_{\text{within-model (posterior + vessels)}}
\;+\;
\underbrace{\mathrm{Var}_m\!\left[\mathbb{E}_{(d,v)}(X_{f,m,\cdot,\cdot} \mid m)\right]}_{\text{between-model (climate)}}
\label{eq:appG-decomp}
\end{equation}

The first term is the average variance within a model, taken over
posterior draws and vessels within fleet jointly: it captures
uncertainty about the structural elasticities and heterogeneity in
vessel exposure under a *fixed* climate forcing. The second term is
the variance across CMIP6 models of the within-model means: it captures
uncertainty about the magnitude of the climate forcing itself.

We pool posterior draws and vessel heterogeneity into the within-model
component for two reasons. First, structural parallelism with
Appendix \ref{appendix-ensemble}, which reports an exactly analogous
two-way decomposition for stock-level intrinsic productivity. Second,
vessel heterogeneity in $(\omega_{v,s}, H^{\text{alloc}}_v)$ is a fixed
feature of the historical fleet that does not shrink with longer
historical samples or larger climate ensembles; reporting it as part of
the within-model component is faithful to the reading that a longer
record or a richer ensemble would not, by construction, reduce that
share. A three-way decomposition that separates posterior, vessel,
and climate contributions can be obtained from the same
`factor_trips_dt` object generated by the trip-pipeline script and is
provided in the supplementary code; the qualitative pattern is
unchanged.

We compute Equation \eqref{eq:appG-decomp} by Monte Carlo from the
T4b-full posterior crossed with the six-model CMIP6 ensemble, propagated
through the Schaefer steady-state biomass equation under historical
average fishing pressure and the negative binomial trip equation, for
each of the 830 vessels in the panel.

## Results


*[R code chunk omitted]*


Table \ref{tab:appG-decomp} reports the decomposition for the four
scenario--window pairs and two fleets.


*[R code chunk omitted]*


The decomposition shows that the within-model component dominates the
total variance across all eight scenario--window/fleet cells: it
accounts for [R] of total variance for the artisanal
fleet under SSP2-4.5 mid-century and saturates at [R]
under SSP5-8.5 end-of-century; for the industrial fleet, the
within-model share rises from [R]
under SSP2-4.5 mid-century to [R] under SSP5-8.5
end-of-century. The between-model component---the share of total
variance attributable to disagreement across CMIP6 models on the
magnitude of climate forcing---is at most $4\%$ of total variance in
the SSP2-4.5 mid-century cells and is numerically zero, to the nearest
percent, in the remaining six cells. This is *not* a statement that the
CMIP6 ensemble is in tight agreement on the climate signal that drives
fleet-level trips, in the sense that one would attribute to the
sub-ensemble of CMIP6 models with similar equilibrium climate
sensitivity; it is the mechanical signature of floor-effect saturation
of the underlying biomass collapse channel.

The mechanism is straightforward. Once the Schaefer steady-state
biomass factor $f^H_v$ collapses across most posterior draws, the
negative binomial trip equation maps that collapse into
$\exp(\beta_f \cdot H^{\text{alloc}}_v \cdot (f^H_v - 1)) \approx
\exp(-\beta_f \cdot H^{\text{alloc}}_v)$, a quantity determined by the
fleet-specific business mechanics ($\beta_f$ and the historical quota
allocation) rather than by the magnitude of the climate forcing. Once
all CMIP6 models drive the system into this saturation region, the
between-model spread of the within-model mean trip response collapses
to a narrow band---numerically near zero in the present sample---while
the within-model variance retains the dispersion induced by vessel
heterogeneity in $(\omega_{v,s}, H^{\text{alloc}}_v)$ and by the
structural posterior across that subset of draws in which the portfolio
survives. The total $SD$ values are correspondingly small in absolute
magnitude ([R] for the artisanal fleet and
[R] for the industrial fleet under SSP5-8.5
end-of-century), confirming that what little variance remains is
within-model.

The means reported in Table \ref{tab:appG-decomp} are systematically
more negative than the medians reported in Table \ref{tab:trip_compstat}
of the main results section---for example, $-17.5\%$ for the artisanal
fleet under SSP5-8.5 end-of-century in this appendix versus $-10.2\%$ in
Table \ref{tab:trip_compstat}. This is the same left-skew mechanism
documented in Appendix \ref{appendix-ensemble} for the underlying
productivity response: posterior draws and vessels in which the
portfolio collapses pull the median up toward the floor at
$\exp(-\beta_f \cdot H^{\text{alloc}}_v) - 1$, while the mean integrates
over the long left tail of vessel-and-draw configurations in which the
collapse drives $f^H_v$ deep into negative territory and the trip
response down with it. Both summaries are valid; we report cross-model
medians in the main results table because the median is robust to the
extreme tail and is the natural complement to the cross-model
inter-quartile range, and we report cross-model means in this appendix
because the law of total variance in
Equation \eqref{eq:appG-decomp} is constructed on means rather than
medians.

This reading is consistent with the underlying biomass-level
decomposition reported in Appendix \ref{appendix-ensemble}: for
sardine---the stock that drives the artisanal fleet's portfolio
collapse---the SSP5-8.5 end-of-century cell exhibits a total $SD$ of
$0.010$ and an inverted within/between ratio that the appendix
explicitly reads as a floor effect at the lower bound of $-100\%$. The
fleet-level decomposition reported here inherits that floor effect: the
total $SD$ for the artisanal fleet under SSP5-8.5 end-of-century is
[R] and the corresponding industrial cell is
[R], both of which are small absolute magnitudes and
mechanically consistent with the saturated regime.

The substantive policy implication is that, for fleet-level trip
projections, the marginal information value of expanding the CMIP6
ensemble is small relative to that of tightening the structural
posterior or refining the description of vessel heterogeneity within
fleet. The dominant uncertainty is *not* "which climate model is
right" but "given that all of them imply portfolio collapse for the
two coastal stocks, how does the resulting heterogeneous economic
exposure across vessels translate into trip-level effort." This is the
econometric counterpart of the well-known result in the climate-impacts
literature that ensemble averaging masks first-order distributional
heterogeneity downstream of the climate signal [@Cline2017-dp;
@Free2019; @Kasperski2013-jz; @Oken2021-of].

Figure \ref{fig:appG-decomp} visualises the decomposition.

\begin{figure}[!ht]
\centering
\includegraphics[width=0.85\textwidth]{figs/t4b/appendix_g_trips_variance_decomposition.png}
\caption{Variance decomposition of $\Delta T_f / T_f^{(0)}$ across the
CMIP6 ensemble. Bars stack to one within each scenario--window pair
and split the total variance into within-model (posterior pooled with
vessel heterogeneity, blue) and between-model (CMIP6 spread, orange)
components. The within-model component dominates across all cells,
reflecting the floor-effect saturation of the underlying Schaefer
steady-state biomass collapse rather than tight cross-model agreement
on the climate signal.}
\label{fig:appG-decomp}
\end{figure}
<!-- ====== end inlined: paper1/sections/appendix_g_trips_variance_decomposition.Rmd ====== -->
