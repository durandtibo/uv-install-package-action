#!/bin/bash
# Validates the action's package-name, package-version, and uv-args inputs.
#
# Usage: validate_inputs.sh <package-name> <package-version> <uv-args>
#
# Arguments:
#   package-name:    The package name (e.g., "numpy", "requests")
#   package-version: The target package version (e.g., "1.2.3")
#   uv-args:         Additional arguments to pass to uv (may be empty)
#
# Outputs:
#   Prints warnings to stderr for non-fatal issues (e.g., shell metacharacters
#   in uv-args)
#
# Exit codes:
#   0: Success - inputs are valid
#   1: Error - a required input is missing or invalid

set -euo pipefail

if [ $# -ne 3 ]; then
    echo "Usage: $0 <package-name> <package-version> <uv-args>" >&2
    exit 1
fi

PACKAGE_NAME="$1"
PACKAGE_VERSION="$2"
UV_ARGS="$3"

# Validate package-name is not empty
if [ -z "$PACKAGE_NAME" ]; then
    echo "Error: package-name cannot be empty" >&2
    exit 1
fi

# Validate package-name doesn't contain obviously invalid characters
if [[ "$PACKAGE_NAME" =~ [[:space:]] ]]; then
    echo "Error: package-name cannot contain whitespace: '$PACKAGE_NAME'" >&2
    exit 1
fi

# Validate package-version is not empty
if [ -z "$PACKAGE_VERSION" ]; then
    echo "Error: package-version cannot be empty" >&2
    exit 1
fi

# Check for potentially dangerous characters in uv-args (shell metacharacters)
if [[ "$UV_ARGS" =~ [\;|] ]]; then
    echo "Warning: uv-args contains shell metacharacters (';' or '|'). Ensure these are properly escaped and intentional." >&2
fi

exit 0
