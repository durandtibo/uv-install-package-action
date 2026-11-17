#!/bin/bash
# Checks that the release archive contains only what the action needs at runtime:
# action.yaml, LICENSE and the scripts in scripts/ (see .gitattributes).
#
# Usage: dev/check_export.sh
#
# Run it from a clean checkout: `git archive` exports the committed files of HEAD.
#
# Exit codes:
#   0: the exported set is exactly the expected one
#   1: files are missing from or unexpected in the archive

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

EXPECTED=$(git ls-files action.yaml LICENSE 'scripts/*.sh' | sort)
ACTUAL=$(git archive --worktree-attributes HEAD | tar t | grep -v '/$' | sort)

if ! DIFF=$(diff <(echo "$EXPECTED") <(echo "$ACTUAL")); then
	echo "::error::The release archive does not contain exactly action.yaml, LICENSE and scripts/*.sh. Fix .gitattributes. Diff (< expected, > actual):"
	echo "$DIFF"
	exit 1
fi

echo "Exported files:"
echo "$ACTUAL"
