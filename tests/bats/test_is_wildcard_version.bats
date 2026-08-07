#!/usr/bin/env bats
# Unit tests for is_wildcard_version.sh using BATS

setup() {
    BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/is_wildcard_version.sh"
}

# Wildcard versions

@test "'2.12.*' is detected as a wildcard version" {
    run "$SCRIPT" "2.12.*"
    [ "$status" -eq 0 ]
}

@test "'2.*' is detected as a wildcard version" {
    run "$SCRIPT" "2.*"
    [ "$status" -eq 0 ]
}

@test "'*' is detected as a wildcard version" {
    run "$SCRIPT" "*"
    [ "$status" -eq 0 ]
}

@test "'2.12.3.*' is detected as a wildcard version" {
    run "$SCRIPT" "2.12.3.*"
    [ "$status" -eq 0 ]
}

# Exact (non-wildcard) versions

@test "'2.12.3' is not detected as a wildcard version" {
    run "$SCRIPT" "2.12.3"
    [ "$status" -eq 1 ]
}

@test "'2.12' is not detected as a wildcard version" {
    run "$SCRIPT" "2.12"
    [ "$status" -eq 1 ]
}

@test "'1.0.0rc1' is not detected as a wildcard version" {
    run "$SCRIPT" "1.0.0rc1"
    [ "$status" -eq 1 ]
}

# Argument count validation

@test "missing argument fails with usage message" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}
