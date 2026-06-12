# Resumen ejecutivo

Para **sardina común** (Sardinops sagax) y **anchoveta chilena** (Engraulis ringens), los informes técnicos de IFOP señalan valores de mortalidad natural (M) usados en modelos edad-estructura, pero no reportan directamente parámetros logísticos *r* (tasa intrínseca de crecimiento) o *K* (capacidad de carga).  En la evaluación más reciente (Convenio IFOP-SUBPESCA 2021–2022):

- **Sardina común (V–X Regiones)**: modelo edad-estructura asume **M = 1.0 año⁻¹** constante【34†L1723-L1725】. No se estiman *r* o *K* en este enfoque (modelo basado en dinámica de edades con información de capturas, CPUE y cruceros acústicos). 
- **Anchoveta (III–IV Regiones, centro-norte)**: modelo edad-estructura usa **M = 1.3 año⁻¹**【56†L879-L888】. Tampoco estima *r* o *K* (modelo anual edad-estructurado con datos de CPUE, cruceros de huevos y acústicos).

Estos valores de **M** (en año⁻¹) reflejan supuestos de mortalidad natural constantes usados en las evaluaciones IFOP. Como fuentes alternativas complementarias, estudios logísticos y bioeconómicos aportan órdenes de magnitud de *r* y *K*:

- Un estudio binacional (Imarpe-IFOP 2018) para la **anchoveta sur de Perú – norte de Chile (XV–II Regiones, 1984–2015)** estimó *r* entre 0.44–0.59 y *K* entre 7.8 y 12.7 millones de toneladas【65†L2786-L2794】, según diversos modelos de producción (Martell & Froese, Zhou, Stock Synthesis).  
- Para la **sardina/anchoveta norte chilena (Regiones I–II, 1980–91)**, Cerda et al. (2001) ajustaron un modelo de Gordon-Schaefer conjunto encontrando *K* ≈ 4.3 Mt y *r* ≈ 1.15 año⁻¹【83†L464-L472】 (modelo bioeconómico simplificado). Estos valores son históricos y asumen ambas especies como único stock. 

En resumen, **IFOP adopta valores fijos de M** (1.0 y 1.3 año⁻¹ según especie/zona) y no provee *r/K*.  Los estudios adicionales sugieren que *r* para estas especies suele ser relativamente alto (>0.5 año⁻¹) y que *K* oscila en varios millones de toneladas【65†L2786-L2794】【83†L464-L472】.  Las estimaciones exactas varían con el método y la región. 

**Recomendaciones:** Para la modelación de manejo se aconseja usar *M* de orden ~1 año⁻¹ con su incertidumbre (p.ej. ±20%)【34†L1723-L1725】【56†L879-L888】.  Si se emplean modelos de producción (biomasa), se pueden utilizar *r/K* en los rangos indicados【65†L2786-L2794】【83†L464-L472】 como informaciones previas, con amplio margen de incertidumbre.  Es crucial considerar el efecto de cambios ambientales en *r* y *K*, y propagar la incertidumbre al calcular puntos de referencia (MSY, B0, FMSY). Finalmente, se recomienda integrar estos parámetros en evaluaciones integradas (VPA/SCAA, Stock Synthesis) con análisis de sensibilidad y validación con índices acústicos o de huevos. 

## Parámetros por especie

### Anchoveta (Engraulis ringens)

- **Mortalidad natural (M):** IFOP asume *M = 1.3 año⁻¹* en la evaluación de stock centro-norte (III–IV Regiones)【56†L879-L888】. Este valor es fijo y uniforme para todas las edades en el modelo edad-estructura.  
- **Tasa intrínseca (r) y capacidad de carga (K):** Los informes IFOP edad-estructura no estiman *r* ni *K*. Fuera de IFOP, un taller conjunto IMARPE–IFOP (2018) aplicó modelos de producción para anchoveta (1984–2015, sur de Perú + norte de Chile) y obtuvo rangos de *r* ≈ 0.44–0.59 año⁻¹ y *K* ≈ (7.8–12.7)×10^6 t【65†L2786-L2794】. Estos valores provienen de diferentes métodos (Martell-Froese, Zhou et al., Stock Synthesis) y reflejan incertidumbre entre enfoques. Otra fuente (Cerda et al. 2001) usando un modelo Gordon-Schaefer conjunto indicó *K* ≈ 4.3 Mt y *r* ≈ 1.15 año⁻¹ para la pesquería de anchoveta+sardina (norte de Chile) en 1980–91【83†L464-L472】, pero es un valor histórico y agregado. 

### Sardina común (Sardinops sagax)

- **Mortalidad natural (M):** IFOP usa *M = 1.0 año⁻¹* en la evaluación edad-estructura de sardina común (V–X Regiones)【34†L1723-L1725】. Al igual que en anchoveta, es un M anual constante.  
- **Tasa intrínseca (r) y capacidad de carga (K):** No se reportan en informes IFOP de evaluación de sardina (modelo SCAA). Como referencia, el modelo bioeconómico Gordon-Schaefer de Cerda et al. (2001) implicó *K* ≈ 4.3 Mt y *r* ≈ 1.15 año⁻¹ (para el sistema combinado sardina/anchoveta norte)【83†L464-L472】. Sin embargo, *r/K* específicos para sardina central-sur no están disponibles en fuentes IFOP; podrían ser estimados vía modelos de biomasa usando datos acústicos y de desembarque futuros.

## Tabla comparativa de parámetros poblacionales

| Especie            | Año/Informe        | Modelo / Método       | **M** (año⁻¹)     | **r** (año⁻¹)           | **K** (t) (×10^6)     | Fuente / Notas                                          |
|--------------------|--------------------|-----------------------|------------------|-------------------------|----------------------|---------------------------------------------------------|
| **Sardina común**  | Convenio 2021–22 IFOP (Valpo–X Regiones) | Edad-estructura SCAA【34†L1723-L1725】 | 1.0 (constante) | –                       | –                    | IFOP; M fijo, modelo SCAA anual, sin estimación de r/K.   |
| **Anchoveta**      | Convenio 2021–22 IFOP (III–IV Regiones) | Edad-estructura SCAA【56†L879-L888】 | 1.3 (constante) | –                       | –                    | IFOP; M fijo, modelo SCAA anual, sin estimación de r/K.   |
| **Anchoveta**      | Imarpe-IFOP (1984–2015) | Producción (Hilborn-Mangel, Stock Synthesis)【65†L2786-L2794】 | –                | 0.44–0.59                | 7.8–12.7            | Estimados con modelos de producción (varios) en stock combinado Perú–Norte Chile. |
| **Anchoveta+Sardina** | Cerda et al. (2001) – Chile norte (1980–91) | G-Schaefer *bioeconómico*【83†L464-L472】 | –                | 1.15                    | 4.3                 | Modelo simplificado tratado como 1 especie (sardina/anchoveta norte Chile).      |

Los valores de **K** están en toneladas métricas (10^6 t) y provienen de estimaciones de equilibrio de producción. Las incertidumbres típicas no se especifican en IFOP; en los modelos de producción citados se infiere un rango amplio (p.ej. percentiles 25–75). 

## Metodologías y fuentes

- **IFOP – Modelos edad-estructura (SCAA):** Los informes “Convenio de Desempeño” (e.g. 2021–2022) utilizan modelos estadísticos de dinámica estructurada por edad, integrando series de desembarque, CPUE e índices acústicos/huevos. Estos modelos estiman biomasa desovante y niveles de F, asumiendo *M* constante (1.0–1.3 año⁻¹). No utilizan una función de producción explícita, por lo cual no proporcionan *r* ni *K*【34†L1723-L1725】【56†L879-L888】. Los supuestos incluyen reclutamiento anual en pulso y mortalidad natural invariante. 
- **Modelos de producción (biomasa):** Estudios complementarios aplicaron modelos Schaefer/Hilborn-Mangel o Zhou et al. usando solo series de capturas (y en algunos casos índices). Por ejemplo, el taller Imarpe-IFOP (2018) ajustó estos modelos al stock de anchoveta (Perú+Chile) entre 1984–2015【65†L2786-L2794】. Estos métodos estiman simultáneamente *r*, *K* y referencia RMS/MSY, pero requieren supuestos sobre estado inicial, error y selección de priors.  
- **Modelos bioeconómicos:** Cerda et al. (2001) usaron un modelo de Gordon-Schaefer aplicando capturas vs. esfuerzo histórico (1980–91) de sardina+anchoveta norte chilena【83†L464-L472】. Esto entregó *r/K* agregados para ambas especies. Fue un modelo estático de equilibrio, útil como referencia histórica pero con fuertes simplificaciones (monoespecie, equilibrio).

Cada fuente describe claramente las ecuaciones usadas y supuestos (e.g. distribución logística de producción【64†L2567-L2574】【65†L2786-L2794】, proporcionalidad CPUE, etc.). Los informes IFOP están disponibles en su repositorio electrónico; por ejemplo, el “Tercer Informe Sardina Común 2022”【34†L1723-L1725】 y el “Segundo Informe Anchoveta 2022”【56†L879-L888】 detalla la fórmula de Von Bertalanffy y estructura del modelo. Los estudios alternativos citados están en literatura académica (ver fuentes). 

## Recomendaciones para modelos de manejo

- **Incorporar incertidumbre de M:** Aunque IFOP fija M≈1–1.3 año⁻¹, se recomienda evaluar rangos plausible (p.ej. 0.8–1.5) en simulaciones de evaluación y estimación de referencia. M es crítico en derivar B0, FMSY y en modelos de edad. Considerar sensibilidad de resultados ante variación de M【34†L1723-L1725】【56†L879-L888】.  
- **Uso de r y K en modelos de biomasa:** Si se usan modelos de producción (p.ej. manejo escalado a panel), usar *r/K* informados con amplias bandas. Los rangos obtenidos (r~0.44–0.59, K~8–13×10^6 t para anchoveta【65†L2786-L2794】) pueden servir como priors. Para sardina, al carecer de estimaciones específicas, podría asumirse *r* similar o mayor (dada su alta mortalidad) o usar resultados de modelos multi-especie【83†L464-L472】 con precaución.  
- **Modelo combinado vs. multiespecie:** Dado que anchoveta y sardina compiten o alternan, no es raro modelarlas separadamente como aquí, pero en contextos multi-espécie (ecosistema), se sugiere validar que las interacciones (depleción de depredadores o competencia) no alteren *r/K* previstos. Los protocolos IFOP actuales clasifican en “tiers” y usan puntos de referencia (*proxy*) adaptados (p.ej. fracción de M para precautorios)【56†L898-L906】. 
- **Validación con datos independientes:** Siempre ajustar o validar las predicciones con observaciones acústicas y de huevos (índices de abundancia). Estos índices mejoran la estimación de parámetros. IFOP incluye cruceros de monitoreo en sus modelos SCAA【56†L892-L901】.  
- **Iterar en el plan de manejo:** Emplear *M, r, K* para calcular BMSY, FMSY, etc. y luego contrastar con tendencias reales (desembarques, biomasa). Revisar periódicamente estos parámetros ante nuevas evidencias (p.ej. cambios en crecimiento o madurez que podrían alterar M aparente o productividad). 
- **Precaución frente al cambio climático:** Las fluctuaciones de estos pelágicos dependen del ambiente (coeficiente de variación alta). Modelos deben incluir escenarios o dummy variable de régimen para *r* o reclutamiento. Mantener principios precautorios: usar percentiles conservadores (e.g. *r* del percentil bajo) cuando se planifique en incertidumbre. 

En resumen, use **M ~1/año** (IFOP) en modelos SCAA o VPA, y para enfoques de producción emplee *r* del orden 0.5–1.0/año y *K* del orden de millones de toneladas como punto de partida【65†L2786-L2794】【83†L464-L472】. Siempre cítese la fuente original al usar cada valor (por ejemplo [34], [56], [65], [83]), y contextualice unidades (biomasa en toneladas métricas). 

**Fuentes:** Informes técnicos oficiales IFOP【34†L1723-L1725】【56†L879-L888】 y literatura científica relevante【65†L2786-L2794】【83†L464-L472】. Estos documentos contienen detalles completos de metodologías y estimaciones originales.