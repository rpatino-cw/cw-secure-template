# Glob: **/*.{go,py}

## Code Style

### General
- Keep functions short — under 40 lines
- One responsibility per function
- Descriptive names over comments (but add SECURITY LESSON comments for security decisions)
- No dead code, no commented-out code

### Go
- Follow `gofmt` / `golangci-lint` standards
- Use `slog` for structured logging (not `log` or `fmt.Println`)
- Error handling: always check errors, never `_ = someFunc()`
- Context: propagate `context.Context` through handlers

### Python
- Follow `ruff` formatting and linting rules
- Use `structlog` for structured logging (not `print` or `logging.info`)
- Type hints on all function signatures
- Pydantic models for all API input/output
- `ConfigDict(strict=True)` on input models

### Imports
- Go: stdlib first, then third-party, then local
- Python: stdlib, third-party, local — enforced by `ruff` isort rules
