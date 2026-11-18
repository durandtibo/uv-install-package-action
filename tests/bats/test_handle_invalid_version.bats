#!/usr/bin/env bats
# Unit tests for handle_invalid_version.sh using BATS

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/handle_invalid_version.sh"
}

@test "skip mode succeeds with a warning" {
	run "$SCRIPT" numpy 2.3.0 3.9 skip
	[ "$status" -eq 0 ]
	[[ "$output" == *"::warning::"* ]]
	[[ "$output" != *"::error::"* ]]
}

@test "skip mode warning names the package, version and Python version" {
	run "$SCRIPT" numpy 2.3.0 3.9 skip
	[[ "$output" == *"numpy 2.3.0 is not valid for Python 3.9"* ]]
	[[ "$output" == *"Skipping installation"* ]]
}

@test "fail mode fails with an error" {
	run "$SCRIPT" numpy 2.3.0 3.9 fail
	[ "$status" -eq 1 ]
	[[ "$output" == *"::error::numpy 2.3.0 is not valid for Python 3.9"* ]]
	[[ "$output" != *"::warning::"* ]]
}

@test "wildcard version is reported as is" {
	run "$SCRIPT" numpy "2.3.*" 3.9 fail
	[ "$status" -eq 1 ]
	[[ "$output" == *"numpy 2.3.* is not valid"* ]]
}

@test "free-threaded Python version is reported as is" {
	run "$SCRIPT" numpy 2.3.0 3.13t skip
	[[ "$output" == *"Python 3.13t"* ]]
}

@test "empty Python version is described as the current interpreter" {
	run "$SCRIPT" numpy 2.3.0 "" skip
	[ "$status" -eq 0 ]
	[[ "$output" == *"current interpreter"* ]]
}

@test "unknown mode fails" {
	run "$SCRIPT" numpy 2.3.0 3.9 ignore
	[ "$status" -eq 1 ]
	[[ "$output" == *"invalid-version-mode must be 'skip' or 'fail'"* ]]
}

@test "empty mode fails" {
	run "$SCRIPT" numpy 2.3.0 3.9 ""
	[ "$status" -eq 1 ]
}

@test "wrong number of arguments fails with usage message" {
	run "$SCRIPT" numpy 2.3.0 3.9
	[ "$status" -eq 1 ]
	[[ "$output" == *"Usage:"* ]]
}
