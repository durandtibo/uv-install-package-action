SHELL = /bin/bash

include .make/all.mk

.PHONY: all
all: format lint test ## Format, lint and test

.PHONY: test-bats
test-bats: ## Run the bats tests of the shell scripts
	bats --recursive tests/bats/

.PHONY: test-functional
test-functional: ## Run the functional tests (pytest)
	pytest tests/functional

.PHONY: test
test: test-bats ## Run the bats and pytest tests
	pytest

.PHONY: check-export
check-export: ## Check that the release archive contains only what the action needs
	./dev/check_export.sh

.PHONY: clean
clean: ## Remove generated caches
	rm -rf .pytest_cache .ruff_cache
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
