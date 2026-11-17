#!/usr/bin/env bats
# Unit tests for check_uv.sh using BATS

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/check_uv.sh"
	MOCK_DIR="$(mktemp -d)"
}

teardown() {
	rm -rf "$MOCK_DIR"
}

@test "uv present prints its path and version" {
	printf '#!/bin/bash\necho "uv 9.9.9"\n' >"${MOCK_DIR}/uv"
	chmod +x "${MOCK_DIR}/uv"
	PATH="${MOCK_DIR}:${PATH}" run "$SCRIPT"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "${MOCK_DIR}/uv" ]]
	[[ "$output" =~ "uv 9.9.9" ]]
}

@test "uv missing fails with an error" {
	# bash is called by absolute path because PATH is restricted to an empty directory
	PATH="$MOCK_DIR" run /bin/bash "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "::error::uv is not installed" ]]
}
