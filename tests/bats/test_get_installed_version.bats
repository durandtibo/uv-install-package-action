#!/usr/bin/env bats
# Unit tests for get_installed_version.sh using BATS. `uv` is mocked on the PATH.

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/get_installed_version.sh"
	MOCK_DIR="$(mktemp -d)"
	export ARGS_FILE="${MOCK_DIR}/args"
}

teardown() {
	rm -rf "$MOCK_DIR"
}

# mock_uv <stdout> <exit status>: uv mock that records its arguments
mock_uv() {
	cat >"${MOCK_DIR}/uv" <<MOCK
#!/bin/bash
echo "\$@" >"\$ARGS_FILE"
printf '%s\n' '$1'
exit $2
MOCK
	chmod +x "${MOCK_DIR}/uv"
	PATH="${MOCK_DIR}:${PATH}"
}

@test "prints the version of an installed package" {
	mock_uv "Name: numpy
Version: 2.3.5
Location: /venv/lib" 0
	run "$SCRIPT" numpy
	[ "$status" -eq 0 ]
	[ "$output" = "2.3.5" ]
}

@test "calls uv pip show with the package name" {
	mock_uv "Version: 1.0" 0
	run "$SCRIPT" scikit-learn
	[ "$(cat "$ARGS_FILE")" = "pip show scikit-learn" ]
}

@test "ignores the other lines, including the ones that mention a version" {
	mock_uv "Name: numpy
Summary: Fundamental package, Version: 9.9.9
Version: 2.3.5
Requires-Dist: foo
Required-by: bar" 0
	run "$SCRIPT" numpy
	[ "$output" = "2.3.5" ]
}

@test "prints only the first Version field" {
	mock_uv "Version: 1.0
Version: 2.0" 0
	run "$SCRIPT" numpy
	[ "$output" = "1.0" ]
}

@test "pre-release versions are printed as is" {
	mock_uv "Version: 2.0.0rc1" 0
	run "$SCRIPT" numpy
	[ "$output" = "2.0.0rc1" ]
}

@test "package not found fails with an error" {
	mock_uv "warning: Package(s) not found for: numpy" 1
	run "$SCRIPT" numpy
	[ "$status" -eq 1 ]
	[[ "$output" =~ "::error::Cannot find the installed version of 'numpy'" ]]
}

@test "output without a Version field fails" {
	mock_uv "Name: numpy" 0
	run "$SCRIPT" numpy
	[ "$status" -eq 1 ]
	[[ "$output" =~ "did not report a version" ]]
}

@test "empty package name fails" {
	run "$SCRIPT" ""
	[ "$status" -eq 1 ]
	[[ "$output" =~ "package-name cannot be empty" ]]
}

@test "missing argument fails with usage message" {
	run "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "Usage:" ]]
}
