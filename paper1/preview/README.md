# Prose-only previews

HTML renders of `paper1_climate_projections.Rmd` (and inlined child
sections from `paper1/sections/`) with all R code chunks stripped.
Useful only for reading prose flow and comparing wording across
branches; tables, figures, and inline R values are absent.

## Files

- `build_prose_preview.py` — script that strips chunks and inlines
  child Rmds. Re-run to regenerate the markdown.
- `preview_MRE.{md,html}` — current (MRE-style) branch.
- `preview_original.{md,html}` — `main` branch (pre-edit baseline).

Open the `.html` files in any browser. They link MathJax and water.css
from CDNs, so they display equations and basic typography without
local dependencies.

## Regenerate

```bash
python3 paper1/preview/build_prose_preview.py
pandoc paper1/preview/preview_prose.md \
  -o paper1/preview/preview_<label>.html \
  --standalone \
  --mathjax="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js" \
  --css=https://cdn.jsdelivr.net/npm/water.css@2/out/water.css
```

These artifacts are not part of the manuscript; they exist for
within-session reading and can be deleted at any time.
