#!/usr/bin/env bats
# Unit tests for validate_inputs.sh using BATS

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/validate_inputs.sh"
}

# Valid inputs

@test "valid name and version succeeds" {
	run "$SCRIPT" "numpy" "1.2.3"
	[ "$status" -eq 0 ]
}

@test "package name with hyphen succeeds" {
	run "$SCRIPT" "scikit-learn" "1.4.0"
	[ "$status" -eq 0 ]
}

@test "package name with dot and underscore succeeds" {
	run "$SCRIPT" "zope.interface_x" "1.0"
	[ "$status" -eq 0 ]
}

@test "single character package name succeeds" {
	run "$SCRIPT" "a" "1.0"
	[ "$status" -eq 0 ]
}

@test "wildcard version '2.12.*' succeeds" {
	run "$SCRIPT" "numpy" "2.12.*"
	[ "$status" -eq 0 ]
}

@test "wildcard version '2.*' succeeds" {
	run "$SCRIPT" "numpy" "2.*"
	[ "$status" -eq 0 ]
}

@test "mode 'skip' succeeds" {
	run "$SCRIPT" "numpy" "1.2.3" "skip"
	[ "$status" -eq 0 ]
}

@test "mode 'fail' succeeds" {
	run "$SCRIPT" "numpy" "1.2.3" "fail"
	[ "$status" -eq 0 ]
}

@test "mode defaults to skip when omitted" {
	run "$SCRIPT" "numpy" "1.2.3"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "mode 'skip'" ]] || false
}

# package-name

@test "empty package-name fails" {
	run "$SCRIPT" "" "1.2.3"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "package-name cannot be empty" ]] || false
}

@test "package-name with whitespace fails" {
	run "$SCRIPT" "num py" "1.2.3"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "not a valid package name" ]] || false
}

@test "package-name with leading space fails" {
	run "$SCRIPT" " numpy" "1.2.3"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "not a valid package name" ]] || false
}

@test "package-name with tab character fails" {
	run "$SCRIPT" "$(printf 'num\tpy')" "1.2.3"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "not a valid package name" ]] || false
}

@test "package-name '-e' fails" {
	run "$SCRIPT" "-e" "1.2.3"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "not a valid package name" ]] || false
}

@test "package-name '--pre' fails" {
	run "$SCRIPT" "--pre" "1.2.3"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "not a valid package name" ]] || false
}

@test "package-name that is a VCS url fails" {
	run "$SCRIPT" "git+https://github.com/org/repo" "1.2.3"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "not a valid package name" ]] || false
}

@test "package-name ending with a hyphen fails" {
	run "$SCRIPT" "numpy-" "1.2.3"
	[ "$status" -eq 1 ]
}

@test "package-name with a specifier fails" {
	run "$SCRIPT" "numpy==1.0" "1.2.3"
	[ "$status" -eq 1 ]
}

# package-version

@test "empty package-version fails" {
	run "$SCRIPT" "numpy" ""
	[ "$status" -eq 1 ]
	[[ "$output" =~ "package-version cannot be empty" ]] || false
}

@test "whitespace-only package-version fails" {
	run "$SCRIPT" "numpy" " "
	[ "$status" -eq 1 ]
	[[ "$output" =~ "package-version cannot contain whitespace" ]] || false
}

@test "package-version with inner whitespace fails" {
	run "$SCRIPT" "numpy" "1.2 3"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "package-version cannot contain whitespace" ]] || false
}

@test "package-version with leading '-' fails" {
	run "$SCRIPT" "numpy" "--pre"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "cannot start with '-'" ]] || false
}

# invalid-version-mode

@test "mode 'ignore' fails" {
	run "$SCRIPT" "numpy" "1.2.3" "ignore"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "invalid-version-mode must be 'skip' or 'fail'" ]] || false
}

@test "mode 'Skip' (wrong case) fails" {
	run "$SCRIPT" "numpy" "1.2.3" "Skip"
	[ "$status" -eq 1 ]
}

@test "empty mode fails" {
	run "$SCRIPT" "numpy" "1.2.3" ""
	[ "$status" -eq 1 ]
}

# Argument count

@test "missing arguments fails with usage message" {
	run "$SCRIPT" "numpy"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "Usage:" ]] || false
}

@test "too many arguments fails with usage message" {
	run "$SCRIPT" "numpy" "1.2.3" "skip" "extra"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "Usage:" ]] || false
}
