#!/bin/bash
# Detects whether a package-version string is a PEP 440 wildcard/prefix
# match (e.g. "2.12.*", "2.*") rather than an exact version.
#
# Wildcard versions cannot be parsed by 'packaging.version.Version', so they
# cannot be validated by 'feu check-valid-version' (which checks a single
# exact version against PyPI metadata). They are still valid 'pip'/'uv'
# version specifiers (e.g. "pkg==2.12.*" matches any 2.12.x release), so
# resolution for these is deferred to 'uv' at install time instead.
#
# Usage: is_wildcard_version.sh <package-version>
#
# Exit codes:
#   0: The version is a wildcard pattern
#   1: The version is not a wildcard pattern (or wrong number of arguments)

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <package-version>" >&2
    exit 1
fi

PACKAGE_VERSION="$1"

if [[ "$PACKAGE_VERSION" == *'*'* ]]; then
    exit 0
fi

exit 1
