# guards/architecture.sh — Stack lock, SQL in routes, auth, dependency direction
# Sourced by guard.sh. Uses: FILE_PATH, CONTENT, REPO_ROOT

# --- Stack lock ---
STACK_FILE="$REPO_ROOT/.stack"
if [[ -f "$STACK_FILE" && -n "$FILE_PATH" ]]; then
  LOCKED_STACK=$(cat "$STACK_FILE" | tr -d '[:space:]')
  case "$LOCKED_STACK" in
    go)
      if [[ "$FILE_PATH" == *"python/"* ]]; then
        echo "BLOCKED: This project is locked to Go. Cannot edit Python files." >&2
        echo "The Python starter was removed during 'make init'." >&2
        exit 2
      fi
      ;;
    python)
      if [[ "$FILE_PATH" == *"go/"* ]]; then
        echo "BLOCKED: This project is locked to Python. Cannot edit Go files." >&2
        echo "The Go starter was removed during 'make init'." >&2
        exit 2
      fi
      ;;
  esac
fi

# --- SQL in route handlers ---
if [[ -n "$CONTENT" && "$FILE_PATH" == *"routes/"* ]]; then
  SQL_PATTERNS=(
    'SELECT\s+.*\s+FROM\s+'
    'INSERT\s+INTO\s+'
    'UPDATE\s+.*\s+SET\s+'
    'DELETE\s+FROM\s+'
    'cursor\.\s*execute'
    'session\.\s*execute'
    'session\.\s*query'
    'db\.\s*execute'
    '\.raw\s*\('
  )
  for pattern in "${SQL_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qEi "$pattern" 2>/dev/null; then
      echo "BLOCKED: Database query detected in route handler: $FILE_PATH" >&2
      echo "Pattern: $pattern" >&2
      echo "Route handlers must NOT contain SQL or ORM queries." >&2
      echo "Move database access to repositories/ or services/." >&2
      exit 2
    fi
  done
fi

# --- Route auth enforcement ---
if [[ -n "$CONTENT" && "$FILE_PATH" == *"routes/"* ]]; then
  HAS_NEW_ROUTE=false
  IS_HEALTH=false

  if echo "$CONTENT" | grep -qE '@(app|router)\.(get|post|put|delete|patch)' 2>/dev/null; then
    HAS_NEW_ROUTE=true
  fi
  if echo "$CONTENT" | grep -qE '(HandleFunc|Handle)\s*\(' 2>/dev/null; then
    HAS_NEW_ROUTE=true
  fi
  if echo "$CONTENT" | grep -qE '(healthz|health|readyz|livez)' 2>/dev/null; then
    IS_HEALTH=true
  fi

  if [[ "$HAS_NEW_ROUTE" == true && "$IS_HEALTH" == false ]]; then
    FULL_FILE=""
    if [[ -f "$FILE_PATH" ]]; then
      FULL_FILE=$(cat "$FILE_PATH" 2>/dev/null || echo "")
    fi
    COMBINED="${FULL_FILE}${CONTENT}"

    if ! echo "$COMBINED" | grep -qE '(Depends\s*\(\s*get_current_user|current_user|RequireAuth|AuthMiddleware|WithAuth|authenticate)' 2>/dev/null; then
      echo "BLOCKED: Route endpoint in $FILE_PATH missing authentication" >&2
      echo "Every endpoint (except /healthz) requires auth middleware." >&2
      echo "Python: Add Depends(get_current_user) to endpoint parameters." >&2
      echo "Go: Wrap handler with RequireAuth(handler)." >&2
      echo "For local dev without Okta, set DEV_MODE=true in .env." >&2
      exit 2
    fi
  fi
fi

# --- Dependency direction ---
if [[ -n "$CONTENT" && "$FILE_PATH" == *"models/"* ]]; then
  if echo "$CONTENT" | grep -qE '(from\s+(routes|services|repositories|handlers|delivery)|import\s+.*(routes|services|repositories|handlers|delivery))' 2>/dev/null; then
    echo "BLOCKED: Invalid import in model file: $FILE_PATH" >&2
    echo "models/ must NOT import from routes/, services/, or repositories/" >&2
    echo "Dependency direction: models depend on NOTHING. Everything else depends on models." >&2
    exit 2
  fi
  if echo "$CONTENT" | grep -qE '"[^"]*/(routes|services|repository|handlers|delivery|controller)"' 2>/dev/null; then
    echo "BLOCKED: Invalid import in model file: $FILE_PATH" >&2
    echo "models/ must NOT import from routes/, services/, or repositories/" >&2
    exit 2
  fi
fi

if [[ -n "$CONTENT" && "$FILE_PATH" == *"routes/"* ]]; then
  if echo "$CONTENT" | grep -qE '(from\s+(repositories|repo|db)|import\s+.*(repositories|repo))' 2>/dev/null; then
    echo "BLOCKED: Route handler importing directly from repository: $FILE_PATH" >&2
    echo "routes/ must call services/, not repositories/ directly." >&2
    echo "Dependency direction: routes -> services -> repositories -> models" >&2
    exit 2
  fi
  if echo "$CONTENT" | grep -qE '"[^"]*/(repository|repo|db)"' 2>/dev/null; then
    echo "BLOCKED: Route handler importing directly from repository: $FILE_PATH" >&2
    echo "routes/ must call services/, not repositories/ directly." >&2
    exit 2
  fi
fi
