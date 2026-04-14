# Glob: **/config/**,**/*config*,**/*constants*,**/*settings*,**/*env*,**/*globals*

## Config, Constants, Globals — What Belongs Here

Global state and configuration. One place for values the whole app reads.

### Allowed
- Environment variable reads (`os.environ`, `os.Getenv`)
- App-wide constants (status codes, role names, limits)
- Feature flags
- Third-party service config (URLs, timeouts, retry counts)

### Not Allowed — Move It
- Secret values hardcoded → use `os.environ` + `make add-secret`
- Business logic → `services/`
- Type definitions → `models/`
- Utility functions → `utils/`

### Pattern
```python
# config/settings.py
import os

DATABASE_URL = os.environ["DATABASE_URL"]
PORT = int(os.environ.get("PORT", "8080"))
DEV_MODE = os.environ.get("DEV_MODE", "false").lower() == "true"
RATE_LIMIT = int(os.environ.get("RATE_LIMIT", "100"))
```

```python
# config/constants.py
ROLES = {"admin", "member", "viewer"}
MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10MB
PASSWORD_MIN_LENGTH = 12
```

### Violations to Block
- `os.getenv()` or `os.environ` scattered across multiple files → centralize in ONE config file
- Secret value hardcoded in any file → refuse, redirect to `make add-secret`
- Config file importing from `routes/`, `services/`, or `models/` → config depends on NOTHING
- Missing default for an optional env var → add a sensible default
- Missing startup check for a required env var → fail fast at startup, not at request time
- Magic numbers or strings in business logic → extract to constants

### Rules
- Config reads from environment. Constants are literal values. Don't mix them
- One file for env-based config (`settings.py`), one for constants (`constants.py`)
- Never import from `routes/`, `services/`, or `models/` — config is the bottom layer
- Every env var has a default OR fails loudly at startup (not silently at request time)
- Secrets (passwords, keys, tokens) go through `make add-secret` → `.env` → `os.environ`
