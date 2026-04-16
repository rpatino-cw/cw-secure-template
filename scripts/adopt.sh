#!/usr/bin/env bash
# === CW Secure Framework — Adopt ===
# Installs security guards into an existing project without architecture opinions.
# Run from the template directory:
#   make adopt TARGET=/path/to/existing/app
#   make adopt TARGET=/path/to/app FORCE=1    (refresh existing adoption)
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-}"
FORCE_FLAG="${2:-}"

info()  { echo -e "  ${GREEN}$1${NC}"; }
warn()  { echo -e "  ${YELLOW}$1${NC}"; }
error() { echo -e "  ${RED}$1${NC}"; }

# ── Validate ──

if [ -z "$TARGET" ]; then
  echo ""
  echo "  Usage: make adopt TARGET=/path/to/existing/project"
  echo "  Installs security guards without architecture opinions."
  exit 1
fi

TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { error "Directory not found: $1"; exit 1; }

if [ "$TARGET" = "$TEMPLATE_ROOT" ]; then
  error "Cannot adopt into the template itself."
  exit 1
fi

if ! git -C "$TARGET" rev-parse --show-toplevel &>/dev/null; then
  error "$TARGET is not a git repository."
  echo "  Run: cd $TARGET && git init"
  exit 1
fi

if [ -d "$TARGET/.cw-secure" ] && [ "$FORCE_FLAG" != "--force" ]; then
  warn "Already adopted — .cw-secure/ exists in $TARGET"
  echo "  To refresh: make adopt TARGET=$TARGET FORCE=1"
  exit 0
fi

echo ""
echo -e "${BOLD}CW Secure Framework — Adopt${NC}"
echo "==========================="
echo ""
echo "  Template: $TEMPLATE_ROOT"
echo "  Target:   $TARGET"
echo ""

# ── macOS vs Linux sed ──
if [[ "$OSTYPE" == darwin* ]]; then
  SED_I="sed -i ''"
else
  SED_I="sed -i"
fi

# ── 1. Create .cw-secure/ ──

echo "  Creating .cw-secure/..."
rm -rf "$TARGET/.cw-secure"
mkdir -p "$TARGET/.cw-secure/guards"

# guard.sh — security-only dispatcher
cat > "$TARGET/.cw-secure/guard.sh" << 'GUARD'
#!/usr/bin/env bash
# CW Secure — PreToolUse guard (adopted)
# Security-only subset. No architecture or collaboration opinions.
set -euo pipefail

GUARD_DIR="$(cd "$(dirname "$0")" && pwd)/guards"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

INPUT="$(cat)"

read_field() {
  python3 -c "
import json, sys
data = json.loads(sys.argv[1])
tool_input = data.get('tool_input', {})
if sys.argv[2] == 'tool_name':
    print(data.get('tool_name', ''))
elif sys.argv[2] == 'file_path':
    print(tool_input.get('file_path', ''))
elif sys.argv[2] == 'content':
    print(tool_input.get('content', tool_input.get('new_string', '')))
" "$INPUT" "$1"
}

TOOL_NAME="$(read_field tool_name)"
FILE_PATH="$(read_field file_path)"
CONTENT="$(read_field content)"

# Config audit gate
source "$GUARD_DIR/config-audit.sh"

# Path traversal check
if [[ "$FILE_PATH" == *".."* ]]; then
  echo "BLOCKED: Path traversal detected: $FILE_PATH" >&2
  exit 2
fi

# Security checks (secrets, dangerous functions, protected files)
source "$GUARD_DIR/security.sh"

exit 0
GUARD

# guard-bash.sh — command guards
cp "$TEMPLATE_ROOT/scripts/guard-bash.sh" "$TARGET/.cw-secure/guard-bash.sh"
# Rewrite protected patterns to use .cw-secure/ paths
if [[ "$OSTYPE" == darwin* ]]; then
  sed -i '' 's#scripts/git-hooks#.cw-secure#g; s#scripts/guard#.cw-secure/guard#g' "$TARGET/.cw-secure/guard-bash.sh"
  sed -i '' 's#make upgrade#make cw-secure-mode#g' "$TARGET/.cw-secure/guard-bash.sh"
else
  sed -i 's#scripts/git-hooks#.cw-secure#g; s#scripts/guard#.cw-secure/guard#g' "$TARGET/.cw-secure/guard-bash.sh"
  sed -i 's#make upgrade#make cw-secure-mode#g' "$TARGET/.cw-secure/guard-bash.sh"
fi

# guards/security.sh — secrets + dangerous functions
cp "$TEMPLATE_ROOT/scripts/guards/security.sh" "$TARGET/.cw-secure/guards/security.sh"
# Rewrite PROTECTED_FILES to use .cw-secure/ paths
if [[ "$OSTYPE" == darwin* ]]; then
  sed -i '' 's|"scripts/git-hooks/"|".cw-secure/"|g; s|"scripts/guard.sh"|".cw-secure/guard.sh"|g; s|"scripts/guard-bash.sh"|".cw-secure/guard-bash.sh"|g; s|"scripts/guards/"|".cw-secure/guards/"|g' "$TARGET/.cw-secure/guards/security.sh"
  # Remove .claude/skills/ and .claude/agents/ from PROTECTED_FILES (template-specific)
  sed -i '' '/"\.claude\/skills\/"/d; /"\.claude\/agents\/"/d' "$TARGET/.cw-secure/guards/security.sh"
else
  sed -i 's|"scripts/git-hooks/"|".cw-secure/"|g; s|"scripts/guard.sh"|".cw-secure/guard.sh"|g; s|"scripts/guard-bash.sh"|".cw-secure/guard-bash.sh"|g; s|"scripts/guards/"|".cw-secure/guards/"|g' "$TARGET/.cw-secure/guards/security.sh"
  sed -i '/"\.claude\/skills\/"/d; /"\.claude\/agents\/"/d' "$TARGET/.cw-secure/guards/security.sh"
fi

# guards/config-audit.sh — config stack check (verbatim)
cp "$TEMPLATE_ROOT/scripts/guards/config-audit.sh" "$TARGET/.cw-secure/guards/config-audit.sh"

# secure-mode.sh (verbatim)
cp "$TEMPLATE_ROOT/scripts/secure-mode.sh" "$TARGET/.cw-secure/secure-mode.sh"

# add-secret.sh (verbatim)
cp "$TEMPLATE_ROOT/scripts/add-secret.sh" "$TARGET/.cw-secure/add-secret.sh"

# Make all scripts executable
chmod +x "$TARGET/.cw-secure/"*.sh "$TARGET/.cw-secure/guards/"*.sh

info ".cw-secure/ created (6 files)"

# ── 2. Merge .claude/settings.json ──

echo "  Merging .claude/settings.json..."
mkdir -p "$TARGET/.claude"

if command -v python3 &>/dev/null; then
  python3 "$TEMPLATE_ROOT/scripts/adopt-merge-settings.py" \
    "$TARGET/.claude/settings.json" ".cw-secure"
  info "settings.json merged (deny list + hooks)"
else
  warn "python3 not found — skipping settings.json merge"
  echo "  Install Python 3, then re-run: make adopt TARGET=$TARGET FORCE=1"
fi

# ── 3. Copy .claude/rules/ ──

echo "  Installing security rules..."
mkdir -p "$TARGET/.claude/rules"
for rule in security.md testing.md code-style.md api-conventions.md; do
  if [ -f "$TEMPLATE_ROOT/.claude/rules/$rule" ]; then
    cp "$TEMPLATE_ROOT/.claude/rules/$rule" "$TARGET/.claude/rules/$rule"
  fi
done
info "4 rule files installed"

# ── 4. Merge CLAUDE.md ──

echo "  Merging CLAUDE.md..."
DELIM_START="<!-- CW-SECURE-ADOPT: DO NOT EDIT BELOW THIS LINE -->"
DELIM_END="<!-- CW-SECURE-ADOPT: END -->"

if [ -f "$TARGET/CLAUDE.md" ]; then
  # Remove old adopted section if re-adopting
  if grep -qF "$DELIM_START" "$TARGET/CLAUDE.md" 2>/dev/null; then
    if [[ "$OSTYPE" == darwin* ]]; then
      sed -i '' "/$DELIM_START/,/$DELIM_END/d" "$TARGET/CLAUDE.md"
    else
      sed -i "/$DELIM_START/,/$DELIM_END/d" "$TARGET/CLAUDE.md"
    fi
  fi
  echo "" >> "$TARGET/CLAUDE.md"
  echo "$DELIM_START" >> "$TARGET/CLAUDE.md"
  cat "$TEMPLATE_ROOT/scripts/adopt-claude-sections.md" >> "$TARGET/CLAUDE.md"
  echo "$DELIM_END" >> "$TARGET/CLAUDE.md"
  info "Security sections appended to existing CLAUDE.md"
else
  echo "# $(basename "$TARGET")" > "$TARGET/CLAUDE.md"
  echo "" >> "$TARGET/CLAUDE.md"
  echo "$DELIM_START" >> "$TARGET/CLAUDE.md"
  cat "$TEMPLATE_ROOT/scripts/adopt-claude-sections.md" >> "$TARGET/CLAUDE.md"
  echo "$DELIM_END" >> "$TARGET/CLAUDE.md"
  info "CLAUDE.md created with security sections"
fi

# ── 5. Merge .gitignore ──

echo "  Merging .gitignore..."
GI_START="# CW-SECURE-ADOPT: Security patterns"
GI_END="# CW-SECURE-ADOPT: END"

PATTERNS=(".env" ".env.*" "!.env.example" ".claude/settings.local.json" ".secrets/" "*.pem" "*.key" "*.p12" "credentials.json" "service-account*.json" "*.tfstate" "*.tfstate.*")

# Remove old section if re-adopting
if [ -f "$TARGET/.gitignore" ] && grep -qF "$GI_START" "$TARGET/.gitignore" 2>/dev/null; then
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "/$GI_START/,/$GI_END/d" "$TARGET/.gitignore"
  else
    sed -i "/$GI_START/,/$GI_END/d" "$TARGET/.gitignore"
  fi
fi

{
  echo ""
  echo "$GI_START"
  for p in "${PATTERNS[@]}"; do
    echo "$p"
  done
  echo "$GI_END"
} >> "$TARGET/.gitignore"
info ".gitignore security patterns added"

# ── 6. Pre-commit config ──

if [ ! -f "$TARGET/.pre-commit-config.yaml" ]; then
  echo "  Creating .pre-commit-config.yaml..."
  cat > "$TARGET/.pre-commit-config.yaml" << 'PRECOMMIT'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: detect-private-key
PRECOMMIT
  info ".pre-commit-config.yaml created"
else
  warn ".pre-commit-config.yaml already exists — verify gitleaks is included"
fi

# ── 7. Run secure-mode ──

echo "  Configuring Claude Code permissions..."
(cd "$TARGET" && bash .cw-secure/secure-mode.sh)

# ── Summary ──

echo ""
echo -e "${BOLD}Adoption complete!${NC}"
echo ""
echo "  Created:"
echo "    .cw-secure/               Security guard files"
echo "    .claude/settings.json     Deny list + PreToolUse hooks"
echo "    .claude/rules/            4 security rule files"
echo "    .claude/settings.local.json  Permission override"
echo ""
echo "  Merged:"
echo "    CLAUDE.md                 Security sections appended"
echo "    .gitignore                Security patterns appended"
echo ""
echo -e "  ${BOLD}Manual TODO:${NC}"
echo "    1. Install pre-commit hooks:  cd $TARGET && pre-commit install"
echo "    2. Commit the changes:        git add -A && git commit -m 'Add CW Secure guards'"
echo ""
echo -e "  ${DIM}To refresh:  make adopt TARGET=$TARGET FORCE=1${NC}"
echo -e "  ${DIM}To remove:   rm -rf $TARGET/.cw-secure/ and remove CW-SECURE-ADOPT sections${NC}"
echo ""
