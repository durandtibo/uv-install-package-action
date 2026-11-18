#!/usr/bin/env bash
#
# Check the result of one run of the action in the action tests (ci-action-deps.yaml and
# ci-action-edge-cases.yaml), for the local action and for the released action, so that both
# runs assert the same thing.
#
# Unit tests run the scripts in scripts/ directly: they cannot see a wrong wiring in
# action.yaml (an input that is not passed, an output that is not exposed or renamed). The
# edge cases are in tests/action_cases.json; this script checks one of them (or, for the
# package tests, a generic success).
#
# Environment variables (passed through env:, never interpolated in a script):
#   CASE               The case, as a JSON object (a row of tests/action_cases.json)
#   OUTCOME            The outcome of the step that ran the action (success or failure)
#   VALID              The output is-valid-version (empty when the step did not set it)
#   INSTALLED          The output installed (empty when not set)
#   INSTALLED_VERSION  The output installed-version (empty when not set)
#   USE_RELEASED       "true" when the released action was tested: it has no output
#                      installed and installed-version, so they are not checked
#
# A case has "id", "expect" (the outcome, "success" by default) and, optionally:
#   "valid", "installed"  the exact value of the outputs is-valid-version and installed
#   "version-prefix"      the prefix of the output installed-version
# On success, the outputs are always checked by format and by invariant, never only printed:
# is-valid-version is true or false, installed equals is-valid-version, and installed-version
# is set if and only if the package was installed.
#
# Exit codes:
#   0 - The check passed
#   1 - At least one problem (each one is reported as an ::error::)

set -euo pipefail

errors=0
id="?"

fail() {
	echo "::error::[$id] $*" >&2
	errors=1
}

# check <what> <actual> <expected>
check() {
	if [ "$2" != "$3" ]; then
		fail "$1: expected '$3', got '$2'"
	fi
}

check_success_outputs() {
	if [ "$VALID" != "true" ] && [ "$VALID" != "false" ]; then
		fail "is-valid-version must be 'true' or 'false', got '$VALID'"
	fi
	[ "$USE_RELEASED" != "true" ] || return 0
	check "installed (must equal is-valid-version)" "$INSTALLED" "$VALID"
	if [ "$INSTALLED" = "true" ] && [ -z "$INSTALLED_VERSION" ]; then
		fail "installed-version is empty although the package was installed"
	fi
	if [ "$INSTALLED" = "false" ] && [ -n "$INSTALLED_VERSION" ]; then
		fail "installed-version must be empty when the installation was skipped, got '$INSTALLED_VERSION'"
	fi
}

main() {
	local expect want_valid want_installed prefix
	: "${CASE:?CASE must be set}"
	OUTCOME="${OUTCOME:-}"
	VALID="${VALID:-}"
	INSTALLED="${INSTALLED:-}"
	INSTALLED_VERSION="${INSTALLED_VERSION:-}"
	USE_RELEASED="${USE_RELEASED:-false}"

	id=$(jq -r '.id // "?"' <<<"$CASE")
	expect=$(jq -r '.expect // "success"' <<<"$CASE")
	want_valid=$(jq -r '.valid // empty' <<<"$CASE")
	want_installed=$(jq -r '.installed // empty' <<<"$CASE")
	prefix=$(jq -r '.["version-prefix"] // empty' <<<"$CASE")

	if [ "$OUTCOME" != "$expect" ]; then
		fail "outcome: expected '$expect', got '$OUTCOME'"
		return 1
	fi
	if [ "$expect" = "success" ]; then
		check_success_outputs
	fi
	if [ -n "$want_valid" ]; then
		check "is-valid-version" "$VALID" "$want_valid"
	fi
	if [ "$USE_RELEASED" != "true" ]; then
		if [ -n "$want_installed" ]; then
			check "installed" "$INSTALLED" "$want_installed"
		fi
		if [ -n "$prefix" ]; then
			check "installed-version prefix" "${INSTALLED_VERSION:0:${#prefix}}" "$prefix"
		fi
	fi
	[ "$errors" -eq 0 ] || return 1
	echo "✅ Case $id: outcome $OUTCOME, is-valid-version='$VALID', installed='$INSTALLED', installed-version='$INSTALLED_VERSION'"
}

main "$@"
