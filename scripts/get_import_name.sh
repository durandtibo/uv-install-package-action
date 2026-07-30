#!/bin/bash
# Converts a package name to its likely Python import name.
#
# Usage: get_import_name.sh <package-name>
#
# Arguments:
#   package-name: The distribution name (e.g., "scikit-learn", "numpy")
#
# Outputs:
#   Prints the import name to stdout (hyphens replaced with underscores)
#
# Exit codes:
#   0: Success

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <package-name>" >&2
    exit 1
fi

echo "${1//-/_}"

exit 0
