# CWT dashboard visual check

Playwright script that loads `.cwt/cwt.html` with mocked `/api/plans` and
`/api/manifest` responses, screenshots each filter tab, and asserts that
the rating UI elements are present.

Solves the "can't bind a port from inside Claude's sandbox" problem —
fetches are intercepted by Playwright, no server required.

## Run

```bash
npm i -D playwright
npx playwright install chromium
node .cwt/tests/visual-check.js
```

Screenshots land in `.cwt/tests/screenshots/` (gitignored).

## Fixtures

Four mock plans cover the full rating spectrum:

| Plan | Status | Overall | Purpose |
|------|--------|---------|---------|
| exempt | approved | `exempt` | CWT tooling path (`.cwt/server.py`) — no score |
| good | pending | 90 | Multi-file plan citing most applicable rules |
| bad | pending | 20 | Vague justification, low citation coverage |
| rejected | rejected | 0 | Hardcoded secret — violates security.md |

## Assertions

The script fails if any of these are missing from the rendered `all` tab:

- 4 plan cards total
- ≥1 `.score.high` pill (green)
- ≥1 `.score.low` pill (red)
- ≥1 `.score.exempt` pill (dim)
- ≥1 `.cited` rule list entry
- ≥1 `.uncited` rule list entry

## When to run

- After editing `.cwt/cwt.html` (layout, styles, render logic)
- After editing `.cwt/rater.py` (scoring shape changes — update fixtures)
- In CI if/when CWT gets a CI pipeline
