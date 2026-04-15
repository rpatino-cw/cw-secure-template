# Blueprint: API Service

This project uses the **API Service** blueprint — a REST API with CRUD endpoints.

## Architecture

```
routes/    → Thin HTTP handlers (parse request, call service, return response)
services/  → Business logic (knows the rules, doesn't know HTTP)
models/    → Data shapes (Pydantic models, SQLAlchemy tables)
middleware/→ Cross-cutting concerns (auth, rate limiting, request ID)
```

## Rules

All rules from `.claude/rules/` apply. Key ones for this blueprint:
- Every endpoint requires authentication (except `/healthz`)
- 80% test coverage minimum
- Routes call services, services call repositories — never skip layers
- All database queries parameterized
