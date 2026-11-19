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

.PHONY: check-bats-assertions
check-bats-assertions: ## Check that the bats assertions do not pass vacuously on bash 3.2
	./dev/check_bats_assertions.sh

.PHONY: check-python
check-python: ## Check the formatting and the lint of the Python files (needs invoke)
	inv format.check-python
	inv lint.check-python

.PHONY: check-types
check-types: ## Check the type annotations of the Python files with ty and pyright (needs invoke)
	inv types.check --complete

.PHONY: pre-commit
pre-commit: ## Run the pre-commit hooks on all files
	pre-commit run --show-diff-on-failure --color=always --all-files

.PHONY: check-export
check-export: ## Check that the release archive contains only what the action needs
	./dev/check_export.sh

.PHONY: clean
clean: ## Remove generated caches
	rm -rf .pytest_cache .ruff_cache
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
