#!/bin/bash
# Checks that uv is available on the runner.
#
# Usage: check_uv.sh
#
# Prints the path and the version of uv on success.
#
# Exit codes:
#   0: uv is available
#   1: uv is not installed or not in PATH

set -euo pipefail

if ! UV_PATH=$(command -v uv); then
	echo "::error::uv is not installed or not in PATH. Install it before using this action (e.g. with astral-sh/setup-uv)." >&2
	exit 1
fi

echo "Step 1.1: uv found at ${UV_PATH} ($(uv --version))"
