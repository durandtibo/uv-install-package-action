#!/bin/bash
# Unit tests for validate_python_version.sh
#
# This script tests the Python version validation and normalization logic

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="${SCRIPT_DIR}/../../scripts/validate_python_version.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Test helper function
test_validation() {
    local test_name="$1"
    local input_version="$2"
    local expected_output="$3"
    local should_fail="${4:-false}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$should_fail" = "true" ]; then
        # Test should fail (invalid format)
        if output=$("$VALIDATE_SCRIPT" "$input_version" 2>&1); then
            echo -e "${RED}✗ FAILED${NC}: $test_name"
            echo "  Expected: failure"
            echo "  Got: success with output '$output'"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        else
            echo -e "${GREEN}✓ PASSED${NC}: $test_name"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        fi
    else
        # Test should succeed (valid format)
        if output=$("$VALIDATE_SCRIPT" "$input_version" 2>&1); then
            if [ "$output" = "$expected_output" ]; then
                echo -e "${GREEN}✓ PASSED${NC}: $test_name"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                return 0
            else
                echo -e "${RED}✗ FAILED${NC}: $test_name"
                echo "  Expected: '$expected_output'"
                echo "  Got: '$output'"
                FAILED_TESTS=$((FAILED_TESTS + 1))
                return 1
            fi
        else
            echo -e "${RED}✗ FAILED${NC}: $test_name"
            echo "  Expected: success with output '$expected_output'"
            echo "  Got: failure with error: $output"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    fi
}

echo "=========================================="
echo "Unit Tests: validate_python_version.sh"
echo "=========================================="
echo ""

# Test valid Python versions (major.minor format)
echo "Test Group: Valid Python versions (major.minor)"
echo "------------------------------------------------"
test_validation "Python 3.10" "3.10" "3.10"
test_validation "Python 3.11" "3.11" "3.11"
test_validation "Python 3.12" "3.12" "3.12"
test_validation "Python 3.13" "3.13" "3.13"
test_validation "Python 3.14" "3.14" "3.14"
test_validation "Python 3.9" "3.9" "3.9"
echo ""

# Test valid Python versions with patch version (should normalize)
echo "Test Group: Valid Python versions with patch (should normalize)"
echo "----------------------------------------------------------------"
test_validation "Python 3.10.1" "3.10.1" "3.10"
test_validation "Python 3.11.5" "3.11.5" "3.11"
test_validation "Python 3.12.0" "3.12.0" "3.12"
test_validation "Python 3.9.18" "3.9.18" "3.9"
test_validation "Python 3.13.999" "3.13.999" "3.13"
echo ""

# Test edge cases
echo "Test Group: Edge cases"
echo "----------------------"
test_validation "Whitespace trimming" "  3.10  " "3.10"
test_validation "Future Python 11.2" "11.2" "11.2"
test_validation "High minor version" "3.100" "3.100"
test_validation "High major version" "20.5" "20.5"
test_validation "Double digit versions" "10.15" "10.15"
echo ""

# Test invalid formats (should fail)
echo "Test Group: Invalid formats (should fail)"
echo "------------------------------------------"
test_validation "Major version only" "3" "" "true"
test_validation "Too many version parts" "3.10.1.2" "" "true"
test_validation "Invalid prefix" "python3.10" "" "true"
test_validation "Non-numeric minor" "3.x" "" "true"
test_validation "Non-numeric major" "x.10" "" "true"
test_validation "Empty string" "" "" "true"
test_validation "Alphabetic" "abc" "" "true"
test_validation "Only dots" "..." "" "true"
test_validation "Leading dot" ".3.10" "" "true"
test_validation "Trailing dot" "3.10." "" "true"
test_validation "Negative numbers" "-3.10" "" "true"
test_validation "Decimal version" "3.10.5.2" "" "true"
echo ""

# Print summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
else
    echo -e "Failed: $FAILED_TESTS"
fi
echo "=========================================="

# Exit with appropriate code
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
