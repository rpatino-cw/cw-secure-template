#!/usr/bin/env bash
# Fixture: target has an existing .pre-commit-config.yaml with a custom hook.
# Apply must MERGE repos (add gitleaks etc.) without removing the custom hook.

source "$(dirname "$0")/../lib.sh"
setup "existing-precommit"

cat > pyproject.toml <<'EOF'
[project]
name = "precommit-app"
dependencies = ["fastapi>=0.115"]
EOF
mkdir -p src && touch src/main.py

# Existing .pre-commit with one user-defined repo
cat > .pre-commit-config.yaml <<'EOF'
repos:
  - repo: https://github.com/existinguser/custom-hook
    rev: v1.2.3
    hooks:
      - id: custom-check
EOF

git_init_repo "init with existing pre-commit"

run_integrate "$FIXTURE_DIR" > /tmp/cw-test-out.log
assert_exit_code 0 $? "apply succeeded"

# Custom hook survives
assert_contains .pre-commit-config.yaml "https://github.com/existinguser/custom-hook" \
  "user's custom hook repo preserved"
assert_contains .pre-commit-config.yaml "custom-check" \
  "user's custom hook id preserved"

# Template's repos added (gitleaks is the canary)
assert_contains .pre-commit-config.yaml "gitleaks" \
  "gitleaks merged in"

# Verify it's still valid YAML and has >= 2 repos
python3 -c "
import yaml, sys
with open('.pre-commit-config.yaml') as f: d = yaml.safe_load(f)
assert isinstance(d.get('repos'), list), 'no repos array'
assert len(d['repos']) >= 2, f'expected ≥2 repos, got {len(d[\"repos\"])}'
urls = [r.get('repo') for r in d['repos']]
assert 'https://github.com/existinguser/custom-hook' in urls, 'custom missing'
print('yaml structure OK')
" && pass "yaml valid + repos merged" || fail "yaml invalid or repos missing"

teardown
