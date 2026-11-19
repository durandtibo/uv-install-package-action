#!/usr/bin/env bats
# Unit tests for handle_invalid_version.sh using BATS

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/handle_invalid_version.sh"
}

@test "skip mode succeeds with a warning" {
	run "$SCRIPT" numpy 2.3.0 3.9 skip
	[ "$status" -eq 0 ]
	[[ "$output" == *"::warning::"* ]] || false
	[[ "$output" != *"::error::"* ]] || false
}

@test "skip mode warning names the package, version and Python version" {
	run "$SCRIPT" numpy 2.3.0 3.9 skip
	[[ "$output" == *"numpy 2.3.0 is not valid for Python 3.9"* ]] || false
	[[ "$output" == *"Skipping installation"* ]] || false
}

@test "fail mode fails with an error" {
	run "$SCRIPT" numpy 2.3.0 3.9 fail
	[ "$status" -eq 1 ]
	[[ "$output" == *"::error::numpy 2.3.0 is not valid for Python 3.9"* ]] || false
	[[ "$output" != *"::warning::"* ]] || false
}

@test "wildcard version is reported as is" {
	run "$SCRIPT" numpy "2.3.*" 3.9 fail
	[ "$status" -eq 1 ]
	[[ "$output" == *"numpy 2.3.* is not valid"* ]] || false
}

@test "free-threaded Python version is reported as is" {
	run "$SCRIPT" numpy 2.3.0 3.13t skip
	[[ "$output" == *"Python 3.13t"* ]] || false
}

@test "empty Python version is described as the current interpreter" {
	run "$SCRIPT" numpy 2.3.0 "" skip
	[ "$status" -eq 0 ]
	[[ "$output" == *"current interpreter"* ]] || false
}

@test "unknown mode fails" {
	run "$SCRIPT" numpy 2.3.0 3.9 ignore
	[ "$status" -eq 1 ]
	[[ "$output" == *"invalid-version-mode must be 'skip' or 'fail'"* ]] || false
}

@test "empty mode fails" {
	run "$SCRIPT" numpy 2.3.0 3.9 ""
	[ "$status" -eq 1 ]
}

@test "wrong number of arguments fails with usage message" {
	run "$SCRIPT" numpy 2.3.0 3.9
	[ "$status" -eq 1 ]
	[[ "$output" == *"Usage:"* ]] || false
}
