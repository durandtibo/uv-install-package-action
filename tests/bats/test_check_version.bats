#!/usr/bin/env bats
# Unit tests for check_version.sh using BATS. `python` is mocked on the PATH.

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/check_version.sh"
	MOCK_DIR="$(mktemp -d)"
	export GITHUB_OUTPUT="${MOCK_DIR}/output"
	export ARGS_FILE="${MOCK_DIR}/args"
	: >"$GITHUB_OUTPUT"
}

teardown() {
	rm -rf "$MOCK_DIR"
}

# mock_python <stdout> <stderr> <exit status>: python mock that records its arguments
mock_python() {
	cat >"${MOCK_DIR}/python" <<MOCK
#!/bin/bash
echo "\$@" >"\$ARGS_FILE"
printf '%s' '$1'
printf '%s' '$2' >&2
exit $3
MOCK
	chmod +x "${MOCK_DIR}/python"
	PATH="${MOCK_DIR}:${PATH}"
}

@test "True is reported as valid" {
	mock_python "True" "" 0
	run "$SCRIPT" numpy 2.3.0 3.11
	[ "$status" -eq 0 ]
	[ "$(cat "$GITHUB_OUTPUT")" = "is-valid-version=true" ]
}

@test "False with exit status 1 is reported as invalid, not as an error" {
	mock_python "False" "" 1
	run "$SCRIPT" numpy 2.3.0 3.9
	[ "$status" -eq 0 ]
	[ "$(cat "$GITHUB_OUTPUT")" = "is-valid-version=false" ]
	[[ "$output" =~ "::warning::numpy 2.3.0 is not valid for Python 3.9" ]]
}

@test "True with a nonzero exit status is still valid" {
	mock_python "True" "" 1
	run "$SCRIPT" numpy 2.3.0 3.11
	[ "$status" -eq 0 ]
	[ "$(cat "$GITHUB_OUTPUT")" = "is-valid-version=true" ]
}

@test "garbage stdout fails and writes no output" {
	mock_python "maybe" "" 0
	run "$SCRIPT" numpy 2.3.0 3.11
	[ "$status" -eq 1 ]
	[[ "$output" =~ "::error::" ]]
	[[ "$output" =~ "got 'maybe'" ]]
	[ ! -s "$GITHUB_OUTPUT" ]
}

@test "empty stdout fails" {
	mock_python "" "" 0
	run "$SCRIPT" numpy 2.3.0 3.11
	[ "$status" -eq 1 ]
	[ ! -s "$GITHUB_OUTPUT" ]
}

@test "crash with a stderr message fails and shows the message" {
	mock_python "" "InvalidVersion: bad" 1
	run "$SCRIPT" numpy 2.3.0 3.11
	[ "$status" -eq 1 ]
	[[ "$output" =~ "InvalidVersion: bad" ]]
	[ ! -s "$GITHUB_OUTPUT" ]
}

@test "crash is never reported as an invalid version" {
	mock_python "" "boom" 1
	run "$SCRIPT" numpy 2.3.0 3.11
	[[ ! "$output" =~ "is not valid" ]]
	! grep -q "is-valid-version=false" "$GITHUB_OUTPUT"
}

@test "error message does not mention PyPI" {
	mock_python "" "boom" 1
	run "$SCRIPT" numpy 2.3.0 3.11
	[[ ! "$output" =~ "PyPI" ]]
}

@test "wildcard version is passed to feu as is" {
	mock_python "True" "" 0
	run "$SCRIPT" numpy "2.3.*" 3.11
	[ "$status" -eq 0 ]
	[[ "$(cat "$ARGS_FILE")" =~ "--pkg-version=2.3.*" ]]
}

@test "wildcard matching nothing is reported as invalid" {
	mock_python "False" "" 1
	run "$SCRIPT" numpy "9.9.*" 3.11
	[ "$status" -eq 0 ]
	[ "$(cat "$GITHUB_OUTPUT")" = "is-valid-version=false" ]
}

@test "python-version is passed to feu when set" {
	mock_python "True" "" 0
	run "$SCRIPT" numpy 2.3.0 3.11
	[ "$(cat "$ARGS_FILE")" = "-m feu check-valid-version --pkg-name=numpy --pkg-version=2.3.0 --python-version=3.11" ]
}

@test "python-version is not passed to feu when empty" {
	mock_python "True" "" 0
	run "$SCRIPT" numpy 2.3.0 ""
	[ "$status" -eq 0 ]
	[[ ! "$(cat "$ARGS_FILE")" =~ "--python-version" ]]
}

@test "python-version is not passed to feu when omitted" {
	mock_python "True" "" 0
	run "$SCRIPT" numpy 2.3.0
	[ "$status" -eq 0 ]
	[[ ! "$(cat "$ARGS_FILE")" =~ "--python-version" ]]
}

@test "free-threaded 3.13t is passed to feu unchanged (regression for A4)" {
	mock_python "True" "" 0
	run "$SCRIPT" numpy 2.3.0 3.13t
	[[ "$(cat "$ARGS_FILE")" =~ "--python-version=3.13t" ]]
}

@test "too few arguments fails with usage message" {
	run "$SCRIPT" numpy
	[ "$status" -eq 1 ]
	[[ "$output" =~ "Usage:" ]]
}
