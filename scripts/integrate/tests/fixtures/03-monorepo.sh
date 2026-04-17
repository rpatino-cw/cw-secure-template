#!/usr/bin/env bash
# Fixture: monorepo with Python backend/ + Node frontend/.
# Default scan: detects both, ambiguity warning fires.
# Scoped scan: only the requested subdir is integrated.

source "$(dirname "$0")/../lib.sh"
setup "monorepo"

mkdir -p backend/src frontend/src

# Python backend
cat > backend/pyproject.toml <<'EOF'
[project]
name = "mono-backend"
dependencies = ["fastapi>=0.115"]
EOF
touch backend/src/main.py

# Node frontend
cat > frontend/package.json <<'EOF'
{"name":"mono-frontend","version":"0.1.0","dependencies":{"next":"^14.0.0"}}
EOF
mkdir -p frontend/src && touch frontend/src/index.js

git_init_repo "init monorepo"

# 1. Default scan should detect Python (Node needs --include-node)
out=$(run_scan "$FIXTURE_DIR")
if echo "$out" | grep -q "python"; then pass "detected python backend"; else fail "python not detected"; fi

# 2. Include-node scan should detect both — ambiguity expected
out=$(run_scan "$FIXTURE_DIR" --include-node)
if echo "$out" | grep -q "Multiple stacks detected"; then
  pass "ambiguity warning fires with both stacks"
else
  fail "expected ambiguity warning for monorepo"
fi

# 3. Scoped integrate — ONLY backend/
run_integrate "$FIXTURE_DIR" --scope=backend/ > /tmp/cw-test-out.log
assert_exit_code 0 $? "scoped apply (backend)"

# backend got middleware
assert_dir_exists "backend/src/middleware/cw"
# frontend did NOT get middleware (scope excluded it)
if [ -d "frontend/src/middleware/cw" ]; then
  fail "frontend should NOT have middleware when scoped to backend"
else
  pass "frontend untouched (scope respected)"
fi

teardown
