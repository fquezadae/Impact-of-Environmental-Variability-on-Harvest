# Handoff — Trackear en git los summaries t4b para knitear `paper1` en cualquier PC

**Para:** el PC principal (el que corre los ajustes Stan y tiene `data/outputs/t4b/` local).
**Objetivo:** commitear al repo los dos CSV de summary posterior que el manuscrito necesita
para renderizar, hoy `gitignored` y por eso ausentes en los demás PCs.

---

## Diagnóstico

`paper1/paper1_climate_projections.Rmd` incluye la sección hija
`paper1/sections/results_identification.Rmd`, que arma la Tabla de identificación de
los climate shifters leyendo:

```
data/outputs/t4b/t4b_full_summary.csv          # obligatorio
data/outputs/t4b/t4b_full_enso_lag1_summary.csv # opcional (fila rho_enso)
```

Ambos viven bajo `/data/outputs/`, que está en `.gitignore` (línea 20,
"large/sensitive, tracked locally only"). En un clon en otra máquina no existen, así que
el render corta con:

```
Error in `file()`: ! cannot open the connection
  read.csv("data/outputs/t4b/t4b_full_summary.csv", ...)
Quitting from results_identification.Rmd:14-85 [rho-posterior-table]
```

Es el mismo patrón que ya resolviste para `biomass_dt.rds`, `sernapesca_v2.rds` y
`poisson_dt.rds` (excepciones en `.gitignore` líneas 74-77 + `git add -f`). Falta
replicarlo para estos dos summaries.

## Archivos a trackear

| Archivo | Lo genera | Contenido | ¿Commitear? |
|---|---|---|---|
| `data/outputs/t4b/t4b_full_summary.csv` | `R/08_stan_t4/08_fit_t4b_full.R` | summary posterior (`r_nat`, `K_nat`, `B0_nat`, `sigma_proc`, `sigma_obs`, `rho_sst`, `rho_chl`, `Omega`): mean/sd/q5/q95/rhat | **Sí — obligatorio** |
| `data/outputs/t4b/t4b_full_enso_lag1_summary.csv` | `R/08_stan_t4/14b_fit_t4b_full_enso.R` | summary posterior del refit ENSO (incluye `rho_enso[3]`) | Sí — recomendado (sin él la tabla omite la fila ENSO; no bloquea) |

Son tablas de summary (`fit$summary(...)`), de unos pocos KB, sin microdato: seguras de
commitear.

**NO commitear** los objetos pesados del ajuste, que deben seguir ignorados:

```
data/outputs/t4b/t4b_full_fit.rds
data/outputs/t4b/t4b_full_stan_data.rds
data/outputs/t4b/t4b_full_enso_lag1_fit.rds
data/outputs/t4b/t4b_full_enso_lag1_stan_data.rds
```

## Pasos (en el PC principal)

### 1. Agregar la excepción en `.gitignore` (al final, junto a las de líneas 74-77)

```gitignore
# Excepciones: summaries posteriores t4b que el manuscrito necesita para knitear
# (los *_fit.rds y *_stan_data.rds se quedan ignorados a propósito)
!/data/outputs/t4b/t4b_full_summary.csv
!/data/outputs/t4b/t4b_full_enso_lag1_summary.csv
```

> Como `/data/outputs/` excluye el directorio entero, la negación por sí sola no basta
> para re-incluir un archivo no trackeado (git no desciende a un dir ignorado). Lo que
> realmente lo trackea es el `git add -f` del paso 2; las líneas de excepción quedan por
> consistencia y documentación, igual que las 74-77.

### 2. Forzar el add y commitear

```bash
git add -f data/outputs/t4b/t4b_full_summary.csv \
           data/outputs/t4b/t4b_full_enso_lag1_summary.csv
git commit -m "Track t4b posterior summaries needed to knit paper1 (results_identification)"
git push
```

### 3. Verificar que quedaron trackeados (y los .rds no)

```bash
git ls-files data/outputs/t4b/        # deben aparecer solo los 2 CSV
git status --short data/outputs/t4b/  # los *_fit.rds / *_stan_data.rds NO deben listarse para commit
```

## Contexto — cambios ya hechos del lado del `.Rmd` (en el otro PC)

Para que esto cierre, en el otro PC ya se editó `paper1/paper1_climate_projections.Rmd`
(falta hacer `commit`/`push`/`pull` para reconciliar):

1. **Lectura de tablas portable:** las 6 referencias `"paper1/tables/..."` pasaron a
   `"tables/..."`. El junction `paper1/tables -> ../tables` está guardado en git como
   symlink (`mode 120000`) y en Windows con `core.symlinks=false` queda como archivo de
   texto roto, así que `here::here("paper1/tables/...")` no resolvía. Leer desde la
   carpeta real `tables/` (raíz, `root.dir = here::here()`) elimina la dependencia del
   symlink en cualquier PC.
2. **Preflight ampliado:** se agregó `here::here("data/outputs/t4b/t4b_full_summary.csv")`
   al guard de insumos, para que falte temprano con la lista exacta en vez de cortar a
   mitad de la sección hija.

Conviene mergear estos cambios del `.Rmd` con el commit de los CSV de este handoff.

## Criterio de aceptación

1. En un clon limpio, `rmarkdown::render("paper1/paper1_climate_projections.Rmd")`
   encuentra `data/outputs/t4b/t4b_full_summary.csv` y renderiza la Tabla de
   identificación sin el error de `file()`.
2. `git ls-files data/outputs/t4b/` lista únicamente los dos CSV de summary; los
   `*_fit.rds` y `*_stan_data.rds` siguen fuera del repo.
3. El PDF resultante es idéntico (los cambios son de tracking/rutas, no de contenido).
