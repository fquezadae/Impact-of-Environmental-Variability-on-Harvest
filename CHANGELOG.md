# Changelog

Notable changes to the project, in reverse chronological order.

## 2026-04-20 (paper1: NB table rendering + manuscript comments + bibliography review)

### Fixed

- `paper1/paper1_climate_projections.Rmd`: the `tabla_poisson` chunk
  failed silently because `stargazer` does not recognize
  `MASS::glm.nb` objects — the error was emitted as a LaTeX comment
  (`% Error: Unrecognized object type`) and the table disappeared
  from the PDF. Workaround: fit a Poisson GLM with the same formula
  (already computed for the LR test), replace its `$coefficients`
  with the NB coefficients, and pass the shell object to `stargazer`
  with clustered SEs supplied externally via `se = list(...)`.
  `stargazer` treats it as a GLM and prints the NB point estimates;
  the LR test statistic is reported in the notes so the reader knows
  the reported estimates come from NB, not Poisson.
- `paper1/paper1_climate_projections.Rmd`: renamed the chunk label
  from `poisson_results` to `poissonresults` (no underscore) — the
  underscore in the chunk name was being injected by bookdown into
  the caption as `(\#tab:poisson_results)` raw text, triggering
  math-mode errors (`Missing $ inserted`). Cross-references now
  resolve.
- `paper1/paper1_climate_projections.Rmd`: fixed the `omit.stat`
  argument in `stargazer` — replaced the invalid statistic names
  `c("f", "deviance", "null.deviance")` with the NB-compatible
  `c("ll", "aic", "bic", "res.dev", "null.dev")`. The invalid names
  were raising `% Error: Unknown statistic in 'omit.stat' argument`
  and dropping the whole table.
- `paper1/paper1_climate_projections.Rmd` YAML: added
  `keep_tex: true` to the `bookdown::pdf_document2` output block so
  stargazer/LaTeX errors (which surface as `%`-commented lines in
  the `.tex`) can be diagnosed directly.
- `bibliography.bib`: replaced the phantom `Arcos2001-jq` entry with
  the real paper — Arcos, Cubillos & Núñez (2001), "The jack
  mackerel fishery and El Niño 1997–98 effects off Chile", Progress
  in Oceanography 49(1–4):597–617, DOI
  `10.1016/S0079-6611(01)00043-X`. Previous entry had an
  unverifiable title/journal and no usable DOI.
- `bibliography.bib`: replaced the phantom `Aufhammer2018` entry.
  The previous entry had a fabricated title ("Quantifying climatic
  and weather impacts on health in the presence of adaptation"),
  wrong journal (Annals of the NYAS), and a DOI
  (`10.1111/nyas.13625`) that resolves to an unrelated cancer
  immunotherapy paper (verified via CrossRef). Replaced with
  Auffhammer (2018), "Quantifying Economic Damages from Climate
  Change", Journal of Economic Perspectives 32(4):33–52, DOI
  `10.1257/jep.32.4.33` — contextually consistent with how the
  citation is used in §3.3 (adaptation caveat on climate
  projections). Citation key kept as `Aufhammer2018` (single f) to
  avoid touching the `.Rmd`; the `author` field carries the correct
  "Auffhammer" spelling that pandoc will render.

### Changed

- `paper1/paper1_climate_projections.Rmd` Discussion: removed the
  self-congratulatory "novel contribution" framing around the
  direct-vs-indirect channel decomposition. The decomposition is
  mechanically straightforward given the structural model; presenting
  it as a methodological innovation was oversold. Replaced with a
  neutral lead-in that keeps the substantive finding (indirect
  channel dominates).
- `paper1/paper1_climate_projections.Rmd` Discussion: replaced the
  forced Birkenbach et al. (2020) citation (about catch-share
  reforms in the US groundfish fishery — not a close fit to the
  multi-species portfolio argument being made) with Kasperski &
  Holland (2013, PNAS), which is the canonical reference for
  portfolio diversification reducing revenue variability in
  fisheries. The argument in the paragraph now reads more cleanly
  as an application of the portfolio-theory logic to the Chilean
  SPF context.

### Bibliography review

- Full verification pass over the 31 unique citation keys used in
  `paper1_climate_projections.Rmd`. Two phantom citations found and
  fixed (`Arcos2001-jq`, `Aufhammer2018`, above). Remaining 29
  entries checked against their DOIs/URLs; all verified.

## 2026-04-18 (follow-up 2: manuscript consistency pass)

### Changed

- `paper1/paper1_climate_projections.Rmd`: consolidated the
  delta-method projection methodology into Section 3.3 (Data and
  methodology). Previously, the section labelled
  `{#projection-approach}` contained only a one-paragraph caveat
  (interannual vs decadal), while Section 3.2 cross-referenced it for
  methodological detail; the actual delta-method description sat in a
  `### Projection methodology` subheading inside Section 4.3 (Results).
  Moved the two methodology paragraphs and the "two channels" framing
  paragraph from 4.3.1 to 3.3, deleted the 4.3.1 subheading, and
  replaced the top of Section 4.3 with a single-sentence pointer back
  to §3.3. The `\ref{projection-approach}` cross-reference from §3.2
  now resolves to the actual methodology.
- `paper1/paper1_climate_projections.Rmd`: trimmed duplication between
  Introduction and Section 2. Removed the fleet-split detail ("In
  Chile, jack mackerel is predominantly harvested by the industrial
  purse-seine fleet…") from the Introduction's third paragraph since
  it is covered in Section 2's Management regime subsection. Removed
  the "94% of total national fish landings" figure and the 3-species
  enumeration from the opener of Section 2; both are already in
  Introduction paragraph 2. Section 2 now opens with the
  latitudinal-zone structure, which is what it contributes beyond the
  Introduction.
- `paper1/paper1_climate_projections.Rmd`: added a Discussion
  paragraph interpreting the <5% direct weather channel as a
  substantive finding rather than a null result — implies that
  climate adaptation policy should focus on quota allocation /
  transferability (institutional) rather than port infrastructure,
  vessel reinforcement, or weather-indexed insurance (operational).
  Conditional on the IPSL wind projection; flagged for revision under
  multi-model ensembles.
- `paper1/paper1_climate_projections.Rmd`: promoted the `days_closed_vy`
  caveat from a footnote in Results to a fourth explicit limitation in
  Discussion. The closure variable currently varies only across
  regulatory zones (151 vs 182 days), so the positive coefficient for
  the artisanal fleet reflects locational heterogeneity rather than a
  causal effect of exposure to closed days.
- `paper2/paper2_bioeconomic_optimization.Rmd`: updated the sample
  description for the SUR model from "N = 23 annual observations
  (2000–2022)" to "N = 23 annual observations covering the 2000–2024
  sample (one observation lost to the lead structure)", consistent
  with the biomass series used in paper1.

### Fixed

- `paper1/paper1_climate_projections.Rmd`: removed an inline
  `<!-- TODO: add to bibliography.bib ... @Lam2016 ... -->` block from
  the Discussion. The `@Lam2016` entry was already present in
  `bibliography.bib` (line 33); the TODO was stale.

## 2026-04-18 (follow-up: Rmd cleanup)

### Changed

- Consolidated all `library()` calls in `paper1_climate_projections.Rmd`
  into the `directorio` setup chunk. Removed 18 scattered `library()`
  calls from individual chunks. The setup chunk now loads: `dplyr`,
  `tidyr`, `data.table`, `tibble`, `janitor`, `ggplot2`, `scales`,
  `viridis`, `lavaan`, `sandwich`, `lmtest`, `stargazer`, `kableExtra`.
  Replaced a generic `library(tidyverse)` with the specific packages
  actually used (`dplyr`, `tidyr`, `tibble`, `ggplot2`). Removed
  `library(knitr)` (implicitly available during knit).
- Replaced `library(MASS)` with namespaced calls `MASS::glm.nb(...)` in
  the `est_poisson` chunk. MASS is no longer attached to the search
  path, so it cannot mask `dplyr::select`.
- Reverted the three defensive `dplyr::select(...)` calls (in chunks
  `biomassprojections`, `decompositiontable`, `projfigure`) back to
  plain `select(...)` — no longer needed once MASS is unloaded.

### Fixed

- Resized Figure 3 (`projfigure` chunk) so it fits the page width.
  Changed `fig.width=8, fig.height=5` → `fig.width=6.5, fig.height=4`
  and added `out.width='100%'`. Previously the figure overflowed the
  text width at 11pt with 1in margins.

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
