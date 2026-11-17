#!/bin/bash
# Reports that the requested version is not valid for the target Python version.
#
# Usage: handle_invalid_version.sh <package-name> <package-version> <python-version> <mode>
#
# Arguments:
#   package-name:    Package name (e.g. "numpy")
#   package-version: Requested version or wildcard (e.g. "2.3.0", "2.3.*")
#   python-version:  Target Python (e.g. "3.9"); may be empty when it is auto-detected
#   mode:            "skip" (warn and succeed) or "fail" (error and fail)
#
# Exit codes:
#   0: mode is "skip" (a ::warning:: is printed)
#   1: mode is "fail" (an ::error:: is printed) or the arguments are invalid

set -euo pipefail

if [ $# -ne 4 ]; then
	echo "Usage: $0 <package-name> <package-version> <python-version> <mode>" >&2
	exit 1
fi

PACKAGE_NAME="$1"
PACKAGE_VERSION="$2"
PYTHON_VERSION="$3"
MODE="$4"

TARGET="Python ${PYTHON_VERSION:-(current interpreter)}"

case "$MODE" in
skip)
	echo "::warning::${PACKAGE_NAME} ${PACKAGE_VERSION} is not valid for ${TARGET}. Skipping installation."
	;;
fail)
	echo "::error::${PACKAGE_NAME} ${PACKAGE_VERSION} is not valid for ${TARGET}." >&2
	exit 1
	;;
*)
	echo "::error::invalid-version-mode must be 'skip' or 'fail', got '${MODE}'" >&2
	exit 1
	;;
esac
