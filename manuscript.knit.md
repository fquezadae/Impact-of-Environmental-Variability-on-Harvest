---
title: "The Impact of Environmental Variability on Fishers' Harvest Decisions in Chile
  using a Multi-Species Approach"
subtitle: "\\begin{center}{\\color{red}\\Large\\textbf{REALLY EARLY DRAFT – PLEASE DO NOT CITE}}\\end{center}"
author: "Felipe J. Quezada-Escalona"
date: "abril 17, 2026"
output: 
  bookdown::pdf_document2:
    latex_engine: xelatex
    number_sections: true
    toc: false
    pandoc_args: ["--variable=fontsize:11pt"]
  bookdown::latex_document2: default
bibliography: bibliography.bib
csl: apa.csl # Optional: for APA-style citations
linkcolor: blue
citecolor: blue
urlcolor: blue
link-citations: TRUE 
header-includes:
  - \usepackage{setspace}
  - \onehalfspacing
  - \usepackage{indentfirst}  # Enables first-line indentation
  - \setlength{\parindent}{10pt}  # Adjusts the indentation size
  - \usepackage{authblk}
  - \usepackage{booktabs}
  - \usepackage{caption}
  - \usepackage{dcolumn}
  - \usepackage{adjustbox}
  - \author{Felipe J. Quezada-Escalona}
  - \affil{Departmento de Economía \\ Universidad de Concepción \vspace{-48pt}}
editor_options: 
  markdown: 
    wrap: 72
abstract: "In this paper, we aim to answer how fishing decisions, aggregate catch levels, and the price of marine resources will be affected under different climatic scenarios in the multi-species small pelagic fishery (SPF) in Chile, composed by anchoveta (*Engraulis ringens*), jack mackerel (*Trachurus murphyi*), and sardine (*Strangomera bentincki*), among others. By doing this, we expect to gain a better understanding of how Chilean fishers and fishing communities will adapt to climate change. To address our research question, we will estimate a multi-species harvesting model. This model considers species' economic and biological interrelation to study the effect of climate variability on harvest decisions and substitution between species, and determine the impact of different climatic scenarios on the well-being (e.g., profits) of fishers and fishing communities in Chile. We hypothesize that when fishers have reduced access to a main target species, they will switch to the closest substitute if the expected revenue from targeting this new species exceeds the expected costs. Otherwise, the vessel would decrease fishing effort or even exit the fishery due to the lack of economically viable substitutes. Moreover, we expect that this behavior is heterogeneous depending on the geographical area of operation -- as it determines the availability of other species-- and the gear type used."
---



# Introduction

<!-- ADD COMMENTS FROM EFD! -->

The distribution and abundance of marine resources are changing in
response to environmental conditions such as global ocean warming
[@Poloczanska2013-qq]. Climate change will shift species distribution in
the future, leading to reduced species availability in some areas and
increased availability in others [@sumaila2011].
<!-- @sumaila2011: The economic consequences of climate change on fisheries might manifest themselves through changes in the price and value of catches, fishing costs, fishers’ incomes, earnings to fishing companies, discount rates and economic rent (that is, the surplus after all costs, including ‘normal’ profits, have been covered), as well as throughout the global economy. -->
The literature that studies fishers’ responses to either changes in fish
availability or policies that restrict access to fisheries [e.g.,
@Stafford2018-pq; @Vasquez_Caballero2023-ip] has identified that they
can adopt the following adaptive strategies: (i) reduce or reallocate
fishing effort, either to another species or to another location
[@Gonzalez-Mon2021-kj]; (ii) continue following the same strategy; or
(iii) exit the fishery and find alternative employment [@Powell2022-wj].
Among these strategies, reallocating effort to alternative species has
been identified as a potentially effective response to climate change
[@Young2018-kk]. Diversification of target species has also been linked
to reduced income variability [e.g., @Kasperski2013-jz; @Sethi2014-bn]
and greater resilience to both climate shocks [@Cline2017-dp;
@Fisher2021-lw] and interannual oceanographic variability
[@Aguilera2015-wo; @Finkbeiner2015-bs].

This emphasis on diversification aligns with broader evidence from
food-producing sectors. As @sjcruz_jmp highlights, climate variability
substantially affects agriculture and fisheries, where income depends
heavily on environmental fluctuations (e.g., temperature, rainfall) and
market forces (e.g., input costs) [@Kasperski2013-jz; @Carter2018]. With
variability expected to reduce productivity, income risk is likely to
rise [@Carter2018; @Free2019]. Diversification—whether within a sector
(e.g., switching crops or species) or across sectors—is often promoted
as an adaptive strategy [@Abbott2023-sb]. However, these strategies can
be costly for resource-dependent communities with limited capital and
skills [@Cherdchuchai2006; @Ellis2000], and the role of switching costs
in shaping diversification remains poorly understood.

In the fisheries context, switching between species requires not only
the skills but also the appropriate gear and permits [@Frawley2021-cw;
@Powell2022-wj]. Even if these conditions are met, diversification may
still be constrained by port infrastructure, markets, and regulations
[@Beaudreau2019-xg; @Kasperski2013-jz; @Powell2022-wj]. Therefore,
deciding which adaptation strategy to adopt is not straightforward and
depends on multiple factors. Moreover, fishers may respond differently
to similar circumstances depending on their goals, skills, and
preferences [@Zhang2011-wv; @Jardine2020-um; @Powell2022-wj].

In this research, we aim to answer how fishing decisions, aggregate
catch levels, and the price of marine resources will be affected under
different climatic scenarios in the multi-species small pelagic fishery
(SPF) in Chile, composed of anchoveta (*Engraulis ringens*), jack
mackerel (*Trachurus murphyi*), sardine (*Strangomera bentincki*), among
others. The SPF is the most important in terms of catches in the
country, accounting for almost 94% of the total Chilean catch in 2019
[@SUBPESCA2020]. Through this research, we aim to gain a deeper
understanding of how Chilean fishers and fishing communities will adapt
to climate change. According to @Cheung2010, the Chilean Exclusive
Economic Zone (EEZ) is projected to experience one of the largest losses
in maximum catch potential due to climate change.
<!-- Caviedes, C. N. & Fik, T. J. in Climate Variability, Climate Change and Fisheries (ed. Glantz, M.) 355–375 (Cambridge Univ. Press, 1992): "During the 1997–1998 El Niño event, Chilean and Peruvian pelagic marine landings declined by about 50%, resulting in a drop in fishmeal export values by about US$8.2 billion. This huge drop generated negative economic effects and caused severe hardship (lost jobs, incomes and earnings) in both countries"-->
However, the Southeast Pacific remains one of the least studied regions
regarding the impacts of climate change on fisheries [@sumaila2011].

To address our research question, we will estimate a multi-species
harvesting model based on @Kasperski2015-jm. This model considers
species' economic and biological interrelations to study the effect of
climate variability on harvest decisions and substitution between
species, and to determine the impact of different climatic scenarios on
the well-being (e.g., profits) of fishers and fishing communities in
Chile. We expect to find significant effects of climate variables on
species stock dynamics, the cost of fishing during a trip, and the
number of trips a vessel takes. These environmental effects might
influence optimal harvest levels and prices in local markets. 

Take into consideration the economic interaction between species is relevant to include how firms adjust to changes in policies, as relative prices between species might change. Also, cost complementarities between trageiting multispcies should be consideredn as it might be cheaper to harvest two species instead of one... In this paper we allow for economic interaction between species by allowing vessel to have multiple-output production and the output price to be dependent on other species, similar to @Kasperski2015-jm.
<!-- We also expect to find significant interrelations between species stock and harvest, and that the composition of the catch will vary depending on the climate scenario we use for future -->
<!-- predictions. -->

Under a changing climate, studying the effect of climatic variability on
fishers' harvest decisions and landings is relevant for understanding
fishing communities' adaptive capacities and strategies in response to
climate change, thereby enabling the design of potential mitigation
measures in response to these changes by policymakers. Countries have
different institutions, cultures, and norms, leading to differing
responses based on the study's location. For this reason, conducting
this research based on the Chilean fishing industry is necessary to
develop local policies that aim to reduce climate change impacts on
fisheries. While there is some literature on the effect of climate
change on Chilean fisheries, I am unaware of local-level studies that
consider a multiple-species framework and the interrelationship between
the local market and fishing decisions seen under a variable climate
context.[^1]

[^1]: For the case of Chile, as far as I know, the only article that
    studies fishers’ behavior using discrete choice modeling is
    @Pena-Torres2017-gn. This article studies how the El Niño–Southern
    Oscillation (ENSO) affects fishers’ location choices in the jack
    mackerel fishery.

Because predator–prey links couple these species, reductions in
anchoveta or sardine availability may reflect not only environmental
drivers but also changes in predation pressure from jack mackerel
[@Alheit2004; @Arancibia2019-FIPA]. Thus, even fishers who do not target
jack mackerel can face induced changes in catch rates and revenues
through ecosystem feedbacks. We hypothesize that if the availability of
a main target species decreases, fishers will switch to the closest
substitute when expected revenues (net of switching costs) exceed
expected costs; otherwise they may reduce effort or exit the fishery. We
also expect cross-fleet spillovers: in Chile, jack mackerel is
predominantly harvested by the industrial purse-seine fleet, whereas
anchoveta and sardine have substantial artisanal and industrial
participation. Shocks in one component can propagate across fleets via
both biology and markets, in addition to economic linkages (bycatch
constraints, shared gear, and market spillovers). This strengthens the
case for a multi-species framework that models joint dynamics and
substitution rather than single-species responses. Moreover, we expect
that this behavior is heterogeneous depending on the geographical area
of operation—as it determines the availability of other species
[@Reimer2017-jw]—and the gear type used.

-- ADD the fact that the government define the TAC using sa single
species model. This modelling effort allow to move further to a better
management of the SPF fishery by using a multispecies approach to obtain
optimal TAC

```{=html}
<!-- Los dos primeros, recordó, son especies clave para la cadena trófica marina, ya que alimentan a peces de mayor valor como corvina, lenguado o congrio, hoy cada vez más escasos.
LINK: https://www.diarioconcepcion.cl/economia/2025/10/07/sector-pesquero-nueva-resolucion-de-la-camara-baja-mantiene-la-discrepancia-entre-biobio-y-nuble.html -->
```

# SPF in Chile

The small pelagic fishery (SPF) in Chile is of critical importance to
the national fisheries sector. In 2019, the SPF represented nearly 94%
of total national fish landings [@SUBPESCA2020]. The fishery is
primarily composed of anchoveta (*Engraulis ringens*), sardine
(*Strangomera bentincki*), and jack mackerel (*Trachurus murphyi*).
While in the Northern region competition mainly occurs between anchoveta
and jack mackerel, in the Central-South region all three species play a
major role. This makes the Central-South particularly relevant for the
study of species interactions and potential substitution within a
multispecies management framework, and it is therefore the focus of this
research.

The jack mackerel fishery was initially concentrated in northern Chile,
but since the mid-1980s the main fishing grounds have shifted to
Central-South Chile, traditionally within 50 nautical miles of the coast
[@Pena-Torres2017-gn]. Historically, species in the SPF have been used
primarily for fishmeal and fish oil production [@Pena-Torres2017-gn]. In
fact, about 85% of jack mackerel landings, on a yearly average between
1987 and 2004, were destined for reduction into fishmeal and fish oil
[@Pena-Torres2017-gn]. Today, several key ports serve as hubs for these
activities, including San Antonio, Tomé, Talcahuano, San Vicente,
Coronel, Lota, and Corral.



"La pesquería de sardina común (Strangomera bentincki) y anchoveta (Engraulis ringens)
de la zona centro sur de Chile se caracteriza por ser una pesquería mixta. A pesar de contener
especies distintas, éstas conviven y se reproducen en un mismo hábitat. Las artes de pesca
utilizadas para capturar estas especies no permiten diferenciarlas." [@dresdner2013]

"La pesquería de sardina común y anchoveta ha sido por largos años una de las pesquerías
más importante de Chile. La disminución paulatina de los desembarques de jurel (Trachurus
murphyi) ha llevado a la sardina común a posicionarse como el principal recurso pelágico
extraído, seguido por la anchoveta" [@dresdner2013]


## Status of the stocks

Historically, anchoveta in the Central-South was considered collapsed
until 2018, shifted to overexploited status in 2019, and has since 2020
been fished within maximum sustainable yield (MSY) limits. Meanwhile,
sardine stocks have generally remained within MSY levels, except in 2021
and 2023 when they were classified as overexploited. Jack mackerel was
overexploited until 2018 but has since been harvested within MSY limits.

## Quota allocation

The Chilean fishing sector is managed primarily through a Total Allowable Catch (TAC; *Cuota Global*), which is divided between the industrial and artisanal sectors. A small share (≈2%) is reserved for research, with additional portions allocated to contingency and human consumption. The TAC is subdivided by region and season, and unused quotas may be reassigned during the fishing year.

Anchoveta and sardine are regulated as a mixed-species fishery: although each has its own quota, substitution between them is permitted. A share
of industrial quota is also periodically reassigned to the artisanal sector.


Since 2013, the industrial sector has operated under an individual transferable quota (ITQ) system, known as Transferable Fishing Licenses
(*Licencias Transables de Pesca, LTP*). Class A licenses were allocated based on historical catches, while Class B licenses—up to 15% of the
industrial fraction—are auctioned, with the first auctions held in 2015. These sealed-bid, first-price auctions aimed to broaden access and limit
concentration but have faced challenges such as low participation,
difficulties in reflecting economies of scale, and signs of potential
coordinated bidding [@peña_torres_2022_MRE].

The artisanal TAC operates under a regulated freedom-to-fish regime,
allowing registered vessels to fish without individual quotas, except in
areas where access is closed or suspended, in which case authorities may
implement management measures. The main measure is the Régimen Artesanal
de Extracción (RAE), which allocates the regional artisanal TAC by area,
vessel size, landing site (caleta), organization, or individually, in
agreement with artisanal fisher organizations. To date, area-based and
organization-based allocations are the only observed schemes. Area-based
allocations allow registered artisanal vessels in a given area to fish
as in open access until the assigned quota is exhausted, while
organization-based allocations follow the historical rights of members
to distribute the organization’s quota.

-   Sardine: RAE in V, VIII Y X regions? What about other species? Open
    access in anchovy and jack mackerel (only artisanal TAC matter at
    country level?)

### Chile regionalized fisheries governance framework

Chile has a regionalize fisheres governance framework, where boat
register in one region can not fish in another one. For instance, a
recent conflict between the Biobío and Ñuble regions has reignited the
debate over the spatial governance of the small pelagic fishery (SPF) in
south–central Chile. In late August 2025, the Chilean Chamber of
Deputies approved a resolution urging the Government to repeal the
authorization that allows vessels from Biobío to operate in the coastal
waters of Ñuble. The measure, promoted by local authorities and
artisanal organizations from Ñuble, aims to protect local fishing
grounds and reduce pressure on nearshore ecosystems. However,
representatives from Biobío have warned that such restrictions could
have severe economic consequences for the region, given its strong
dependence on small pelagic landings. This episode highlights the
institutional tensions arising from Chile’s regionalized fisheries
governance framework, where jurisdictional boundaries often conflict
with the biological and economic interdependencies of fish stocks.

## Other regulations

### Limited entry

Fishery with restricted access to new operators

### Biological closures for recruitment

-   Jack mackerel is open through all year.
-   Sardine and anchovy: In southern-central Chile, December–March
    (fixed period: January to February).

### Biological closures for reproduction

-   Jack mackerel is open through all year.

-   Sardine and anchovy: In southern-central Chile, July–October (fixed
    period: August-September).

-   Seasonality? Include quarter dummies? Jack mackerel gather in the
    first 6 month of the year in shoals, great density in EEZ, then
    migrate outside 200nm ()

### Minimum size

-   Jack mackerel: 26 cm
-   Sardine and anchovy?

### Maximum harvest levels

-   All species: Maximum catch limit per vessel owner (LMC) for industrial vessels, based on the industrial share of the TAC.







## Switching patterns

ARE THIS SPF TRIPS?????





See Figure \@ref(fig:switchStrategy-ART) for strategy transitions. The
year 2019 is used as reference as anchoveta and jack mackerel started to
recover.



Table \@ref(tab:table-art) for strategy transitions.

\begin{table}
\centering
\caption{(\#tab:table-art)Comparison of Strategies Before and After -- Small-scale vessels}
\centering
\fontsize{10}{12}\selectfont
\begin{tabular}[t]{lrrrr}
\toprule
\multicolumn{1}{c}{ } & \multicolumn{2}{c}{Before} & \multicolumn{2}{c}{After} \\
\cmidrule(l{3pt}r{3pt}){2-3} \cmidrule(l{3pt}r{3pt}){4-5}
Strategy & n & \% & n & \%\\
\midrule
Sardine and Anchoveta & 420 & 31.9 & 376 & 63.5\\
Only Sardine & 416 & 31.6 & 133 & 22.5\\
Sardine and Other & 193 & 14.6 & 8 & 1.4\\
Sardine, Anchoveta and Other & 139 & 10.5 & 21 & 3.5\\
Sardine, JackMackerel and Anchoveta & 23 & 1.7 & 23 & 3.9\\
\addlinespace
Only Other & 60 & 4.6 & 2 & 0.3\\
Only Anchoveta & 21 & 1.6 & 16 & 2.7\\
Anchoveta and Other & 14 & 1.1 & 2 & 0.3\\
Sardine and JackMackerel & 10 & 0.8 & 3 & 0.5\\
Only JackMackerel & 7 & 0.5 & 3 & 0.5\\
\addlinespace
JackMackerel and Other & 4 & 0.3 & 2 & 0.3\\
JackMackerel and Anchoveta & 1 & 0.1 & 3 & 0.5\\
JackMackerel, Anchoveta and Other & 4 & 0.3 & 0 & 0.0\\
Sardine, JackMackerel, Anchoveta, Other & 4 & 0.3 & 0 & 0.0\\
Sardine, JackMackerel and Other & 2 & 0.2 & 0 & 0.0\\
\bottomrule
\end{tabular}
\end{table}



Table \@ref(tab:table-ind) for industrial strategy transitions.

\begin{table}
\centering
\caption{(\#tab:table-ind)Comparison of Strategies Before and After -- Industrial vessels}
\centering
\fontsize{10}{12}\selectfont
\begin{tabular}[t]{lrrrr}
\toprule
\multicolumn{1}{c}{ } & \multicolumn{2}{c}{Before} & \multicolumn{2}{c}{After} \\
\cmidrule(l{3pt}r{3pt}){2-3} \cmidrule(l{3pt}r{3pt}){4-5}
Strategy & n & \% & n & \%\\
\midrule
Only JackMackerel & 46 & 36.2 & 28 & 96.6\\
Sardine and JackMackerel & 22 & 17.3 & 1 & 3.4\\
Sardine and Anchoveta & 14 & 11.0 & 0 & 0.0\\
JackMackerel and Other & 13 & 10.2 & 0 & 0.0\\
Sardine, JackMackerel and Anchoveta & 13 & 10.2 & 0 & 0.0\\
\addlinespace
Only Other & 6 & 4.7 & 0 & 0.0\\
JackMackerel and Anchoveta & 3 & 2.4 & 0 & 0.0\\
Sardine, JackMackerel and Other & 3 & 2.4 & 0 & 0.0\\
Only Sardine & 2 & 1.6 & 0 & 0.0\\
Anchoveta and Other & 1 & 0.8 & 0 & 0.0\\
\addlinespace
Only Anchoveta & 1 & 0.8 & 0 & 0.0\\
Sardine and Other & 1 & 0.8 & 0 & 0.0\\
Sardine, Anchoveta and Other & 1 & 0.8 & 0 & 0.0\\
Sardine, JackMackerel, Anchoveta, Other & 1 & 0.8 & 0 & 0.0\\
\bottomrule
\end{tabular}
\end{table}

![(\#fig:switchStrategy-ART)Strategy transitions for small-scale vessels](manuscript_files/figure-latex/switchStrategy-ART-1.pdf) 

![(\#fig:switchStrategy-IND)Strategy transitions for industrial vessels](manuscript_files/figure-latex/switchStrategy-IND-1.pdf) 

## Fishing seasons





\begin{figure}[ht!]

{\centering \includegraphics{manuscript_files/figure-latex/monthlyharvest-1} 

}

\caption{Average monthly landings by species (2012-2024; South-Central Chile) }(\#fig:monthlyharvest)
\end{figure}



# Data and methodology

To fulfill the research's objectives, and following @Kasperski2015-jm,
the research entails five different stages: (i) estimating the annual
stock dynamics of each species included in the model, (ii) estimating
trip level cost functions, (iii) estimating total annual trips, (iv)
estimate the inverse demand model for outputs (i.e., price responses to
supply), and (v) conduct numerical optimization to examine how harvest
and profits levels evolve over time. The numeral optimization uses
estimated parameters from the previous four stages to conduct the
optimization procedure.

<!-- Following the bioeconomic literature on regulated fisheries (e.g. Richter et al., 2018), we model a fishery composed of multiple fleet segments that differ in cost structure, harvesting technology, and catch quality, which in turn implies segment-specific output prices (Asche et al., 2015). -->


## Historical data

We use data requested from the Chilean Fisheries Development Institute
(Instituto de Fomento Pesquero, IFOP) covering the 2013–2024 period. The
dataset includes trip-level microdata, which contain detailed records on
vessel identifiers, departure and arrival times, vessel capacity, fleet
and gear type, ports of departure and landing, fishery codes, haul
timing and location, species composition, retained catch, and trip
activity. In addition, we requested annual information on stock
abundance and vessel landings by port, county, region, country, and
species. Finally, we use ex-vessel prices, reported monthly or annually
by port, county, region, country, and species. These prices reflect
those paid by processing plants to fishers at the point of first sale
and are obtained through IFOP’s landing surveys, which do not
necessarily cover all market transactions.

<!-- How different are SERNAPESCA and IFOP harvest data? (Figura -->

<!-- @ref(fig:harvestsource)) -->



For the environmental covariates, we use data from the E.U. Copernicus Marine Service Information, accessed through the Copernicus Marine Toolbox API. Salinity, sea surface temperature, and current speed and direction were obtained from the Global Ocean Physics Reanalysis (GLORYS12V1), which provides data at a 1/12° horizontal resolution with 50 vertical levels [@GLORYS12V1]. Wind speed and direction at the surface were obtained from the Global Ocean Hourly Reprocessed Sea Surface Wind and Stress from Scatterometer and Model dataset, available at 0.125° horizontal spatial resolution and hourly frequency [@WIND_GLO_PHY]. Chlorophyll-a concentrations were obtained from the Global Ocean Colour dataset, which provides data at \~4 km horizontal resolution [@GlobColour]. All environmental data were retrieved daily (hourly in the case of winds) for the 2013–2024 period, covering the Chilean Exclusive Economic Zone (EEZ) between 32°S and 41°S (Figure \@ref(fig:figEnvData))


#### Imputation of missing jack mackerel biomass {-}

To address the years in which no acoustic survey was conducted in south-central Chile---or in which insufficient information was available to produce a stock assessment---we imputed missing jack mackerel biomass values. Of the 25 years in the sample period (2000--2024), jack mackerel CS biomass is directly observed in 17 years; the remaining 8 years require imputation. The primary predictor is jack mackerel biomass from the Northern zone, estimated from independent acoustic surveys conducted since 2010 (correlation with observed CS biomass: $r = 0.82$, $N = 7$ overlapping years).

We estimated five alternative GLM specifications with a Gamma distribution and log link, ranging from a parsimonious model with Northern biomass as the sole predictor (2 parameters) to a saturated specification including Northern biomass, its square, the SPRFMO spawning biomass index, and their interaction (5 parameters). All models using Northern biomass are estimated with only 7 observations (years where both CS and Norte are simultaneously observed). The most complex specification exhibited severe overfitting (pseudo-$R^2 = 0.97$, but biologically implausible predictions requiring ad hoc censoring in two years). We therefore selected a parsimonious specification---Model B: Northern biomass and its square (3 parameters)---which achieves an in-sample pseudo-$R^2 = 0.90$ and a leave-one-out cross-validation $R^2 = 0.78$, indicating acceptable out-of-sample predictive performance. For the single year where Northern biomass is also unavailable (2022), we use linear interpolation between adjacent observed values as a fallback.

The SPRFMO spawning biomass index, which covers the transzonal stock across the EEZ of Chile, Ecuador, and Peru, was also considered as a predictor. However, its correlation with observed CS biomass is low ($r = 0.11$, $N = 17$), reflecting the weak correspondence between regional stock dynamics and local abundance in south-central Chile. The interpolated series, together with a source flag indicating whether each observation is acoustically observed, GLM-predicted, or linearly interpolated, is used in subsequent estimation. To assess sensitivity to the imputation procedure, we report robustness checks using only observed jack mackerel biomass (Appendix \ref{appendix-robustness}).

\begin{figure}[ht!]

{\centering \includegraphics[width=0.8\linewidth]{figs/env_data_map} 

}

\caption{Geographical extent of the study area used for environmental covariates limited to the Chilean Exclusive Economic Zone}(\#fig:figEnvData)
\end{figure}

### To be requested

-   Diesel cost.
-   Permits by vessels
-   Quota prices?
    -   Auction market but also secondary market if available
        -   If no data, maybe intrapolate prices from other auctions?
    -   Captures elements of forward-looking behavior and information
        [@Birkenbach2024]. @reimer2022structural similarly argue that
        including a quota price captures forward looking behavior and
        allows one to simplify the dynamic model to a static one.
-   Quota by area/fishing organization for Artisanal, and TAC for
    industrial with ITQ (by vessel?)

## Future data for projections

-   OracleBio
    -   Unfurtunally, only decadal (e.g., 2040–2050) projections for
        different scenarios for SST, salinity, currents and chlorophyll
        (4km resolution)
    -   No winds; CMIP6 for winds? (\~100 km).

## Econometrics models

### Stock dynamics

To estimate stock dynamics, we use annual data on species-specific biomass (stock abundance) and vessel landings within Chile's Exclusive Economic Zone (EEZ). Following @Kasperski2015-jm, the baseline model for the interannual growth of each species $i$ is represented by a discrete logistic function that accounts for intra- and inter-species interactions:

\begin{equation}
x_{i,y+1} + h_{iy} = \underbrace{(1 + r_i)x_{iy} + \eta_i x_{iy}^2}_{R_i(x_{iy})} + \underbrace{\sum_{j \neq i}^{n-1} a_{ij} x_{iy} x_{jy}}_{I_i(x_y)} \quad i=1,\ldots,n
\label{eq1}
\end{equation} 

where $x_{iy}$ is the biomass of species $i$ in year $y$, $n$ is the total number of species, $h_{iy}$ is the annual harvest, $r_i$ is the intrinsic growth rate, $\eta_i$ is the density-dependent parameter, and $\alpha_{ij}$ captures pairwise species interactions. The system of $n$ growth equations is estimated simultaneously using Seemingly Unrelated Regression (SUR). Following @Richter2018, we augment \eqref{eq1} by including environmental covariates $Env_{iy}$ that affect stock dynamics, along with an error term $\varepsilon_{iy}$ representing stochastic recruitment:

\begin{equation}
x_{i,y+1} + h_{iy} = \underbrace{(1 + r_i)x_{iy} + \eta_i x_{iy}^2}_{R_i(x_{iy})} + \underbrace{\sum_{j \neq i}^{n-1} a_{ij} x_{iy} x_{jy}}_{I_i(x_y)} + \rho_i Env_{iy} + \varepsilon_{iy} \quad i=1,\ldots,n
\label{eq2}
\end{equation} 

where $\rho_i$ denotes the environmental response parameters. Each species has its own equation, allowing for species-specific growth, density dependence, and environmental sensitivities.

Environmental conditions were summarized annually using sea surface temperature (SST) and chlorophyll-a concentration (CHL), both averaged over the South-Central Chile region within the EEZ. These variables were selected due to their recognized influence on small pelagic productivity and spatial distribution [@Axbard2016]. SST serves as a proxy for large-scale oceanographic regimes (warm vs. cold phases) that shape recruitment success along the Humboldt Current System. Anchoveta typically dominates during cold, nutrient-rich phases, whereas sardine tends to increase under warmer regimes [@cahuin2009; @Yáñez2014]. CHL reflects interannual variation in primary productivity, which forms the energetic base sustaining small pelagics [see @cheung2008; @jennings2008].

To select the preferred specification, we compared five candidate models by AIC and BIC, varying the inclusion of quadratic environmental terms, cross-species interaction terms, and wind covariates (Table \ref{tab:model_selection}). Wind effects were excluded first, as a joint exclusion test failed to reject their omission. Cross-species interaction terms ($x_{iy} x_{jy}$) and quadratic CHL were subsequently tested but did not improve fit---both AIC and BIC increased when these terms were added. The preferred specification retains own biomass, its square, SST, SST$^2$, and CHL (linear) for each species, yielding six parameters per equation and approximately 17 residual degrees of freedom with $N = 23$ observations. This parsimonious model is estimated as:

\begin{equation}
x_{i,y+1} + h_{iy} = (1 + r_i)x_{iy} + \eta_i x_{iy}^2 + \rho_{i,1} SST_y + \rho_{i,2} SST_y^2 + \rho_{i,3} CHL_y + \varepsilon_{iy} \quad i=1,\ldots,n
\label{eq2b}
\end{equation}

where all environmental variables are centered at their sample means to reduce collinearity between linear and quadratic terms.

Figure \@ref(fig:biomass) shows that anchoveta, sardine, and jack mackerel exhibit distinct biomass trajectories over time, with no evidence of strong interannual co-movement across species. Biomass levels differ markedly between them, and the figure suggests only limited interrelation alongside clear divergences in year-to-year dynamics. Harvest pressure is also visibly associated with these fluctuations; for instance, jack mackerel experienced an abrupt decline during the late 2000s, consistent with the combined effects of intense fishing pressure and unfavorable environmental conditions.

\begin{figure}[ht!]

{\centering \includegraphics{manuscript_files/figure-latex/biomass-1} 

}

\caption{Estimated biomass of small pelagic species in Chile (2000--2024)}(\#fig:biomass)
\end{figure}

The SUR framework is particularly suited to this multi-species setting, as it allows for contemporaneous correlation among residuals that naturally arise from shared non-observed environmental shocks, trophic linkages, and imperfectly observed ecological processes. We estimate a three-equation SUR system using the SEM framework implemented in lavaan, freely allowing the error terms across biomass equations to be correlated. The model is estimated via robust maximum likelihood (MLR), yielding SUR coefficients with Huber--White robust standard errors. Cross-species interaction terms were tested as an extension but did not improve model fit (see Section 4.1 and Appendix \ref{appendix-robustness}).


### Trip level cost functions

The full @Kasperski2015-jm framework includes trip-level restricted cost functions estimated separately for each fleet segment, capturing how vessel characteristics, stock levels, and input prices interact to determine operating costs. These cost functions, together with an inverse demand system for ex-vessel prices, feed into a numerical optimization that determines optimal quotas and harvest paths under climate change. The estimation of these components requires detailed trip-level cost data (fuel expenditure, crew wages, and trip duration) that is currently being compiled from IFOP logbooks. This module will be completed in a companion paper that extends the present analysis to a full bioeconomic optimization, following the approach in @Kasperski2015-jm and @KASPERSKI201655.


### Total annual trips

We model the annual number of fishing trips taken by vessel $v$ in year $y$ as a count process following @Kasperski2015-jm. Since the available logbook data only record purse-seine operations, the unit of observation is a vessel--year. Separate effort models are estimated for the industrial and artisanal fleets, allowing fishing activity to respond differently to economic conditions and regulatory constraints across sectors. This specification explicitly accommodates technological heterogeneity across fleet segments, reflecting differences in vessel capacity, operating scale, and production technology.

The baseline specification is a Poisson model:

\begin{equation}
T_{vy} \sim \text{Poisson}(\lambda_{vy}), \qquad 
\lambda_{vy} = \exp\!\left(U_{vy}'\beta\right),
\label{eq:poisson_trips}
\end{equation}

where $T_{vy}$ denotes the total number of purse-seine trips recorded for vessel $v$ in year $y$. Given substantial overdispersion in the data---the variance-to-mean ratio of $T_{vy}$ is 22.4 for the artisanal fleet and 4.9 for the industrial fleet---we estimate a negative binomial (NB) model, which nests the Poisson as a special case. A likelihood ratio test strongly rejects the Poisson restriction in both fleets ($p < 0.001$).

The vector of explanatory variables $U_{vy}$ includes output prices by species, vessel-level allocated harvest, fixed vessel characteristics, and operating conditions:

\begin{equation}
U_{vy}=\big[p_{sy},\, H^{alloc}_{vy},\, Z_v,\, Env_{vy}\big].
\label{eq:U_trips}
\end{equation}

Output prices $p_{sy}$ correspond to species-specific ex-vessel prices paid by processing plants to fishers, obtained from IFOP's manufacturing survey and deflated to constant 2018 pesos using the consumer price index from the Central Bank of Chile. Consistent with @dresdner2013, prices are measured as annual averages over peak fishing months to reflect the economically relevant conditions faced by vessels when planning annual effort.

Because the objective of the model is to characterize vessels' effort responses to changes in prices, quotas, and environmental conditions within the small pelagic fishery, we restrict attention to SPF trips recorded in logbooks. These trips account for approximately 95\% of observed fishing revenue and therefore capture the primary economic margin through which vessels adjust annual fishing effort.

Quota shares do not enter Eq.~\eqref{eq:poisson_trips} directly. Instead, shares translate annual TACs into vessel-level allocated harvests. Let $\omega_{vs}^r$ denote vessel $v$'s historical share of landings of species $s$ within its administrative region $r$ (for artisanal vessels) or regulatory zone (for industrial vessels), computed over the full sample period. Given the effective TAC $\bar{Q}_{sy}^r$ for species $s$ in year $y$ in region $r$---obtained from SERNAPESCA quota monitoring records and reflecting all inter-fleet transfers and adjustments---vessel-level allocated harvest is:

\begin{equation}
H^{alloc}_{vy,s}=\omega_{vs}^r\,\bar{Q}_{sy}^r,
\qquad
H^{alloc}_{vy}=\sum_{s} H^{alloc}_{vy,s}.
\label{eq:Halloc}
\end{equation}

Each vessel is assigned to its administrative region based on its modal departure port from the logbook records. Artisanal TACs are assigned at the regional level (regions V, VIII, IX, XIV, X), while industrial TACs follow the regulatory zone structure established by SUBPESCA (zones V--IX and XIV--X for jack mackerel; zone V--X for sardine and anchoveta). This regional construction introduces cross-sectional variation in $H^{alloc}_{vy}$ that reflects the heterogeneous quota environments faced by vessels operating in different parts of the Centro-Sur fishery.

This construction is essential for the forward-looking simulation framework. When the social planner chooses aggregate TAC paths $\{\bar{Q}_{sy}\}$, Eq.~\eqref{eq:Halloc} generates internally consistent vessel-level harvest allocations that can be combined with predicted trips and trip-level cost functions to compute total harvesting costs.

The vector $Z_v$ contains time-invariant vessel characteristics, including hold capacity (log of cubic meters) and vessel type. Hold capacity determines the physical constraint on catch per trip and proxies for vessel scale.

The vector $Env_{vy}$ captures operating and regulatory constraints that vary across both vessels and years. Unlike the environmental variables in the stock dynamics model, which reflect biological productivity (SST, chlorophyll-a), the variables in the trip equation capture conditions that affect the *feasibility* of fishing operations. Two vessel--year variables are constructed using each vessel's center of gravity (COG)---the catch-weighted centroid of its haul locations over the sample period. First, the number of days with adverse weather conditions is computed as the count of days per year in which wind speed exceeds 8~m/s at the environmental grid point nearest to the vessel's COG.\footnote{The wind threshold of 8~m/s corresponds approximately to Beaufort scale 5, at which purse-seine operations become difficult for artisanal vessels. This threshold was selected based on model fit (AIC comparison across 8, 10, and 12~m/s thresholds); robustness checks are reported in Appendix~\ref{appendix-robustness}.} Second, the number of days closed due to biological closures (\textit{vedas}) is assigned based on the regulatory zone corresponding to the vessel's COG latitude. In the Centro-Sur region, sardine and anchoveta face seasonal closures for reproduction (August--October in regions V--VIII; July--October in regions IX--XIV) and recruitment (January--February in all regions), yielding 151 and 182 closed days per year, respectively. Jack mackerel has no biological closures.

Quota prices are not included explicitly in the trip equation. Instead, the economic scarcity of quota is captured implicitly through aggregate TAC levels and vessel-level allocated harvest. In the simulation stage, quota scarcity generates shadow values that affect optimal harvest and effort decisions through profits rather than through an explicit quota price term.

Trips, harvest, and prices may be jointly determined within the year, implying potential endogeneity in reduced-form trip regressions. However, the purpose of Eq.~\eqref{eq:poisson_trips} is not causal identification but rather to provide an empirically grounded behavioral relationship that maps changes in prices, quotas, and environmental conditions into expected fishing effort for use in the bioeconomic simulation.


### Inverse demand model

The full bioeconomic model additionally requires an inverse demand system to endogenize ex-vessel prices as a function of aggregate landings. Following @Kasperski2015-jm, the price of each species can be modeled using an Inverse Almost Ideal Demand System (IADS), estimated via three-stage least squares to account for the simultaneity between harvest and prices. The estimation of this component, together with the cost functions described above, is deferred to a companion paper that will incorporate the complete numerical optimization framework.





## Numerical optimization

The present analysis focuses on the reduced-form projections of fishing effort under climate change, holding prices and management rules at their historical levels. A companion paper will extend this framework to a full numerical optimization following @Kasperski2015-jm, in which vessels maximize profits by jointly choosing the number of trips and the harvest portfolio per trip, subject to individual quota constraints. That extension will incorporate the trip-level cost functions and inverse demand system described above, enabling welfare analysis and the computation of optimal quota paths under alternative climate scenarios.





## Projections

As noted by @Kasperski2015-jm, the multi-species bioeconomic framework is particularly suited for long-term projections of fish populations and fishing activity rather than intra-annual management responses. However, because our empirical models are estimated on interannual variability rather than decadal trends, the projections presented here capture the impact of changed environmental conditions without accounting for endogenous adaptation by fishers or managers [@Aufhammer2018]. This provides a useful benchmark for understanding the direction and magnitude of climate impacts, while acknowledging that behavioral responses may attenuate or amplify these effects over time.

# Results


## Stock biomass model

<!-- Figure \@ref(fig:harvestbiomass) shows biomass and harvest. -->



<!-- ============================================================ -->
<!-- BIOMASS ESTIMATION: DATA PREPARATION                          -->
<!-- ============================================================ -->





<!-- ============================================================ -->
<!-- SUR ESTIMATION                                                -->
<!-- ============================================================ -->



Table \ref{tab:model_selection} summarizes the model selection exercise. Five candidate specifications were compared, ranging from a baseline with only own-biomass terms to a full model including quadratic chlorophyll-a and cross-species interaction terms. The preferred specification---which includes own biomass, its square, SST, SST$^2$, and chlorophyll-a---yields the lowest AIC and BIC. Adding quadratic CHL terms or cross-species interactions does not improve fit; in fact, both AIC and BIC increase when these terms are included. Wind variables were excluded in an earlier specification search, as a joint exclusion test failed to reject their omission. The preferred specification contains six parameters per equation, yielding approximately 17 residual degrees of freedom with $N=23$ observations.

Table \ref{tab:SUR_results} reports the SUR estimates of annual biomass dynamics for sardine, anchoveta, and jack mackerel. The system is estimated via robust maximum likelihood (MLR), yielding Huber--White standard errors and allowing unrestricted contemporaneous correlation across equations.

All three species exhibit strong interannual persistence and significant density dependence, consistent with discrete logistic growth. However, the species differ markedly in their sensitivity to environmental conditions.

Sardine biomass displays the strongest environmental response. Chlorophyll-a enters positively and is highly significant ($\hat{\rho}_{CHL} = 80.99$, $p < 0.001$), indicating that years with higher primary productivity favor sardine growth. The quadratic SST term is also significant and positive ($\hat{\rho}_{SST^2} = 54.74$, $p = 0.001$), suggesting a convex response to temperature anomalies---sardine biomass increases more sharply under larger SST deviations from the mean. This pattern is consistent with evidence from the Humboldt Current System, where sardine tends to exhibit smoother population changes associated with warmer or transitional oceanographic regimes [@cahuin2009; @Yáñez2014].

Anchoveta biomass is dominated by density dependence, with the strongest own-biomass coefficient ($\hat{r} = 1.11$, $p < 0.001$) and a highly significant quadratic term ($\hat{\eta} = -0.202$, $p < 0.001$). SST has a marginally significant negative effect ($p = 0.087$), but neither SST$^2$ nor CHL are significant. This asymmetric environmental response---where anchoveta reacts primarily to temperature rather than productivity---is consistent with the ecological literature. Anchoveta in the Humboldt Current is known to respond sharply to short-term cold, nutrient-rich conditions, dominating during cold phases of decadal-scale oceanographic variability [@cahuin2009; @Yáñez2014; @Alheit2004].

Jack mackerel shows strong persistence ($\hat{r} = 1.06$, $p < 0.001$) but a distinct environmental signature. The quadratic SST term is large and highly significant ($\hat{\rho}_{SST^2} = -56.49$, $p = 0.001$), indicating a clear thermal optimum: biomass declines when temperatures deviate substantially from the long-run mean in either direction. Neither linear SST nor CHL are individually significant, suggesting that jack mackerel growth is less sensitive to annual fluctuations in upwelling productivity than sardine. This weaker coupling to coastal environmental variability is consistent with jack mackerel's broader spatial distribution, deeper foraging behavior, and transboundary stock structure within the Southeast Pacific [@Pena-Torres2017-gn].

These contrasting environmental responses have direct implications for climate projections. Under warming scenarios, sardine may benefit from increased thermal variability if accompanied by sustained productivity, whereas anchoveta could face reduced biomass if warming erodes the cold, nutrient-rich conditions it depends on. Jack mackerel, with its thermal optimum response, would be adversely affected by both warming and cooling extremes.

Cross-species interactions were tested but did not improve model fit (Table \ref{tab:model_selection}). The residual covariances across equations are also statistically insignificant, suggesting that shared unobserved shocks---beyond those captured by SST and CHL---do not generate strong contemporaneous co-movement across species. This does not rule out ecological interactions (e.g., predator--prey dynamics between jack mackerel and small pelagics), but it indicates that such effects are not detectable in the annual aggregate biomass data given the available sample size.

Appendix \ref{appendix-robustness} presents three robustness checks. Table \ref{tab:SUR_rob_obs} restricts the jack mackerel series to observed (non-interpolated) years, reducing the sample to 12 observations and requiring a more parsimonious specification without SST$^2$. Table \ref{tab:SUR_rob_2sp} estimates a two-species SUR for sardine and anchoveta only, treating jack mackerel biomass as an exogenous covariate. Table \ref{tab:SUR_interactions} augments the main specification with cross-species interaction terms, confirming that their coefficients are individually and jointly insignificant. The core findings---strong density dependence, positive CHL effects on sardine, and a thermal optimum for jack mackerel---are qualitatively robust across all specifications, lending confidence that the results are not driven by the interpolation procedure.


<!-- ============================================================ -->
<!-- BUILD TABLES                                                  -->
<!-- ============================================================ -->








\begin{table}[!htbp]
\centering
\caption{Model selection for SUR biomass dynamics}
\label{tab:model_selection}
\begin{tabular}{lcrrr}
\toprule
Specification & K/eq & AIC & BIC & $\Delta$AIC \\
\midrule
No environment & 3 & 490.7 & 507.7 & 13.1 \\
Main (SST + SST2 + CHL) & 6 & 477.6 & 504.9 & 0.0 \\
Main + CHL2 & 7 & 482.9 & 513.6 & 5.3 \\
Main + interactions & 8 & 485.0 & 519.1 & 7.4 \\
Full (interactions + CHL2) & 10 & 490.5 & 528.0 & 12.9 \\
\bottomrule
\end{tabular}
\end{table}




\begin{table}[!htbp] \centering 
  \caption{SUR estimates of biomass dynamics (main specification, N = 23)} 
  \label{tab:SUR_results} 
\footnotesize 
\begin{tabular}{@{\extracolsep{5pt}}lccc} 
\\[-1.8ex]\hline 
\hline \\[-1.8ex] 
 & \multicolumn{3}{c}{\textit{Dependent variable:}} \\ 
\cline{2-4} 
 & Sardine & Anchoveta & Jack mackerel \\ 
\\[-1.8ex] & (1) & (2) & (3)\\ 
\hline \\[-1.8ex] 
 Own biomass ($x_{it}$) & 0.438$^{***}$ (0.113) & 1.112$^{***}$ (0.157) & 1.057$^{***}$ (0.137) \\ 
  Own biomass$^2$ ($x_{it}^2$) & $-$0.021$^{***}$ (0.005) & $-$0.202$^{***}$ (0.047) & $-$0.017$^{***}$ (0.005) \\ 
  SST & $-$9.158$^{*}$ (5.409) & $-$4.972$^{*}$ (2.906) & 5.923 (5.161) \\ 
  SST$^2$ & 54.738$^{***}$ (16.038) & $-$4.608 (7.203) & $-$56.485$^{***}$ (17.413) \\ 
  Chlorophyll-a & 80.992$^{***}$ (17.061) & $-$5.366 (11.155) & 15.454 (24.835) \\ 
  Constant & 23.745$^{***}$ (2.132) & 12.096$^{***}$ (1.639) & 28.188$^{***}$ (3.376) \\ 
 \hline \\[-1.8ex] 
Observations & 23 & 23 & 23 \\ 
R$^{2}$ & 0.707 & 0.608 & 0.790 \\ 
Adjusted R$^{2}$ & 0.621 & 0.493 & 0.729 \\ 
Residual Std. Error (df = 17) & 7.308 & 3.917 & 9.589 \\ 
\hline 
\hline \\[-1.8ex] 
\textit{Note:}  & \multicolumn{3}{l}{$^{*}$p$<$0.1; $^{**}$p$<$0.05; $^{***}$p$<$0.01.} \\ 
 & \multicolumn{3}{l}{Robust (Huber--White) SEs via MLR. Biomass in $10^5$ tons.} \\ 
 & \multicolumn{3}{l}{Environmental variables centered at sample means.} \\ 
 & \multicolumn{3}{l}{Jack mackerel uses Model B interpolation (see Section 3.1).} \\ 
\end{tabular} 
\end{table} 




<!-- Trip level cost function results deferred to companion paper -->


## Total Annual trips






Table \ref{tab:poisson_results} reports the negative binomial estimates separately for each fleet segment.


\begin{table}[!htbp] \centering 
  \caption{Negative binomial estimates of annual fishing trips (2013--2024, $N_{IND}$ = 319, $N_{ART}$ = 4498)} 
  \label{tab:poisson_results} 
\footnotesize 
\begin{tabular}{@{\extracolsep{5pt}}lcc} 
\\[-1.8ex]\hline 
\hline \\[-1.8ex] 
 & \multicolumn{2}{c}{\textit{Dependent variable:}} \\ 
\cline{2-3} 
 & Industrial & Artisanal \\ 
\\[-1.8ex] & (1) & (2)\\ 
\hline \\[-1.8ex] 
 Hold capacity (log m$^3$) & $-$0.037 (0.201) & 0.193$^{***}$ (0.056) \\ 
  Allocated harvest ($H^{alloc}_{vy}$, tons) & 0.00003$^{***}$ (0.00001) & 0.001$^{***}$ (0.00003) \\ 
  Price jack mackerel (1000s \$/ton) & 0.005$^{***}$ (0.002) & $-$0.002$^{**}$ (0.001) \\ 
  Price sardine (1000s \$/ton) & $-$0.001 (0.002) & 0.003$^{***}$ (0.001) \\ 
  Price anchoveta (1000s \$/ton) & $-$0.00001 (0.0003) & $-$0.0005$^{***}$ (0.0002) \\ 
  Bad weather days & $-$0.0001 (0.001) & $-$0.002$^{***}$ (0.0004) \\ 
  Veda days & $-$0.081$^{***}$ (0.004) & 0.009$^{***}$ (0.002) \\ 
  Vessel type (UNK) &  & $-$0.518$^{***}$ (0.109) \\ 
  Vessel type (BR) &  & $-$1.033$^{***}$ (0.173) \\ 
  Vessel type (BRV) &  & $-$2.456$^{***}$ (0.189) \\ 
  Vessel type (L) &  & $-$0.103 (0.150) \\ 
  Vessel type (LM) & $-$0.982$^{***}$ (0.077) & 0.266$^{*}$ (0.143) \\ 
  Constant & 14.638$^{***}$ (1.995) & 1.230$^{***}$ (0.446) \\ 
 \hline \\[-1.8ex] 
Observations & 319 & 4,201 \\ 
Log Likelihood & $-$1,231.493 & $-$17,512.890 \\ 
$\theta$ & 8.345$^{***}$  (0.903) & 1.407$^{***}$  (0.031) \\ 
Akaike Inf. Crit. & 2,480.986 & 35,051.770 \\ 
\hline 
\hline \\[-1.8ex] 
\textit{Note:}  & \multicolumn{2}{l}{$^{*}$p$<$0.1; $^{**}$p$<$0.05; $^{***}$p$<$0.01.} \\ 
 & \multicolumn{2}{l}{Vessel-clustered robust SEs. Prices in constant 2018 thousands of pesos/ton.} \\ 
 & \multicolumn{2}{l}{Allocated harvest = historical vessel share $\times$ lagged aggregate harvest.} \\ 
 & \multicolumn{2}{l}{LR test NB vs Poisson: Industrial $\chi^2$ = 524.8; Artisanal $\chi^2$ = 49060.9 (both $p < 0.001$).} \\ 
\end{tabular} 
\end{table} 

Allocated harvest enters positively and is highly significant in both fleets, confirming that vessels with larger quota allocations undertake more trips per year. This variable provides the key linkage between the trip equation and the simulation framework: changes in regional TACs translate into vessel-level effort adjustments through the quota share mechanism.

The two fleets differ markedly in their price responsiveness. For the industrial fleet, the jack mackerel price is positive and significant ($p < 0.01$), consistent with this fleet's primary orientation toward jack mackerel. Sardine and anchoveta prices have no detectable effect on industrial effort, reflecting the limited participation of industrial vessels in the sardine-anchoveta fishery. For the artisanal fleet, the sardine price is positive and significant ($p < 0.01$), consistent with sardine being the dominant target species for artisanal vessels in the Centro-Sur region. The anchoveta price enters with a negative and significant coefficient. This counterintuitive sign likely reflects simultaneity: years of low anchoveta availability produce both higher prices (through the inverse demand channel) and fewer trips (through reduced catch opportunities), generating a negative reduced-form correlation. As noted above, the purpose of this equation is not causal identification but rather to provide an empirically grounded mapping for the simulation, where prices are determined endogenously by the inverse demand module.

Hold capacity is not significant for the industrial fleet, where vessels are relatively homogeneous in scale, but is positive and significant for the artisanal fleet. Among artisanal vessels, larger hold capacity is associated with more annual trips, consistent with larger vessels being more commercially active and better able to sustain operations across varying conditions.

The environmental and regulatory variables show distinct patterns across fleets. For the artisanal fleet, adverse weather days are strongly negative and significant ($p < 0.001$), indicating that years with more days of wind speeds above 8~m/s substantially reduce fishing effort for smaller vessels. For the industrial fleet, adverse weather is not significant, consistent with larger vessels being better equipped to operate under rough conditions. Biological closure days are strongly negative for the industrial fleet, representing the largest effect in the model, consistent with the industrial fleet's dependence on access during open seasons. For the artisanal fleet, the positive coefficient on closure days reflects the current limitation that this variable varies only across regulatory zones (151 days for regions V--VIII versus 182 days for regions IX--XIV) and therefore captures locational differences in fishing activity rather than the causal effect of closures.\footnote{Once year-specific closure dates from annual SUBPESCA resolutions are incorporated, providing within-zone temporal variation, this coefficient is expected to become negative.}

Vessel type dummies capture residual heterogeneity in fleet composition. Among artisanal vessels, larger vessel categories (L, BRV) are associated with substantially fewer trips relative to the baseline, reflecting differences in trip duration and operational patterns across vessel classes.



## Climate change projections {#projections}

We assess the impact of climate change on fishing effort through two channels: (i) a *direct weather channel*, where projected changes in wind speed alter the number of bad weather days that constrain fishing operations, and (ii) an *indirect biomass channel*, where projected changes in sea surface temperature and chlorophyll-a affect stock growth capacity through the SUR equations, which in turn modifies harvest allocations and fishing effort through the trip equation.

### Projection methodology

Climate projections are derived from the IPSL-CM6A-LR Earth system model under two Shared Socioeconomic Pathways: SSP2-4.5 (moderate emissions) and SSP5-8.5 (high emissions). We apply the delta method [@Burke2015; @Free2019], which preserves the observed interannual variability and fine-scale spatial structure from satellite records while imposing the climate change signal from CMIP6. For each variable, the delta is computed as the difference (additive for SST and wind speed) or ratio (multiplicative for chlorophyll-a) between the CMIP6 future climatology and the CMIP6 historical climatology (1995--2014 baseline), applied cyclically to each calendar month. We consider two future time windows: mid-century (2041--2060) and end-of-century (2081--2100).

For the direct weather channel, monthly wind speed deltas from CMIP6 are interpolated to the observed 0.125-degree wind grid and applied additively to daily wind speed observations. Bad weather days (wind speed exceeding 8 m/s) are then recomputed under each scenario and fed into the NB trip equation. For the indirect biomass channel, we compute changes in growth capacity for each species using comparative statics on the SUR environmental coefficients, evaluating the predicted change in $y_i$ (next-period biomass plus current harvest) under projected versus historical SST and chlorophyll-a, holding biomass at its historical mean. These growth capacity changes are translated into proportional changes in harvest allocations ($H^{alloc}_{vy}$), weighted by each vessel's historical species composition.



### Projected environmental changes

Table \ref{tab:env_projections} summarizes the projected environmental changes for the Centro-Sur study area. Sea surface temperature increases by 0.8--2.3$^\circ$C depending on the scenario, with the strongest warming under SSP5-8.5 end-of-century. Chlorophyll-a declines moderately (2--6\%), consistent with increased stratification reducing nutrient supply to the surface. Wind speed changes are negligible across all scenarios ($<$0.1 m/s), reflecting the limited sensitivity of near-surface atmospheric circulation to greenhouse forcing in the IPSL model for this region.

\begin{table}[!h]
\centering
\caption{(\#tab:env_projections)Projected environmental changes for Centro-Sur Chile (IPSL-CM6A-LR, delta method)}
\centering
\fontsize{10}{12}\selectfont
\begin{tabular}[t]{llrrr}
\toprule
SSP & Window & $\Delta$ SST ($^\circ$C) & $\Delta$ CHL (ratio) & $\Delta$ Wind (m/s)\\
\midrule
SSP2-4.5 & 2081--2100 & 1.480 & 0.942 & 0.037\\
SSP2-4.5 & 2041--2060 & 0.811 & 0.971 & 0.060\\
SSP5-8.5 & 2081--2100 & 2.333 & 0.959 & 0.068\\
SSP5-8.5 & 2041--2060 & 0.970 & 0.988 & -0.049\\
\bottomrule
\end{tabular}
\end{table}

### Projected changes in biomass growth capacity

The SUR environmental coefficients imply asymmetric impacts across species (Table \ref{tab:biomass_proj}). Sardine growth capacity increases substantially under all scenarios, driven by the large positive and significant SST$^2$ coefficient and the strong CHL response. In contrast, jack mackerel growth declines sharply due to its concave thermal response---warming pushes temperatures away from the species' thermal optimum. Anchoveta growth capacity also declines, though less severely, primarily through the negative SST effect.

\begin{table}[!h]
\centering
\caption{(\#tab:biomass_proj)Projected change in species growth capacity (\% change from historical mean, comparative statics on SUR coefficients)}
\centering
\fontsize{10}{12}\selectfont
\begin{threeparttable}
\begin{tabular}[t]{lllll}
\toprule
SSP & Window & Sardine & Anchoveta & Jack mackerel\\
\midrule
SSP2-4.5 & 2081--2100 & 416.6\% & -218.3\% & -592.5\%\\
SSP2-4.5 & 2041--2060 & 108.7\% & -88.1\% & -167.7\%\\
SSP5-8.5 & 2081--2100 & 1111.4\% & -463.1\% & -1507.6\%\\
SSP5-8.5 & 2041--2060 & 169.8\% & -115.5\% & -243.5\%\\
\bottomrule
\end{tabular}
\begin{tablenotes}
\item \textit{Note:} 
\item Computed at mean biomass levels. Values reflect the partial effect of projected SST and CHL changes on the SUR growth equation, relative to the historical mean of $y_i$ (next-period biomass plus harvest).
\end{tablenotes}
\end{threeparttable}
\end{table}

### Decomposition of climate effects on fishing effort

Table \ref{tab:decomposition} presents the central result: the projected percentage change in annual fishing trips decomposed into the direct weather channel and the indirect biomass channel. The decomposition reveals that the indirect channel dominates---changes in stock productivity, transmitted through harvest allocations, drive the bulk of the effort response.

\begin{table}[!h]
\centering
\caption{(\#tab:decomposition)Projected \% change in annual fishing trips by channel and fleet}
\centering
\fontsize{10}{12}\selectfont
\begin{threeparttable}
\begin{tabular}[t]{lllrrr}
\toprule
Fleet & SSP & Window & Direct (weather) & Indirect (biomass) & Combined\\
\midrule
Artisanal & SSP2-4.5 & 2081--2100 & 1.7 & 153.0 & 154.6\\
Artisanal & SSP2-4.5 & 2041--2060 & 1.7 & 20.0 & 21.7\\
Artisanal & SSP5-8.5 & 2081--2100 & -4.2 & 250.7 & 246.5\\
Artisanal & SSP5-8.5 & 2041--2060 & -3.0 & 39.8 & 36.8\\
Industrial & SSP2-4.5 & 2081--2100 & 0.1 & -21.9 & -21.8\\
\addlinespace
Industrial & SSP2-4.5 & 2041--2060 & -0.2 & -21.6 & -21.8\\
Industrial & SSP5-8.5 & 2081--2100 & -0.1 & -21.9 & -21.9\\
Industrial & SSP5-8.5 & 2041--2060 & 0.1 & -21.7 & -21.7\\
\bottomrule
\end{tabular}
\begin{tablenotes}
\item \textit{Note:} 
\item Direct channel: change in bad weather days from projected wind speed. Indirect channel: change in harvest allocation from projected biomass growth capacity. Combined: both channels applied simultaneously. Harvest allocation scaling capped at [0.2, 3.0] of current levels.
\end{tablenotes}
\end{threeparttable}
\end{table}

\begin{figure}[ht!]

{\centering \includegraphics{manuscript_files/figure-latex/projection_figure-1} 

}

\caption{Projected change in annual fishing trips under climate change scenarios, decomposed by channel}(\#fig:projection_figure)
\end{figure}

The results reveal a stark asymmetry between fleet segments. Artisanal fishing effort increases by 20--250\% across scenarios, driven by the expansion of sardine growth capacity under warming. Since artisanal vessels predominantly target sardine, the increase in sardine biomass translates into larger harvest allocations and more annual trips. The effect is strongest under SSP5-8.5 end-of-century, where sardine growth capacity more than doubles.

Industrial fishing effort, in contrast, declines by approximately 22\% across all scenarios. The industrial fleet is more dependent on jack mackerel, whose thermal optimum response means that warming of any magnitude reduces growth capacity. The consistency of the industrial decline across scenarios reflects the capped harvest allocation scaling and the dominance of jack mackerel in the industrial species mix.

The direct weather channel is negligible in all scenarios (less than 5\% in magnitude), reflecting the limited projected changes in wind speed for the Chilean coast under IPSL-CM6A-LR. This finding implies that the primary mechanism through which climate change affects fishing effort in this fishery is biological rather than operational.


These findings have important implications for fisheries management under climate change in Chile. The divergent responses across fleet segments suggest that uniform management policies may be inadequate, and that adaptation planning should account for the heterogeneous vulnerability of different fleets to environmental change.

# Discussion

Our results reveal a fundamental asymmetry in how climate change affects different segments of Chile’s small pelagic fishery. The artisanal fleet, which predominantly targets sardine, stands to benefit from warming through increased stock growth capacity, while the industrial fleet, which depends more heavily on jack mackerel, faces declining productivity as ocean temperatures move away from that species’ thermal optimum. This finding aligns with the broader literature on heterogeneous climate impacts across fleet segments [@sumaila2011; @Free2019] and underscores that aggregate projections can mask important distributional consequences within the same fishery.

The decomposition of climate effects into direct (weather) and indirect (biomass) channels provides a novel contribution to the fisheries-climate literature. The finding that the indirect biomass channel dominates---accounting for virtually all of the projected effort response---has important implications for both research and management. It suggests that the primary pathway through which climate change will reshape fishing activity in this region is through altered species productivity, transmitted via quota allocations, rather than through changes in operational conditions at sea. This result is consistent with the limited sensitivity of near-surface wind patterns to greenhouse forcing in the southeastern Pacific, as projected by the IPSL-CM6A-LR model, although multi-model ensembles would be needed to assess the robustness of this finding.

The species-level biomass projections deserve careful interpretation. The large projected increase in sardine growth capacity under warming reflects the strong positive response of sardine to SST in the estimated SUR equations. While this is consistent with the historical observation that sardine populations in the Humboldt system tend to expand during warm phases [@Chavez2003-xt], the magnitude of the projected changes---particularly under end-of-century SSP5-8.5---should be viewed as indicative of the direction and relative scale of impacts rather than as precise point forecasts. Several sources of uncertainty affect these projections, including the small sample size of the SUR estimation (N=23), the use of a single climate model, and the assumption that historical relationships between environmental conditions and biomass will remain stable under novel climate states.

The projected decline in jack mackerel growth capacity raises important questions for the management of Chile’s largest pelagic fishery. As a highly migratory, transboundary stock managed under the South Pacific Regional Fisheries Management Organisation (SPRFMO), jack mackerel’s future trajectory depends not only on local environmental conditions but also on international harvest agreements and the stock’s distributional response to warming [@Arcos2001-jq]. Our comparative statics approach captures only the local productivity effect and does not account for potential range shifts, which could either exacerbate or mitigate the projected declines depending on whether jack mackerel moves toward or away from Chilean waters.

Several caveats apply to the present analysis. First, the projections hold ex-vessel prices and management rules constant at historical levels, implying that the effort responses capture the mechanical effect of changed environmental and biological conditions without accounting for endogenous price adjustments or adaptive management. @sumaila2011 note that reduced fish supply under climate change could increase prices, partially offsetting revenue losses from lower catches. Our companion paper will incorporate an inverse demand system and numerical optimization to capture these equilibrium adjustments. Second, the use of chlorophyll-a projections from a single Earth system model introduces additional uncertainty, as the direction and magnitude of primary productivity changes under climate change remain contested across models [@sumaila2011; @Free2019]. Third, our models do not explicitly incorporate risk preferences or production risk, which may play an important role in shaping fleet-level responses to environmental variability [@Kasperski2013-jz; @Sethi2014-bn].

The finding that climate change creates winners and losers within the same fishery has direct implications for quota allocation policy. Chile’s current system allocates quotas separately for the artisanal and industrial sectors, with limited transferability across fleet segments. If sardine productivity increases while jack mackerel declines, the relative value of artisanal quotas could rise substantially, potentially motivating reforms to the quota allocation system to allow more flexible cross-sector transfers. This echoes the theoretical work of @Birkenbach2020-nh on multispecies harvest patterns under catch shares, and the practical observation that secure property rights can help fishers adapt to changing species composition by reallocating effort across their portfolio.

# Conclusions

This paper estimates a multi-species bioeconomic model for Chile's small pelagic fishery and projects the impact of climate change on fishing effort under CMIP6 scenarios. We contribute to the literature in three ways. First, we jointly estimate stock dynamics and fishing effort in a multi-species setting that captures both biological interdependencies (through a SUR biomass model) and economic responses (through a negative binomial trip equation), applied to a major developing-country fishery. Second, we decompose the projected climate impact on fishing effort into a direct weather channel and an indirect biomass channel, showing that the latter dominates. Third, we document a stark asymmetry between fleet segments: the artisanal fleet benefits from warming-driven sardine expansion while the industrial fleet faces declining jack mackerel productivity, with implications for the distributional consequences of climate change in multi-fleet fisheries.

Our projections indicate that climate change will reshape the composition of fishing activity in Chile's Centro-Sur region. Under moderate warming (SSP2-4.5, mid-century), artisanal effort is projected to increase by approximately 20\%, while industrial effort declines by a similar magnitude. Under high-emission end-of-century conditions (SSP5-8.5, 2081--2100), the divergence between fleets becomes substantially larger. These results suggest that management policies focused on aggregate effort levels may miss important heterogeneity across fleets and species, and that climate adaptation in this fishery will need to address the uneven distribution of impacts.

Several extensions to the present framework are planned. A companion paper will incorporate trip-level cost functions and an inverse demand system to enable full numerical optimization of quota paths under climate change, following the complete @Kasperski2015-jm approach. The spatial dimension of effort allocation is also a natural extension, connecting the multi-species model to the location choice literature [e.g., @Dupont1993-jn; @Smith2005-us; @Hicks2020-mz], since the geographic distribution of species availability is likely to shift under warming. Finally, incorporating risk preferences and production risk---through, for example, random coefficient models---would provide a richer characterization of how fishers respond to the increased environmental variability projected under climate change [@Kasperski2013-jz].

# Repository

The source code for this project is available on
[GitHub](https://github.com/fquezadae/Impact-of-Environmental-Variability-on-Harvest)


# References

<div id="refs"></div>


# (APPENDIX) Appendix {-}

# Additional robustness checks {#appendix-robustness}


\begin{table}[!htbp] \centering 
  \caption{SUR robustness: observed jurel CS only (N = 12)} 
  \label{tab:SUR_rob_obs} 
\footnotesize 
\begin{tabular}{@{\extracolsep{5pt}}lccc} 
\\[-1.8ex]\hline 
\hline \\[-1.8ex] 
 & \multicolumn{3}{c}{\textit{Dependent variable:}} \\ 
\cline{2-4} 
 & Sardine & Anchoveta & Jack mackerel \\ 
\\[-1.8ex] & (1) & (2) & (3)\\ 
\hline \\[-1.8ex] 
 Own biomass ($x_{it}$) & 0.733$^{***}$ (0.085) & 0.288$^{**}$ (0.120) & 0.705$^{***}$ (0.066) \\ 
  Own biomass$^2$ ($x_{it}^2$) & $-$0.025$^{***}$ (0.002) & $-$0.289$^{***}$ (0.030) & $-$0.019$^{***}$ (0.002) \\ 
  SST & $-$23.156$^{***}$ (6.761) & $-$6.703$^{*}$ (3.680) & 19.431$^{*}$ (11.587) \\ 
  Chlorophyll-a & 74.023$^{***}$ (15.267) & $-$30.841$^{***}$ (9.070) & $-$10.944 (38.159) \\ 
  Constant & 30.089$^{***}$ (1.652) & 15.884$^{***}$ (1.359) & 35.144$^{***}$ (3.165) \\ 
 \hline \\[-1.8ex] 
Observations & 12 & 12 & 12 \\ 
R$^{2}$ & 0.892 & 0.540 & 0.766 \\ 
Adjusted R$^{2}$ & 0.830 & 0.277 & 0.632 \\ 
Residual Std. Error (df = 7) & 6.225 & 4.697 & 12.653 \\ 
\hline 
\hline \\[-1.8ex] 
\textit{Note:}  & \multicolumn{3}{l}{$^{*}$p$<$0.1; $^{**}$p$<$0.05; $^{***}$p$<$0.01. Robust SEs.} \\ 
 & \multicolumn{3}{l}{Only years with observed (non-interpolated) jurel CS biomass.} \\ 
 & \multicolumn{3}{l}{SST$^2$ dropped for parsimony given reduced sample.} \\ 
\end{tabular} 
\end{table} 




\begin{table}[!htbp] \centering 
  \caption{SUR robustness: two-species, jurel as exogenous (N = 23)} 
  \label{tab:SUR_rob_2sp} 
\footnotesize 
\begin{tabular}{@{\extracolsep{5pt}}lcc} 
\\[-1.8ex]\hline 
\hline \\[-1.8ex] 
 & \multicolumn{2}{c}{\textit{Dependent variable:}} \\ 
\cline{2-3} 
 & Sardine & Anchoveta \\ 
\\[-1.8ex] & (1) & (2)\\ 
\hline \\[-1.8ex] 
 Own biomass ($x_{it}$) & 0.410$^{**}$ (0.170) & 0.666$^{***}$ (0.219) \\ 
  Own biomass$^2$ ($x_{it}^2$) & $-$0.021$^{***}$ (0.008) & $-$0.123$^{***}$ (0.037) \\ 
  SST & $-$10.159$^{*}$ (5.729) & $-$1.995 (2.023) \\ 
  SST$^2$ & 53.217$^{***}$ (17.052) & $-$2.043 (5.831) \\ 
  Chlorophyll-a & 79.958$^{***}$ (16.038) & $-$2.463 (8.085) \\ 
  Jack mackerel biomass & $-$0.064 (0.100) & 0.150$^{***}$ (0.040) \\ 
  Constant & 23.911$^{***}$ (2.229) & 10.405$^{***}$ (1.259) \\ 
 \hline \\[-1.8ex] 
Observations & 23 & 23 \\ 
R$^{2}$ & 0.711 & 0.745 \\ 
Adjusted R$^{2}$ & 0.603 & 0.650 \\ 
Residual Std. Error (df = 16) & 7.485 & 3.255 \\ 
\hline 
\hline \\[-1.8ex] 
\textit{Note:}  & \multicolumn{2}{l}{$^{*}$p$<$0.1; $^{**}$p$<$0.05; $^{***}$p$<$0.01. Robust SEs.} \\ 
 & \multicolumn{2}{l}{Two-species SUR; jack mackerel biomass enters as exogenous covariate.} \\ 
\end{tabular} 
\end{table} 



\begin{table}[!htbp] \centering 
  \caption{SUR robustness: with cross-species interactions (N = 23)} 
  \label{tab:SUR_interactions} 
\footnotesize 
\begin{tabular}{@{\extracolsep{5pt}}lccc} 
\\[-1.8ex]\hline 
\hline \\[-1.8ex] 
 & \multicolumn{3}{c}{\textit{Dependent variable:}} \\ 
\cline{2-4} 
 & Sardine & Anchoveta & Jack mackerel \\ 
\\[-1.8ex] & (1) & (2) & (3)\\ 
\hline \\[-1.8ex] 
 Own biomass ($x_{it}$) & 0.426$^{***}$ (0.137) & 1.142$^{***}$ (0.163) & 1.048$^{***}$ (0.132) \\ 
  Own biomass$^2$ ($x_{it}^2$) & $-$0.017 (0.010) & $-$0.202$^{***}$ (0.054) & $-$0.021$^{***}$ (0.005) \\ 
  SST & $-$9.969$^{*}$ (5.850) & $-$4.172 (2.935) & 6.055 (4.696) \\ 
  SST$^2$ & 52.621$^{***}$ (16.586) & $-$1.582 (7.976) & $-$54.858$^{***}$ (16.153) \\ 
  Chlorophyll-a & 80.145$^{***}$ (17.796) & $-$2.248 (14.017) & 5.593 (24.541) \\ 
  Sardine $\times$ Anchoveta & $-$0.0001 (0.022) & $-$0.019 (0.017) &  \\ 
  Sardine $\times$ Jack mackerel & 0.007 (0.011) &  & $-$0.014$^{*}$ (0.008) \\ 
  Anchoveta $\times$ Jack mackerel &  & $-$0.010 (0.023) & 0.041$^{**}$ (0.020) \\ 
  Constant & 24.183$^{***}$ (2.420) & 12.108$^{***}$ (1.551) & 26.270$^{***}$ (3.477) \\ 
 \hline \\[-1.8ex] 
Observations & 23 & 23 & 23 \\ 
R$^{2}$ & 0.711 & 0.618 & 0.814 \\ 
Adjusted R$^{2}$ & 0.575 & 0.440 & 0.728 \\ 
Residual Std. Error (df = 15) & 7.738 & 4.116 & 9.601 \\ 
\hline 
\hline \\[-1.8ex] 
\textit{Note:}  & \multicolumn{3}{l}{$^{*}$p$<$0.1; $^{**}$p$<$0.05; $^{***}$p$<$0.01. Robust SEs.} \\ 
 & \multicolumn{3}{l}{Main specification augmented with pairwise biomass interactions.} \\ 
 & \multicolumn{3}{l}{No interaction term is individually or jointly significant.} \\ 
\end{tabular} 
\end{table} 


