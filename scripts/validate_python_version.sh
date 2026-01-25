#!/bin/bash
# Validates and normalizes Python version to major.minor format
#
# Usage: validate_python_version.sh <python-version>
# 
# Arguments:
#   python-version: Python version string (e.g., "3.10", "3.11", "3.10.1")
#
# Outputs:
#   Prints the normalized Python version (major.minor) to stdout
#
# Exit codes:
#   0: Success - valid version format
#   1: Error - invalid version format

set -euo pipefail

# Check if argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <python-version>" >&2
    exit 1
fi

PYTHON_VERSION="$1"

# Remove leading/trailing whitespace
PYTHON_VERSION=$(echo "$PYTHON_VERSION" | xargs)

# Validate format: should be digits.digits or digits.digits.digits
if ! echo "$PYTHON_VERSION" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
    echo "Error: Invalid Python version format: '$PYTHON_VERSION'. Expected format: 'X.Y' or 'X.Y.Z' (e.g., '3.10' or '3.10.1')" >&2
    exit 1
fi

# Extract major.minor version (ignore patch version if present)
NORMALIZED_VERSION=$(echo "$PYTHON_VERSION" | cut -d. -f1,2)

# Print the normalized version to stdout
echo "$NORMALIZED_VERSION"

# Exit successfully
exit 0
