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

### Rules
- One repository file per table/entity: `repositories/user_repo.py`
- Repositories return model objects, not raw rows
- Migrations are versioned and reversible
- Never `SELECT *` — name your columns
