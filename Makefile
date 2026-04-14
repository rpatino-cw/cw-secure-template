# === CW Secure Template ===
#
# You only need 3 commands:
#   make start   — Run your app
#   make check   — Run before pull requests
#   make help    — See everything else
#

SHELL := /bin/bash
.DEFAULT_GOAL := help

GO_EXISTS := $(wildcard go/go.mod)
PY_EXISTS := $(wildcard python/pyproject.toml)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THE 3 COMMANDS YOU NEED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: start
start: ## Run your app
ifdef GO_EXISTS
	@cd go && go run .
endif
ifdef PY_EXISTS
	@cd python && uvicorn src.main:app --reload --port $${PORT:-8080}
endif

.PHONY: check
check: lint test security-scan ## Run ALL checks — do this before every pull request
	@echo ""
	@echo "  All checks passed. You're good to open a pull request."
	@echo ""

.PHONY: help
help: ## Show all available commands
	@echo ""
	@echo "  CW Secure Template — Commands"
	@echo "  ─────────────────────────────"
	@echo ""
	@echo "  Quick start:"
	@echo "    make start       Run your app"
	@echo "    make check       Run before pull requests"
	@echo ""
	@echo "  Testing & quality:"
	@echo "    make test        Run tests"
	@echo "    make lint        Check code style"
	@echo "    make fix         Auto-fix lint + security issues"
	@echo ""
	@echo "  Security:"
	@echo "    make doctor      Is my security pipeline healthy?"
	@echo "    make scan        Deep security scan"
	@echo "    make learn       Take a security quiz (15 questions)"
	@echo "    make dashboard   Open the security dashboard"
	@echo ""
	@echo "  Multi-agent:"
	@echo "    make rooms       Set up room-based coordination"
	@echo "    make agent       Start Claude as a room agent (NAME=go-dev)"
	@echo "    make room-status See pending requests across rooms"
	@echo ""
	@echo "  Branch workflow:"
	@echo "    make branch      Create a feature branch (NAME=my-feature)"
	@echo "    make pr          Run checks + push + open PR to main"
	@echo "    make review      AI code review on unpushed changes"
	@echo ""
	@echo "  Docs:"
	@echo "    make readme      Simplify README via Claude Code"
	@echo ""
	@echo "  Setup:"
	@echo "    make init        Personalize for your project (name, team, data)"
	@echo "    make add-secret  Safely store an API key in .env"
	@echo "    make add-config  Safely store a config file (.json, .pem, etc.)"
	@echo "    make setup       Re-run first-time setup"
	@echo "    make docker      Build Docker image"
	@echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TESTING & QUALITY (behind make help)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: test
test:
ifdef GO_EXISTS
	@cd go && go test -race -cover ./...
endif
ifdef PY_EXISTS
	@cd python && pytest --cov=src --cov-report=term-missing
endif

.PHONY: lint
lint:
ifdef GO_EXISTS
	@cd go && golangci-lint run 2>/dev/null || echo "  golangci-lint not installed — run: brew install golangci-lint"
endif
ifdef PY_EXISTS
	@cd python && ruff check . 2>/dev/null && ruff format --check . 2>/dev/null || echo "  ruff not installed — run: pip install ruff"
endif

.PHONY: fix
fix: ## Auto-fix lint + security issues
ifdef GO_EXISTS
	@cd go && golangci-lint run --fix 2>/dev/null || true
endif
ifdef PY_EXISTS
	@cd python && ruff check --fix . 2>/dev/null && ruff format . 2>/dev/null || true
endif
	@echo ""
	@bash scripts/security-fix.sh

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECURITY (behind make help)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: doctor
doctor:
	@bash scripts/doctor.sh

.PHONY: scan
scan:
	@echo "  Running deep security scan..."
	@gitleaks detect --source . --no-banner 2>/dev/null || echo "  gitleaks not installed — run: brew install gitleaks"
ifdef GO_EXISTS
	@cd go && gosec ./... 2>/dev/null || echo "  gosec not installed"
	@cd go && govulncheck ./... 2>/dev/null || echo "  govulncheck not installed"
endif
ifdef PY_EXISTS
	@cd python && bandit -c bandit.yaml -r src/ 2>/dev/null || echo "  bandit not installed"
	@cd python && pip-audit . 2>/dev/null || echo "  pip-audit not installed"
endif

.PHONY: security-scan
security-scan: scan

.PHONY: add-secret
add-secret:
	@bash scripts/add-secret.sh

.PHONY: add-config
add-config:
	@bash scripts/add-config.sh

.PHONY: scan-drops
scan-drops:
	@bash scripts/scan-drops.sh

.PHONY: learn
learn:
	@bash scripts/security-quiz.sh

.PHONY: dashboard
dashboard:
	@open security-dashboard.html 2>/dev/null || xdg-open security-dashboard.html 2>/dev/null || echo "  Open security-dashboard.html in your browser"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTI-AGENT ROOMS (behind make help)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: rooms
rooms: ## Set up room-based multi-agent coordination
	@bash scripts/init-rooms.sh

.PHONY: agent
agent: ## Start a Claude session as a room agent (NAME=go-dev)
	@bash scripts/start-agent.sh $(NAME)

.PHONY: room-status
room-status: ## Show pending requests across all rooms
	@bash scripts/room-status.sh

.PHONY: room-lint
room-lint: ## Validate room config (runs automatically on push)
	@bash scripts/room-lint.sh

.PHONY: review
review: ## AI code review on your unpushed changes
	@bash scripts/agent-review.sh

.PHONY: branch
branch: ## Create a feature branch (NAME=my-feature)
	@bash scripts/create-branch.sh $(NAME)

.PHONY: pr
pr: ## Run checks + push + open PR to main
	@bash scripts/open-pr.sh

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SETUP (behind make help)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: setup
setup:
	@bash setup.sh

.PHONY: init
init:
	@bash scripts/init-project.sh

.PHONY: run
run: start

.PHONY: docker
docker:
ifdef GO_EXISTS
	docker build -f go/Dockerfile -t my-app:latest go/
endif
ifdef PY_EXISTS
	docker build -f python/Dockerfile -t my-app:latest python/
endif

.PHONY: lint-fix
lint-fix: fix

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# README (behind make help)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: readme
readme: ## Simplify README via Claude Code
	@claude -p "Read README.md. Rewrite it: keep the one-liner clone command, the 5 make commands, and requirements. Move everything else into <details> dropdowns. No section should exceed 10 lines when collapsed. Write the result back to README.md." --allowedTools Edit,Read
