# Plan de revisión V2 — Climate Change, Stock Productivity, and Fishing Effort in Chile's Multi-Species Small Pelagic Fishery

**Felipe J. Quezada-Escalona** · Abril 2026

> **V2 · Post-decisión arquitectural 2026-04-20.** Esta versión reemplaza el plan original de abril 2026. Deadline se relaja de "submission octubre 2026" a **"accepted febrero 2028"**. La arquitectura cambia de *SUR reduced-form proyectado* a *modelo bio estructural (Schaefer) con shifters climáticos estimados en state-space*. La versión V1 queda preservada en el historial de git para referencia.

---

# 1. Resumen ejecutivo

## Decisiones centrales

- **Target editorial:** *Environmental and Resource Economics (ERE)*. Alternativa: *Journal of the Association of Environmental and Resource Economists (JAERE)* si el paper sale más fuerte de lo esperado bajo la nueva arquitectura. MRE como plan B.
- **Deadline real:** accepted febrero 2028. Deriva de hito interno FONDECYT, no de deadline editorial externo.
- **Arquitectura:** modelo bio estructural de producción excedente por especie (Schaefer o Pella-Tomlinson), con `r`, `K`, `M` adoptados del stock assessment oficial (IFOP para sardina común y anchoveta centro-sur; SPRFMO SS3 para jurel). Shifters climáticos `ρ^SST` y `ρ^CHL` estimados vía state-space Bayesiano (Stan) como modulación de `r` o `K`.
- **Contribución nítida:** "cómo incorporar shocks climáticos identificados a nivel de ecosistema en un modelo bioeconómico con assessment oficial, y sus consecuencias distributivas entre flota artesanal e industrial bajo regulación status-quo".

## Cambio arquitectural respecto a V1

La simulación forward del SUR (Tarea 4 de V1) fue implementada y ejecutada el 2026-04-20. Confirmó que el SUR reduced-form **no es viable como motor proyectivo**, ni con término SST² ni sin él. Con N=23, `β ≥ 1` en anchoveta y jurel, y `b0` alejado de `B_MEAN`, el sistema converge explosivamente al fixed-point reduced-form (jurel +79% por año en t=1 con clima histórico). El cap `[0.2, 3.0]` del draft V1 enmascaraba mecánicamente esto. Corolario: el SUR es una regresión de crecimiento de corto plazo, no un modelo poblacional; proyectarlo 75 años es intrínsecamente no identificado independiente de cuántas réplicas bootstrap se hagan.

## Solución adoptada (Plan 2)

Adoptar un modelo bio estructural por especie:

$$
B_{i,t+1} = B_{i,t} + r_i(X_t) \cdot B_{i,t} \cdot \left(1 - \frac{B_{i,t}}{K_i}\right) - C_{i,t} + \epsilon_{i,t}
$$

con

$$
r_i(X_t) = r_i^{\text{IFOP/SPRFMO}} + \rho_i^{\text{SST}} \cdot (SST_t - \overline{SST}) + \rho_i^{\text{CHL}} \cdot (CHL_t - \overline{CHL})
$$

donde los parámetros biológicos `r_i`, `K_i`, `M_i` vienen como priors informativos del assessment oficial, y lo que se identifica vía estimación Bayesiana state-space son únicamente `ρ_i^SST`, `ρ_i^CHL` y la varianza `σ_i^2`. Esto reduce la dimensión de estimación de ~18 parámetros (V1) a ~9 parámetros estructurales nuevos con N=23, que sí está identificado.

## Cronograma resumido

| Ventana | Foco | Hito |
|---|---|---|
| Q2 2026 (abr–jun) | T2, T3 (calibración base sin clima) | Schaefer reproduce trayectoria histórica |
| Q3 2026 (jul–sep) | T1, T4 (CMIP6 + shifters Bayesianos) | Posteriors de `ρ^SST`, `ρ^CHL` |
| Q4 2026 (oct–dic) | T5, T6, T7 primera iteración | Draft paper 1 completo |
| Q1 2027 (ene–mar) | T7 pulido + cover letter | **Submission ERE** |
| Q2–Q3 2027 | R&R paper 1 en paralelo con inicio paper 2 | — |
| Q4 2027 | Draft paper 2 | — |
| Q1 2028 | Resubmission paper 1 → accepted | **Accepted** ← objetivo |

Margen de ~6 meses para absorber R&R. No es ruta crítica apretada.

---

# 2. Arquitectura detallada

## 2.1 El SUR reduced-form muere como motor proyectivo

Diagnóstico confirmado empíricamente el 2026-04-20 corriendo `R/06_projections/04_forward_simulation.R` y `05_sensitivity_sur_spec.R`:

**Coeficientes SUR estimados (spec `full`):**

| especie | intercept | β | η | ρ_SST | ρ_SST² | ρ_CHL |
|---|---|---|---|---|---|---|
| sardine | 23.74 | 0.438 | -0.021 | -9.16 | +54.74 | +80.99 |
| anchoveta | 12.10 | 1.112 | -0.202 | -4.97 | -4.61 | -5.37 |
| jurel | 28.19 | 1.057 | -0.017 | +5.92 | -56.49 | +15.45 |

**Patologías identificadas:**

1. `β ≥ 1` en anchoveta (1.112) y jurel (1.057). Para que el sistema sea estable alrededor de `B_MEAN` con harvest proporcional `F·b`, necesitamos `1 − β + F > 0`; con `F_jurel = 0.43` y `β = 1.057` eso da 0.37, muy cerca de la frontera de explosividad.
2. El fixed-point reduced-form de jurel es `b* ≈ (intercept − β·B_MEAN)/(1−β+F) ≈ 32`, mientras que `mean_last5 = 9.67`. El SUR interpreta cualquier estado lejos de `B_MEAN` como "crecimiento acelerado hacia el fixed point".
3. `ρ_SST² = -56.5` para jurel implica, a `sst_c² = 5.3` (delta end-century), una contribución de -299 al growth equation, lo que hunde biomasa a cero.
4. Spec `no_sst2`: sardina y jurel siguen catastróficos, con signos invertidos. El cuadrático no era el único problema.

**Causa raíz:** el SUR tiene la forma reducida correcta para ajustar crecimiento observado histórico (R² elevado, residuos bien comportados), pero no tiene estructura que asegure convergencia a un fixed-point biológicamente sensato bajo condiciones distintas a la media muestral. No es un modelo poblacional.

## 2.2 Estado-del-arte en bio: modelo estructural con assessment oficial

Tres fuentes públicas con parámetros listos para adoptar:

**Sardina común y anchoveta centro-sur:**
- Comité Científico Técnico de Pesquerías de Pequeños Pelágicos (CCT-PP) de SUBPESCA emite Informe Técnico anual con CBA (Captura Biológicamente Aceptable).
- Evaluación técnica la hace IFOP bajo Convenio Desempeño. Modelo: estadístico de captura a la edad (ASAP / Stock Synthesis variante). Publican `Informe Final` con trayectoria de SSB, reclutas, F, selectividad, M.
- Para 2024-2025: biomasa total anchoveta centro-sur ≈ 858,000 t, status plena explotación.

**Jurel (*Trachurus murphyi*):**
- Evaluación hecha por Scientific Committee de SPRFMO (Chile, Perú, Ecuador, UE, China).
- Modelo: Stock Synthesis v3 (SS3). Todos los inputs, outputs, y archivos `.ctl` / `.dat` son públicos en sprfmo.int.
- Reporte anual `SC-Report-Annex-7` con parámetros finales.
- Para 2025: TAC global 1,552,500 t; área SPRFMO 1,419,119 t; survey hidroacústico R/V Abate Molina 33 transectas Arica–Valparaíso.

Esto colapsa el riesgo principal de la Ruta C (V1): no calibramos desde cero, **adoptamos**. Esto es ~2–3 meses de trabajo, no 6.

## 2.3 Ley de movimiento estructural del paper 1

Modelo por especie `i ∈ {sardina, anchoveta, jurel}`:

$$
B_{i,t+1} = B_{i,t} + g_i(B_{i,t}, X_t) - C_{i,t} + \epsilon_{i,t}, \quad \epsilon_{i,t} \sim \mathcal{N}(0, \sigma_i^2)
$$

con función de crecimiento Pella-Tomlinson (o Schaefer si `m=2`):

$$
g_i(B, X) = \frac{r_i(X)}{m-1} \cdot B \cdot \left(1 - \left(\frac{B}{K_i}\right)^{m-1}\right)
$$

y modulación climática de `r_i`:

$$
r_i(X_t) = r_i^0 \cdot \exp\left(\rho_i^{\text{SST}} \cdot (SST_t - \overline{SST}) + \rho_i^{\text{CHL}} \cdot \log(CHL_t / \overline{CHL})\right)
$$

La forma exponencial evita que `r_i` se vuelva negativo bajo shocks fuertes y da interpretación limpia: `ρ_i^SST` es semi-elasticidad de productividad intrínseca respecto a SST.

**Correlaciones cruzadas entre especies:** se modelan vía estructura de covarianza `Σ = cov(ε_1, ε_2, ε_3)` del error de proceso, estimada conjuntamente. Esto preserva el valor original de la SUR (covarianza contemporánea entre shocks de biomasa) pero dentro de una estructura poblacional estable.

**Parámetros fijos adoptados:** `r_i^0`, `K_i`, `m` (o `m=2` para Schaefer), `M_i`, `B_{i,0}`.

**Parámetros estimados:** `ρ_i^SST`, `ρ_i^CHL`, `σ_i^2` para cada `i`, más 3 covarianzas cruzadas. Total 12 parámetros con N=23 por especie → ratio 3.8. Identificable.

## 2.4 División de contribución con paper 2

Para evitar que paper 1 "agote" paper 2 y el referee de ERE pida fusión:

**Paper 1 — descriptivo, equilibrio actual bajo clima cambiante.**
- Identificar `ρ_i^SST`, `ρ_i^CHL`.
- Proyectar biomasa bajo regulación status-quo (TAC histórico, reglas de asignación artesanal/industrial vigentes, CPUE histórico).
- Cuantificar cambio en viajes por flota.
- Mensaje: "la regulación actual no reacciona al clima, y eso tiene consecuencias distributivas asimétricas entre flotas artesanal e industrial".

**Paper 2 — prescriptivo, regulador y pescadores optimizan.**
- Tomar la ley de movimiento calibrada de paper 1 como restricción biológica.
- Stackelberg bi-nivel: regulador elige TAC óptimo (Bellman + HJB); pescadores eligen captura por viaje por especie (MPEC o nested fixed-point).
- Solver: JuMP.jl (Julia) o CasADi (Python). R no sirve para esto.
- Mensaje: "TAC óptimo bajo clima difiere del actual en X, la heterogeneidad en CPUE entre pescadores amplifica/atenúa el shock en Y, y el bienestar bajo regulación adaptativa supera el status-quo en Z".

La división es limpia: paper 1 **identifica y describe**, paper 2 **optimiza y prescribe**. Referee de ERE valora esto explícitamente.

---

# 3. Tareas

## T1 — Ensemble CMIP6 multi-modelo (Pangeo/Zarr)

**Estado:** heredada de V1 sin cambios, sigue siendo válida bajo Plan 2.

**Objetivo:** reemplazar IPSL-CM6A-LR único por ensemble de 4 modelos (IPSL-CM6A-LR, GFDL-ESM4, MPI-ESM1-2-HR, CanESM5). Reportar mediana e IQR por escenario × ventana en vez de punto.

**Pipeline:** Pangeo Cloud + Zarr (NO ESGF, que ya probamos y falla). Subset espacial-temporal antes de transferir bytes → archivos de 2–10 MB en vez de 60–80 GB.

Detalles técnicos, catálogo, conversiones de unidades y script completo están en la versión V1 del plan (sección homónima) — se preservan sin cambios en `R/06_projections/01_cmip6_deltas.R` y `cmip6_pangeo_download.py`.

**Tiempo estimado:** 2–2.5 semanas cuando se ejecute (Q3 2026).

## T2 — Adoptar parámetros bio de assessment oficial

**Objetivo:** obtener y procesar `r`, `K`, `M`, `B_0`, serie anual de SSB y F para las tres especies desde fuentes oficiales.

**Sub-tareas:**

1. Descargar Informe Final IFOP más reciente con evaluación de sardina común y anchoveta centro-sur. Fuente: `ifop.cl/wp-content/contenidos/uploads/RepositorioIfop/InformeFinal/`.
2. Descargar Informe Técnico CCT-PP de SUBPESCA con CBA más reciente. Fuente: `subpesca.cl/portal/sitio/Institucionalidad/Comites-Cientificos-Tecnicos-Pesqueros/Comite-Cientifico-de-Pesquerias-de-Pequenos-Pelagicos/`.
3. Descargar SPRFMO SC Report Annex 7 para jurel. Fuente: `sprfmo.int/meetings/sc-meetings/`. Específicamente el más reciente (SC13-2025).
4. Extraer tabla de parámetros a un archivo `data/bio_params/official_assessments.yaml` con estructura:
   ```yaml
   sardine_common_cs:
     source: "IFOP Informe Final 2025, P-XXXXXX"
     model: "Stock Synthesis v3.30"
     year: 2025
     r: [point, lower95, upper95]
     K: [point, lower95, upper95]
     M: 0.80   # mortalidad natural, constante
     B_0: ...
     SSB_series: {1990: ..., 1991: ..., ...}
     F_series:   {1990: ..., ...}
   anchoveta_cs:
     ...
   jurel_sprfmo:
     source: "SPRFMO SC13 Report 2025, Annex 7"
     model: "Stock Synthesis v3.30"
     ...
   ```
5. Script `R/07_structural_bio/01_load_official_params.R` que parsea el YAML y retorna una lista `R` para uso downstream.

**Riesgo:** Stock Synthesis usa estructura por edad, no por biomasa agregada. Hay que o bien colapsar SSB a `B_i` (pérdida de información) o calibrar un modelo bio agregado que preserve la trayectoria de SSB observada (más sólido). Ruta preferida: segunda.

**Tiempo estimado:** 1.5 semanas.

## T3 — Schaefer calibrado reproduce trayectoria histórica (sanity check)

**Objetivo:** antes de meter clima, verificar que el modelo bio estructural con parámetros adoptados **reproduce** la serie histórica de biomasa observada dada la serie histórica de captura. Si no reproduce con error <20%, hay inconsistencia entre los parámetros adoptados y los datos de captura, y hay que resolverla antes de agregar shifters climáticos.

**Implementación:**

```r
# R/07_structural_bio/02_hindcast_check.R

simulate_hindcast <- function(params, catch_series, B0, years) {
  B <- numeric(length(years)); B[1] <- B0
  for (t in seq_along(years)[-1]) {
    g <- (params$r / (params$m - 1)) * B[t-1] *
         (1 - (B[t-1] / params$K)^(params$m - 1))
    B[t] <- max(0.01 * params$K, B[t-1] + g - catch_series[t-1])
  }
  tibble(year = years, B_hat = B)
}

# Para cada especie, comparar B_hat vs SSB observada del assessment
hindcast_errors <- map_dfr(species, function(sp) {
  params <- official_params[[sp]]
  sim <- simulate_hindcast(params, catch[[sp]], params$B_0, years)
  sim %>%
    left_join(SSB_obs[[sp]], by = "year") %>%
    mutate(species = sp, abs_err_pct = abs(100 * (B_hat - SSB_obs) / SSB_obs))
})

# Criterio: mediana de abs_err_pct < 20%
stopifnot(
  hindcast_errors %>% group_by(species) %>%
    summarise(m = median(abs_err_pct)) %>%
    pull(m) %>% max(na.rm = TRUE) < 20
)
```

**Si falla el test:**
- Primer sospechoso: unidades inconsistentes entre captura (tu data SERNAPESCA) y assessment (SUBPESCA/IFOP/SPRFMO). Chequear.
- Segundo: `B_0` del assessment corresponde a un año anterior a tu serie. Ajustar `B_0` y `year_start`.
- Tercero: el assessment usa modelo por edad que no se colapsa bien a biomasa agregada. Plan B: calibrar `r`, `K` mediante profile likelihood sobre tu serie de SSB observada, manteniendo `M` fijo del assessment.

**Tiempo estimado:** 1–1.5 semanas.

## T4 — Estimación Bayesiana state-space (identificación de shifters climáticos)

**Objetivo:** estimar `ρ_i^SST`, `ρ_i^CHL` y estructura de covarianza del error de proceso mediante filtro de Kalman Bayesiano con priors informativos en `r`, `K`.

**Por qué state-space y no MLE frecuentista:**

1. Con N=23 por especie y parámetros previos informativos (de assessments), priors Bayesianos son la herramienta natural. MLE colapsa a los priors si la likelihood es plana, y Bayes lo hace explícito.
2. El error de proceso y el error de observación son distintos (`SSB_obs_t = B_t + ν_t`, `B_{t+1} = g(B_t) + ε_t`). State-space lo separa limpio.
3. Posteriors propagan incertidumbre a proyecciones sin necesidad de bootstrap.

**Stack técnico:** Stan via `cmdstanr` (más rápido y moderno que `rstan`). Alternativa: TMB para MLE penalizado si la posterior es unimodal y bien comportada (más rápido, menos flexible).

**Especificación Stan (esqueleto):**

```stan
// paper1/stan/structural_bio_climate.stan
data {
  int<lower=1> T;       // años
  int<lower=1> S;       // especies (3)
  matrix[T, S] C;       // captura observada por especie
  matrix[T, S] SSB_obs; // SSB observada (del assessment)
  vector[T] SST;        // SST centrada
  vector[T] log_CHL;    // log CHL centrado
  // Priors informativos desde assessment oficial
  vector[S] r_prior_mean;
  vector[S] r_prior_sd;
  vector[S] K_prior_mean;
  vector[S] K_prior_sd;
  vector[S] M_prior_mean;
  vector[S] B0_prior_mean;
}
parameters {
  vector<lower=0>[S] r0;
  vector<lower=0>[S] K;
  vector[S] rho_sst;        // shifters
  vector[S] rho_chl;
  cholesky_factor_corr[S] L_Omega;  // correlación cruzada de errores
  vector<lower=0>[S] sigma_proc;     // sd del error de proceso
  vector<lower=0>[S] sigma_obs;      // sd del error de observación
  matrix<lower=0>[T, S] B_latent;    // biomasa latente
}
model {
  // priors informativos
  r0 ~ normal(r_prior_mean, r_prior_sd);
  K  ~ normal(K_prior_mean, K_prior_sd);
  rho_sst ~ normal(0, 0.3);   // débil
  rho_chl ~ normal(0, 0.3);
  L_Omega ~ lkj_corr_cholesky(2);
  sigma_proc ~ exponential(1);
  sigma_obs  ~ exponential(1);

  // estado inicial
  B_latent[1] ~ normal(B0_prior_mean, K * 0.1);

  // dinámica
  for (t in 2:T) {
    vector[S] r_t = r0 .* exp(rho_sst * SST[t-1] + rho_chl * log_CHL[t-1]);
    vector[S] growth = r_t .* B_latent[t-1]' .* (1 - B_latent[t-1]' ./ K);
    vector[S] B_expected = B_latent[t-1]' + growth - C[t-1]';
    B_latent[t] ~ multi_normal_cholesky(
      B_expected,
      diag_pre_multiply(sigma_proc, L_Omega)
    );
  }

  // observación
  for (t in 1:T)
    SSB_obs[t] ~ normal(B_latent[t], sigma_obs);
}
generated quantities {
  corr_matrix[S] Omega = multiply_lower_tri_self_transpose(L_Omega);
}
```

**Posteriors que reportar:**
- `ρ_i^SST`, `ρ_i^CHL` con CI 95% por especie.
- `Ω` matriz de correlación cruzada.
- Smoothed `B_latent_t` con bandas.

**Diagnósticos obligatorios:**
- R-hat < 1.01 para todos los parámetros.
- ESS > 400.
- Posterior predictive check contra SSB observada.
- Prior predictive check para asegurar que los priors de `ρ` son débiles pero regulares.

**Tiempo estimado:** 3 semanas (1 de setup Stan + 1 de convergencia + 1 de diagnóstico y reporte).

## T5 — Forward simulation del modelo estructural × CMIP6 ensemble

**Objetivo:** proyectar biomasa y captura 2025–2100 bajo los 4 modelos CMIP6 × 2 escenarios SSP, usando la ley de movimiento estructural con posteriors de T4 y deltas climáticos de T1.

**Implementación:**

Para cada draw `d` del posterior (típico: 1000 draws):
- Para cada modelo `m` × escenario `s`:
  - Para cada año `t` de 2025 a 2100:
    - Construir `SST_t`, `log_CHL_t` vía delta aditivo/multiplicativo.
    - Calcular `r_i(X_t)` con draws `ρ_i^SST^{(d)}`, `ρ_i^CHL^{(d)}`.
    - Aplicar ley Pella-Tomlinson con captura `C_{i,t}` = regla status-quo (TAC histórico o F histórico).
- Agregar a mediana + bandas 90% por (m, s, t, especie).

**Regla de captura status-quo:**
- Opción A (TAC fijo histórico): `C_{i,t} = C̄_{i, 2015-2024}`.
- Opción B (F proporcional): `C_{i,t} = F̄_i · B_{i,t}`.
- Opción C (HCR SUBPESCA actual): regla de decisión que aplica SUBPESCA por especie según status de biomasa vs `B_MSY`.

Preferido: **C** (es la regla real), con A y B como sensibilidades en apéndice. Requiere codificar la Harvest Control Rule específica de cada especie (disponible en los Informes Técnicos del CCT-PP).

**Tiempo estimado:** 2 semanas.

## T6 — Mapping biomasa → viajes por flota (NB de esfuerzo)

**Objetivo:** una vez que tenemos trayectoria de captura por especie bajo cada escenario, mapear a número de viajes por flota (industrial / artesanal) usando CPUE histórico y la regla de asignación sectorial.

**Estructura:**

1. Asignación sectorial: `H^{art}_{i,t} = α_i · H_{i,t}`, `H^{ind}_{i,t} = (1 - α_i) · H_{i,t}`, con `α_i` calibrado a la fracción histórica por especie. Fuente: SERNAPESCA cuando llegue (T8), proxy actual mientras.
2. CPUE por flota-especie: `CPUE^f_{i}` (toneladas por viaje), estimado del panel IFOP 2013–2024.
3. Viajes esperados: `N^f_{i,t} = H^f_{i,t} / CPUE^f_{i}`.
4. Agregar a `N^f_t = Σ_i N^f_{i,t}` (viajes totales por flota).
5. NB ajustado con covariables adicionales (clima directo: viento), manteniendo la defensa reduced-form de V1.

**Endogeneidad:** se mantiene el caveat reduced-form de V1 (ver T7).

**Tiempo estimado:** 1.5 semanas.

## T7 — Reescritura del manuscrito

**ESTADO 2026-04-24: T7 ejecutado en su mayor parte.** Ver `CHANGELOG.md` entry 2026-04-24 para lista detallada. Lo que ya está hecho:

- Abstract sincronizado con lenguaje Cowles y cifras T4b-full.
- Contribution paragraph de §1 reescrito alrededor de identificación estructural.
- §3.3 Stock dynamics con Pella–Tomlinson + shifter log-linear + observation equation (nuevo aparato principal).
- §3.1 subsección jurel reescrita: "Observation structure" (16 unc + 2 cen + 7 latent), sin Gamma-GLM.
- §3.4 Projection approach con canal indirecto via shifter identificado.
- §4.4 Climate change projections con `tab:growth_compstat` (del CSV T5) y ridgeline figure; cap [0.2, 3.0], tab:biomass_proj y decomposition table/fig eliminados.
- Discussion + Conclusions rearmadas alrededor de identificación + no-identificación de jurel como hallazgo sustantivo.
- SUR reduced-form benchmark (§4.1 + 3 paneles appendix robustness) BORRADO del main, archivado en `paper1/deprecated/sur_benchmark_deprecated.Rmd`.

**Pendiente de T7 (para una sesión futura):**

- **Appendix A (stress tests T3-bis)**: `results_identification.Rmd` cita "stress tests (Appendix A)" y la subsección nueva de §3.1 también. Necesita escribirse un `paper1/sections/appendix_stress_tests.Rmd` child que formalice el protocolo de stress-test que produce los priors sobre (ρ^SST, ρ^CHL). Sin eso, la cita queda colgada (texto literal "Appendix A" sin \ref, no rompe knit pero es deuda).
- **Posterior-predictive check formal (Appendix C o inline)**: el bloque comentado en `results_identification.Rmd` L207-225 espera un `appendix_posterior_diagnostics.Rmd` con PPC smooth-vs-obs y residuals. Decidir si se formaliza o se elimina el TODO.
- **Sección 4 "Estimation"**: el revision plan V2 pidió "describir state-space Bayesiano con Stan. Incluir sección de diagnósticos (R-hat, ESS, PPC)". Parte de esto está en §3.3 y parte en appendix predictive; pero una subsección dedicada a diagnósticos de convergencia + tabla con R-hat max, min ESS, etc. no existe todavía.
- **Trayectorias de biomasa con bandas 90%**: el revision plan pide "trayectorias de biomasa con bandas 90% de incertidumbre propagada (no ensemble puntual); tabla de cambios en viajes por flota con intervalos". Hoy §4.4 reporta comparative statics sobre r (no trayectorias de B) y la implicancia para trips es cualitativa (forward sim → paper 2). Decisión pendiente: ¿se agrega al paper 1 una figura de B_t^{sim} con bandas, o se deja todo para paper 2?

---

**Cambios estructurales mayores vs V1 (plan original, conservado como referencia):**

- **Abstract:** reemplazar mención de "three-equation SUR" como modelo poblacional por "structural bio model calibrated from official stock assessments, augmented with Bayesian climate shifters". Mantener defensa reduced-form para la ecuación de esfuerzo (NB).
- **Introduction:** reescribir párrafo de contribución para que enfatice la nueva arquitectura. Subrayar el gap: "la literatura de climate-econ en pesquerías usa o bien reduced-form econometrics sin estructura poblacional, o modelos bio calibrados sin fundamento climático; acá combinamos ambos".
- **Sección 2 (Model):** reescribir. La ley de movimiento ya no es SUR; es Pella-Tomlinson con `r_i(X_t)`. El SUR sólo aparece como estimación estadística dentro del state-space, no como modelo sustantivo.
- **Sección 3 (Data):** agregar subsección sobre adopción de parámetros oficiales. Justificar `B_0`, `r`, `K` como priors informativos con fuentes específicas (IFOP Informe Final 2025, SPRFMO SC13 2025).
- **Sección 4 (Estimation):** describir state-space Bayesiano con Stan. Incluir sección de diagnósticos (R-hat, ESS, PPC).
- **Sección 5 (Results):** posteriors de `ρ^SST`, `ρ^CHL`; trayectorias de biomasa con bandas 90% de incertidumbre **propagada** (no ensemble puntual); tabla de cambios en viajes por flota con intervalos.
- **Eliminar completamente:** cap `[0.2, 3.0]`, Tabla 4 (growth capacity con -1508%), panel industrial plano por cap activo.
- **Discussion:** reformular caveats. El primero ya no es endogeneidad, es "estos resultados dependen de que los assessments oficiales sean correctos"; el segundo endogeneidad reduced-form; el tercero `N=23`.

**Texto sugerido para abstract:**

> "We estimate a structural bio-climate model for Chile's multi-species small pelagic fishery that combines official stock assessments from IFOP and SPRFMO with a Bayesian state-space identification of climate shifters. Projecting biomass trajectories under CMIP6 multi-model ensemble, we quantify the heterogeneous effect of climate change on artisanal and industrial fleet trips through a reduced-form negative binomial effort equation. Results reveal a distributional asymmetry: under status-quo regulation, artisanal trips [rise/fall] by X% while industrial trips [rise/fall] by Y% in end-century under SSP5-8.5, driven primarily by differential species composition rather than by direct climate exposure."

**Tiempo estimado:** 3 semanas continuas (Q4 2026).

## T8 — Actualización con datos SERNAPESCA (bloqueada en entrega)

**Sin cambios respecto a V1.** La tabla de contingencia por fecha de llegada sigue siendo válida, solo que ya no hay deadline de octubre 2026 que presione.

| Llega antes de | Acción |
|---|---|
| Jun 2026 | Incorporar antes de T5 (forward sim). Re-estimación completa, ruta limpia. |
| Sep 2026 | Incorporar durante T4–T5. Paper 1 va con SERNAPESCA v3. |
| Dic 2026 | Incorporar durante T6–T7. Posible delay de submission a Q2 2027. |
| Después de Dic 2026 | Submitir versión sin estos datos. Mencionar como extensión planeada en Discussion. Incorporar en R&R. |

Mantener el principio de V1: todo el código parametrizado por `data_version`, así cuando llegue no hay que reescribir.

---

# 4. Cronograma trimestral hasta feb 2028

| Trimestre | Paper 1 | Paper 2 | Hitos externos |
|---|---|---|---|
| **Q2 2026** (abr–jun) | T2 (adoptar assessments). T3 (hindcast check). | — | SERNAPESCA eventual. |
| **Q3 2026** (jul–sep) | T1 (CMIP6 Pangeo). T4 (Stan state-space). | — | — |
| **Q4 2026** (oct–dic) | T5 (forward × ensemble). T6 (NB viajes). T7 primera iteración draft. | Scoping: literatura, formalización Stackelberg. | Feedback interno (Dresdner, Chávez). |
| **Q1 2027** (ene–mar) | T7 final + cover letter. **Submission ERE.** | Bellman del regulador + MPEC pescadores. | — |
| **Q2 2027** (abr–jun) | — (bajo revisión) | Numerical solve Julia/JuMP. Calibración funciones de costo. | Decision ERE probable. |
| **Q3 2027** (jul–sep) | R&R paper 1. | Draft paper 2 primera iteración. | — |
| **Q4 2027** (oct–dic) | Resubmission paper 1 final. | Draft paper 2 completo. | — |
| **Q1 2028** (ene–feb) | **Paper 1 accepted.** | Submission paper 2. | **← objetivo FONDECYT.** |

Ruta crítica: T2→T3→T4 en 2026. Si T4 (Stan) se atasca por problemas de convergencia (posibles con N=23), tomar 2 semanas extra en Q3 2026; no comprime el cronograma global.

**Buffer:** Q2 2027 (bajo revisión ERE) es holgura natural. Si R&R entra antes, ahí se absorbe.

---

# 5. Estructura del repo (V2)

```
paper1/
├── paper1_climate_projections.Rmd            # manuscrito principal
├── appendix.Rmd                              # diagnósticos Stan, sensibilidades
├── refs.bib
├── paper1_revision_plan.md                   # este archivo
├── CHANGELOG.md
├── data/
│   ├── raw/                                  # sin cambios
│   ├── bio_params/
│   │   ├── official_assessments.yaml         # NUEVO — parámetros IFOP/SPRFMO
│   │   ├── ifop_sardina_2025.pdf             # respaldo
│   │   ├── ifop_anchoveta_2025.pdf
│   │   └── sprfmo_sc13_jurel_2025.pdf
│   ├── cmip6/                                # de T1 (sin cambios vs V1)
│   └── processed/
├── R/
│   ├── 00_config/
│   ├── 01_clean_ifop.R
│   ├── 02_biomass_imputation.R
│   ├── 03_environmental_aggregation.R
│   ├── 04_sur_estimation.R                   # se mantiene pero solo para tabla descriptiva
│   ├── 05_nb_effort.R
│   ├── 06_projections/
│   │   ├── 01_cmip6_deltas.R
│   │   ├── 02_project_and_predict.R          # OBSOLETO V1 (comparative statics)
│   │   ├── 03_project_biomass.R              # OBSOLETO V1
│   │   ├── 04_forward_simulation.R           # DIAGNÓSTICO histórico
│   │   ├── 04_forward_simulation_tests.R
│   │   └── 05_sensitivity_sur_spec.R         # DIAGNÓSTICO histórico
│   ├── 07_structural_bio/                    # NUEVO — corazón V2
│   │   ├── 01_load_official_params.R
│   │   ├── 02_hindcast_check.R
│   │   ├── 03_fit_state_space.R              # driver Stan
│   │   ├── 04_project_structural.R           # forward × CMIP6
│   │   └── 05_map_trips.R
│   └── cmip6_pangeo_download.py
├── stan/
│   └── structural_bio_climate.stan           # NUEVO
└── output/
    ├── tables/
    ├── figures/
    └── projections/
```

**Scripts obsoletos (V1):** `02_project_and_predict.R` y `03_project_biomass.R` quedan en el repo como referencia histórica — no se ejecutan en el pipeline V2. Los scripts `04_forward_simulation.R`, `04_forward_simulation_tests.R`, `05_sensitivity_sur_spec.R` quedan como diagnóstico del problema que motivó el cambio arquitectural (útil para una nota al pie en el paper si un referee pregunta "¿por qué no usaron el SUR directamente?").

---

# 6. Herramientas

- **R (primary, paper 1):** `dplyr`, `tidyr`, `purrr`, `cmdstanr` para Stan, `lavaan` (residual SUR descriptivo), `terra` para NetCDF CMIP6.
- **Python (pipeline CMIP6):** `intake-esm`, `zarr`, `xarray`, `dask`. Solo para `cmip6_pangeo_download.py`.
- **Stan (estimación Bayesiana):** `cmdstan 2.35+`. 4 chains, 2000 iter warmup + 2000 iter sampling. Tiempo por corrida esperado: 30–90 minutos en laptop moderno.
- **Julia (paper 2, Q1 2027+):** `JuMP.jl`, `Ipopt.jl` (NLP solver), `Optim.jl`. Alternativa: CasADi desde Python.
- **Git:** branches `feature/structural-bio`, `feature/stan-state-space`, `feature/cmip6-ensemble`, `feature/nb-effort`. Un solo PR grande cuando T2–T6 cierren.

---

# 7. Rutas descartadas (para referencia)

Durante la discusión del 2026-04-20 se consideraron tres rutas de salida del diagnóstico SUR:

- **Ruta A — `b0 = B_MEAN` + horizonte corto.** Neutraliza el transitorio pero pierde "end-century" que ERE espera. Descartada.
- **Ruta B — Comparative statics analíticas vía delta method sobre SUR.** Identificación limpia pero no permite hablar de trayectorias ni acopla bien con paper 2 (que necesita ley de movimiento). Descartada.
- **Ruta C — Modelo bio estructural con shifters climáticos.** Adoptada (es el Plan 2 de este documento).

La Ruta C se adoptó tras confirmar que los stock assessments oficiales están disponibles y son metodológicamente sólidos (SS3 / ASAP) para las tres especies, lo que colapsa el costo de calibración de 6 meses a ~2–3 meses.

---

# 8. Notas para futuras sesiones Cowork

- **T2 (adoptar assessments):** bajar los tres PDFs primero, extraer tablas de parámetros a YAML, y construir `R/07_structural_bio/01_load_official_params.R`. Este es el próximo paso concreto.
- **T3 (hindcast):** es el primer test de realidad. Si falla con error >20%, parar y diagnosticar antes de seguir. No vale la pena montar Stan encima de un modelo bio que ya no replica el histórico.
- **T4 (Stan):** los problemas típicos con N=23 son divergencias y low ESS en `rho_*`. Estrategia: priors `rho ~ normal(0, 0.3)` (débil pero regular), `non_centered parameterization` para `B_latent`, y `adapt_delta = 0.95`.
- **T5–T6:** son mecánicos una vez T4 converge. Script, ejecución, tablas.
- **T7:** el título puede cambiar. Sugerencia actual: "Climate Shifters in a Structural Bioeconomic Model: Distributional Effects on Chilean Small Pelagic Fisheries".

---

# 9. Decisión editorial pendiente

**¿ERE o JAERE?**

JAERE es más técnico y valora estimación Bayesiana state-space. Con la nueva arquitectura, paper 1 pasa a ser competitivo para JAERE, no solo ERE.

| Criterio | ERE | JAERE |
|---|---|---|
| Prestigio | Alto | Alto (ranking similar) |
| Fit con estimación Bayesiana | Bueno | Excelente |
| Audiencia | Econ ambiental general | Econ ambiental técnico |
| Tiempo a decisión típico | 4–6 meses | 5–7 meses |
| Aceptación esperada con V2 | Media-alta | Media |

Recomendación tentativa: **submitir primero a JAERE** dado que el componente metodológico (state-space + assessment adoption) se valora más ahí. Si rechazo, ERE. Decisión final a revisitar en Q4 2026 cuando el draft esté completo.
