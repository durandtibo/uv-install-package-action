#!/bin/bash
# Validates and normalizes Python version to major.minor format
#
# Usage: validate_python_version.sh <python-version>
#
# Arguments:
#   python-version: Python version string (e.g., "3.10", "3.11", "3.10.1",
#                    or the free-threaded variant "3.13t", "3.13.0t")
#
# Outputs:
#   Prints the normalized Python version (major.minor, with a trailing 't'
#   preserved for free-threaded builds) to stdout
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

# Validate format: digits.digits or digits.digits.digits, with an optional
# trailing 't' marking a free-threaded build (e.g. "3.13t", "3.14.0t")
if ! echo "$PYTHON_VERSION" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?t?$'; then
    echo "Error: Invalid Python version format: '$PYTHON_VERSION'. Expected format: 'X.Y', 'X.Y.Z', or the free-threaded variant 'X.Yt' (e.g., '3.10', '3.10.1', '3.13t')" >&2
    exit 1
fi

# Detect and strip the free-threaded 't' suffix so the numeric part can be
# normalized independently, then reattach it to the result.
FREE_THREADED_SUFFIX=""
NUMERIC_VERSION="$PYTHON_VERSION"
if [[ "$PYTHON_VERSION" == *t ]]; then
    FREE_THREADED_SUFFIX="t"
    NUMERIC_VERSION="${PYTHON_VERSION%t}"
fi

# Extract major.minor version (ignore patch version if present)
NORMALIZED_VERSION="$(echo "$NUMERIC_VERSION" | cut -d. -f1,2)${FREE_THREADED_SUFFIX}"

# Print the normalized version to stdout
echo "$NORMALIZED_VERSION"

# Exit successfully
exit 0
