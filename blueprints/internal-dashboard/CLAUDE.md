# Blueprint: Internal Dashboard

This project uses the **Internal Dashboard** blueprint — an authenticated web dashboard with data views.

## Architecture

```
routes/      → Page handlers (render templates with data from services)
services/    → Data aggregation, queries, business logic
models/      → Database tables, Pydantic schemas for API responses
templates/   → Jinja2 HTML templates (dashboard pages, partials)
static/      → CSS, JS, images (served by FastAPI)
middleware/  → Auth (Okta OIDC), rate limiting, request ID
```

## Rules

All rules from `.claude/rules/` apply. Key ones for this blueprint:
- Every page requires authentication (except `/healthz`)
- Role-based views: check Okta group claims before rendering admin-only sections
- Data tables must paginate server-side (never load unbounded result sets)
- Charts use server-rendered data endpoints, not direct DB queries from templates
- 80% test coverage minimum
- No inline `<script>` — CSP blocks it. Use static JS files
