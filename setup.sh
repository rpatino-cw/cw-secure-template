#!/usr/bin/env bash
set -euo pipefail

# === CW Secure Template — Setup ===
# One command. Everything installed. App running in 2 minutes.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

clear
echo ""
echo -e "${BOLD}  Welcome to the CW Secure Template${NC}"
echo "  ──────────────────────────────────"
echo ""
echo "  This will set up a secure project with:"
echo "  - Authentication (Okta)"
echo "  - Security scanning on every commit"
echo "  - Tests that must pass before you can push"
echo "  - A dashboard showing how your code is protected"
echo ""

# ─── Language choice (recommend Python) ───
echo -e "${BOLD}  Which language do you want to use?${NC}"
echo ""
echo -e "  1) Python  ${GREEN}← recommended (simpler, great for internal tools)${NC}"
echo "  2) Go       (faster, used for high-performance services)"
echo "  3) Both     (keep both starters — decide later)"
echo ""
read -rp "  Enter 1, 2, or 3 [default: 1]: " lang_choice
lang_choice=${lang_choice:-1}

case "$lang_choice" in
  1)
    echo ""
    echo -e "  ${GREEN}Python selected.${NC}"
    if [ -d go/ ]; then
      mkdir -p .archived 2>/dev/null
      mv go/ .archived/go/ 2>/dev/null || true
      echo -e "  ${DIM}(Go starter archived to .archived/go/ — you can restore it later)${NC}"
    fi
    ;;
  2)
    echo ""
    echo -e "  ${GREEN}Go selected.${NC}"
    if [ -d python/ ]; then
      mkdir -p .archived 2>/dev/null
      mv python/ .archived/python/ 2>/dev/null || true
      echo -e "  ${DIM}(Python starter archived to .archived/python/ — you can restore it later)${NC}"
    fi
    ;;
  3)
    echo ""
    echo "  Keeping both starters."
    ;;
  *)
    echo ""
    echo -e "  ${GREEN}Defaulting to Python.${NC}"
    if [ -d go/ ]; then
      mkdir -p .archived 2>/dev/null
      mv go/ .archived/go/ 2>/dev/null || true
    fi
    ;;
esac

# ─── Create .env ───
echo ""
if [ ! -f .env ]; then
  cp .env.example .env
  echo -e "  ${GREEN}Created your .env file.${NC}"
  echo ""
  echo "  For local development, you don't need Okta credentials."
  echo -e "  The app runs in ${BOLD}DEV_MODE${NC} by default (fake test user)."
  echo -e "  ${DIM}When you're ready to deploy, fill in the Okta values.${NC}"
else
  echo "  .env already exists — skipping."
fi

# ─── Git init ───
if [ -d .git ]; then
  : # Already has its own git repo — good
elif git rev-parse --git-dir 2>/dev/null | grep -qv "^\.git$"; then
  echo ""
  echo -e "  ${RED}WARNING: This folder is inside another git repo.${NC}"
  echo "  The template needs its own repo to work correctly."
  echo ""
  echo "  Move this folder somewhere else first, then re-run setup."
  echo "  Example: mv $(pwd) ~/dev/my-app && cd ~/dev/my-app && bash setup.sh"
  echo ""
  exit 1
else
  echo ""
  echo "  Setting up git..."
  GIT_TEMPLATE_DIR="" git init -q 2>/dev/null || git init -q
fi

# ─── Pre-commit hooks ───
echo ""
echo "  Installing security hooks..."
if command -v pre-commit &> /dev/null; then
  pre-commit install -q 2>/dev/null
else
  pip install pre-commit -q 2>/dev/null || brew install pre-commit -q 2>/dev/null || true
  pre-commit install -q 2>/dev/null || true
fi

# Custom enforcement hooks
for hook in pre-commit post-checkout pre-push; do
  if [ -f "scripts/git-hooks/$hook" ]; then
    cp "scripts/git-hooks/$hook" ".git/hooks/$hook" 2>/dev/null || true
    chmod +x ".git/hooks/$hook" 2>/dev/null || true
  fi
done
echo -e "  ${GREEN}Security hooks installed.${NC} Every commit and push is checked."

# ─── Install dependencies ───
if [ -f go/go.mod ]; then
  echo ""
  echo "  Installing Go dependencies..."
  (cd go && go mod download 2>/dev/null) && echo -e "  ${GREEN}Done.${NC}" || echo -e "  ${YELLOW}Go not installed — install from go.dev${NC}"
fi

if [ -f python/pyproject.toml ]; then
  echo ""
  echo "  Installing Python dependencies..."
  (cd python && pip install -e ".[dev]" -q 2>/dev/null) && echo -e "  ${GREEN}Done.${NC}" || echo -e "  ${YELLOW}Failed — need Python 3.11+${NC}"
fi

# ─── Initial commit ───
if [ -z "$(git log --oneline -1 2>/dev/null)" ]; then
  git add -A
  git commit -q -m "Initial commit from cw-secure-template"
  echo -e "  ${GREEN}First commit created.${NC}"
fi

# ─── Auto branch protection ───
if command -v gh &>/dev/null; then
  REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)
  if [ -n "$REPO" ]; then
    echo ""
    echo "  Configuring branch protection..."
    gh api -X PUT "repos/${REPO}/branches/main/protection" \
      --input - <<'PROTECTION' 2>/dev/null && echo -e "  ${GREEN}Branch protection enabled.${NC}" || true
{
  "required_status_checks": { "strict": true, "contexts": [] },
  "enforce_admins": false,
  "required_pull_request_reviews": { "dismiss_stale_reviews": true, "required_approving_review_count": 1 },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
PROTECTION
  fi
fi

# ─── Health check ───
echo ""
echo -e "${BOLD}  Checking your setup...${NC}"
echo "  ──────────────────────"
bash scripts/doctor.sh 2>/dev/null || true

# ─── Guided first run ───
echo ""
echo -e "${BOLD}  ──────────────────────────────────${NC}"
echo -e "${BOLD}  Setup complete!${NC}"
echo -e "${BOLD}  ──────────────────────────────────${NC}"
echo ""
echo "  What to do next:"
echo ""
echo -e "  ${BOLD}1.${NC} Start your app:"
echo -e "     ${GREEN}make start${NC}"
echo ""
echo -e "  ${BOLD}2.${NC} Open Claude Code in this folder and start building."
echo "     Claude will automatically follow the security rules."
echo ""
echo -e "  ${BOLD}3.${NC} Before creating a pull request, run:"
echo -e "     ${GREEN}make check${NC}"
echo ""
echo -e "  ${DIM}Other useful commands: make help${NC}"
echo ""

# Auto-open dashboard if possible
if command -v open &>/dev/null && [ -f security-dashboard.html ]; then
  echo -e "  Opening the Security Dashboard..."
  open security-dashboard.html 2>/dev/null || true
fi
