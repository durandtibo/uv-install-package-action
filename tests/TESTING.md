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
- `test_check_action_case.bats` - Tests for `dev/check_action_case.sh`, the verify step shared by
  the local and the released action tests (outcome, format and invariants of the outputs)
- `test_action_cases.bats` - Checks the table of edge cases `tests/action_cases.json`: unique ids,
  required fields, every input of `action.yaml` is set by a case, every validated input has a
  failing case
- `test_check_bats_assertions.bats` - Tests for `dev/check_bats_assertions.sh`, which rejects the
  `[[ ]]` and `! cmd` assertions without `|| false` (they pass vacuously on bash 3.2 when they are
  not the last command of a test). Run on the repository by `make check-bats-assertions`
- `test_action_readme_sync.bats` - Checks that `action.yaml` and `README.md` list the same inputs
  and outputs with the same required flags and defaults, and that every input reaches the scripts
  through `env:` (never interpolated in a `run:` block). Its last tests run the helpers on modified
  copies to prove that a drift is detected

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
make test-bats

# Run with timing information
bats --recursive --timing tests/bats/

# Run with verbose output
bats --recursive -t tests/bats/
```

### 2. Functional Tests (pytest)

Tests that verify installed packages can be imported and used correctly.

**Location:** `tests/functional/`

**Coverage:**

- Package import verification for common packages (numpy, polars, torch, etc.)
- Uses conditional decorators to skip if package not available

**Running the Tests:**

```bash
# Run functional tests
make test-functional
```

### 3. Integration Tests (GitHub Actions)

Full end-to-end tests run in GitHub Actions workflows.

**Location:** `.github/workflows/`

**Key Workflows:**

- `ci.yaml` - Entry point of the checks; calls the `ci-*.yaml` workflows below
- `ci-python.yaml` - Functional tests (`make test-functional`) across Python versions and OS platforms
- `ci-action.yaml` - Tests the action in a real workflow. The input `use-released` (default
  `false`) selects the action from this checkout (`uses: ./`) or the latest release. It tests each
  optional dependency of the package (`ci-action-deps.yaml`) and with edge cases
  (`ci-action-edge-cases.yaml`). Both assert the outcome and the `is-valid-version`, `installed`
  and `installed-version` outputs with `dev/check_action_case.sh`, for the local and the released
  action. The edge cases are data, a table in `tests/action_cases.json` (one matrix cell per row,
  with the expected outcome and outputs, and a `released` flag): free-threaded and auto-detected
  Python versions, an invalid version in `skip` and `fail` mode, wildcards, an incorrect or patch
  `python-version`, an invalid `invalid-version-mode`, an invalid `package-name` or
  `package-version`, and `uv-args` (a default index as positive control, an unreachable index that
  must fail the install). A case that expects a failure follows a positive run on the same runner,
  so it cannot fail for the wrong reason. Cases that need unreleased behaviour have
  `"released": false` and are skipped for the released action
- `ci-format.yaml` / `ci-pre-commit.yaml` - Format and lint checks, through the make targets
  `make format`, `make lint`, `make check-bats-assertions`, `make check-python` and `make pre-commit`
- `ci-export.yaml` - Checks with `make check-export` that the release archive contains only
  `action.yaml`, `LICENSE` and `scripts/*.sh`
- `nightly.yaml` - Calls `ci-action.yaml` with `use-released: true`: same edge cases and package
  matrix, but against the latest published release (run nightly, not on every PR) to catch
  regressions between what's merged and what's tagged
- `ci-shell.yaml` / `ci-shell-bash32.yaml` - Runs BATS shell tests in CI (the second one with the
  system bash 3.2 of macOS)

**Coverage:**

- Multiple Python versions and OS platforms: both lists come from `durandtibo/workflow-config-action`
  through `lib-get-test-matrix.yaml` (`python_versions`: the standard versions plus the free-threaded
  ones; `os_matrix`: the Ubuntu and macOS runners, including ARM variants). Windows is not supported
  and not tested
- Real package installations with various versions (`dev/config/package_versions.json`)

**Cost of a run (cells per run).** The same matrix runs on pull requests, pushes and the schedule
(there is no reduced matrix). With the lists loaded on 2026-11-18 (13 runners, 8 Python versions,
so 104 OS x Python cells):

| Job                                 | Cells                                                  |
| ----------------------------------- | ------------------------------------------------------ |
| `ci-shell.yaml`                     | 13 (`os_matrix`)                                       |
| `ci-shell-bash32.yaml`              | 5 (`os_macos`)                                         |
| `ci-python.yaml`                    | 208 (2 jobs x 104)                                     |
| `ci-action-deps.yaml` (general)     | 15288 (147 package versions in 14 extras x 104)        |
| `ci-action-edge-cases.yaml` (edges) | 17 rows on `ubuntu-latest` (6 for the released action) |
| `ci-export.yaml`                    | 1                                                      |

The general behaviour is the only job that crosses the whole matrix; the edge cases never do. The
count changes with the lists of `workflow-config-action` and with `dev/config/package_versions.json`
(`bot-generate-package-versions.yaml`).

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
