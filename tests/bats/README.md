# Script Tests

This directory contains unit tests for bash scripts using [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

## Running the Tests

### Prerequisites

Install BATS on your system:

```bash
# On macOS with Homebrew
brew install bats-core

# On Ubuntu/Debian
sudo apt-get install bats
```

### Run All Tests

```bash
bats --recursive tests/bats/
```

### Run All Tests and Show Running Times

```bash
bats --recursive --timing tests/bats/
```

### Run with Verbose Output

```bash
bats --recursive -t tests/bats/
```

## Test Files

- `test_validate_python_version.bats` - Tests for the Python version validation and normalization script

## Test Coverage

The tests cover:
- Valid Python versions (major.minor format)
- Normalization of patch versions (X.Y.Z → X.Y)
- Edge cases (whitespace, high version numbers)
- Invalid formats (comprehensive error cases)
