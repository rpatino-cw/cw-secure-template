#!/usr/bin/env bash
# Fixture: target already has CLAUDE.md. Apply should APPEND with markers,
# preserving user content. Re-run should REPLACE the marked section
# (not duplicate it).

source "$(dirname "$0")/../lib.sh"
setup "existing-claude-md"

# Build: FastAPI app with pre-existing CLAUDE.md containing user content
cat > pyproject.toml <<'EOF'
[project]
name = "existing-app"
dependencies = ["fastapi>=0.115"]
EOF
mkdir -p src && touch src/main.py

cat > CLAUDE.md <<'EOF'
# existing-app

This project uses FastAPI for payments processing.
Keep endpoints under 50 LOC.
EOF

git_init_repo "init with existing CLAUDE.md"

# First integrate
run_integrate "$FIXTURE_DIR" > /tmp/cw-test-out.log
assert_exit_code 0 $? "first apply"

# User's original content must survive
assert_contains CLAUDE.md "This project uses FastAPI for payments processing." \
  "user content preserved"
assert_contains CLAUDE.md "Keep endpoints under 50 LOC." \
  "user guideline preserved"

# Markers must be present, exactly once
assert_marker_count CLAUDE.md "CW-SECURE-ADOPT: DO NOT EDIT" 1
assert_marker_count CLAUDE.md "CW-SECURE-ADOPT: END" 1

# Commit the integration so re-run has a clean tree
git add -A && git commit -q -m "first integration"

# Re-run — marker section must replace, not duplicate
run_integrate "$FIXTURE_DIR" > /tmp/cw-test-out.log
assert_exit_code 0 $? "second apply (idempotent)"

assert_marker_count CLAUDE.md "CW-SECURE-ADOPT: DO NOT EDIT" 1
assert_marker_count CLAUDE.md "CW-SECURE-ADOPT: END" 1
assert_contains CLAUDE.md "This project uses FastAPI for payments processing." \
  "user content still intact after re-run"

teardown
