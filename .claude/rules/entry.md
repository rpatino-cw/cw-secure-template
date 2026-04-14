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

### Foundation Gate — Infrastructure Before Features
Before ANY endpoint or business logic, the entry point must wire up these in order:
1. Config/settings loaded from environment
2. Logger initialized
3. Database connection established
4. Middleware registered (auth, rate limit, CORS, headers)
5. Routes mounted

If any of these are missing, DO NOT write feature code. Set up infrastructure first.

### Violations to Block
- Entry point longer than 50 lines → logic leaked in, extract
- Route handler defined inline in entry point → move to `routes/`
- Middleware defined inline → move to `middleware/`
- Business logic of any kind → move to `services/`
- Model definition → move to `models/`
- Database query → move to `repositories/`
- Missing health check endpoint (`/healthz`) → add it
- `os.getenv()` scattered throughout → centralize in config, reference config here

### Rules
- Entry point is under 50 lines. If it's longer, you're putting logic here
- Every route is imported from `routes/`, not defined inline
- Every middleware is imported from `middleware/`, not defined inline
- Required env vars are checked at startup — fail fast, not at request time
