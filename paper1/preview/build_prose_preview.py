#!/usr/bin/env python3
"""Build a prose-only markdown preview from paper1_climate_projections.Rmd.

Strips:
- All ```{r ...} ... ``` code chunks (replaced by a placeholder note)
- Inline R expressions like `r ...`
- YAML front matter is replaced by a minimal stub

Inlines:
- Child Rmd files referenced by ```{r ..., child='...'} chunks

Output: paper1/preview/preview_prose.md
"""
import re
import sys
from pathlib import Path

ROOT = Path("/home/user/Impact-of-Environmental-Variability-on-Harvest")
MAIN = ROOT / "paper1/paper1_climate_projections.Rmd"
OUT_DIR = ROOT / "paper1/preview"
OUT_MD = OUT_DIR / "preview_prose.md"

CHUNK_OPEN_RE = re.compile(r'^```\{r\b([^}]*)\}\s*$')
CHUNK_CLOSE_RE = re.compile(r'^```\s*$')
CHILD_RE = re.compile(r"child\s*=\s*['\"]([^'\"]+)['\"]")
INLINE_R_RE = re.compile(r'`r\s+[^`]+`')


def strip_yaml_to_stub(text: str) -> str:
    """Replace YAML front matter with a minimal title-only stub."""
    if not text.startswith('---\n'):
        return text
    end = text.find('\n---\n', 4)
    if end == -1:
        return text
    stub = (
        "---\n"
        "title: \"Differential Climate Impacts on Fishing Effort in Chilean Small Pelagic Fisheries\"\n"
        "subtitle: \"PROSE-ONLY PREVIEW (R chunks stripped)\"\n"
        "author: \"Felipe J. Quezada-Escalona\"\n"
        "---\n"
    )
    return stub + text[end + len('\n---\n'):]


def process(text: str, source_label: str) -> str:
    """Process a single Rmd's body: strip code chunks, inline children."""
    out_lines = []
    lines = text.splitlines()
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        m = CHUNK_OPEN_RE.match(line)
        if m:
            opts = m.group(1)
            child_match = CHILD_RE.search(opts)
            # find chunk close
            j = i + 1
            while j < n and not CHUNK_CLOSE_RE.match(lines[j]):
                j += 1
            if child_match:
                child_path = ROOT / child_match.group(1)
                if child_path.exists():
                    child_text = child_path.read_text(encoding='utf-8')
                    out_lines.append(f"\n<!-- ====== inlined: {child_match.group(1)} ====== -->\n")
                    out_lines.append(process(child_text, child_match.group(1)))
                    out_lines.append(f"<!-- ====== end inlined: {child_match.group(1)} ====== -->\n")
                else:
                    out_lines.append(f"\n*[child file not found: {child_match.group(1)}]*\n")
            else:
                out_lines.append("\n*[R code chunk omitted]*\n")
            i = j + 1
            continue
        # strip inline R
        cleaned = INLINE_R_RE.sub("[R]", line)
        out_lines.append(cleaned)
        i += 1
    return "\n".join(out_lines)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    text = MAIN.read_text(encoding='utf-8')
    text = strip_yaml_to_stub(text)
    body = process(text, "paper1_climate_projections.Rmd")
    OUT_MD.write_text(body, encoding='utf-8')
    print(f"Wrote {OUT_MD} ({len(body)} chars, {body.count(chr(10))} lines)")


if __name__ == "__main__":
    main()
