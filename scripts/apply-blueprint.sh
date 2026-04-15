#!/usr/bin/env bash
# === CW Secure Framework — Blueprint Apply ===
# Applies a blueprint to your project, adding routes, services, tests, and deps.
#
# Usage:
#   make new                        # Interactive — pick from a menu
#   make new BLUEPRINT=chat-assistant  # Direct — skip the menu
#   bash scripts/apply-blueprint.sh    # Same as make new
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

BLUEPRINTS_DIR="blueprints"
REGISTRY="${BLUEPRINTS_DIR}/_registry.json"

# ─── Check prerequisites ───
if [ ! -f "$REGISTRY" ]; then
  echo -e "  ${RED}Error:${NC} Blueprint registry not found at ${REGISTRY}"
  echo "  Are you running this from the project root?"
  exit 1
fi

# Detect stack
STACK=""
if [ -f .stack ]; then
  STACK=$(cat .stack)
elif [ -f python/pyproject.toml ] && [ ! -f go/go.mod ]; then
  STACK="python"
elif [ -f go/go.mod ] && [ ! -f python/pyproject.toml ]; then
  STACK="go"
else
  STACK="python"  # Default if both exist
fi

# ─── Blueprint selection ───
BLUEPRINT="${1:-}"

if [ -z "$BLUEPRINT" ]; then
  echo ""
  echo -e "${BOLD}  Choose a Blueprint${NC}"
  echo "  ──────────────────"
  echo ""

  # Parse registry and display options
  # Using python for JSON parsing (available in both stacks)
  NAMES=$(python3 -c "
import json, sys
with open('$REGISTRY') as f:
    reg = json.load(f)
for i, (key, bp) in enumerate(reg['blueprints'].items(), 1):
    stacks = ', '.join(bp.get('stacks', []))
    print(f'  {i}) {bp[\"name\"]:20s} {key:20s} [{stacks}]')
" 2>/dev/null)

  if [ -z "$NAMES" ]; then
    echo -e "  ${RED}Error:${NC} Could not parse blueprint registry."
    exit 1
  fi

  echo "$NAMES"
  echo ""
  echo "  4) Blank (framework only — no starter code)"
  echo ""

  BLUEPRINT_COUNT=$(python3 -c "
import json
with open('$REGISTRY') as f:
    print(len(json.load(f)['blueprints']))
" 2>/dev/null)

  read -rp "  Pick a blueprint [1-${BLUEPRINT_COUNT}, or 4 for blank]: " CHOICE

  if [ "$CHOICE" = "4" ]; then
    echo ""
    echo -e "  ${GREEN}✓${NC} Blank project — framework only, no blueprint applied."
    echo "blank" > .blueprint
    echo ""
    echo "  You have the full security framework with no starter code."
    echo "  Start building: Claude will follow all .claude/rules/ automatically."
    echo ""
    exit 0
  fi

  BLUEPRINT=$(python3 -c "
import json
with open('$REGISTRY') as f:
    keys = list(json.load(f)['blueprints'].keys())
try:
    print(keys[int('$CHOICE') - 1])
except (IndexError, ValueError):
    pass
" 2>/dev/null)

  if [ -z "$BLUEPRINT" ]; then
    echo -e "  ${RED}Error:${NC} Invalid choice."
    exit 1
  fi
fi

# ─── Validate blueprint exists ───
BP_DIR="${BLUEPRINTS_DIR}/${BLUEPRINT}"
BP_MANIFEST="${BP_DIR}/blueprint.json"

if [ ! -f "$BP_MANIFEST" ]; then
  echo -e "  ${RED}Error:${NC} Blueprint '${BLUEPRINT}' not found at ${BP_DIR}/"
  echo ""
  echo "  Available blueprints:"
  ls -d blueprints/*/  2>/dev/null | sed 's|blueprints/||;s|/||' | grep -v '^_' | sed 's/^/    /'
  exit 1
fi

# ─── Check stack compatibility ───
COMPATIBLE=$(python3 -c "
import json
with open('$BP_MANIFEST') as f:
    bp = json.load(f)
print('yes' if '$STACK' in bp.get('stacks', []) else 'no')
" 2>/dev/null)

if [ "$COMPATIBLE" = "no" ]; then
  echo -e "  ${RED}Error:${NC} Blueprint '${BLUEPRINT}' doesn't support the '${STACK}' stack."
  echo "  Supported stacks: $(python3 -c "
import json
with open('$BP_MANIFEST') as f:
    print(', '.join(json.load(f).get('stacks', [])))
" 2>/dev/null)"
  exit 1
fi

# ─── Display what we're about to do ───
BP_DISPLAY=$(python3 -c "
import json
with open('$BP_MANIFEST') as f:
    bp = json.load(f)
print(bp.get('display_name', '$BLUEPRINT'))
" 2>/dev/null)

BP_DESC=$(python3 -c "
import json
with open('$BP_MANIFEST') as f:
    bp = json.load(f)
print(bp.get('description', ''))
" 2>/dev/null)

echo ""
echo -e "${BOLD}  Applying: ${BP_DISPLAY}${NC}"
echo -e "  ${DIM}${BP_DESC}${NC}"
echo ""

# ─── Copy blueprint files ───
COPY_COUNT=0

if [ "$STACK" = "python" ] && [ -d "${BP_DIR}/python" ]; then
  # Read copy list from manifest
  python3 -c "
import json, shutil, os
with open('$BP_MANIFEST') as f:
    bp = json.load(f)
files = bp.get('files', {}).get('python', {}).get('copy', [])
for entry in files:
    if isinstance(entry, dict):
        src = '${BP_DIR}/python/' + entry['src'].split('/', 1)[-1] if '/' in entry['src'] else '${BP_DIR}/python/' + entry['src']
        # Use the blueprint-relative path
        src = '${BP_DIR}/' + entry['src']
        dest = 'python/' + entry['dest']
    else:
        src = '${BP_DIR}/python/' + entry
        dest = 'python/src/' + entry
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(src):
        shutil.copy2(src, dest)
        print(f'COPIED:{dest}')
    else:
        print(f'MISSING:{src}')
" 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" == COPIED:* ]]; then
      echo -e "  ${GREEN}✓${NC} ${line#COPIED:}"
      ((COPY_COUNT++)) || true
    elif [[ "$line" == MISSING:* ]]; then
      echo -e "  ${YELLOW}!${NC} Source not found: ${line#MISSING:}"
    fi
  done
fi

if [ "$STACK" = "go" ] && [ -d "${BP_DIR}/go" ]; then
  echo -e "  ${DIM}Go blueprint files would be copied here (not yet implemented)${NC}"
fi

# ─── Add dependencies ───
DEPS_ADDED=0

if [ "$STACK" = "python" ] && [ -f python/pyproject.toml ]; then
  python3 -c "
import json
with open('$BP_MANIFEST') as f:
    bp = json.load(f)
deps = bp.get('requires', {}).get('dependencies', {}).get('python', [])
for d in deps:
    print(d)
" 2>/dev/null | while IFS= read -r dep; do
    # Check if dependency already exists in pyproject.toml
    DEP_NAME=$(echo "$dep" | sed 's/[>=<].*//')
    if ! grep -q "\"${DEP_NAME}" python/pyproject.toml 2>/dev/null; then
      # Add before the closing bracket of dependencies
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^]$/i\\
    \"${dep}\",
" python/pyproject.toml
      else
        sed -i "/^]$/i\\    \"${dep}\"," python/pyproject.toml
      fi
      echo -e "  ${GREEN}+${NC} Added dependency: ${dep}"
      ((DEPS_ADDED++)) || true
    else
      echo -e "  ${DIM}  Already has: ${DEP_NAME}${NC}"
    fi
  done
fi

# ─── Add env vars to .env.example ───
VARS_ADDED=0

python3 -c "
import json
with open('$BP_MANIFEST') as f:
    bp = json.load(f)
for var in bp.get('requires', {}).get('env_vars', []):
    print(var)
" 2>/dev/null | while IFS= read -r var; do
  if [ -f .env.example ] && ! grep -q "^${var}=" .env.example 2>/dev/null; then
    echo "" >> .env.example
    echo "# Added by ${BLUEPRINT} blueprint" >> .env.example
    echo "${var}=" >> .env.example
    echo -e "  ${GREEN}+${NC} Added to .env.example: ${var}"
    ((VARS_ADDED++)) || true
  elif [ -f .env.example ]; then
    echo -e "  ${DIM}  Already in .env.example: ${var}${NC}"
  fi
done

# ─── Copy blueprint CLAUDE.md ───
if [ -f "${BP_DIR}/CLAUDE.md" ]; then
  cp "${BP_DIR}/CLAUDE.md" ".blueprint-rules.md"
  echo -e "  ${GREEN}✓${NC} Blueprint rules saved to .blueprint-rules.md"
fi

# ─── Store active blueprint ───
echo "$BLUEPRINT" > .blueprint
echo -e "  ${GREEN}✓${NC} Active blueprint: ${BLUEPRINT}"

# ─── Add to .gitignore if not present ───
for pattern in ".blueprint" ".blueprint-rules.md"; do
  if [ -f .gitignore ] && ! grep -q "^${pattern}$" .gitignore 2>/dev/null; then
    echo "$pattern" >> .gitignore
  fi
done

# ─── Summary ───
echo ""
echo -e "${BOLD}  ────────────────────────${NC}"
echo -e "${BOLD}  Blueprint applied: ${BP_DISPLAY}${NC}"
echo -e "${BOLD}  ────────────────────────${NC}"
echo ""
echo "  What was added:"
[ "$STACK" = "python" ] && echo "    Routes, services, and tests from the ${BLUEPRINT} blueprint"
echo "    Dependencies in pyproject.toml (if new)"
echo "    Environment variables in .env.example (if new)"
echo "    Blueprint rules in .blueprint-rules.md"
echo ""
echo "  Next steps:"
echo "    1. Review the new files in python/src/"
echo "    2. Run ${BOLD}make add-secret${NC} for any new API keys"
echo "    3. Run ${BOLD}make test${NC} to verify everything works"
echo "    4. Start building on top of the blueprint"
echo ""
