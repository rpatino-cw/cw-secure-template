#!/usr/bin/env bash
# === CW Secure Framework — Secure Secret Pipeline ===
# Safely stores API keys and secrets in .env without ever displaying them.
# Usage: make add-secret
#
# WHY THIS EXISTS:
# Lazy developers paste API keys directly into Claude prompts or source files.
# This script gives them a faster path: paste the key here, it goes straight
# to .env. The key never appears in code, git, logs, or conversation history.
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Ensure .env exists
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo -e "${GREEN}Created .env from .env.example${NC}"
  else
    touch .env
  fi
fi

echo ""
echo -e "${BOLD}  Add a Secret${NC}"
echo "  ────────────"
echo ""
echo "  This stores your secret in .env (which is gitignored)."
echo "  The value is never displayed, logged, or put in code."
echo ""

# Get variable name
read -rp "  Variable name (e.g. API_KEY, DATABASE_URL): " VAR_NAME

# Validate name
if [[ ! "$VAR_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo -e "  ${RED}Invalid variable name.${NC} Use letters, numbers, underscores only."
  exit 1
fi

# Check if already exists
if grep -q "^${VAR_NAME}=" .env 2>/dev/null; then
  echo ""
  echo -e "  ${YELLOW}${VAR_NAME} already exists in .env.${NC}"
  read -rp "  Overwrite? [y/N]: " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "  Cancelled."
    exit 0
  fi
fi

# Get secret value (hidden input)
echo ""
echo -e "  Paste your secret value below (input is hidden):"
read -rsp "  > " SECRET_VALUE
echo ""

if [ -z "$SECRET_VALUE" ]; then
  echo -e "  ${RED}Empty value. Cancelled.${NC}"
  exit 1
fi

# Write to .env
if grep -q "^${VAR_NAME}=" .env 2>/dev/null; then
  # Replace existing line
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|^${VAR_NAME}=.*|${VAR_NAME}=${SECRET_VALUE}|" .env
  else
    sed -i "s|^${VAR_NAME}=.*|${VAR_NAME}=${SECRET_VALUE}|" .env
  fi
else
  # Append new line
  echo "${VAR_NAME}=${SECRET_VALUE}" >> .env
fi

# Add to .env.example (without value) if not already there
if ! grep -q "^${VAR_NAME}" .env.example 2>/dev/null; then
  echo "${VAR_NAME}=" >> .env.example
  echo -e "  ${DIM}Added ${VAR_NAME} to .env.example (no value, safe to commit)${NC}"
fi

# Clear the variable from memory
SECRET_VALUE=""

echo ""
echo -e "  ${GREEN}Done.${NC} ${VAR_NAME} is stored in .env."
echo ""
echo "  Use it in your code:"
echo -e "  ${DIM}  Python: os.environ[\"${VAR_NAME}\"]${NC}"
echo -e "  ${DIM}  Go:     os.Getenv(\"${VAR_NAME}\")${NC}"
echo ""
echo -e "  ${YELLOW}Never paste secrets into Claude prompts or source files.${NC}"
echo -e "  ${YELLOW}Always use this command: make add-secret${NC}"
echo ""
