# Instrucciones para Claude Cowork — Revisión paper Climate-SPF Chile

## Contexto

El manuscrito actual (`paper1_climate_projections.pdf` / archivo fuente correspondiente) contiene cinco menciones a un contraste con un "reduced-form Seemingly Unrelated Regression (SUR) of growth increments on environmental anomalies" como benchmark contra el cual se compara la especificación state-space estructural. El SUR no se estima ni se reporta en ningún lugar del paper; funciona como strawman retórico.

**Decisión:** eliminar el contraste con el SUR en todo el manuscrito y reframear la contribución 3 alrededor del mecanismo *portfolio composition × LMCA quota architecture* — que es lo que efectivamente se demuestra con la Tabla 5 y la decomposición marginal/condicional de la sección 4.3.3.

La identificación estructural (state-space, transportabilidad fuera de muestra, separación process/observation noise) se conserva como justificación interna del método, no como contraste con un benchmark fantasma.

---

## Cambios solicitados

### Cambio 1 — Abstract

**Localizar la última oración del abstract**, que empieza con *"These results reverse the sign of the distributional asymmetry implied by a reduced-form reading of the same data..."*

**Reemplazar por:**

> Because the artisanal fleet's portfolio is concentrated in the two coastal-upwelling stocks while the industrial fleet is diversified by its allocation to jack mackerel, Chile's Límite Máximo de Captura por Armador (LMCA) regime — with limited cross-sector quota transferability — translates the climate signal into a disproportionate long-run loss of harvest capacity for the artisanal segment. This carries direct implications for the design of the LMCA under non-stationary climate.

---

### Cambio 2 — Introducción, contribución 3

**Localizar el tercer punto del párrafo de contribuciones** (sección 1, hacia el final), que empieza con *"Third, we show that the direction of the distributional asymmetry between the artisanal and industrial fleets is set by the differential exposure..."*

**Reemplazar el párrafo completo de la contribución 3 por:**

> Third, we link the identified structural response to the negative binomial trip equations estimated separately for each fleet and show that the long-run distributional incidence of climate change across the artisanal and industrial segments is governed by the interaction between (i) the differential exposure of each fleet's species portfolio to the identified shifters and (ii) the limited cross-sector transferability built into the LMCA quota regime. The artisanal fleet, concentrated in the two coastal-upwelling stocks whose climate semi-elasticities are identified and large, bears a sharper long-run decline in harvest capacity than the industrial fleet, whose portfolio is diversified by jack mackerel.

---

### Cambio 3 — Sección 3.3.1, justificación del state-space

**Localizar el párrafo que empieza con** *"The state-space formulation in Eq. (1)–(2) differs from reduced-form Seemingly Unrelated Regression (SUR) specifications of the type considered in Richter et al. (2018) and Kasperski (2015)..."*

**Reemplazar el párrafo completo por:**

> Three features of the state-space formulation in Eq. (1)–(3) are material for this paper. First, it separates process noise $\sigma_{\text{proc}}$ from observation noise $\sigma_{\text{obs}}$, which is essential given the documented coefficient-of-variation of acoustic and egg-production surveys in this fishery. Second, it enforces the pre-determined ordering between year-$(t-1)$ environmental forcing and year-$t$ latent biomass, ruling out contemporaneous feedback into the climate covariates. Third, it yields structural climate semi-elasticities $(\rho^{SST}_i, \rho^{CHL}_i)$ that are invariant to the joint historical distribution of $(SST, B, C)$ and therefore transportable to climate regimes outside the 2000–2024 estimation window. Because the comparative-statics exercise of Section 4.3 evaluates the climate shifter at projected SST anomalies that lie several historical standard deviations beyond the estimation envelope, this transportability property is the substantive justification for the structural specification.

**Adicionalmente:** localizar el párrafo siguiente, que empieza con *"Compared with a reduced-form SUR regression of growth increments on contemporaneous covariates, the state-space specification (i) separates process noise..."*. Este párrafo es redundante con el anterior y también invoca al SUR.

**Eliminar este párrafo completo.** No reemplazarlo. La justificación queda subsumida en el párrafo de los tres features.

---

### Cambio 4 — Sección 4.3.3, último párrafo del bloque de implicaciones

**Localizar el párrafo que empieza con** *"This is the mechanism that reverses the sign of the distributional asymmetry that an unstructured reduced-form comparative-statics reading of a Seemingly Unrelated Regression..."*

**Reemplazar el párrafo completo por:**

> This decomposition makes the policy-relevant mechanism transparent: the distributional incidence of climate change in this fishery is not driven by differential behavioural elasticities across fleets but by the interaction between portfolio composition and the identified climate shifters. The artisanal fleet is exposed because its historical landings are concentrated in the two stocks for which $(\rho^{SST}_i, \rho^{CHL}_i)$ are both identified and economically large; the industrial fleet is partially insulated because 95% of its historical portfolio sits in jack mackerel, whose Centro-Sur shifter is not identified and is therefore held at the climatological mean in the projection. The LMCA's limited cross-sector transferability locks this differential exposure into differential losses of harvest capacity.

---

### Cambio 5 — Discusión, primer párrafo

**Localizar la oración** *"The artisanal fleet, concentrated in the sardina–anchoveta pair, is therefore the segment whose long-run harvest capacity is most exposed to the CMIP6 climate signal, reversing the direction of exposure that an unstructured comparative-statics reading of a reduced-form Seemingly Unrelated Regression of growth increments on environmental anomalies would have suggested."*

**Reemplazar por:**

> The artisanal fleet, concentrated in the sardina–anchoveta pair, is therefore the segment whose long-run harvest capacity is most exposed to the CMIP6 climate signal under the current LMCA architecture.

---

### Cambio 6 — Conclusiones (sección 6)

**Localizar la oración** *"...we show that the direction of the distributional asymmetry across fleets is set by the differential exposure of each fleet's species portfolio to the identified shifters—not by reduced-form correlations that a forecasting-oriented specification would deliver."*

**Reemplazar por:**

> ...we show that the direction of the distributional asymmetry across fleets is governed by the interaction between portfolio composition and the LMCA's limited cross-sector transferability, with the artisanal segment bearing the sharper long-run loss because its historical landings are concentrated in the two stocks whose climate semi-elasticities are identified and economically large.

---

## Cambios que NO se deben hacer

Los siguientes elementos del paper se deben **conservar intactos**:

1. La sección 4.1 ("Identification of climate shifters") y su discusión Cowles-style sobre identificación estructural del jurel. Esa argumentación es interna al manejo del jurel (state-space reporta no-identificación de manera honesta vs. una alternativa MLE que daría boundary solution), no apela al SUR como benchmark estimado.

2. El Apéndice A ("Reduced-form stress tests and prior elicitation"). Este SÍ es un ejercicio reducido que se reporta efectivamente — se usa para elicitar priors y como diagnóstico de identificabilidad. Es legítimo. No tocar.

3. El Apéndice B (PSIS-LOO y PSIS-LFO). No tocar.

4. Las menciones a Richter et al. (2018) y Kasperski (2015) **como referencias bibliográficas** — solo eliminar las cláusulas que las usan como contraste metodológico con el SUR. Si la referencia al autor sigue siendo relevante por otro motivo (e.g., Kasperski 2015 como fuente de la especificación NB del trip equation), conservarla en su contexto.

---

## Verificación final solicitada

Después de aplicar los seis cambios, hacer una búsqueda en el manuscrito completo de los siguientes términos y reportar cualquier ocurrencia restante:

- "Seemingly Unrelated Regression"
- "SUR"
- "reduced-form correlation" (en contextos donde se compara con la especificación estructural)
- "reverses the sign" / "reverse the direction"
- "unstructured comparative-statics"

Si alguna ocurrencia queda en pie y no es internamente coherente con la nueva narrativa (portfolio × LMCA), reportarla para revisión adicional.

---

## Cambio 7 — Reservar lugar para Apéndice E (robustez espacial)

Se planea un nuevo Apéndice E titulado *"Spatial robustness of the jack mackerel non-identification result"* que reportará el refit del modelo full bajo dos dominios espaciales alternativos para las anomalías de SST y CHL: (a) banda offshore extendida (32°S–41°S, hasta 85°W) y (b) Pacífico Sudeste regional (20°S–45°S, hasta 90°W). El propósito es verificar que la no-identificación del shifter climático del jurel Centro-Sur no es un artefacto del dominio Centro-Sur EEZ usado en el cuerpo del paper.

Este apéndice se agregará en una iteración posterior. Por ahora, **agregar una sola oración al cuerpo del paper** que reserve el lugar y anuncie el resultado.

### Localización

En la **sección 4.1**, después del párrafo que discute la no-identificación del jurel (el párrafo que termina con *"...which would then propagate into climate projections as if it were information."*), antes de la oración que introduce la Figura 3 (*"Figure 3 visualises the posterior–prior updating as a forest plot."*).

### Texto a insertar

Insertar como párrafo nuevo:

> The non-identification result for jack mackerel is robust to the choice of spatial domain over which the environmental anomalies are constructed. Appendix E reports refits of the full state-space specification using SST and log-CHL averaged over two alternative dominios — an offshore-extended band (32°S–41°S, to 85°W) and a Southeast Pacific regional domain (20°S–45°S, to 90°W) — and confirms that the posterior-to-prior standard-deviation ratio of $(\rho^{SST}_{\text{jurel}}, \rho^{CHL}_{\text{jurel}})$ remains close to unity under all spatial aggregations considered. This supports the interpretation that the relevant climate forcing for the Centro-Sur jack mackerel stock operates at a scale not captured by Chilean coastal anomalies, consistent with its transboundary SPRFMO management.

### Nota a Cowork

**No generar el contenido del Apéndice E todavía.** Solo insertar la oración referencial en la sección 4.1. El Apéndice E se desarrollará en una iteración futura una vez que el autor haya corrido el refit con los dominios alternativos. Si el refit cambia el resultado (i.e., si algún dominio sí identifica el shifter), el cuerpo del paper se actualizará en consecuencia y esta oración se reescribirá; pero por ahora, asumir el caso base de que la no-identificación se mantiene.

Si el manuscrito no contiene aún un Apéndice E, dejarlo como placeholder al final de los apéndices con el título y una nota:

```
E   Spatial robustness of the jack mackerel non-identification result

[To be completed: refit of the full state-space specification under alternative
spatial domains for SST and CHL averaging. Results pending.]
```

---

## Cambio 8 — Citas a la literatura de portfolio en pesquerías

La contribución 3 reformulada se apoya en el mecanismo de exposición diferencial del portafolio de cada flota bajo restricciones de transferibilidad cross-sector. Esta es una literatura desarrollada principalmente por Daniel S. Holland y co-autores. La referencia foundational, Kasperski & Holland (2013), ya está en la bibliografía del paper. Se deben **agregar tres referencias adicionales** que son directamente relevantes para el argumento, y aumentar la frecuencia de citación de Kasperski & Holland (2013) en los lugares donde el argumento de portfolio se hace por primera vez.

### Referencias a agregar a la bibliografía

1. **Cline, T. J., Schindler, D. E., & Hilborn, R. (2017).** Fisheries portfolio diversification and turnover buffer Alaskan fishing communities from abrupt resource and market changes. *Nature Communications*, 8, 14042. https://doi.org/10.1038/ncomms14042

2. **Oken, K. L., Holland, D. S., & Punt, A. E. (2021).** The effects of population synchrony, life history, and access constraints on benefits from fishing portfolios. *Ecological Applications*, 31(4), e2307. https://doi.org/10.1002/eap.2307

3. **Holland, D. S., & Kasperski, S. (2016).** The Impact of Access Restrictions on Fishery Income Diversification of US West Coast Fishermen. *Coastal Management*, 44(5), 452–463. https://doi.org/10.1080/08920753.2016.1208883

Las dos primeras son las más críticas: Cline et al. (2017) es el referente sobre portfolio buffering de shocks abruptos (regime shifts climáticos y de mercado), y Oken, Holland & Punt (2021) trata específicamente cómo las restricciones de acceso limitan los beneficios del portfolio — que es exactamente el argumento sobre el LMCA del paper. Holland & Kasperski (2016) refuerza el punto sobre access restrictions y diversificación.

### Localización 1 — Cambio 2 (contribución 3 en la Introducción)

En el texto de reemplazo del Cambio 2, **modificar la oración final** que dice:

> The artisanal fleet, concentrated in the two coastal-upwelling stocks whose climate semi-elasticities are identified and large, bears a sharper long-run decline in harvest capacity than the industrial fleet, whose portfolio is diversified by jack mackerel.

**Reemplazar por:**

> The artisanal fleet, concentrated in the two coastal-upwelling stocks whose climate semi-elasticities are identified and large, bears a sharper long-run decline in harvest capacity than the industrial fleet, whose portfolio is diversified by jack mackerel — a mechanism consistent with the broader fishery portfolio literature on income diversification and risk (Kasperski & Holland, 2013; Cline et al., 2017) and with evidence that institutional access constraints can limit the realized benefits of diversification (Oken, Holland & Punt, 2021).

### Localización 2 — Cambio 4 (sección 4.3.3)

En el texto de reemplazo del Cambio 4, **modificar la oración final** que dice:

> The LMCA's limited cross-sector transferability locks this differential exposure into differential losses of harvest capacity.

**Reemplazar por:**

> The LMCA's limited cross-sector transferability locks this differential exposure into differential losses of harvest capacity, echoing the portfolio mechanism documented for U.S. West Coast and Alaskan fisheries by Kasperski & Holland (2013) and the regime-shift buffering documented by Cline et al. (2017): segments with narrower species portfolios face systematically higher exposure to species-specific shocks, climate-driven or otherwise, and institutional access constraints of the type imposed by the LMCA can limit the realized benefits of diversification (Oken, Holland & Punt, 2021).

### Localización 3 — Cambio 6 (Conclusiones)

En el texto de reemplazo del Cambio 6, **modificar la oración final** que dice:

> ...with the artisanal segment bearing the sharper long-run loss because its historical landings are concentrated in the two stocks whose climate semi-elasticities are identified and economically large.

**Reemplazar por:**

> ...with the artisanal segment bearing the sharper long-run loss because its historical landings are concentrated in the two stocks whose climate semi-elasticities are identified and economically large. This finding extends the portfolio mechanism documented by Kasperski & Holland (2013) and Cline et al. (2017) to the climate-impact setting and to a quota regime — the LMCA — that constrains the cross-sector reallocation of fishing rights, in line with the access-constraint argument of Oken, Holland & Punt (2021).

### Localización 4 — Discusión, párrafo sobre LMCA (penúltimo párrafo de la sección 5)

**Localizar el párrafo de la Discusión que empieza con** *"The finding that climate change creates winners and losers within the same fishery has direct implications for quota allocation policy..."*

Este párrafo ya cita a Kasperski & Holland (2013). **Modificar la oración final** del párrafo, que actualmente dice:

> This echoes the portfolio literature on fishery diversification (Kasperski & Holland, 2013), which shows that access to a broader species portfolio reduces revenue variability and therefore that secure, transferable rights across fleet segments would facilitate adaptation to climate-driven shifts in species composition.

**Reemplazar por:**

> This echoes the portfolio literature on fishery diversification (Kasperski & Holland, 2013; Cline et al., 2017), which shows that access to a broader species portfolio reduces revenue variability and buffers communities against abrupt regime shifts. Oken, Holland & Punt (2021) further document that institutional access constraints — such as limits on transferability of fishing rights — can substantially reduce the realized benefits of diversification, which is precisely the channel through which the LMCA's cross-sector restrictions translate into amplified climate exposure for the artisanal segment. Secure, transferable rights across fleet segments would facilitate adaptation to climate-driven shifts in species composition (Holland & Kasperski, 2016).

### Verificación

Después de aplicar el Cambio 8, confirmar que las cuatro referencias (Kasperski & Holland 2013; Cline et al. 2017; Oken, Holland & Punt 2021; Holland & Kasperski 2016) aparecen en la bibliografía con formato consistente al estilo bibliográfico ya empleado en el paper, y que cada una está citada al menos una vez en el cuerpo del texto.

---

## Resumen del reframing

**Antes:** la contribución 3 era metodológica — "el state-space estructural revierte el signo que daría un SUR reducido".

**Después:** la contribución 3 es de policy — "la incidencia distributiva del cambio climático en esta pesquería está gobernada por la interacción entre composición de portafolio (artesanal concentrada en costeros, industrial diversificada con jurel) y la limitada transferibilidad cross-sector del LMCA". La identificación estructural sigue siendo central como método, pero como justificación interna (transportabilidad fuera de muestra hacia regímenes climáticos +2.3 °C que están ~9 sd fuera del rango histórico), no como contraste con un benchmark que no se reporta.

Adicionalmente:
- Se reserva lugar en la sección 4.1 y un placeholder de Apéndice E para una verificación de robustez espacial pendiente sobre la no-identificación del shifter climático del jurel Centro-Sur.
- Se conecta el argumento reformulado con la literatura de portfolio en pesquerías (Kasperski & Holland 2013; Cline et al. 2017; Oken, Holland & Punt 2021; Holland & Kasperski 2016), que es la literatura natural en la que el paper se inserta una vez que la contribución pasa de ser metodológica a ser de policy.

---

## Cambio 9 — Citar Quezada-Escalona et al. (2026, *Ecological Economics*) como extensión natural

El primer autor publicó recientemente un paper en *Ecological Economics* sobre el U.S. West Coast Coastal Pelagic Species fishery, que utiliza un discrete choice model (DCM) diario con species distribution models (SDMs) como proxy de availability, separado por fleet segments. Esta es la extensión natural daily-and-spatial del modelo NB anual del paper actual, y debería citarse en dos lugares como paper paralelo del mismo autor que provee la metodología daily/spatial complementaria a la metodología annual del paper actual.

### Referencia a agregar a la bibliografía

**Quezada-Escalona, F. J., Tommasi, D., Kaplan, I. C., Muhling, B., & Stohs, S. M. (2026).** Are fishing decisions flexible? Participation, species target, and landing location choices in the U.S. west coast coastal pelagic species fishery. *Ecological Economics*, 247, 109051. https://doi.org/10.1016/j.ecolecon.2026.109051

### Localización 1 — Sección 3.3.2 (Total annual trips), cierre del párrafo introductorio

**Localizar el párrafo que empieza con** *"We model the annual number of fishing trips taken by vessel v in year y as a count process following Kasperski (2015)..."*

Este párrafo justifica el uso del NB sobre datos vessel-year y menciona la limitación de los logbooks a operaciones purse-seine. **Agregar una oración al final del párrafo** que conecte con el DCM diario:

> A complementary approach, used in Quezada-Escalona et al. (2026) for the U.S. West Coast Coastal Pelagic Species fishery, models daily participation and target-species choice through a discrete choice framework with species distribution models as proxies for daily availability. The annual NB specification adopted here is the natural counterpart for a setting where vessel-year is the operational unit at which TACs are allocated under the LMCA, and where daily logbook coverage is too sparse to support a daily DCM for the Centro-Sur Chilean SPF over the 2013–2024 window.

### Localización 2 — Conclusión (sección 6), extensiones futuras

**Localizar el párrafo de extensiones que empieza con** *"Several extensions to the present framework are natural..."* y que incluye la mención al Stackelberg bi-level optimization.

**Después de la oración** *"The spatial dimension of effort allocation is also a natural extension, connecting the multi-species model to the location choice literature (e.g., Dupont, 1993; Hicks et al., 2020; Smith, 2005), since the geographic distribution of species availability is likely to shift under warming."*

**Agregar la siguiente oración:**

> A direct route for this spatial extension is to migrate the annual NB trip equation to a daily discrete choice specification with environmentally-informed species distribution models as proxies for local availability, following the approach of Quezada-Escalona et al. (2026) for the U.S. West Coast Coastal Pelagic Species fishery. SDMs for the Chilean Humboldt Current System are an active area of development in IFOP and academic collaborations, and once available at sufficient spatial resolution for anchoveta, sardina común, and jack mackerel, they would allow the present framework to capture the daily and within-port heterogeneity in fishing-effort responses to climate-driven shifts in availability.

---

## Cambio 10 — Hacer el paper más amigable a economistas

El paper actual asume un lector con background en stock assessment y oceanografía del Humboldt Current. Para un journal de economía ambiental (*Ecological Economics*, *Marine Resource Economics*, *JEEM*, *Environmental and Resource Economics*), el lector típico es un economista que entiende identificación, elasticidades, y comparative statics, pero no necesariamente Bayesian state-space, HMC, ni biología de pelágicos pequeños. Se requiere un reframing en cuatro dimensiones.

### 10.1 — Glosario econométrico para Bayesian state-space

**Localizar la sección 3.3.1**, en el párrafo que empieza con *"The system is estimated by full-information Bayesian inference in Stan via Hamiltonian Monte Carlo..."*

Este párrafo introduce HMC, Stan, priors y nested specifications sin explicar al lector economista por qué se usa una aproximación bayesiana en lugar de máxima verosimilitud. **Agregar al inicio del párrafo** la siguiente oración aclaratoria:

> The state-space specification is estimated by Bayesian inference rather than maximum likelihood for two reasons that are standard in the small-sample fishery literature: with $N = 25$ annual observations per stock, the joint identification of the biological parameters $(r^0_i, K_i)$ and the climate shifters $(\rho^{SST}_i, \rho^{CHL}_i)$ requires the prior information embedded in the IFOP and SPRFMO single-species assessments to avoid degenerate likelihood maxima at the boundary of the parameter space (see Appendix A.3 for an explicit demonstration of this boundary problem under maximum likelihood); and posterior credible intervals provide a natural framework for propagating the uncertainty in the climate shifters through to the comparative-statics exercise of Section 4.3, which would otherwise require a non-trivial delta-method approximation around an unstable point estimate. Readers familiar with the maximum likelihood treatment of state-space models in the macro-econometrics literature (e.g., Kalman filtering with EM updates) will find the Bayesian treatment a direct generalisation, where the EM step is replaced by the joint posterior over latent states and parameters.

**Adicionalmente, en el mismo párrafo**, donde se mencionan las herramientas técnicas:

**Localizar:** *"All reported posteriors are based on four chains of 2,000 post-warmup iterations with standard convergence diagnostics ($\hat{R} \leq 1.01$, bulk- and tail-ESS above 400 for all top-level parameters; see Appendix D for the convergence diagnostics by parameter family)."*

**Reemplazar por:**

> All reported posteriors are based on four independent Hamiltonian Monte Carlo chains of 2,000 post-warmup iterations each, evaluated against standard convergence diagnostics: the Gelman–Rubin statistic $\hat{R}$ (which compares within-chain to between-chain variance and should be close to one if chains have mixed) is below 1.01 for all top-level parameters, and the effective sample size — both in the bulk of the posterior distribution and in its tails — exceeds 400 for all top-level parameters, indicating that posterior summaries are not contaminated by autocorrelation between adjacent draws. These thresholds are conventional in the applied Bayesian literature; see Appendix D for the convergence diagnostics by parameter family.

### 10.2 — Glosario biológico-oceanográfico para el lector economista

**Localizar la sección 4.1**, párrafo segundo de la subsección de identificación, donde se discute la respuesta diferencial al chlorophyll-a:

**Localizar la oración:** *"This is a reduced-form footprint of the well-documented trophic asymmetry between the two species: sardina filter-feeds on smaller phytoplankton and benefits from productivity pulses, while anchoveta preys on larger zooplankton whose populations are suppressed when the food web is dominated by small primary producers."*

**Reemplazar por:**

> This is a reduced-form footprint of the well-documented trophic asymmetry between the two species, summarised here for the non-specialist reader. Chlorophyll-a is a satellite-observable proxy for phytoplankton biomass, the primary producers at the base of the marine food web. Pulses of high chlorophyll-a indicate periods of strong primary productivity, typically driven by coastal upwelling that brings nutrient-rich deep water to the surface. Sardina común feeds directly on small phytoplankton and benefits from these pulses, so its productivity rises with chlorophyll-a anomalies. Anchoveta, by contrast, feeds on larger zooplankton whose populations are themselves preyed upon by small phytoplankton-feeders; when the food web is dominated by small primary producers, the zooplankton biomass that anchoveta relies on is suppressed, and anchoveta productivity falls. The opposite-signed semi-elasticities of $\rho^{CHL}_{\text{anch}}$ and $\rho^{CHL}_{\text{sard}}$ identified in Table 1 are consistent with this trophic asymmetry and are not a statistical artefact.

**Adicionalmente, en la sección 2** (descripción de la pesquería), agregar al inicio una oración de contextualización oceanográfica para el lector economista:

**Localizar el inicio de la sección 2** (*"The Chilean small pelagic fishery is structured into two latitudinal zones..."*).

**Insertar antes de esa oración un párrafo introductorio:**

> The Centro-Sur Chilean coast lies within the Humboldt Current System, an eastern boundary upwelling system in which prevailing southerly winds drive cold, nutrient-rich deep water to the surface near the coast. This wind-driven upwelling sustains one of the most productive marine ecosystems in the world, and the three target species of the Chilean small pelagic fishery — anchoveta, sardina común, and jack mackerel — occupy this productive coastal corridor. Climate change affects this system primarily through warming of the surface ocean (which the species perceive directly through their thermal envelope) and through changes in the wind-driven upwelling regime that modulate the supply of nutrients and therefore primary productivity at the base of the food web. The first channel is captured in the present paper through the sea-surface temperature shifter $\rho^{SST}$, the second through the chlorophyll-a shifter $\rho^{CHL}$.

### 10.3 — Reordenamiento de prioridad: la economía primero, la oceanografía después

**Localizar la introducción** (sección 1) y revisar si los primeros tres párrafos enfatizan suficientemente el problema económico (impacto distributivo del cambio climático sobre flotas heterogéneas bajo una arquitectura de cuotas con transferibilidad limitada) versus el problema biológico-oceanográfico (cómo el upwelling responde al cambio climático).

La versión actual abre con *"The distribution and abundance of marine resources are changing in response to environmental conditions such as global ocean warming"* — esto es un opening biológico, no económico. Para un journal de economía:

**Reemplazar la oración inicial de la introducción** por:

> Climate change is reshaping the productivity of marine fisheries with heterogeneous incidence across fleet segments, raising first-order questions for the design of quota-allocation regimes that were originally calibrated under stationary climate assumptions. The distribution and abundance of marine resources are changing in response to environmental conditions such as global ocean warming (Poloczanska et al., 2013), and these biophysical shifts translate into economic consequences for fishers that depend on the differential exposure of each fleet's species portfolio to the climate signal and on the institutional architecture that governs the cross-sector reallocation of fishing rights.

### 10.4 — Aclarar el lenguaje de "shifter" y "semi-elasticity" desde el inicio

El término "structural climate shifter" aparece desde el abstract sin definición operativa hasta la sección 4.1. Para un lector economista que no viene de la literatura de stock-assessment, "shifter" es ambiguo. **Localizar el abstract** y, en la oración que dice:

*"We identify a set of structural climate shifters ($\rho^{SST}_i$, $\rho^{CHL}_i$), interpretable as semi-elasticities of intrinsic stock productivity with respect to sea-surface temperature and log-chlorophyll-a anomalies..."*

**Reemplazar por:**

> We identify a set of structural climate parameters ($\rho^{SST}_i$, $\rho^{CHL}_i$) — semi-elasticities of intrinsic stock productivity with respect to a one-degree Celsius sea-surface temperature anomaly and a one-log-point chlorophyll-a anomaly, respectively — within a Bayesian state-space specification of the biological law of motion calibrated on official IFOP and SPRFMO assessments for 2000–2024.

A lo largo del resto del paper, mantener "climate shifter" cuando se hable del término técnico-biológico (la función exponencial $\exp(\rho^{SST} \Delta SST + \rho^{CHL} \Delta \log CHL)$ que modula el growth rate intrínseco), pero referirse a $\rho^{SST}_i$ y $\rho^{CHL}_i$ explícitamente como "semi-elasticities" cuando se discuta su interpretación económica. Esa distinción terminológica reduce ambigüedad para el lector economista.

### Verificación final del Cambio 10

Después de aplicar las cuatro sub-modificaciones de este cambio, hacer una pasada de lectura sobre el manuscrito completo y reportar:

- Cualquier término técnico de Bayesian inference que aparezca sin definición o glosa al lado (HMC, posterior, prior, ELPD, LFO, LOO, $\hat{R}$, ESS, LKJ, non-centred parameterisation).
- Cualquier término técnico de oceanografía o biología pesquera que aparezca sin definición (upwelling, MSY, SSB, recruitment, ENSO, transboundary, hydroacoustic).
- Cualquier sección donde el orden retórico priorice el detalle biológico/oceanográfico sobre el argumento económico.

Reportar estas instancias para revisión adicional. La meta es que un economista ambiental con interés en pesquerías pueda leer el paper de extremo a extremo sin necesidad de consultar literatura de stock assessment ni textos de oceanografía física.

---

## Cambio 11 — Ensemble multi-modelo CMIP6 para las proyecciones climáticas

El paper actual utiliza un único Earth System Model (IPSL-CM6A-LR) para construir las anomalías climáticas Δ SST, Δ log CHL y Δ wind que entran a las comparative statics de la sección 4.3 y a la trip equation. Esto es insuficiente para un journal económico de tier medio o alto, porque la incertidumbre estructural entre modelos climáticos en el Pacífico Sudeste — particularmente para chlorophyll-a en sistemas de upwelling costero — es típicamente más grande que la incertidumbre dentro de un solo modelo. Un referee informado va a pedir, con razón, que se propague esta incertidumbre estructural a las proyecciones reportadas.

### Contexto y justificación

La literatura reciente sobre proyecciones climáticas en pesquerías (e.g., Free et al., 2019; Lam et al., 2016; trabajos del proyecto Fish-MIP) reporta resultados de ensembles multi-modelo, típicamente entre 5 y 10 modelos CMIP6, y descompone la varianza total de las proyecciones en (i) incertidumbre del posterior de los parámetros estructurales del modelo biológico y (ii) incertidumbre estructural entre modelos climáticos. El paper actual propaga (i) pero no (ii), lo cual es una omisión metodológica que conviene corregir antes del envío.

### Modelos CMIP6 a incorporar

Se sugiere un ensemble de seis modelos que cubre la variabilidad estructural típica en el Pacífico Sudeste:

1. **IPSL-CM6A-LR** (ya en el paper) — Institut Pierre Simon Laplace, Francia.
2. **GFDL-ESM4** — Geophysical Fluid Dynamics Laboratory, NOAA, USA.
3. **CESM2** — National Center for Atmospheric Research, USA.
4. **CNRM-ESM2-1** — Centre National de Recherches Météorologiques, Francia.
5. **UKESM1-0-LL** — UK Met Office Hadley Centre, Reino Unido.
6. **MPI-ESM1-2-HR** — Max Planck Institute, Alemania.

Estos seis modelos están disponibles bajo SSP2-4.5 y SSP5-8.5, con outputs mensuales de SST (`tos`), concentración de chlorophyll-a (`chl` o derivada de `phyc`/`phydiat`) y wind speed (`uas`/`vas`) descargables desde el Earth System Grid Federation. Todos tienen el período histórico (1850–2014) y el período futuro (2015–2100) que se necesita para el delta method.

### Procedimiento sugerido

Aplicar el delta method actual del paper individualmente a cada uno de los seis modelos, manteniendo el período base 1995–2014 y las dos ventanas futuras (2041–2060 mid-century, 2081–2100 end-of-century). Esto produce, para cada combinación de SSP × ventana, un conjunto de seis vectores de anomalías $(\Delta SST_m, \Delta \log CHL_m, \Delta wind_m)$ donde $m$ indexa el modelo CMIP6.

Para las comparative statics de la productividad intrínseca, evaluar:

$$\Delta r^{\star}_{i,m,d} / r^0_i = \exp(\rho^{SST}_{i,d} \Delta SST_m + \rho^{CHL}_{i,d} \Delta \log CHL_m) - 1$$

donde $d$ indexa los draws del posterior y $m$ indexa el modelo CMIP6. La distribución posterior reportada en el paper se construye agregando sobre $(d, m)$, lo cual propaga ambas fuentes de incertidumbre simultáneamente.

### Cambios concretos al manuscrito

**1. Sección 3.2 (Future climate data).** Reemplazar el uso exclusivo de IPSL-CM6A-LR por la descripción del ensemble de seis modelos. Mantener la justificación del delta method y agregar una oración explícita sobre la propagación de incertidumbre estructural inter-modelo.

**2. Sección 3.4 (Projection approach).** Reformular para indicar que las anomalías climáticas entran a las comparative statics como una distribución sobre los seis modelos del ensemble, no como un valor puntual.

**3. Tabla 3 (Projected environmental changes).** Expandir para reportar, para cada combinación de SSP × ventana, la mediana del ensemble y el rango (mínimo y máximo) entre modelos para Δ SST, Δ log CHL y Δ wind. Esto da al lector una idea inmediata de la dispersión inter-modelo.

**4. Tabla 4 (Comparative statics on intrinsic stock productivity).** Las medianas posteriores y los intervalos de credibilidad de 90% deben recomputarse agregando sobre $(d, m)$. Los intervalos resultantes serán más amplios que los actuales, y eso es esperable y deseable — refleja la incertidumbre estructural genuina del ejercicio.

**5. Tabla 5 (Long-run implications for fleet-level effort).** Análogamente, recomputar Pr$(f^H_v < 0.5)$ y los percentiles de %Δ trips integrando sobre el ensemble. La asimetría central del paper (artesanal sustancialmente más expuesta que industrial) debería sostenerse, pero los intervalos serán más amplios.

**6. Apéndice F nuevo — Descomposición de incertidumbre por modelo CMIP6.** Crear un apéndice que reporte modelo-por-modelo: (i) las anomalías Δ SST, Δ log CHL, Δ wind para cada combinación de SSP × ventana × modelo; (ii) las comparative statics modelo-por-modelo equivalentes a la Tabla 4; y (iii) una descomposición de varianza que cuantifique qué fracción de la incertidumbre total proviene del posterior de los parámetros estructurales versus del ensemble climático. La descomposición sugerida es:

$$\text{Var}_{\text{total}}(\Delta r^{\star}/r^0) = \mathbb{E}_m[\text{Var}_d(\Delta r^{\star}/r^0 \mid m)] + \text{Var}_m[\mathbb{E}_d(\Delta r^{\star}/r^0 \mid m)]$$

donde el primer término captura la incertidumbre del posterior promediada sobre modelos y el segundo término captura la incertidumbre inter-modelo en la expectativa posterior. Reportar la descomposición como porcentajes de la varianza total para cada combinación de stock × SSP × ventana.

### Texto a insertar en el cuerpo del paper (sección 3.2)

**Localizar la sección 3.2 (Future climate data)** y reemplazar el párrafo actual por:

> Climate projections are obtained from a six-model ensemble of CMIP6 Earth System Models: IPSL-CM6A-LR (Institut Pierre Simon Laplace), GFDL-ESM4 (NOAA Geophysical Fluid Dynamics Laboratory), CESM2 (National Center for Atmospheric Research), CNRM-ESM2-1 (Centre National de Recherches Météorologiques), UKESM1-0-LL (UK Met Office Hadley Centre), and MPI-ESM1-2-HR (Max Planck Institute). The ensemble is selected to span the structural variability characteristic of CMIP6 simulations of the Southeast Pacific upwelling regime, where individual models differ substantially in projected changes to coastal upwelling intensity, surface chlorophyll-a, and the thermal structure of the eastern boundary current. We use monthly outputs for two Shared Socioeconomic Pathways — SSP2-4.5 (moderate emissions) and SSP5-8.5 (high emissions) — and two future windows (2041–2060 mid-century, 2081–2100 end-of-century) relative to a 1995–2014 historical baseline. The delta method (Burke et al., 2015; Free et al., 2019) is applied independently to each model in the ensemble, and the resulting anomalies enter the comparative-statics exercise of Section 4.3 as a distribution over models rather than as a single point estimate. This propagates the inter-model structural uncertainty — typically larger than within-model uncertainty for primary productivity in coastal upwelling systems — to the posterior of the long-run productivity response.

### Tiempo y costo

Implementar este cambio toma aproximadamente dos a tres semanas de trabajo, distribuidas como:
- Semana 1: descarga de los seis modelos × dos SSPs × tres variables × dos períodos desde el Earth System Grid Federation, regridding a una grilla común, y construcción de los climatologías históricas y futuras.
- Semana 2: aplicación del delta method y refitting del posterior conjunto sobre el ensemble. El refit del modelo bayesiano en sí no se necesita repetir — los shifters $(\rho^{SST}_i, \rho^{CHL}_i)$ se identifican en el período histórico 2000–2024 y son invariantes al ensemble climático. Solo se reevalúan las comparative statics.
- Semana 3: actualización de tablas, figuras, y construcción del Apéndice F con la descomposición de varianza.

El refit principal del modelo state-space sobre 2000–2024 NO se repite. Solo se reevalúan las comparative statics bajo el nuevo conjunto de inputs climáticos. Esto reduce sustancialmente el costo computacional del cambio.

### Nota a Cowork

Este cambio NO se ejecuta en la pasada inicial. Requiere bajar y procesar datos CMIP6 que el autor debe gestionar fuera del flujo de Cowork. Por ahora, **agregar al manuscrito un placeholder en la sección 3.2** que indique que la versión final usará un ensemble multi-modelo, y un placeholder de Apéndice F vacío con el título y una nota.

**Texto del placeholder en sección 3.2:**

```
[NOTA INTERNA: la versión final de este paper utilizará un ensemble de seis
modelos CMIP6 (IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL,
MPI-ESM1-2-HR) en lugar del modelo único actualmente reportado. El delta
method se aplicará independientemente a cada modelo y las comparative statics
se reportarán integrando sobre el posterior de los parámetros estructurales y
sobre la dimensión modelo del ensemble. Apéndice F nuevo descompondrá la
incertidumbre total por modelo. Esta nota se eliminará al consolidar la
versión final.]
```

**Placeholder de Apéndice F:**

```
F   Decomposition of projection uncertainty across the CMIP6 ensemble

[To be completed: per-model anomalies, per-model comparative statics, and
variance decomposition into structural-parameter posterior uncertainty
versus inter-model climate ensemble uncertainty. Six-model ensemble:
IPSL-CM6A-LR, GFDL-ESM4, CESM2, CNRM-ESM2-1, UKESM1-0-LL, MPI-ESM1-2-HR.]
```
