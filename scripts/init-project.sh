#!/usr/bin/env bash
# === CW Secure Template — Project Initializer ===
# Personalizes the template for YOUR specific app.
# Turns generic CLAUDE.md + .claude/ into your project's AI config.
#
# Run: make init (or bash scripts/init-project.sh)
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}  Personalize Your Project${NC}"
echo "  ────────────────────────"
echo ""
echo "  This customizes the template for your specific app."
echo "  Claude will use this context every time you prompt it."
echo ""

# ─── App name ───
read -rp "  App name (e.g. inventory-tracker): " APP_NAME
APP_NAME=${APP_NAME:-my-app}
APP_NAME_UPPER=$(echo "$APP_NAME" | tr '[:lower:]-' '[:upper:]_')

# ─── Description ───
echo ""
read -rp "  What does this app do? (1 sentence): " APP_DESC
APP_DESC=${APP_DESC:-An internal tool.}

# ─── Team ───
echo ""
read -rp "  Team name (e.g. platform, dct-ops): " TEAM_NAME
TEAM_NAME=${TEAM_NAME:-my-team}

# ─── Slack channel ───
echo ""
read -rp "  Team Slack channel (e.g. #platform-eng): " SLACK_CHANNEL
SLACK_CHANNEL=${SLACK_CHANNEL:-#your-team}

# ─── Data handled ───
echo ""
echo "  What kind of data does this app handle?"
echo "    1) Internal only (configs, logs, team data)"
echo "    2) User data (names, emails)"
echo "    3) Sensitive data (PII, financial, credentials)"
echo ""
read -rp "  Enter 1, 2, or 3 [default: 1]: " DATA_LEVEL
DATA_LEVEL=${DATA_LEVEL:-1}

case "$DATA_LEVEL" in
  1) DATA_DESC="Internal data only — configs, logs, team info." ;;
  2) DATA_DESC="Handles user data (names, emails). PII considerations apply." ;;
  3) DATA_DESC="Handles sensitive data (PII, financial, credentials). Strict access controls required." ;;
  *) DATA_DESC="Internal data only." ;;
esac

# ─── Update .claude/MEMORY.md ───
echo ""
echo -e "  ${DIM}Updating project memory...${NC}"

cat > .claude/MEMORY.md << MEMEOF
# Project Memory

> Claude reads this file to understand project context across sessions.

## Project Overview

- **Name:** ${APP_NAME}
- **Purpose:** ${APP_DESC}
- **Stack:** $([ -f go/go.mod ] && echo "Go" || echo "")$([ -f python/pyproject.toml ] && echo "Python" || echo "")
- **Status:** Development
- **Team:** ${TEAM_NAME} (${SLACK_CHANNEL})
- **Data classification:** ${DATA_DESC}

## Architecture Decisions

| Decision | Why | Date |
|----------|-----|------|
| Using Okta OIDC for auth | CW standard, required by InfoSec | $(date +%Y-%m-%d) |
| $([ -f python/pyproject.toml ] && echo "FastAPI + Pydantic" || echo "net/http + stdlib") | Template default, CW-approved stack | $(date +%Y-%m-%d) |
| Doppler for secrets | CW standard, ESO integration | $(date +%Y-%m-%d) |

## Current Sprint / Focus

- [ ] Initial app setup from cw-secure-template
- [ ] Add core business logic
- [ ] File Okta registration ticket
- [ ] First AppSec review

## Doppler Config

- **Project:** ${TEAM_NAME}-${APP_NAME}
- **Configs:** dev, stg, prod

## External Dependencies

| Service | Purpose | Auth Method |
|---------|---------|-------------|
| Okta | User authentication | OIDC / JWT |

## Deployment

- **Cluster:** core-internal
- **Namespace:** ${TEAM_NAME}
- **Doppler project:** ${TEAM_NAME}-${APP_NAME}
MEMEOF

# ─── Update Helm values ───
if [ -f deploy/helm/values.yaml ]; then
  echo -e "  ${DIM}Updating Helm values...${NC}"
  # Replace in values, Chart.yaml, helpers, AND all templates that reference
  # the helper functions (deployment, service, configmap, ingress, etc.)
  HELM_FILES=(
    deploy/helm/values.yaml
    deploy/helm/Chart.yaml
    deploy/helm/templates/_helpers.tpl
  )
  # Include all template files that call {{ include "cw-secure-app.*" }}
  for f in deploy/helm/templates/*.yaml; do
    [ -f "$f" ] && HELM_FILES+=("$f")
  done
  if [[ "$OSTYPE" == "darwin"* ]]; then
    for f in "${HELM_FILES[@]}"; do
      sed -i '' "s|cw-secure-app|${APP_NAME}|g" "$f"
    done
  else
    for f in "${HELM_FILES[@]}"; do
      sed -i "s|cw-secure-app|${APP_NAME}|g" "$f"
    done
  fi
fi

# ─── Update pyproject.toml ───
if [ -f python/pyproject.toml ]; then
  echo -e "  ${DIM}Updating Python project name...${NC}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|name = \"my-app\"|name = \"${APP_NAME}\"|" python/pyproject.toml
    sed -i '' "s|description = \"Internal CW application\"|description = \"${APP_DESC}\"|" python/pyproject.toml
  else
    sed -i "s|name = \"my-app\"|name = \"${APP_NAME}\"|" python/pyproject.toml
    sed -i "s|description = \"Internal CW application\"|description = \"${APP_DESC}\"|" python/pyproject.toml
  fi
fi

# ─── Update go.mod ───
if [ -f go/go.mod ]; then
  echo -e "  ${DIM}Updating Go module name...${NC}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|github.com/coreweave/my-app|github.com/coreweave/${APP_NAME}|" go/go.mod
    # Update imports in Go files
    find go/ -name "*.go" -exec sed -i '' "s|github.com/coreweave/my-app|github.com/coreweave/${APP_NAME}|g" {} +
  else
    sed -i "s|github.com/coreweave/my-app|github.com/coreweave/${APP_NAME}|" go/go.mod
    find go/ -name "*.go" -exec sed -i "s|github.com/coreweave/my-app|github.com/coreweave/${APP_NAME}|g" {} +
  fi
fi

# ─── Update CODEOWNERS ───
if [ -f .github/CODEOWNERS ]; then
  echo -e "  ${DIM}Updating CODEOWNERS...${NC}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|TODO-replace-with-your-team|${TEAM_NAME}|" .github/CODEOWNERS
  else
    sed -i "s|TODO-replace-with-your-team|${TEAM_NAME}|" .github/CODEOWNERS
  fi
fi

# ─── Update SECURITY.md contacts ───
if [ -f SECURITY.md ]; then
  echo -e "  ${DIM}Updating security contacts...${NC}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|Fill in when adopting template|${SLACK_CHANNEL} (${TEAM_NAME})|g" SECURITY.md
  else
    sed -i "s|Fill in when adopting template|${SLACK_CHANNEL} (${TEAM_NAME})|g" SECURITY.md
  fi
fi

# ─── Summary ───
echo ""
echo -e "${BOLD}  ────────────────────────${NC}"
echo -e "${BOLD}  Project initialized!${NC}"
echo -e "${BOLD}  ────────────────────────${NC}"
echo ""
echo "  Updated:"
echo -e "  ${GREEN}\u2713${NC} .claude/MEMORY.md — Claude knows your app, team, and data classification"
echo -e "  ${GREEN}\u2713${NC} Helm chart — ${APP_NAME} as the app name"
echo -e "  ${GREEN}\u2713${NC} CODEOWNERS — @coreweave/${TEAM_NAME}"
echo -e "  ${GREEN}\u2713${NC} SECURITY.md — ${SLACK_CHANNEL} as team contact"
[ -f python/pyproject.toml ] && echo -e "  ${GREEN}\u2713${NC} pyproject.toml — ${APP_NAME}"
[ -f go/go.mod ] && echo -e "  ${GREEN}\u2713${NC} go.mod — github.com/coreweave/${APP_NAME}"
echo ""
echo "  Claude now knows:"
echo -e "  ${DIM}  App: ${APP_NAME}${NC}"
echo -e "  ${DIM}  Purpose: ${APP_DESC}${NC}"
echo -e "  ${DIM}  Team: ${TEAM_NAME} (${SLACK_CHANNEL})${NC}"
echo -e "  ${DIM}  Data: ${DATA_DESC}${NC}"
echo ""
echo "  Next: start building! Claude will use this context automatically."
echo ""
