# === CW Secure Framework ===
#
# You only need 4 commands:
#   make new     — Start a new app from a blueprint
#   make start   — Run your app
#   make check   — Run before pull requests
#   make help    — See everything else
#

SHELL := /bin/bash
.DEFAULT_GOAL := help

GO_EXISTS := $(wildcard go/go.mod)
PY_EXISTS := $(wildcard python/pyproject.toml)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# THE 4 COMMANDS YOU NEED
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: new
new: ## Start a new app from a blueprint
	@bash scripts/apply-blueprint.sh $(BLUEPRINT)

.PHONY: start
start: ## Run your app
ifdef GO_EXISTS
	@cd go && go run .
endif
ifdef PY_EXISTS
	@cd python && \
	if [ -f .venv/bin/uvicorn ]; then \
		.venv/bin/uvicorn src.main:app --reload --port $${PORT:-8080}; \
	else \
		uvicorn src.main:app --reload --port $${PORT:-8080}; \
	fi
endif

.PHONY: check
check: lint test security-scan ## Run ALL checks — do this before every pull request
	@echo ""
	@echo "  All checks passed. You're good to open a pull request."
	@echo ""

.PHONY: help
help: ## Show commands
	@echo ""
	@echo "  CW Secure Framework"
	@echo "  ──────────────────"
	@echo ""
	@echo "    make new         Start from a blueprint"
	@echo "    make start       Run your app"
	@echo "    make check       Run before pushing"
	@echo "    make rooms       Set up multi-agent coordination"
	@echo ""
	@echo "  Run 'make help-all' for the full command list."
	@echo ""

.PHONY: help-all
help-all: ## Show all available commands
	@echo ""
	@echo "  CW Secure Framework — All Commands"
	@echo "  ──────────────────────────────────"
	@echo ""
	@echo "  Start here:"
	@echo "    make new          Start from a blueprint (BLUEPRINT=chat-assistant)"
	@echo "    make start        Run your app"
	@echo "    make check        Run before pushing"
	@echo "    make rooms        Set up multi-agent coordination"
	@echo ""
	@echo "  Multi-agent:"
	@echo "    make agent        Start Claude as a room agent (NAME=go)"
	@echo "    make room-status  See pending requests across rooms"
	@echo "    make room-lint    Validate room config"
	@echo "    make review       AI code review on unpushed changes"
	@echo ""
	@echo "  Branch workflow (opt-in: BRANCH_MODE=1 in .env):"
	@echo "    make branch       Create a feature branch (NAME=my-feature)"
	@echo "    make pr           Run checks + push + open PR to main"
	@echo ""
	@echo "  Testing & quality:"
	@echo "    make test         Run tests"
	@echo "    make lint         Check code style"
	@echo "    make fix          Auto-fix lint + security issues"
	@echo ""
	@echo "  Security:"
	@echo "    make doctor       Is my security pipeline healthy?"
	@echo "    make scan         Deep security scan"
	@echo "    make learn        Take a security quiz (15 questions)"
	@echo "    make add-secret   Safely store an API key in .env"
	@echo "    make add-config   Safely store a config file"
	@echo "    make viz          How it works — interactive visualizer"
	@echo ""
	@echo "  Setup:"
	@echo "    make init         Personalize for your project"
	@echo "    make setup        Re-run first-time setup"
	@echo "    make profile      Set enforcement level (LEVEL=hackathon|balanced|strict|production)"
	@echo "    make docker       Build Docker image"
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

.PHONY: viz
viz: ## How it works — interactive visualizer
	@open docs/visualizer.html 2>/dev/null || xdg-open docs/visualizer.html 2>/dev/null || echo "  Open docs/visualizer.html in your browser"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTI-AGENT ROOMS (behind make help)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

.PHONY: rooms
rooms: ## Set up room-based multi-agent coordination
	@bash scripts/init-rooms.sh

.PHONY: agent
agent: ## Start a Claude session as a room agent (NAME=go-dev, BRANCH=optional)
	@BRANCH=$(BRANCH) bash scripts/start-agent.sh $(NAME)

.PHONY: room-status
room-status: ## Show pending requests across all rooms
	@bash scripts/room-status.sh

.PHONY: room-lint
room-lint: ## Validate room config (runs automatically on push)
	@bash scripts/room-lint.sh

.PHONY: review
review: ## AI code review on your unpushed changes
	@bash scripts/agent-review.sh

.PHONY: repo-lint
repo-lint: ## Check repo hygiene (LICENSE, OG tags, homepage, etc.)
	@bash scripts/repo-lint.sh

.PHONY: test-guards
test-guards: ## Run guard unit tests (30 checks)
	@bash scripts/guards/test-guards.sh

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

.PHONY: profile
profile: ## Set enforcement level (LEVEL=hackathon|balanced|strict|production)
	@bash scripts/set-profile.sh $(LEVEL)

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
readme: ## Regenerate README from rules and project structure
	@bash scripts/gen-readme.sh

.PHONY: bump-version
bump-version: ## Patch site footer with latest git tag
	@VERSION=$$(git describe --tags --abbrev=0 2>/dev/null || echo "dev"); \
	sed -i '' "s/v[0-9]*\.[0-9]*\.[0-9]*/$$VERSION/" docs/index.html; \
	echo "  Site version bumped to $$VERSION"
