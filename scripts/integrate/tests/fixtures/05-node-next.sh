#!/usr/bin/env bash
# Fixture: Node/Next app. Default scan should NOT pick it up
# (Node is opt-in). With --include-node, detection should fire
# and integration should work.
#
# NOTE: Node middleware source isn't shipped in the template yet (stretch
# support), so the action is 'generate' with source: null. The test verifies
# DETECTION + wiring snippet rendering rather than file output.

source "$(dirname "$0")/../lib.sh"
setup "node-next"

cat > package.json <<'EOF'
{
  "name": "next-payments",
  "version": "0.1.0",
  "dependencies": { "next": "^14.0.0", "react": "^18.0.0" },
  "scripts": { "test": "jest", "lint": "next lint" }
}
EOF
mkdir -p src && cat > src/index.ts <<'EOF'
export default function App() { return null }
EOF

git_init_repo "init next app"

# 1. Default scan: Node NOT detected (opt-in)
out=$(run_scan "$FIXTURE_DIR")
if echo "$out" | grep -q "No Go/Python/Node stack detected"; then
  pass "Node correctly ignored without --include-node"
else
  fail "Node should be ignored without opt-in; got: $(echo "$out" | head -5)"
fi

# 2. With --include-node: detected as next
out=$(run_scan "$FIXTURE_DIR" --include-node)
if echo "$out" | grep -q "node"; then pass "Node stack detected with --include-node"
else fail "Node stack not detected even with opt-in"; fi
if echo "$out" | grep -q "framework=next"; then pass "framework=next detected"
else fail "framework=next NOT detected"; fi
if echo "$out" | grep -q "next-payments"; then pass "app_name=next-payments from package.json"
else fail "app_name not resolved from package.json"; fi

# 3. Plan with --include-node should include a wiring snippet for Node
out=$(run_plan "$FIXTURE_DIR" --include-node)
if echo "$out" | grep -q "Express/Next app"; then pass "Node wiring snippet rendered"
else fail "no Node wiring snippet in plan output"; fi

teardown
