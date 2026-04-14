# Glob: **/db/**,**/database/**,**/repositories/**,**/*repo*,**/*repository*,**/*migration*,**/*query*

## Database Layer — What Belongs Here

Database files handle DATA ACCESS. Queries, connections, migrations. Nothing else.

### Allowed
- SQL queries (parameterized ONLY)
- Database connection setup
- Migration files
- Repository functions (CRUD operations)
- Connection pooling config

### Not Allowed — Move It
- Business logic ("if admin then...") → `services/`
- Data validation → `models/`
- HTTP handling → `routes/`
- Hardcoded connection strings → `config/` reading from `.env`

### Connection Strings
```
NEVER this:  db = connect("postgres://user:pass@host/db")
ALWAYS this: db = connect(os.environ["DATABASE_URL"])
```

Store via `make add-secret`. Hidden input. Never in code. Never in git.

### Queries
```
NEVER this:  f"SELECT * FROM users WHERE id = {user_id}"
ALWAYS this: cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

Every query is parameterized. No exceptions. No string concatenation.

### Passwords
```
NEVER this:  INSERT INTO users (password) VALUES ('plaintext')
ALWAYS this: INSERT INTO users (password_hash) VALUES (bcrypt.hash(password))
```

### Dependency Direction
```
repositories/ imports from → models/ (for return types)
repositories/ NEVER imports from → routes/, services/
```

Repositories know HOW to get data. They don't know WHY.

### Violations to Block
- String concatenation in ANY query → parameterized only, always
- Hardcoded connection string anywhere → must read from env/config
- Database query in a route handler → must go through repository + service
- `SELECT *` → name every column explicitly
- Schema change without a migration file → all schema changes go through migrations
- `cursor.execute()` or `session.execute()` in a service file → must be in repository
- Plain text password in an INSERT → must hash first

### Rules
- One repository file per table/entity: `repositories/user_repo.py`
- Repositories return model objects, not raw rows
- Migrations are versioned and reversible
- Never `SELECT *` — name your columns
