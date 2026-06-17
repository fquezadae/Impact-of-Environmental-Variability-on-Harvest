# Handoff — Hacer `paper1_climate_projections.Rmd` knit-friendly en cualquier PC

**Para:** sesión Cowork en el PC del trabajo (el que SÍ tiene los datos locales).
**Objetivo:** que `paper1/paper1_climate_projections.Rmd` se pueda knitear en cualquier
máquina (casa, trabajo, coautor) sin editar el `.Rmd` ni el error críptico de `gzfile()`.

---

## Diagnóstico (por qué falla en otro PC)

El render corta en el chunk `load_biomass`:

```
Quitting from lines 237-240 [load_biomass]
Error in `gzfile()`: ! cannot open the connection
  readRDS("data/biomass/biomass_dt.rds")
```

No es un bug de rutas. El setup (`knitr::opts_knit$set(root.dir = here::here())`)
y el junction `paper1/data -> ../data` están bien y son portables. **El problema es
que faltan los archivos de datos**: `data/biomass/`, `data/harvest/`, `data/trips/`,
etc. están en `.gitignore` ("tracked locally only"), así que un clon de git en otra
máquina no los tiene. Solo existen en el disco local de este PC.

## Inventario de insumos que el `.Rmd` lee al renderizar

> Líneas aproximadas; pueden correrse unas pocas tras editar. Verificar con grep.

| Insumo | Línea | Estado en git | ¿Está en otros PC hoy? |
|---|---|---|---|
| `<dirdata>Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds` | 231 | externo (OneDrive) | Sí, si OneDrive sincroniza |
| `<dirdata>Environmental/env/2000-2011/EnvCoastDaily_2000_2011_0.25deg.rds` | 232 | externo (OneDrive) | Sí, si OneDrive sincroniza |
| `data/biomass/biomass_dt.rds` | 238 | **gitignored** | **No** ← bloqueante |
| `data/harvest/sernapesca_v2.rds` | 244 | **gitignored** | **No** ← bloqueante |
| `data/trips/poisson_dt.rds` | 406 | **gitignored** | **No** ← bloqueante |
| `data/cmip6/deltas_ensemble.csv` | 655 | trackeado | Sí |
| `paper1/tables/growth_comparative_statics.csv` | 744 | trackeado | Sí |
| `paper1/tables/trip_comparative_statics_raw.csv` | 795 | trackeado | Sí |
| `paper1/tables/trip_comparative_statics_by_tipo_emb_raw.csv` | 882 | trackeado | Sí |
| `../figs/env_data_map.pdf` | 262 | revisar | no bloqueante (`error = FALSE`) |

El hueco real son los tres `.rds` procesados gitignored (biomass, harvest, trips)
más los dos `.rds` ambientales de OneDrive.

---

## Tareas (en orden)

### 1. Decidir dónde viven los 3 `.rds` procesados

Primero medir tamaño y sensibilidad:

```r
f <- c("data/biomass/biomass_dt.rds",
       "data/harvest/sernapesca_v2.rds",
       "data/trips/poisson_dt.rds")
data.frame(f, MB = round(file.size(here::here(f)) / 1e6, 1))
```

- **Si son chicos (< ~50 MB) y no son microdatos sensibles** → commitearlos al repo
  con una excepción en `.gitignore` (opción A). Es lo más knit-friendly: cualquier
  clon knitea sin pasos extra.
- **Si son grandes o sensibles** (p. ej. `poisson_dt.rds` con microdato de bitácora)
  → dejarlos en la carpeta OneDrive `dirdata` y leerlos desde ahí (opción B), porque
  OneDrive ya está sincronizado en los PCs del equipo.

> Nota: `biomass_dt.rds` y `sernapesca_v2.rds` suelen ser series procesadas (chicas);
> `poisson_dt.rds` es el panel de viajes y puede ser pesado/sensible. Es válido
> commitear los dos primeros y mandar el tercero a OneDrive.

#### Opción A — commitear (para los que se decidan)

Agregar excepciones al `.gitignore` (raíz), DESPUÉS de las reglas `/data/...`:

```gitignore
# Excepciones: insumos procesados que el manuscrito necesita para knitear
!/data/biomass/biomass_dt.rds
!/data/harvest/sernapesca_v2.rds
# (agregar poisson_dt.rds aquí solo si NO es sensible)
```

Luego:

```bash
git add -f data/biomass/biomass_dt.rds data/harvest/sernapesca_v2.rds
git commit -m "Track processed rds needed to knit paper1 on any machine"
```

#### Opción B — mover a OneDrive `dirdata`

Copiar el/los `.rds` a, p. ej., `<dirdata>processed/` y cambiar la lectura en el
`.Rmd` de `readRDS("data/trips/poisson_dt.rds")` a
`readRDS(paste0(dirdata, "processed/poisson_dt.rds"))`. Repetir en cada PC que
no comparta el mismo OneDrive.

### 2. Refactor de `dirdata` a variable de entorno (chunk `directorio`, ~líneas 63-76)

Hoy hay 3 ramas hardcodeadas por usuario. Reemplazar por una variable de entorno con
fallback, así un PC nuevo solo define `FONDECYT_DATA` en su `~/.Renviron` (o
`usethis::edit_r_environ()`) en vez de editar el `.Rmd`:

```r
# Raíz de datos externos (OneDrive). Resolución:
#   1) variable de entorno FONDECYT_DATA (recomendado; definir en .Renviron)
#   2) fallback por usuario (compatibilidad con setup actual)
dirdata <- Sys.getenv("FONDECYT_DATA", unset = NA)
if (is.na(dirdata) || !nzchar(dirdata)) {
  dirdata <- switch(
    Sys.info()[["user"]],
    "felip"  = "C:/Users/felip/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/",
    "FACEA"  = "C:/Users/FACEA/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/",
    "Felipe" = "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/",
    stop("Define FONDECYT_DATA en tu .Renviron, o agrega tu usuario en el chunk 'directorio'.")
  )
}
if (!grepl("/$", dirdata)) dirdata <- paste0(dirdata, "/")   # asegurar trailing slash
if (!dir.exists(dirdata)) stop(sprintf("dirdata no existe: %s", dirdata))
```

### 3. Guard de insumos (nuevo chunk, justo después de `directorio`)

Que falle temprano y claro, listando exactamente qué falta, en vez del error de
`gzfile()`:

```r
# Preflight: verificar que todos los insumos del render existan.
required <- c(
  paste0(dirdata, "Environmental/env/EnvCoastDaily_2012_2025_0.125deg.rds"),
  paste0(dirdata, "Environmental/env/2000-2011/EnvCoastDaily_2000_2011_0.25deg.rds"),
  here::here("data/biomass/biomass_dt.rds"),
  here::here("data/harvest/sernapesca_v2.rds"),
  here::here("data/trips/poisson_dt.rds"),
  here::here("data/cmip6/deltas_ensemble.csv"),
  here::here("paper1/tables/growth_comparative_statics.csv"),
  here::here("paper1/tables/trip_comparative_statics_raw.csv"),
  here::here("paper1/tables/trip_comparative_statics_by_tipo_emb_raw.csv")
)
missing <- required[!file.exists(required)]
if (length(missing)) {
  stop("Faltan insumos para el knit (sincronízalos; ver data/README.md):\n",
       paste0("  - ", missing, collapse = "\n"))
}
```

> Si en la tarea 1 mueves algún `.rds` a OneDrive, actualiza su ruta aquí y en el
> chunk que lo lee.

### 4. (Opcional, recomendado a futuro) Separar "compute" de "render"

El patrón más robusto: un script de build corre el procesamiento pesado en el PC que
tiene los datos crudos y guarda **artefactos chicos** (`paper1/tables/*.csv`,
`paper1/figs/*.pdf`, y los `.rds` procesados) que se commitean. El `.Rmd` solo lee
esos artefactos → knitea en segundos en cualquier PC sin datos crudos. Ya lo hacen
para las tablas; extenderlo a biomass/harvest/trips elimina toda dependencia
gitignored en tiempo de render.

### 5. Documentar en `data/README.md`

Asegurar que `data/README.md` diga, para cada `.rds` gitignored: qué script lo genera,
desde qué fuente cruda, o desde dónde copiarlo. Así un PC sin datos sabe cómo
obtenerlos.

---

## Criterio de aceptación

1. En un clon limpio (o PC sin la carpeta `data/` local), `rmarkdown::render(...)` o
   bien knitea completo, o falla en el guard (tarea 3) con la lista exacta de archivos
   faltantes — nunca con el error de `gzfile()`.
2. Definir `FONDECYT_DATA` en `.Renviron` basta; no hay que editar el `.Rmd`.
3. El PDF resultante es idéntico al actual (los cambios son de rutas/insumos, no de
   contenido).

## Nota sobre las ediciones recientes de la Tabla 6

Ya se acortaron el título y las notas de la Tabla 6 (`tab:tripcompstatemb`) y se quitó
una redundancia en el Discussion. Eso es independiente de este problema de knit (la
Tabla 6 lee de `paper1/tables/*.csv`, que sí están trackeados). No requiere acción aquí.
