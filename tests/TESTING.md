# Testing Guide

This document explains the different types of tests in this repository and how to run them.

## Test Types

### 1. Shell Script Tests (BATS)

Unit tests for bash scripts using [BATS](https://github.com/bats-core/bats-core) (Bash Automated
Testing System).

**Location:** `tests/bats/`

**Test Files:**

- `test_check_uv.bats` - Tests for the uv availability check
- `test_validate_python_version.bats` - Tests for the Python version validation script
- `test_validate_inputs.bats` - Tests for the package-name/package-version/invalid-version-mode
  input validation script
- `test_get_import_name.bats` - Tests for the package-name → import-name conversion script used
  by the "Verify installation" step

**Coverage:**

- Valid Python versions (major.minor format), including free-threaded builds (`X.Yt`)
- Rejection of patch versions (X.Y.Z, X.Y.Zt)
- Edge cases (whitespace, tab characters, high version numbers)
- Invalid formats (comprehensive error cases)
- Error message quality
- Input validation for package-name (PEP 508 name, no leading `-`), package-version and
  invalid-version-mode
- Package-name to import-name conversion (e.g. `scikit-learn` → `sklearn` module prefix)

All bash logic embedded in `action.yaml` that has meaningful branching (input validation, Python
version validation, import-name conversion) is extracted into standalone scripts under
`scripts/` specifically so it can be unit-tested here rather than only exercised indirectly via
the slower GitHub Actions integration tests below.

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

**Location:** `tests/unit/`

**Note:** The action's validation logic (input validation, Python version validation) is
implemented in standalone scripts under `scripts/` and is unit-tested with BATS (see above), not
pytest. This directory is reserved for future Python-level unit tests.

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

- `ci.yaml` - Entry point of the checks; calls the `ci-*.yaml` workflows below
- `ci-test.yaml` - Functional tests across Python versions and OS platforms
- `ci-action.yaml` - Tests local action changes (uses `./` action reference) with each optional
  dependency of the package (`ci-action-deps.yaml`) and with edge cases
  (`ci-action-edge-cases.yaml`): no `python-version` given (auto-detect), a patch
  `python-version`, a free-threaded `python-version`, an invalid `python-version`, and an empty
  `package-name`
- `nightly.yaml` / `nightly-test-released.yaml` - Same edge cases and package matrix as
  `ci-action.yaml`, but against the latest published release (run nightly, not on every PR) to
  catch regressions between what's merged and what's tagged
- `ci-shell.yaml` / `ci-shell-bash32.yaml` - Runs BATS shell tests in CI (the second one with the
  system bash 3.2 of macOS)

**Coverage:**

- Multiple Python versions (3.10-3.14, plus free-threaded `3.13t`/`3.14t` variants)
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
