#!/bin/bash
# Checks with feu whether a package version is valid for the target Python version.
#
# Usage: check_version.sh <package-name> <package-version> [<python-version>]
#
# Arguments:
#   package-name:    Package name (e.g. "numpy")
#   package-version: Exact version ("2.3.0") or wildcard ("2.3.*")
#   python-version:  Target Python ("3.12", "3.13t"). When empty or omitted, feu uses the
#                    interpreter it runs in (including the free-threaded 't' suffix).
#
# Environment:
#   GITHUB_OUTPUT: file the "is-valid-version" output (true or false) is appended to
#
# `python -m feu check-valid-version` prints True or False on stdout and exits with status 1
# in both the False case and the crash case. So the exit status is ignored and stdout is
# parsed: any other output is a real error (never reported as an invalid version).
#
# Exit codes:
#   0: the check ran (the result is in the output, even when the version is invalid)
#   1: bad usage, or feu did not print True or False

set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
	echo "Usage: $0 <package-name> <package-version> [<python-version>]" >&2
	exit 1
fi

PACKAGE_NAME="$1"
PACKAGE_VERSION="$2"
PYTHON_VERSION="${3-}"

FEU_ARGS=(--pkg-name="$PACKAGE_NAME" --pkg-version="$PACKAGE_VERSION")
if [ -n "$PYTHON_VERSION" ]; then
	FEU_ARGS+=(--python-version="$PYTHON_VERSION")
fi

STDERR_FILE=$(mktemp)
trap 'rm -f "$STDERR_FILE"' EXIT

# The exit status is ignored on purpose (see above)
RESULT=$(python -m feu check-valid-version "${FEU_ARGS[@]}" 2>"$STDERR_FILE") || true

TARGET="${PYTHON_VERSION:-the current Python}"
if [ "$RESULT" = "True" ]; then
	echo "Step 2.2: ${PACKAGE_NAME} ${PACKAGE_VERSION} is valid for Python ${TARGET}"
	echo "is-valid-version=true" >>"$GITHUB_OUTPUT"
elif [ "$RESULT" = "False" ]; then
	echo "Step 2.2: ${PACKAGE_NAME} ${PACKAGE_VERSION} is not valid for Python ${TARGET}"
	echo "is-valid-version=false" >>"$GITHUB_OUTPUT"
else
	echo "::error::feu check-valid-version failed for ${PACKAGE_NAME} ${PACKAGE_VERSION}: expected 'True' or 'False' on stdout, got '${RESULT}'" >&2
	if [ -s "$STDERR_FILE" ]; then
		echo "::error::feu stderr: $(cat "$STDERR_FILE")" >&2
	fi
	exit 1
fi
