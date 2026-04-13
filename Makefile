# === CW Secure Template — Common Commands ===
# Run `make help` to see all available commands.

SHELL := /bin/bash

.DEFAULT_GOAL := help

# Auto-detect language based on which starter exists
GO_EXISTS := $(wildcard go/go.mod)
PY_EXISTS := $(wildcard python/pyproject.toml)

# ──────────────────────────────────────
# Setup
# ──────────────────────────────────────

.PHONY: setup
setup: ## First-time setup — install hooks, deps, create .env
	@echo "=== Installing pre-commit hooks ==="
	pip install pre-commit 2>/dev/null || brew install pre-commit
	pre-commit install
	@echo "=== Installing custom git hooks ==="
	@cp scripts/git-hooks/pre-commit .git/hooks/pre-commit 2>/dev/null || true
	@cp scripts/git-hooks/post-checkout .git/hooks/post-checkout 2>/dev/null || true
	@chmod +x .git/hooks/pre-commit .git/hooks/post-checkout 2>/dev/null || true
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "=== Created .env from .env.example — fill in your values ==="; \
	fi
ifdef GO_EXISTS
	@echo "=== Installing Go dependencies ==="
	cd go && go mod download
endif
ifdef PY_EXISTS
	@echo "=== Installing Python dependencies ==="
	cd python && pip install -e ".[dev]"
endif
	@echo ""
	@$(MAKE) doctor
	@echo "Setup complete. Run 'make run' to start."

# ──────────────────────────────────────
# Run
# ──────────────────────────────────────

.PHONY: run
run: ## Start the application
ifdef GO_EXISTS
	cd go && go run .
endif
ifdef PY_EXISTS
	cd python && uvicorn src.main:app --reload --port $${PORT:-8080}
endif

# ──────────────────────────────────────
# Lint
# ──────────────────────────────────────

.PHONY: lint
lint: ## Run linters
ifdef GO_EXISTS
	cd go && golangci-lint run
endif
ifdef PY_EXISTS
	cd python && ruff check . && ruff format --check .
endif

.PHONY: lint-fix
lint-fix: ## Run linters and auto-fix
ifdef GO_EXISTS
	cd go && golangci-lint run --fix
endif
ifdef PY_EXISTS
	cd python && ruff check --fix . && ruff format .
endif

# ──────────────────────────────────────
# Test
# ──────────────────────────────────────

.PHONY: test
test: ## Run tests
ifdef GO_EXISTS
	cd go && go test -race -cover ./...
endif
ifdef PY_EXISTS
	cd python && pytest --cov=src --cov-report=term-missing
endif

# ──────────────────────────────────────
# Security
# ──────────────────────────────────────

.PHONY: security-scan
security-scan: ## Run all security scanners
	@echo "=== Secret scanning ==="
	gitleaks detect --source . --verbose 2>/dev/null || echo "Install gitleaks: brew install gitleaks"
ifdef GO_EXISTS
	@echo "=== Go security scan (gosec) ==="
	cd go && gosec ./... 2>/dev/null || echo "Install gosec: go install github.com/securego/gosec/v2/cmd/gosec@latest"
	@echo "=== Go vulnerability check ==="
	cd go && govulncheck ./... 2>/dev/null || echo "Install govulncheck: go install golang.org/x/vuln/cmd/govulncheck@latest"
endif
ifdef PY_EXISTS
	@echo "=== Python security scan (bandit) ==="
	cd python && bandit -c bandit.yaml -r src/
	@echo "=== Python dependency audit ==="
	cd python && pip-audit .
endif

# ──────────────────────────────────────
# Docker
# ──────────────────────────────────────

.PHONY: docker-build
docker-build: ## Build Docker image
ifdef GO_EXISTS
	docker build -f go/Dockerfile -t my-app:latest go/
endif
ifdef PY_EXISTS
	docker build -f python/Dockerfile -t my-app:latest python/
endif

# ──────────────────────────────────────
# All checks (run before PR)
# ──────────────────────────────────────

.PHONY: check
check: lint test security-scan ## Run ALL checks (lint + test + security) — run before every PR

# ──────────────────────────────────────
# Fix & Doctor
# ──────────────────────────────────────

.PHONY: fix
fix: ## Auto-fix security + lint issues (runs scanners, fixes what it can)
	@bash scripts/security-fix.sh

.PHONY: doctor
doctor: ## Health check — verify the entire security pipeline is working
	@bash scripts/doctor.sh

# ──────────────────────────────────────
# Learn
# ──────────────────────────────────────

.PHONY: learn
learn: ## Interactive security quiz — test your OWASP knowledge
	@bash scripts/security-quiz.sh

# ──────────────────────────────────────
# Dashboard
# ──────────────────────────────────────

.PHONY: dashboard
dashboard: ## Open the security pipeline dashboard in your browser
	@open security-dashboard.html 2>/dev/null || xdg-open security-dashboard.html 2>/dev/null || echo "Open security-dashboard.html in your browser"

# ──────────────────────────────────────
# Help
# ──────────────────────────────────────

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
