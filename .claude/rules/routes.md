# Glob: **/routes/**,**/handlers/**,**/views/**,**/api/**,**/*router*,**/*route*

## Route Files — What Belongs Here

Route files are THIN. They receive requests and return responses. Nothing else.

### Allowed
- HTTP handler/endpoint definitions
- Request parsing (reading path params, query params, body)
- Calling a service function and returning its result
- Setting response status codes and headers

### Not Allowed — Move It
- Business logic → `services/`
- Database queries → `models/` or `repositories/`
- Data validation schemas → `models/` or `schemas/`
- Utility functions → `utils/`
- Constants or config → `config/`
- Shared types/interfaces → `types/`

### Pattern
```
request in → validate input → call service → return response
```

A route handler should be 10-20 lines max. If it's longer, logic leaked in.

### Dependency Direction
```
routes/ imports from → services/, models/
routes/ NEVER imports from → repositories/, db/, utils/ directly
```

Handlers call services. Services call repositories. Never skip a layer.

### Violations to Block
- Handler longer than 20 lines → logic leaked in, extract to service
- `import` from `repositories/` or `db/` in a route file → must go through service layer
- Raw SQL or ORM query in a route handler → move to repository
- Business conditional (`if user.role == "admin"`) in a handler → move to service
- Multiple resources in one route file → split into separate files
- Route defined in `main.py` or `app.py` → move to `routes/`

### When Adding a New Route
1. Create a new file per resource: `routes/users.py`, `routes/teams.py`
2. Never add routes to an existing file that handles a different resource
3. Register the route in the main app file — don't auto-discover
4. Every route gets a corresponding test file: `tests/test_users.py`
