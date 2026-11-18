#!/usr/bin/env bats
# Unit tests for validate_python_version.sh using BATS

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/validate_python_version.sh"
}

# Valid values are printed unchanged

@test "empty value is accepted and printed empty" {
	run "$SCRIPT" ""
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "3.10 is valid" {
	run "$SCRIPT" "3.10"
	[ "$status" -eq 0 ]
	[ "$output" = "3.10" ]
}

@test "3.9 is valid" {
	run "$SCRIPT" "3.9"
	[ "$status" -eq 0 ]
	[ "$output" = "3.9" ]
}

@test "3.14 is valid" {
	run "$SCRIPT" "3.14"
	[ "$status" -eq 0 ]
	[ "$output" = "3.14" ]
}

@test "3.100 is valid" {
	run "$SCRIPT" "3.100"
	[ "$status" -eq 0 ]
	[ "$output" = "3.100" ]
}

@test "free-threaded 3.13t is valid" {
	run "$SCRIPT" "3.13t"
	[ "$status" -eq 0 ]
	[ "$output" = "3.13t" ]
}

@test "free-threaded 3.14t is valid" {
	run "$SCRIPT" "3.14t"
	[ "$status" -eq 0 ]
	[ "$output" = "3.14t" ]
}

# Patch versions are rejected, not normalized

@test "patch version 3.10.1 fails" {
	run "$SCRIPT" "3.10.1"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Patch versions are not accepted"* ]]
}

@test "free-threaded patch version 3.13.0t fails" {
	run "$SCRIPT" "3.13.0t"
	[ "$status" -eq 1 ]
}

@test "four parts 3.10.1.2 fails" {
	run "$SCRIPT" "3.10.1.2"
	[ "$status" -eq 1 ]
}

# Invalid formats

@test "major only '3' fails" {
	run "$SCRIPT" "3"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Expected 'X.Y'"* ]]
}

@test "major only free-threaded '3t' fails" {
	run "$SCRIPT" "3t"
	[ "$status" -eq 1 ]
}

@test "prefix 'python3.10' fails" {
	run "$SCRIPT" "python3.10"
	[ "$status" -eq 1 ]
}

@test "non-numeric minor '3.x' fails" {
	run "$SCRIPT" "3.x"
	[ "$status" -eq 1 ]
}

@test "non-numeric major 'x.10' fails" {
	run "$SCRIPT" "x.10"
	[ "$status" -eq 1 ]
}

@test "text 'abc' fails" {
	run "$SCRIPT" "abc"
	[ "$status" -eq 1 ]
}

@test "double suffix '3.13tt' fails" {
	run "$SCRIPT" "3.13tt"
	[ "$status" -eq 1 ]
}

@test "leading 't' 't3.13' fails" {
	run "$SCRIPT" "t3.13"
	[ "$status" -eq 1 ]
}

@test "leading dot '.3.10' fails" {
	run "$SCRIPT" ".3.10"
	[ "$status" -eq 1 ]
}

@test "trailing dot '3.10.' fails" {
	run "$SCRIPT" "3.10."
	[ "$status" -eq 1 ]
}

@test "negative '-3.10' fails" {
	run "$SCRIPT" "-3.10"
	[ "$status" -eq 1 ]
}

@test "surrounding whitespace ' 3.10 ' fails" {
	run "$SCRIPT" " 3.10 "
	[ "$status" -eq 1 ]
}

# Argument count

@test "missing argument fails with usage message" {
	run "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" == *"Usage:"* ]]
}
