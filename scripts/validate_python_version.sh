#!/bin/bash
# Validates the python-version input.
#
# Usage: validate_python_version.sh <python-version>
#
# Arguments:
#   python-version: Empty (the target is detected later), "X.Y" (e.g. "3.12") or the
#                   free-threaded variant "X.Yt" (e.g. "3.13t"). Patch versions such
#                   as "3.12.1" are rejected, not normalized.
#
# Outputs:
#   Prints the validated value to stdout (an empty line when it is empty).
#
# Exit codes:
#   0: valid
#   1: invalid format (an ::error:: message is printed to stderr)

set -euo pipefail

if [ $# -ne 1 ]; then
	echo "Usage: $0 <python-version>" >&2
	exit 1
fi

PYTHON_VERSION="$1"

if [ -n "$PYTHON_VERSION" ] && ! [[ "$PYTHON_VERSION" =~ ^[0-9]+\.[0-9]+t?$ ]]; then
	echo "::error::Invalid python-version '${PYTHON_VERSION}'. Expected 'X.Y' or the free-threaded 'X.Yt' (e.g. '3.12', '3.13t'), or empty to use the current interpreter. Patch versions are not accepted." >&2
	exit 1
fi

echo "$PYTHON_VERSION"
