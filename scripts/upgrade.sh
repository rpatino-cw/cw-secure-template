#!/usr/bin/env bash
# === CW Secure Framework — Upgrade ===
# Pulls the latest framework updates from the upstream template repo.
# Safe: never touches user code (go/, python/, .env, rooms/).
# Shows what changed before applying.
#
# Usage:
#   make upgrade              Interactive — shows diff, asks before applying
#   make upgrade YES=1        Non-interactive — applies without asking
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

UPSTREAM_URL="https://github.com/rpatino-cw/cw-secure-template.git"
UPSTREAM_REMOTE="upstream"
VERSION_FILE=".framework-version"
AUTO_YES="${1:-}"

# ── Framework file lists ──

REPLACE_FILES=(
  scripts/guard.sh
  scripts/guard-bash.sh
  scripts/guards/security.sh
  scripts/guards/architecture.sh
  scripts/guards/collaboration.sh
  scripts/guards/rooms.sh
  scripts/guards/config-audit.sh
  scripts/guards/freeze.sh
  scripts/guards/test-guards.sh
  scripts/secure-mode.sh
  scripts/doctor.sh
  scripts/security-fix.sh
  scripts/security-quiz.sh
  scripts/agent-review.sh
  scripts/room-lint.sh
  scripts/room-status.sh
  scripts/init-rooms.sh
  scripts/start-agent.sh
  scripts/create-branch.sh
  scripts/open-pr.sh
  scripts/repo-lint.sh
  scripts/gen-readme.sh
  scripts/freeze.sh
  scripts/scan-drops.sh
  scripts/activity-log.sh
  scripts/add-secret.sh
  scripts/add-config.sh
  scripts/git-hooks/pre-commit
  scripts/git-hooks/post-checkout
  scripts/git-hooks/pre-push
  scripts/upgrade.sh
  .claude/settings.json
  .pre-commit-config.yaml
  .github/workflows/ci.yml
  .github/pull_request_template.md
)

MERGE_FILES=(
  CLAUDE.md
  Makefile
  .gitignore
)

# ── Helper functions ──

info()  { echo -e "  ${GREEN}$1${NC}"; }
warn()  { echo -e "  ${YELLOW}$1${NC}"; }
error() { echo -e "  ${RED}$1${NC}"; }

# ── Read current version ──

CURRENT="v1.0.0"
[ -f "$VERSION_FILE" ] && CURRENT=$(cat "$VERSION_FILE" | tr -d '[:space:]')

echo ""
echo -e "${BOLD}CW Secure Framework — Upgrade${NC}"
echo "=============================="
echo ""
echo -e "  Current framework version: ${BOLD}${CURRENT}${NC}"

# ── Ensure upstream remote ──

ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")

# If origin IS the template repo, there's nothing to upgrade from
if [ "$ORIGIN_URL" = "$UPSTREAM_URL" ] || [ "$ORIGIN_URL" = "${UPSTREAM_URL%.git}" ]; then
  echo ""
  info "This IS the upstream template repo. Nothing to upgrade from."
  echo -e "  ${DIM}Upgrade is for downstream forks that cloned from this template.${NC}"
  echo ""
  exit 0
fi

# Check if upstream remote exists
if git remote get-url "$UPSTREAM_REMOTE" &>/dev/null; then
  EXISTING_URL=$(git remote get-url "$UPSTREAM_REMOTE")
  if [ "$EXISTING_URL" != "$UPSTREAM_URL" ] && [ "$EXISTING_URL" != "${UPSTREAM_URL%.git}" ]; then
    error "Upstream remote exists but points to: $EXISTING_URL"
    error "Expected: $UPSTREAM_URL"
    echo -e "  Fix: git remote set-url upstream $UPSTREAM_URL"
    exit 1
  fi
else
  echo "  Adding upstream remote..."
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
  info "Added upstream: $UPSTREAM_URL"
fi

# ── Fetch tags ──

echo "  Fetching latest tags..."
if ! git fetch "$UPSTREAM_REMOTE" --tags --quiet 2>/dev/null; then
  echo ""
  error "Cannot reach upstream. Check your connection."
  echo -e "  Remote: $UPSTREAM_URL"
  echo -e "  Verify: git ls-remote $UPSTREAM_REMOTE"
  exit 1
fi

# ── Determine latest version ──

LATEST=$(git tag -l 'v*' --sort=-v:refname 2>/dev/null | head -1)

if [ -z "$LATEST" ]; then
  error "No version tags found on upstream."
  exit 1
fi

echo -e "  Latest upstream version:   ${BOLD}${LATEST}${NC}"

# ── Load framework paths from .cwt/framework-paths.txt (canonical) ──
# Falls back to the hardcoded REPLACE_FILES/MERGE_FILES arrays above
# if the file is missing, unparseable, or has no section content.

load_framework_paths_from_manifest() {
  local manifest=".cwt/framework-paths.txt"
  [ -f "$manifest" ] || return 1

  local section=""
  local -a parsed_replace=()
  local -a parsed_merge=()
  local line trimmed

  while IFS= read -r line || [ -n "$line" ]; do
    # Strip trailing comment
    trimmed="${line%%#*}"
    # Trim whitespace
    trimmed="$(echo "$trimmed" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$trimmed" ] && continue
    if [[ "$trimmed" == "[replace]" ]]; then section="replace"; continue; fi
    if [[ "$trimmed" == "[merge]" ]];   then section="merge";   continue; fi
    [ -z "$section" ] && continue

    if [ "$section" = "replace" ]; then
      if [[ "$trimmed" == */ ]]; then
        # Directory — enumerate at LATEST version
        local f
        while IFS= read -r f; do
          [ -n "$f" ] && parsed_replace+=("${trimmed}${f}")
        done < <(git ls-tree --name-only -r "${LATEST}" "$trimmed" 2>/dev/null | sed "s|^${trimmed}||")
      else
        parsed_replace+=("$trimmed")
      fi
    elif [ "$section" = "merge" ]; then
      parsed_merge+=("$trimmed")
    fi
  done < "$manifest"

  # Require at least one entry in each to consider the parse successful
  if [ "${#parsed_replace[@]}" -eq 0 ] && [ "${#parsed_merge[@]}" -eq 0 ]; then
    return 1
  fi

  REPLACE_FILES=("${parsed_replace[@]}")
  MERGE_FILES=("${parsed_merge[@]}")
  return 0
}

if load_framework_paths_from_manifest; then
  echo -e "  File list source:          ${DIM}.cwt/framework-paths.txt${NC}"
else
  echo -e "  File list source:          ${DIM}upgrade.sh (fallback)${NC}"
fi

# ── Idempotent check ──

if [ "$CURRENT" = "$LATEST" ]; then
  echo ""
  info "Already up to date ($CURRENT)."
  echo ""
  exit 0
fi

# ── Dirty tree warning ──

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo ""
  warn "You have uncommitted changes. Recommend committing or stashing first."
  echo -e "  ${DIM}Upgrade will modify framework files — your changes are safe but review carefully.${NC}"
fi

# ── Preview ──

echo ""
echo -e "${BOLD}Changes from ${CURRENT} → ${LATEST}:${NC}"
echo ""

REPLACE_CHANGED=0
REPLACE_NEW=0
for f in "${REPLACE_FILES[@]}"; do
  if git cat-file -e "${LATEST}:${f}" 2>/dev/null; then
    if git cat-file -e "${CURRENT}:${f}" 2>/dev/null; then
      DIFF=$(git diff "${CURRENT}:${f}" "${LATEST}:${f}" --stat 2>/dev/null)
      if [ -n "$DIFF" ]; then
        echo -e "  ${GREEN}M${NC}  $f"
        ((REPLACE_CHANGED++))
      fi
    else
      echo -e "  ${GREEN}A${NC}  $f"
      ((REPLACE_NEW++))
    fi
  fi
done

# Also discover new .claude/rules/*.md files
# git ls-tree returns full paths like ".claude/rules/foo.md" — use directly.
for RULE_PATH in $(git ls-tree --name-only -r "${LATEST}" .claude/rules/ 2>/dev/null); do
  # Skip if already in REPLACE_FILES
  if printf '%s\n' "${REPLACE_FILES[@]}" | grep -qx "$RULE_PATH" 2>/dev/null; then
    continue
  fi
  if ! git cat-file -e "${CURRENT}:${RULE_PATH}" 2>/dev/null; then
    echo -e "  ${GREEN}A${NC}  $RULE_PATH (new rule)"
    ((REPLACE_NEW++))
  fi
done

MERGE_CHANGED=0
for f in "${MERGE_FILES[@]}"; do
  if git cat-file -e "${LATEST}:${f}" 2>/dev/null && git cat-file -e "${CURRENT}:${f}" 2>/dev/null; then
    DIFF=$(git diff "${CURRENT}:${f}" "${LATEST}:${f}" --stat 2>/dev/null)
    if [ -n "$DIFF" ]; then
      echo -e "  ${YELLOW}~${NC}  $f ${DIM}(three-way merge)${NC}"
      ((MERGE_CHANGED++))
    fi
  fi
done

TOTAL=$((REPLACE_CHANGED + REPLACE_NEW + MERGE_CHANGED))
if [ "$TOTAL" -eq 0 ]; then
  echo "  No framework file changes detected."
  echo "$LATEST" > "$VERSION_FILE"
  info "Version updated to $LATEST."
  echo ""
  exit 0
fi

echo ""
echo -e "  ${BOLD}${REPLACE_CHANGED}${NC} updated, ${BOLD}${REPLACE_NEW}${NC} new, ${BOLD}${MERGE_CHANGED}${NC} merged"

# ── Confirm ──

if [ "$AUTO_YES" != "--yes" ]; then
  echo ""
  read -rp "  Apply these changes? [y/N]: " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
  fi
fi

# ── Apply REPLACE files ──

echo ""
echo "  Applying framework updates..."
APPLIED=0

for f in "${REPLACE_FILES[@]}"; do
  if git cat-file -e "${LATEST}:${f}" 2>/dev/null; then
    mkdir -p "$(dirname "$f")"
    git show "${LATEST}:${f}" > "$f"
    # Preserve executable bit for scripts
    if [[ "$f" == scripts/* ]] || [[ "$f" == .git/hooks/* ]]; then
      chmod +x "$f" 2>/dev/null || true
    fi
    ((APPLIED++))
  fi
done

# Apply new .claude/rules/ files
# git ls-tree returns full paths — no manual prefix needed.
for RULE_PATH in $(git ls-tree --name-only -r "${LATEST}" .claude/rules/ 2>/dev/null); do
  mkdir -p "$(dirname "$RULE_PATH")"
  git show "${LATEST}:${RULE_PATH}" > "$RULE_PATH"
  ((APPLIED++))
done

info "$APPLIED framework files updated."

# ── Apply MERGE files (three-way) ──

CONFLICTS=0
MERGED=0
TMPDIR=$(mktemp -d)

for f in "${MERGE_FILES[@]}"; do
  # Skip if template side didn't change
  if ! git cat-file -e "${LATEST}:${f}" 2>/dev/null; then continue; fi
  if ! git cat-file -e "${CURRENT}:${f}" 2>/dev/null; then continue; fi

  DIFF=$(git diff "${CURRENT}:${f}" "${LATEST}:${f}" 2>/dev/null)
  if [ -z "$DIFF" ]; then continue; fi

  # Extract base (old version) and theirs (new version) to temp
  git show "${CURRENT}:${f}" > "$TMPDIR/base"
  git show "${LATEST}:${f}" > "$TMPDIR/theirs"
  cp "$f" "$TMPDIR/ours"

  if git merge-file -p "$TMPDIR/ours" "$TMPDIR/base" "$TMPDIR/theirs" > "$TMPDIR/result" 2>/dev/null; then
    cp "$TMPDIR/result" "$f"
    info "Merged: $f"
    ((MERGED++))
  else
    cp "$TMPDIR/result" "$f"
    warn "Merge conflict in $f — resolve manually"
    ((CONFLICTS++))
    ((MERGED++))
  fi
done

rm -rf "$TMPDIR"

if [ "$MERGED" -gt 0 ]; then
  info "$MERGED files merged."
fi

# ── Update version ──

echo "$LATEST" > "$VERSION_FILE"

# ── Reinstall git hooks ──

if [ -d .git ]; then
  for hook in pre-commit post-checkout pre-push; do
    if [ -f "scripts/git-hooks/$hook" ]; then
      cp "scripts/git-hooks/$hook" ".git/hooks/$hook" 2>/dev/null || true
      chmod +x ".git/hooks/$hook" 2>/dev/null || true
    fi
  done
  info "Git hooks reinstalled."
fi

# ── Summary ──

echo ""
echo -e "${BOLD}Upgraded: ${CURRENT} → ${LATEST}${NC}"
echo ""

if [ "$CONFLICTS" -gt 0 ]; then
  warn "$CONFLICTS file(s) have merge conflicts — resolve them, then commit."
  echo ""
else
  echo -e "  Review changes:  ${BOLD}git diff${NC}"
  echo -e "  Commit upgrade:  ${BOLD}git add -A && git commit -m \"Upgrade framework to ${LATEST}\"${NC}"
  echo ""
fi
