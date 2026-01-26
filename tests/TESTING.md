# Testing Guide

This document explains the different types of tests in this repository and how to run them.

## Test Types

### 1. Shell Script Tests (BATS)

Unit tests for bash scripts using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

**Location:** `tests/bats/`

**Test Files:**
- `test_validate_python_version.bats` - Tests for the Python version validation and normalization script

**Coverage:**
- Valid Python versions (major.minor format)
- Normalization of patch versions (X.Y.Z → X.Y)
- Edge cases (whitespace, high version numbers)
- Invalid formats (comprehensive error cases)
- Error message quality

**Prerequisites:**

Install BATS on your system:

```bash
# On macOS with Homebrew
brew install bats-core

# On Ubuntu/Debian
sudo apt-get install bats
```

**Running the Tests:**

```bash
# Run all BATS tests
bats --recursive tests/bats/

# Run with timing information
bats --recursive --timing tests/bats/

# Run with verbose output
bats --recursive -t tests/bats/
```

### 2. Functional Tests (pytest)

Tests that verify installed packages can be imported and used correctly.

**Location:** `tests/functional/`

**Coverage:**
- Package import verification for common packages (numpy, pandas, torch, etc.)
- Uses conditional decorators to skip if package not available

**Running the Tests:**

```bash
# Run functional tests
pytest tests/functional/

# Or via invoke
inv functional-test
```

### 3. Unit Tests (pytest)

Specification tests that document expected behavior for the action's validation logic.

**Location:** `tests/unit/`

**Coverage:**
- Input validation specifications
- Error message quality requirements
- Retry logic specifications
- Post-install verification requirements

**Note:** These are primarily documentation tests that specify expected behavior. The actual validation happens in action.yaml shell scripts.

**Running the Tests:**

```bash
# Run unit tests
pytest tests/unit/

# Or via invoke
inv unit-test
```

### 4. Integration Tests (GitHub Actions)

Full end-to-end tests run in GitHub Actions workflows.

**Location:** `.github/workflows/`

**Key Workflows:**
- `test.yaml` - Matrix testing across Python versions and OS platforms
- `test-local.yaml` - Tests local action changes
- `test-shell.yaml` - Runs BATS shell tests in CI

**Coverage:**
- Multiple Python versions (3.10-3.14)
- Multiple OS platforms (Ubuntu, macOS, including ARM variants)
- Real package installations with various versions

**Running:**
- Automatically triggered on push/PR to main
- Can be manually triggered via GitHub Actions UI

## Running All Tests Locally

```bash
# Shell tests (requires BATS)
bats tests/bats/

# Python tests (requires pytest)
pytest tests/

# With coverage
pytest tests/ --cov

# Specific test type
pytest tests/functional/
pytest tests/unit/
```

## Continuous Integration

All tests run automatically in CI via GitHub Actions:

- **On Push/PR:** Shell tests, functional tests, formatting checks
- **Nightly:** Extended tests with latest dependencies
- **Manual:** Any workflow can be triggered via workflow_dispatch

See `.github/workflows/ci.yaml` for the complete CI configuration.
