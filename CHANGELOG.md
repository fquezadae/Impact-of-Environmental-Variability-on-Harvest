# Changelog

Notable changes to the project, in reverse chronological order.

## 2026-04-18

### Fixed
- `paper1/paper1_climate_projections.Rmd` now knits end-to-end from a fresh R
  session. Several compounding issues were resolved.

#### R Markdown — chunk evaluation

- Added `knitr::opts_knit$set(root.dir = here::here())` to the `directorio`
  setup chunk so relative paths in later chunks resolve from the project
  root, not from `paper1/`. This removes the dependency on the Windows
  junctions (`paper1/data`, `paper1/figs`, `paper1/tables`, etc.) which
  are not portable across machines or preserved by git.
- Centralised core library loads (`dplyr`, `tidyr`, `data.table`) in the
  `directorio` chunk. Previously `arrange()`, `filter()`, and `data.table`
  syntax (`.()`, `by=`, `dcast`, `:=`) were used in chunks that did not
  load the corresponding packages — it worked interactively only because
  the user's R session happened to have them already loaded.
- Replaced three `select(...)` calls with `dplyr::select(...)` in the
  chunks `biomassprojections`, `decompositiontable`, and `projfigure`.
  These run after `library(MASS)` (loaded in the `est_poisson` chunk),
  which masks `dplyr::select` with `MASS::select`.

#### R Markdown — YAML & pandoc

- Changed `bibliography: bibliography.bib` → `bibliography: ../bibliography.bib`
  and `csl: apa.csl` → `csl: ../apa.csl`. Pandoc resolves these paths
  relative to the Rmd, and `paper1/bibliography.bib` / `paper1/apa.csl`
  are broken junction stubs (plain text files on non-Windows systems).

#### R Markdown — figures

- Changed `include_graphics("figs/env_data_map.pdf")` →
  `include_graphics("../figs/env_data_map.pdf", error = FALSE)` in the
  `figEnvData` chunk. The relative path is resolved by xelatex from the
  location of the `.tex` file (`paper1/`), so `..` correctly reaches the
  project root. `error = FALSE` disables knitr's pre-flight existence
  check, which otherwise runs from the chunk's working directory (project
  root, due to `opts_knit$set(root.dir = ...)`) where `../figs/` would
  point outside the project.

#### Environment

- Migrated local LaTeX distribution from MiKTeX 2.9 (pre-2019, could not
  install new packages because its repository is too old) to TinyTeX.
  Install command: `tinytex::install_tinytex(force = TRUE)`. TinyTeX
  lives at `%APPDATA%/TinyTeX` and auto-installs LaTeX packages as
  xelatex requests them.

### Known issues / follow-ups

- Figure 3 renders wider than the page width in the compiled PDF. Needs
  `out.width` / `fig.width` adjustment.
- The `paper1/` subdirectory contains Windows junctions (`data`, `figs`,
  `logo`, `R`, `tables`, `bibliography.bib`, `apa.csl`) that do not
  travel well via git. Consider replacing all remaining uses with
  `here::here()` or relative paths from `paper1/`, and deleting the
  junctions from the repo.
- 13 scattered `library(...)` calls remain inside individual chunks.
  Consolidating them into the `directorio` chunk would make dependencies
  obvious at the top of the Rmd. Candidates: `ggplot2`, `scales`,
  `viridis`, `janitor`, `lavaan`, `stargazer`, `MASS`, `sandwich`,
  `lmtest`, `knitr`, `kableExtra`.
- `library(MASS)` masks `dplyr::select`. Safer to call `MASS::glm.nb()`
  directly without attaching MASS.

### Added
- `data/harvest/` and `data/biomass/` output directories populated by
  running `R/01_data_cleaning/harvest_data.R` and
  `R/01_data_cleaning/biomass_data.R` in order. These directories (and
  the `.rds` files inside) are excluded from git per `.gitignore`.
