#!/usr/bin/env bats
# Unit tests for get_import_name.sh using BATS

setup() {
    BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/get_import_name.sh"
}

@test "package name without hyphens is unchanged" {
    run "$SCRIPT" "numpy"
    [ "$status" -eq 0 ]
    [ "$output" = "numpy" ]
}

@test "single hyphen is converted to underscore" {
    run "$SCRIPT" "scikit-learn"
    [ "$status" -eq 0 ]
    [ "$output" = "scikit_learn"  ]
}

@test "multiple hyphens are all converted to underscores" {
    run "$SCRIPT" "a-b-c"
    [ "$status" -eq 0 ]
    [ "$output" = "a_b_c" ]
}

@test "already-underscored name is unchanged" {
    run "$SCRIPT" "python_dateutil"
    [ "$status" -eq 0 ]
    [ "$output" = "python_dateutil" ]
}

@test "missing argument fails with usage message" {
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}
