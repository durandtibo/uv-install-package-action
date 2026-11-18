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
- `test_check_version.bats` - Tests for the `feu` version check (mocked `python`)
- `test_handle_invalid_version.bats` - Tests for the `skip` and `fail` modes
- `test_validate_inputs.bats` - Tests for the package-name/package-version/invalid-version-mode
  input validation script
- `test_get_installed_version.bats` - Tests for the script that reads the installed version with
  `uv pip show` (mocked `uv`)

**Coverage:**

- uv present or missing
- Valid Python versions (major.minor format), including free-threaded builds (`X.Yt`)
- Rejection of patch versions (X.Y.Z, X.Y.Zt)
- Edge cases (whitespace, tab characters, high version numbers)
- Invalid formats (comprehensive error cases)
- Error message quality
- Version check: `True`, `False` (exit status 1), garbage stdout, crash with stderr, wildcards,
  `--python-version` passed only when set, free-threaded `3.13t`
- `skip` (warning, exit 0) and `fail` (error, exit 1) modes
- Input validation for package-name (PEP 508 name, no leading `-`), package-version and
  invalid-version-mode
- Reading the installed version (package found, not found, extra output lines)

All bash logic embedded in `action.yaml` that has meaningful branching (input validation, Python
version validation, installed-version lookup) is extracted into standalone scripts under
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
```

### 3. Integration Tests (GitHub Actions)

Full end-to-end tests run in GitHub Actions workflows.

**Location:** `.github/workflows/`

**Key Workflows:**

- `ci.yaml` - Entry point of the checks; calls the `ci-*.yaml` workflows below
- `ci-python.yaml` - Functional tests across Python versions and OS platforms
- `ci-action.yaml` - Tests the action in a real workflow. The input `use-released` (default
  `false`) selects the action from this checkout (`uses: ./`) or the latest release. It tests each
  optional dependency of the package (`ci-action-deps.yaml`, which also asserts the `is-valid-version`,
  `installed` and `installed-version` outputs) and with edge cases
  (`ci-action-edge-cases.yaml`). The edge cases are a table (one matrix entry per case, with the
  expected outcome and outputs): free-threaded and auto-detected Python versions, an invalid
  version in `skip` and `fail` mode, wildcards, an incorrect or patch `python-version`, an invalid
  `invalid-version-mode`, an invalid `package-name` or `package-version`, and `uv-args` (a default
  index as positive control, an unreachable index that must fail the install). Cases that need
  unreleased behaviour are marked `local-only`
- `ci-export.yaml` - Checks with `make check-export` that the release archive contains only
  `action.yaml`, `LICENSE` and `scripts/*.sh`
- `nightly.yaml` - Calls `ci-action.yaml` with `use-released: true`: same edge cases and package
  matrix, but against the latest published release (run nightly, not on every PR) to catch
  regressions between what's merged and what's tagged
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
```

## Continuous Integration

All tests run automatically in CI via GitHub Actions:

- **On Push/PR:** Shell tests, functional tests, formatting checks
- **Nightly:** Extended tests with latest dependencies
- **Manual:** Any workflow can be triggered via workflow_dispatch

See `.github/workflows/ci.yaml` for the complete CI configuration.
