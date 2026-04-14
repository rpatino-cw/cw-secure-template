# Glob: **/main.*,**/app.*,**/index.py,**/index.ts,**/server.*

## Entry Point — What Belongs Here

The entry point STARTS the app. It wires things together. No logic lives here.

### Allowed
- App initialization (create app instance)
- Middleware registration (auth, rate limit, CORS, headers)
- Route registration (import and mount route files)
- Server startup (listen on port)
- Graceful shutdown handling
- Startup validation (check required env vars exist)

### Not Allowed — Move It
- Route handler definitions → `routes/`
- Business logic → `services/`
- Model definitions → `models/`
- Database setup → `db/` or `config/`
- Utility functions → `utils/`
- Constants → `config/`

### Pattern
```python
# main.py — startup only
app = FastAPI(docs_url=None)
app.add_middleware(AuthMiddleware)
app.add_middleware(RateLimitMiddleware)
app.include_router(users_router, prefix="/api")
app.include_router(teams_router, prefix="/api")

@app.get("/healthz")
def health(): return {"status": "ok"}
```

### Rules
- Entry point is under 50 lines. If it's longer, you're putting logic here
- Every route is imported from `routes/`, not defined inline
- Every middleware is imported from `middleware/`, not defined inline
- Required env vars are checked at startup — fail fast, not at request time
