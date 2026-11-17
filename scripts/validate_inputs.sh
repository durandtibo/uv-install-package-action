#!/bin/bash
# Validates the package-name, package-version and invalid-version-mode inputs.
#
# Usage: validate_inputs.sh <package-name> <package-version> [<invalid-version-mode>]
#
# Arguments:
#   package-name:         Distribution name (PEP 508 name syntax, e.g. "numpy", "scikit-learn")
#   package-version:      Exact version ("2.0.2") or wildcard ("2.12.*"): non-empty, no
#                         whitespace, no leading '-'
#   invalid-version-mode: "skip" or "fail" (default: "skip")
#
# Exit codes:
#   0: inputs are valid
#   1: an input is missing or invalid (an ::error:: message is printed to stderr)

set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
	echo "Usage: $0 <package-name> <package-version> [<invalid-version-mode>]" >&2
	exit 1
fi

PACKAGE_NAME="$1"
PACKAGE_VERSION="$2"
MODE="${3-skip}"

if [ -z "$PACKAGE_NAME" ]; then
	echo "::error::package-name cannot be empty" >&2
	exit 1
fi

# PEP 508 name: letters, digits, '.', '_' and '-', starting and ending with a letter or digit.
if ! [[ "$PACKAGE_NAME" =~ ^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$ ]]; then
	echo "::error::package-name '${PACKAGE_NAME}' is not a valid package name (letters, digits, '.', '_' and '-' only, starting and ending with a letter or digit)" >&2
	exit 1
fi

if [ -z "$PACKAGE_VERSION" ]; then
	echo "::error::package-version cannot be empty" >&2
	exit 1
fi

if [[ "$PACKAGE_VERSION" =~ [[:space:]] ]]; then
	echo "::error::package-version cannot contain whitespace: '${PACKAGE_VERSION}'" >&2
	exit 1
fi

if [[ "$PACKAGE_VERSION" == -* ]]; then
	echo "::error::package-version cannot start with '-': '${PACKAGE_VERSION}'" >&2
	exit 1
fi

if [ "$MODE" != "skip" ] && [ "$MODE" != "fail" ]; then
	echo "::error::invalid-version-mode must be 'skip' or 'fail', got '${MODE}'" >&2
	exit 1
fi

echo "Step 1.2: inputs are valid (package '${PACKAGE_NAME}', version '${PACKAGE_VERSION}', mode '${MODE}')"
