#!/usr/bin/env bats
# Unit tests for validate_python_version.sh using BATS

setup() {
    # Get the directory containing this test file
    BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    # Path to the validation script
    VALIDATE_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/validate_python_version.sh"
}

# Test valid Python versions (major.minor format)

@test "Python 3.10 is valid and returns 3.10" {
    run "$VALIDATE_SCRIPT" "3.10"
    [ "$status" -eq 0 ]
    [ "$output" = "3.10" ]
}

@test "Python 3.11 is valid and returns 3.11" {
    run "$VALIDATE_SCRIPT" "3.11"
    [ "$status" -eq 0 ]
    [ "$output" = "3.11" ]
}

@test "Python 3.12 is valid and returns 3.12" {
    run "$VALIDATE_SCRIPT" "3.12"
    [ "$status" -eq 0 ]
    [ "$output" = "3.12" ]
}

@test "Python 3.13 is valid and returns 3.13" {
    run "$VALIDATE_SCRIPT" "3.13"
    [ "$status" -eq 0 ]
    [ "$output" = "3.13" ]
}

@test "Python 3.14 is valid and returns 3.14" {
    run "$VALIDATE_SCRIPT" "3.14"
    [ "$status" -eq 0 ]
    [ "$output" = "3.14" ]
}

@test "Python 3.9 is valid and returns 3.9" {
    run "$VALIDATE_SCRIPT" "3.9"
    [ "$status" -eq 0 ]
    [ "$output" = "3.9" ]
}

# Test valid Python versions with patch version (should normalize)

@test "Python 3.10.1 normalizes to 3.10" {
    run "$VALIDATE_SCRIPT" "3.10.1"
    [ "$status" -eq 0 ]
    [ "$output" = "3.10" ]
}

@test "Python 3.11.5 normalizes to 3.11" {
    run "$VALIDATE_SCRIPT" "3.11.5"
    [ "$status" -eq 0 ]
    [ "$output" = "3.11" ]
}

@test "Python 3.12.0 normalizes to 3.12" {
    run "$VALIDATE_SCRIPT" "3.12.0"
    [ "$status" -eq 0 ]
    [ "$output" = "3.12" ]
}

@test "Python 3.9.18 normalizes to 3.9" {
    run "$VALIDATE_SCRIPT" "3.9.18"
    [ "$status" -eq 0 ]
    [ "$output" = "3.9" ]
}

@test "Python 3.13.999 normalizes to 3.13" {
    run "$VALIDATE_SCRIPT" "3.13.999"
    [ "$status" -eq 0 ]
    [ "$output" = "3.13" ]
}

# Test edge cases

@test "Whitespace trimming: '  3.10  ' returns 3.10" {
    run "$VALIDATE_SCRIPT" "  3.10  "
    [ "$status" -eq 0 ]
    [ "$output" = "3.10" ]
}

@test "Future Python 11.2 is valid and returns 11.2" {
    run "$VALIDATE_SCRIPT" "11.2"
    [ "$status" -eq 0 ]
    [ "$output" = "11.2" ]
}

@test "High minor version 3.100 is valid and returns 3.100" {
    run "$VALIDATE_SCRIPT" "3.100"
    [ "$status" -eq 0 ]
    [ "$output" = "3.100" ]
}

@test "High major version 20.5 is valid and returns 20.5" {
    run "$VALIDATE_SCRIPT" "20.5"
    [ "$status" -eq 0 ]
    [ "$output" = "20.5" ]
}

@test "Double digit versions 10.15 is valid and returns 10.15" {
    run "$VALIDATE_SCRIPT" "10.15"
    [ "$status" -eq 0 ]
    [ "$output" = "10.15" ]
}

# Test invalid formats (should fail)

@test "Major version only '3' fails" {
    run "$VALIDATE_SCRIPT" "3"
    [ "$status" -eq 1 ]
}

@test "Too many version parts '3.10.1.2' fails" {
    run "$VALIDATE_SCRIPT" "3.10.1.2"
    [ "$status" -eq 1 ]
}

@test "Invalid prefix 'python3.10' fails" {
    run "$VALIDATE_SCRIPT" "python3.10"
    [ "$status" -eq 1 ]
}

@test "Non-numeric minor '3.x' fails" {
    run "$VALIDATE_SCRIPT" "3.x"
    [ "$status" -eq 1 ]
}

@test "Non-numeric major 'x.10' fails" {
    run "$VALIDATE_SCRIPT" "x.10"
    [ "$status" -eq 1 ]
}

@test "Empty string fails" {
    run "$VALIDATE_SCRIPT" ""
    [ "$status" -eq 1 ]
}

@test "Alphabetic 'abc' fails" {
    run "$VALIDATE_SCRIPT" "abc"
    [ "$status" -eq 1 ]
}

@test "Only dots '...' fails" {
    run "$VALIDATE_SCRIPT" "..."
    [ "$status" -eq 1 ]
}

@test "Leading dot '.3.10' fails" {
    run "$VALIDATE_SCRIPT" ".3.10"
    [ "$status" -eq 1 ]
}

@test "Trailing dot '3.10.' fails" {
    run "$VALIDATE_SCRIPT" "3.10."
    [ "$status" -eq 1 ]
}

@test "Negative numbers '-3.10' fails" {
    run "$VALIDATE_SCRIPT" "-3.10"
    [ "$status" -eq 1 ]
}

@test "Decimal version '3.10.5.2' fails" {
    run "$VALIDATE_SCRIPT" "3.10.5.2"
    [ "$status" -eq 1 ]
}
