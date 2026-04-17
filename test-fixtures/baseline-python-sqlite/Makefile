# === Python / FastAPI secure scaffold ===
SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help start check lint test security-scan doctor fix add-secret wizard

help:
	@echo "make start         — run the app"
	@echo "make check         — run all gates (lint + test + security)"
	@echo "make lint          — style / format check"
	@echo "make test          — unit + integration (80% coverage gate)"
	@echo "make security-scan — gitleaks + bandit/gosec + SCA"
	@echo "make add-secret    — append to .env via hidden input"
	@echo "make doctor        — full pipeline health check"
	@echo "make wizard        — open the setup wizard in browser (re-pick stack)"

start:
	cd python && .venv/bin/uvicorn src.main:app --reload --port $${PORT:-8080}

lint:
	cd python && .venv/bin/ruff check src/ && .venv/bin/ruff format --check src/

test:
	cd python && .venv/bin/pytest --cov=src --cov-report=term --cov-fail-under=80

security-scan:
	cd python && .venv/bin/bandit -r src/ -ll
	gitleaks detect --source . --verbose

check: lint test security-scan
	@echo "✓ all gates passed"

add-secret:
	@bash scripts/add-secret.sh

doctor:
	@bash scripts/doctor.sh

wizard:
	@open setup.html 2>/dev/null || xdg-open setup.html 2>/dev/null || echo "Open setup.html in your browser"
