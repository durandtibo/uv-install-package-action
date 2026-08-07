#!/usr/bin/env bats
# Unit tests for validate_inputs.sh using BATS

setup() {
    BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    VALIDATE_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/validate_inputs.sh"
}

# Valid inputs

@test "valid package name, version, and empty uv-args succeeds" {
    run "$VALIDATE_SCRIPT" "numpy" "1.2.3" ""
    [ "$status" -eq 0 ]
}

@test "valid inputs with uv-args succeeds without warning" {
    run "$VALIDATE_SCRIPT" "numpy" "1.2.3" "--index-url https://custom.pypi.org/simple"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "package name with hyphen succeeds" {
    run "$VALIDATE_SCRIPT" "scikit-learn" "1.4.0" ""
    [ "$status" -eq 0 ]
}

# package-name validation

@test "empty package-name fails" {
    run "$VALIDATE_SCRIPT" "" "1.2.3" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "package-name cannot be empty" ]]
}

@test "package-name with whitespace fails" {
    run "$VALIDATE_SCRIPT" "num py" "1.2.3" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "package-name cannot contain whitespace" ]]
}

@test "package-name with leading space fails" {
    run "$VALIDATE_SCRIPT" " numpy" "1.2.3" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "package-name cannot contain whitespace" ]]
}

@test "package-name with tab character fails" {
    run "$VALIDATE_SCRIPT" "$(printf 'num\tpy')" "1.2.3" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "package-name cannot contain whitespace" ]]
}

# package-version validation

@test "empty package-version fails" {
    run "$VALIDATE_SCRIPT" "numpy" "" ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "package-version cannot be empty" ]]
}

@test "whitespace-only package-version is treated as non-empty and succeeds" {
    run "$VALIDATE_SCRIPT" "numpy" " " ""
    [ "$status" -eq 0 ]
}

@test "wildcard package-version '2.12.*' succeeds" {
    run "$VALIDATE_SCRIPT" "numpy" "2.12.*" ""
    [ "$status" -eq 0 ]
}

@test "wildcard package-version '2.*' succeeds" {
    run "$VALIDATE_SCRIPT" "numpy" "2.*" ""
    [ "$status" -eq 0 ]
}

# uv-args validation (non-fatal warning)

@test "uv-args with semicolon warns but succeeds" {
    run "$VALIDATE_SCRIPT" "numpy" "1.2.3" "--foo; rm -rf /"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "shell metacharacters" ]]
}

@test "uv-args with pipe warns but succeeds" {
    run "$VALIDATE_SCRIPT" "numpy" "1.2.3" "--foo | cat"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "shell metacharacters" ]]
}

@test "uv-args with both semicolon and pipe warns once but succeeds" {
    run "$VALIDATE_SCRIPT" "numpy" "1.2.3" "--foo; bar | baz"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "shell metacharacters" ]]
}

@test "uv-args with only whitespace does not warn" {
    run "$VALIDATE_SCRIPT" "numpy" "1.2.3" "   "
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# Argument count validation

@test "missing arguments fails with usage message" {
    run "$VALIDATE_SCRIPT" "numpy" "1.2.3"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}
