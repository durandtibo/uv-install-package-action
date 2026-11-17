#!/bin/bash
# Prints the version of a package installed in the environment, as reported by uv.
#
# Usage: get_installed_version.sh <package-name>
#
# Arguments:
#   package-name: Package name (e.g. "numpy")
#
# Outputs:
#   Prints the value of the "Version:" field of `uv pip show` to stdout.
#
# Exit codes:
#   0: version printed
#   1: bad usage, package not found, or no "Version:" field in the output

set -euo pipefail

if [ $# -ne 1 ]; then
	echo "Usage: $0 <package-name>" >&2
	exit 1
fi

PACKAGE_NAME="$1"

if [ -z "$PACKAGE_NAME" ]; then
	echo "::error::package-name cannot be empty" >&2
	exit 1
fi

if ! SHOW_OUTPUT=$(uv pip show "$PACKAGE_NAME" 2>&1); then
	echo "::error::Cannot find the installed version of '${PACKAGE_NAME}': ${SHOW_OUTPUT}" >&2
	exit 1
fi

# Keep only the first "Version:" line, ignore every other line
VERSION=$(printf '%s\n' "$SHOW_OUTPUT" | sed -n 's/^Version:[[:space:]]*//p' | head -n 1)

if [ -z "$VERSION" ]; then
	echo "::error::'uv pip show ${PACKAGE_NAME}' did not report a version" >&2
	exit 1
fi

echo "$VERSION"
