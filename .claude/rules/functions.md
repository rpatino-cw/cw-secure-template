# Glob: **/utils/**,**/helpers/**,**/lib/**,**/*util*,**/*helper*

## Utility Functions — What Belongs Here

Pure, reusable functions with no side effects. Tools the rest of the app imports.

### Allowed
- String formatting, date parsing, slug generation
- Hashing, encoding, token generation
- File path manipulation
- Validation helpers (email format, phone format)
- Math, conversion, transformation functions

### Not Allowed — Move It
- Database calls → `repositories/`
- HTTP handling → `routes/`
- Business rules → `services/`
- Config or env vars → `config/`
- Class definitions with state → `models/` or `services/`

### Rules
- Every utility function is PURE — same input, same output, no side effects
- No database connections, no HTTP clients, no file I/O inside utils
- Group by domain: `utils/strings.py`, `utils/dates.py`, `utils/crypto.py`
- If a "utility" has side effects, it's a service — move it
- If a utility is only used in one file, inline it. Don't create a utility for one caller
- Under 20 lines per function. If longer, decompose
