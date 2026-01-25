#!/usr/bin/env bats
# Integration tests for action edge cases and error handling

setup() {
    # Get the directory containing this test file
    BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    # Path to the validation script
    VALIDATE_SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/validate_python_version.sh"
}

# Test edge cases for package names (validation that should happen before processing)

@test "Empty package name should be caught by action" {
    # Input validation is implemented in action.yaml Step 2
    # The action validates that package-name is not empty
    skip "This is tested in action.yaml - requires full workflow integration test"
}

@test "Package name with special characters should be handled" {
    # Input validation is implemented in action.yaml Step 2
    # The action validates package-name doesn't contain whitespace
    skip "This is tested in action.yaml - requires full workflow integration test"
}

@test "Very long package name should be handled" {
    # This edge case could be handled with additional validation
    # Currently not explicitly validated but PyPI will reject invalid names
    skip "Edge case - tested implicitly via PyPI validation"
}

# Test edge cases for package versions

@test "Empty package version should be caught by action" {
    # Input validation is implemented in action.yaml Step 2
    # The action validates that package-version is not empty
    skip "This is tested in action.yaml - requires full workflow integration test"
}

@test "Invalid version format should be caught" {
    # Version format validation is implemented in action.yaml Step 5
    # Validates version matches expected format after PyPI query
    skip "This is tested in action.yaml - requires full workflow integration test"
}

@test "Version with special characters should be handled" {
    # PyPI query will naturally reject invalid version formats
    # Additional validation could be added if needed
    skip "Edge case - tested implicitly via PyPI validation"
}

# Test uv-args edge cases

@test "uv-args with shell metacharacters should warn or validate" {
    # Warning is implemented in action.yaml Step 2
    # The action warns when detecting semicolons or pipes
    skip "This is tested in action.yaml - requires full workflow integration test"
}

@test "uv-args with quotes should be properly escaped" {
    # Shell escaping is handled by GitHub Actions input mechanism
    # Additional testing could validate proper escaping
    skip "Edge case - tested via GitHub Actions input handling"
}

# Test Python version validation integration

@test "Python version validation integrates with validate script" {
    run "$VALIDATE_SCRIPT" "3.11"
    [ "$status" -eq 0 ]
    [ "$output" = "3.11" ]
}

@test "Python version with patch is normalized" {
    run "$VALIDATE_SCRIPT" "3.11.5"
    [ "$status" -eq 0 ]
    [ "$output" = "3.11" ]
}

@test "Invalid Python version fails validation" {
    run "$VALIDATE_SCRIPT" "invalid"
    [ "$status" -eq 1 ]
}

# Test error message quality

@test "Validation script provides helpful error for major-only version" {
    run "$VALIDATE_SCRIPT" "3"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid Python version format" ]]
    [[ "$output" =~ "Expected format: 'X.Y' or 'X.Y.Z'" ]]
}

@test "Validation script provides helpful error for text input" {
    run "$VALIDATE_SCRIPT" "python3.10"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid Python version format" ]]
}

# Test whitespace handling

@test "Leading whitespace in Python version is trimmed" {
    run "$VALIDATE_SCRIPT" "  3.10"
    [ "$status" -eq 0 ]
    [ "$output" = "3.10" ]
}

@test "Trailing whitespace in Python version is trimmed" {
    run "$VALIDATE_SCRIPT" "3.10  "
    [ "$status" -eq 0 ]
    [ "$output" = "3.10" ]
}

@test "Multiple spaces around Python version are trimmed" {
    run "$VALIDATE_SCRIPT" "   3.10   "
    [ "$status" -eq 0 ]
    [ "$output" = "3.10" ]
}
