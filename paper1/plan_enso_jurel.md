# Plan de extensión: ENSO como shifter climático para jurel CS

## Contexto

El paper actual identifica shifters climáticos (ρ_SST, ρ_CHL) para anchoveta y sardina común con buena precisión sobre el dominio Centro-Sur (D1: 32°S–42°S, costa chilena), pero reporta no-identificación para jurel (σ_post/σ_prior ≈ 1). El Apéndice E robustece este nulo con tres tests (dominios espaciales, dual-source con serie Norte, fallo OROP-PS), pero hay tensión con literatura que documenta efectos climáticos sobre jurel — Arcos et al. (2001) sobre El Niño 1997–98 e intrusión del isotermo 15°C, Peña-Torres et al. (2017) sobre ENSO y location choices, y Espinoza et al. (2013) sobre PDO/SOI y disponibilidad de jurel en el sistema peruano.

**Hipótesis a testear:** el forzamiento climático relevante para jurel CS opera a escala basin-scale vía teleconexiones ENSO, no vía las anomalías costeras locales que identifican a anchoveta y sardina.

## Decisión de especificación

- **Anchoveta y sardina:** mantener exactamente como están con (SST_D1, log CHL_D1). Funcionan, los ratios σ_post/σ_prior de 0.43–0.83 muestran updating sustancial, los signos son interpretables, y la elección encaja con Cahuin et al. (2009) y Yáñez et al. (2014). No tocar.
- **Jurel:** reemplazar (SST_D1, log CHL_D1) — que ya sabes que no identifica nada — por un único shifter ENSO basado en SST anomaly sobre la región Niño 3.4 (5°N–5°S, 170°W–120°W).
- **Implementación:** vía la generalización stock-specific Eq. 11 del Apéndice E que ya está implementada en el pipeline.

## Sobre la variable ENSO

ENSO se construye con la misma variable física que ya usás (SST, `tos` o superficie de `thetao` en CMIP6) pero promediada sobre un bounding box distinto. No es una variable nueva en términos de pipeline; es un re-extract sobre otras coordenadas:

- **Bounding box Niño 3.4:** lat ∈ [-5°, +5°], lon ∈ [-170°, -120°] (o equivalente en convención 0–360°: lon ∈ [190°, 240°]).
- **Construcción del índice:** anomalía mensual de SST sobre Niño 3.4 relativa a la climatología 2000–2024, agregada anualmente (media simple o promedio sobre meses peak DJF, según la convención que prefiera la literatura que cites).
- **Para el período histórico:** se puede construir desde el mismo Copernicus GLORYS12V1 (extendiendo el bounding box) o desde NOAA OISST que es el estándar del campo. Recomendaría OISST por ser la fuente canónica que usan Arcos y Peña-Torres.
- **Para las proyecciones CMIP6:** mismo `tos` o `thetao` superficial de los seis modelos del ensamble, sobre Niño 3.4. Aplicás el delta method igual que ya lo aplicás para SST_D1.

**Caveat a documentar:** los modelos CMIP6 tienen sesgos conocidos en amplitud y asimetría de ENSO. Las proyecciones de cambios futuros en frecuencia/intensidad de ENSO bajo SSP5-8.5 son área activa de debate. Como semi-elasticidad estructural sobre un índice basin-scale es defendible, pero el discussion debe reconocer esta limitación.

## Cómo entra ENSO en la proyección comparative-statics

Recordatorio importante sobre la naturaleza de la proyección del paper: **NO se proyecta biomasa año por año de 2025 a 2100**. Lo que se calcula es comparative statics de largo plazo — Δr*/r₀ bajo un clima contrafactual de equilibrio, no una trayectoria dinámica. Para cada celda (escenario × ventana × modelo CMIP6), el delta climático es un solo número: la diferencia entre la climatología de la ventana futura (2041–2060 o 2081–2100) y el baseline histórico spliceado (2000–2024). Ese delta entra una vez al shifter y produce una posterior de Δr*/r₀. La biomasa de Tabla 5 es Schaefer steady-state B* = K · (1 − F_hist/r*), también punto fijo de equilibrio.

**Aplicado a ENSO**, la lógica es idéntica:

- ΔENSO_{ventana, modelo} = media del índice Niño 3.4 sobre la ventana futura bajo el escenario, menos media histórica spliced sobre 2000–2024.
- Un valor escalar por celda. No se proyectan trayectorias de eventos El Niño individuales.
- Lo que se proyecta es el cambio en la **media** del estado climático ecuatorial, no la variabilidad interanual.

**Caveat adicional específico de ENSO** (a documentar en el discussion): ENSO es fundamentalmente un fenómeno de variabilidad interanual, así que el delta de la media puede ser pequeño aunque la frecuencia o amplitud de eventos cambie sustancialmente bajo SSP5-8.5. Si jurel responde a la **amplitud** de eventos ENSO más que al estado medio, este enfoque comparative-statics subestimaría el efecto. La literatura CMIP6 sobre cambios futuros en frecuencia/amplitud de ENSO es activa y disensada — Cai et al. han documentado posible aumento en eventos extremos pero el spread inter-modelo es amplio. Reconocer esta limitación explícitamente y, si los datos lo permiten, reportar también la posterior bajo un delta calculado sobre la **varianza** del índice Niño 3.4 como sensibilidad complementaria.

## Pasos operativos

1. **Re-extract de SST sobre Niño 3.4 para el período histórico.** Decidir entre extender el pull de Copernicus o usar OISST. OISST es más estándar pero requiere agregar una fuente al pipeline.
2. **Construcción del índice anual ENSO** sobre 2000–2024, centrado en su media muestral, paralelo a cómo centrás SST_D1 y log CHL_D1.
3. **Re-extract de SST CMIP6 sobre Niño 3.4** para los seis modelos del ensamble, escenarios SSP2-4.5 y SSP5-8.5, ventanas mid-century y end-of-century. Aplicar delta method.
4. **Refit del state-space full** vía la Eq. 11 stock-specific del Apéndice E:
   - Anchoveta: forzada por (SST_D1, log CHL_D1) — sin cambios.
   - Sardina común: forzada por (SST_D1, log CHL_D1) — sin cambios.
   - Jurel: forzada por ENSO (un solo shifter, ρ_ENSO_jurel).
5. **Estructura de lag para jurel: testear lag 1 año y lag 2 años.** Tu Eq. (2) actual usa lag de 1 año (X_{t-1}) para anchoveta y sardina, y eso se mantiene. Para jurel ENSO, Arcos et al. (2001) documenta lag de ~1–2 años entre eventos ENSO y respuesta de juveniles, y Espinoza et al. (2013) consistente. Especificación a correr:
   - Fit principal: jurel con ENSO_{t-1} (paralelo a costeros, comparabilidad).
   - Sensibilidad: jurel con ENSO_{t-2} como specification check.
   - Reportar ambos σ_post/σ_prior y elegir el principal según identificación; documentar el otro en apéndice.
6. **Prior para ρ_ENSO_jurel.** Usar 𝒩(0, 1) deliberadamente vago, como el prior actual de jurel — no querés sesgar la identificación con un prior informativo basado en la literatura cualitativa. La interpretación posterior debe nacer del likelihood.
7. **Diagnóstico de identificación:** reportar σ_post/σ_prior y el 90% CI. Threshold informal: si baja a 0.7 o menos, identificación positiva; si queda cerca de 1, nulo confirmado.
8. **Recalcular Tabla 4 y Tabla 5** con jurel proyectado bajo ENSO (o, si el shifter no identifica, propagando el prior completo en lugar de fijar factor_B = 1).
9. **Variance decomposition (Apéndices F y G)** se actualiza naturalmente al recorrer el pipeline.

## Escenarios de resultado y cómo presentar cada uno

**Escenario A — ENSO identifica (σ_post/σ_prior ≤ 0.7):**
- Convertís el null de jurel en identificación positiva.
- Discussion: "el forzamiento relevante para jurel CS opera a escala basin-scale vía teleconexiones ENSO, no vía anomalías costeras — consistente con Arcos et al. (2001), Peña-Torres et al. (2017) y Espinoza et al. (2013) para el sistema peruano".
- La asimetría 11:1 flota-flota se recalcula y probablemente se atenúa o redirecciona, pero ahora con base estructural defendible para los tres stocks.
- El paper gana sustancialmente en identificación y narrative coherence.

**Escenario B — ENSO tampoco identifica:**
- Documentás que ni el candidato más obvio de la literatura levanta señal en este sample.
- Esto **fortalece** el null original en lugar de debilitarlo: cuatro líneas de evidencia convergente (tres dominios espaciales del Apéndice E, dual-source con serie Norte, fallo OROP-PS, y ahora ENSO).
- Discussion: "los efectos climáticos sobre jurel documentados por Arcos et al. (2001), Peña-Torres et al. (2017) y Espinoza et al. (2013) operan probablemente sobre márgenes — distribución espacial, comportamiento de localización, disponibilidad regional — que no se mapean en la elasticidad de productividad estructural a escala anual".
- En este escenario se gatilla el experimento PDO (ver sección siguiente) como segundo intento antes de cerrar el null.
- La conclusión de policy se mantiene pero con caveat más explícito.

En cualquiera de los dos escenarios, ENSO mejora el paper. Es una apuesta con upside asimétrico.

## Fallback condicional: PDO si ENSO no identifica

**Sólo gatillar si Escenario B se materializa** (ENSO con lag 1 y lag 2 ambos no identifican).

PDO opera a escala decadal y modula el background state sobre el que ENSO actúa (Espinoza et al. 2013 lo documenta para jurel peruano). Con N=25 años tenés ~1–2 ciclos completos de PDO en la ventana, lo que es marginal para identificación pero defendible como sensibilidad.

- **Construcción:** índice PDO mensual desde NOAA/NCEI (basado en ERSST, fuente canónica). Agregar a anual sobre 2000–2024 y centrar.
- **Especificación:** reemplazar ENSO por PDO en el shifter de jurel (no agregar como segundo shifter — degrada identificación con N=25). Mantener anchoveta y sardina sin cambios.
- **Lag:** dado que PDO es decadal, el lag de 1 año sigue siendo razonable; testear lag 2 también por consistencia con la sensibilidad ENSO.
- **Para proyecciones CMIP6:** PDO es derivable de los modelos pero su proyección es menos directa que ENSO — implica calcular el patrón espacial de SST sobre Pacífico Norte y proyectarlo. Si PDO identifica históricamente pero no podés proyectarlo limpiamente desde CMIP6, el resultado entra como evidencia de identificación in-sample pero no se incorpora a Tabla 4/5; se reporta como hallazgo separado en discussion.
- **Si PDO tampoco identifica:** se documenta en el apéndice junto con ENSO. El null queda con cinco líneas de evidencia (tres dominios + dual-source + OROP-PS + ENSO + PDO), lo cual es virtualmente imposible de batir para un referee escéptico.

PDO no es experimento principal: es un seguro contra el peor caso. Si ENSO funciona, este paso se omite y queda como future work.

## Qué pasa con las otras 4 sugerencias previas

Las 4 sugerencias originales siguen siendo útiles pero cambian de prioridad una vez que ENSO entra:

1. **Sensibilidad propagando prior completo de jurel en proyecciones.** Baja a opcional condicional. Si ENSO identifica, ya no es necesaria. Si no identifica, se vuelve importante como única vía para mostrar que el "0.7–1.1% industrial" es punto estimado bajo asunción fuerte.

2. **Separar "no podemos identificar" de "no hay efecto" en discussion, citando Arcos, Peña-Torres y Espinoza.** Se mantiene y se vuelve *más fácil* con ENSO. En escenario A, citás los tres como confirmación del mecanismo basin-scale identificado. En escenario B, los citás como evidencia externa de efectos sobre márgenes que el sample no resuelve. Espinoza et al. (2013) es particularmente útil porque da evidencia comparativa transboundary (Perú) que complementa la chilena de Arcos y Peña-Torres.

3. **Cálculo de potencia: qué magnitud de ρ hubieras podido detectar con N=16 y σ_proc estimado.** Se mantiene y se vuelve más interesante. Corrés dos veces — una para (SST_D1, CHL_D1) y otra para ENSO. Si ENSO identifica con ratio 0.7 y los costeros no, el cálculo te dice si la diferencia refleja señal real o simplemente que ENSO tiene más varianza histórica (̂σ_SST_D1 = 0.26°C vs ENSO ±2°C). Implementación: simular biomasas bajo Schaefer con ρ fijado y ver con qué frecuencia el posterior excluye cero al 90%.

4. **Reordenar el triple-evidence package del Apéndice E para empezar con el problema de potencia bajo.** Independiente de ENSO. ENSO le da más fuerza al apéndice porque ahora tenés cuatro líneas de evidencia en vez de tres. Reordenando con potencia adelante y ENSO al final, el apéndice cuenta una historia más persuasiva.

## Priorización sugerida

1. **ENSO con lag 1** (experimento principal).
2. **ENSO con lag 2** (sensibilidad sí o sí, paralela al principal — bajo costo marginal una vez montado el pipeline).
3. **Cálculo de potencia** (sanity check que cualquier referee va a pedir).
4. **Wording del discussion** citando Arcos, Peña-Torres y Espinoza.
5. **PDO condicional** sólo si los dos lags de ENSO no identifican.
6. Sensibilidad con prior completo y reordering del Apéndice E quedan para segunda pasada después de ver qué dice ENSO.

## Notas técnicas adicionales

- El refit con Eq. 11 stock-specific ya está validado en el Apéndice E: el cambio en covariate de jurel no contamina las posteriors de anchoveta y sardina (≤ 0.03 sd de movimiento). El experimento ENSO hereda esta propiedad.
- Mantener ocho cadenas HMC de 2000 iteraciones post-warmup, adapt_delta = 0.99, max_treedepth = 14, igual que en el Apéndice E.
- Convergencia esperada: R̂ ≤ 1.01 para top-level. Si ρ_ENSO_jurel queda no identificado, posiblemente E-BFMI marginal igual que en la extensión dual-source — documentarlo si pasa.
- El bounding box Niño 3.4 está totalmente fuera del Pacífico Sudeste, así que no hay correlación espuria con SST_D1 que confunda la identificación de las costeras (chequear igual: Pearson r esperado < 0.3 entre SST_D1 anual y ENSO anual; si sale alto, pensar implicaciones).

## Archivos esperados a actualizar

- Pipeline R/01_data: script nuevo para extract Niño 3.4 histórico (Copernicus o OISST) y CMIP6. Si se gatilla PDO, agregar pull de PDO desde NOAA/NCEI.
- Pipeline R/02_models: refit T4b-full con shifter ENSO para jurel (lag 1 y lag 2 como specs paralelas), reusando arquitectura del Apéndice E. Si PDO se gatilla, fit adicional con PDO en lugar de ENSO.
- Tablas: Tabla 1 (identificación) gana fila ρ_ENSO_jurel (lag 1 y lag 2 si ambos relevantes); Tabla 4 y 5 se recalculan; Apéndice E gana sección sobre ENSO y, condicionalmente, sobre PDO.
- Figuras: Figura 3 (forest plot) gana entrada ρ_ENSO_jurel; Figura 4 (ridges de proyección) puede recuperar jurel si identifica.
- Texto: Sección 4.1 incorpora resultado ENSO; Sección 5 (discussion) incorpora citas a Arcos, Peña-Torres y Espinoza con marco basin-scale vs coastal.
