#!/usr/bin/env bash
# Fixture: target has uncommitted changes. Without --force, apply must REFUSE.
# With --force, apply must proceed and the backup tag still captures the
# pre-integration state.

source "$(dirname "$0")/../lib.sh"
setup "dirty-git"

cat > pyproject.toml <<'EOF'
[project]
name = "dirty-app"
dependencies = ["fastapi>=0.115"]
EOF
mkdir -p src && echo "print('v1')" > src/main.py

git_init_repo "init clean"

# Introduce uncommitted change
echo "print('v2-uncommitted')" > src/main.py

# 1. Without --force — must refuse (non-zero exit)
run_integrate "$FIXTURE_DIR" > /tmp/cw-test-out.log
code=$?
if [ $code -ne 0 ]; then
  pass "apply refused dirty tree (exit=$code)"
else
  fail "apply should have refused dirty tree, but exited 0"
fi
# Nothing should have been written
if [ ! -d ".cw-secure" ]; then pass "no .cw-secure/ created"; else fail ".cw-secure/ created despite refusal"; fi

# 2. With --force — must proceed and backup tag the dirty state
run_integrate "$FIXTURE_DIR" --force > /tmp/cw-test-out.log
assert_exit_code 0 $? "apply with --force succeeded"
assert_dir_exists ".cw-secure"

# Backup tag should exist
if git tag --list | grep -q "^cw-integrate-backup-"; then
  pass "backup tag created under --force"
else
  fail "no backup tag created"
fi

teardown
