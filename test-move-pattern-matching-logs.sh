#!/bin/bash

# Test script for move-pattern-matching-logs.sh
# Extracts log entries containing social security numbers and phone numbers
# Compares results with expected outputs using MD5 checksums

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/move-pattern-matching-logs.sh"
INPUT_DIR="${SCRIPT_DIR}/input/crud-logs"
SHARED_OUTPUT="${SCRIPT_DIR}/shared-output"
EXPECTED_DIR="${SHARED_OUTPUT}/expected"
ACTUAL_DIR="${SHARED_OUTPUT}/actual"
TEST_NAME="SSN and Phone Number Extraction"

# Patterns
SSN_PATTERN="[0-9]{3}-[0-9]{2}-[0-9]{4}"
PHONE_PATTERN="[+][0-9]{6,}|\([0-9]{3}\)[[:space:]][0-9]{3}-[0-9]{4}|[0-9]{3}-[0-9]{3}-[0-9]{4}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create output directories
mkdir -p "${ACTUAL_DIR}"

# Clean actual directory before running tests (remove old results)
rm -rf "${ACTUAL_DIR:?}"/* 2>/dev/null || true

echo -e "${BLUE}=== ${TEST_NAME} ===${NC}"
echo "Input Directory: ${INPUT_DIR}"
echo "Expected Directory: ${EXPECTED_DIR}"
echo "Actual Directory: ${ACTUAL_DIR}"
echo "Main Script: ${MAIN_SCRIPT}"
echo ""

# Verify main script exists
if [[ ! -f "${MAIN_SCRIPT}" ]]; then
    echo -e "${RED}ERROR: Main script not found: ${MAIN_SCRIPT}${NC}"
    exit 1
fi

# Verify input directory exists
if [[ ! -d "${INPUT_DIR}" ]]; then
    echo -e "${RED}ERROR: Input directory not found: ${INPUT_DIR}${NC}"
    exit 1
fi

# Test Case 1: Extract entries with SSN
echo -e "${YELLOW}Test Case 1: Extract entries containing SSN (${SSN_PATTERN})${NC}"

"${MAIN_SCRIPT}" \
    -p "${SSN_PATTERN}" \
    -i "${INPUT_DIR}" \
    -o "${ACTUAL_DIR}/ssn-patterns" \
    -v 2>&1 | tee "${ACTUAL_DIR}/ssn-test.log" || true

echo ""

# Test Case 2: Extract entries with phone numbers
echo -e "${YELLOW}Test Case 2: Extract entries containing phone numbers${NC}"

"${MAIN_SCRIPT}" \
    -p "${PHONE_PATTERN}" \
    -i "${INPUT_DIR}" \
    -o "${ACTUAL_DIR}/phone-patterns" \
    -v 2>&1 | tee "${ACTUAL_DIR}/phone-test.log" || true

echo ""

# Test Case 3: Combined pattern (SSN OR phone)
echo -e "${YELLOW}Test Case 3: Extract entries containing SSN OR phone numbers${NC}"
COMBINED_PATTERN="${SSN_PATTERN}|${PHONE_PATTERN}"

"${MAIN_SCRIPT}" \
    -p "${COMBINED_PATTERN}" \
    -i "${INPUT_DIR}" \
    -o "${ACTUAL_DIR}/combined-patterns" \
    -v 2>&1 | tee "${ACTUAL_DIR}/combined-test.log" || true

echo ""

# Check if this is first run - if expected doesn't exist or is empty, create it from actual
if [[ ! -d "${EXPECTED_DIR}" ]] || [[ -z "$(ls -A ${EXPECTED_DIR} 2>/dev/null)" ]]; then
    echo -e "${YELLOW}First run detected: Creating expected snapshots from actual results...${NC}"
    mkdir -p "${EXPECTED_DIR}"
    
    # Copy all files from actual to expected
    if [[ -d "${ACTUAL_DIR}" ]]; then
        cp -r "${ACTUAL_DIR}"/* "${EXPECTED_DIR}/" 2>/dev/null || true
        echo -e "${GREEN}✓ Expected snapshots created at: ${EXPECTED_DIR}${NC}"
        echo -e "${YELLOW}Note: On next run, actual results will be compared with these expected snapshots${NC}"
    fi
    echo ""
fi

# Compare folder structures
echo -e "${BLUE}=== Folder Structure Comparison ===${NC}"
if [[ -d "${EXPECTED_DIR}" ]]; then
    STRUCT_PASS=0
    STRUCT_FAIL=0
    
    # Get list of all files in expected (relative paths), excluding *-test.log files
    expected_files=$(cd "${EXPECTED_DIR}" && find . -type f ! -name '*-test.log' | sort)
    actual_files=$(cd "${ACTUAL_DIR}" && find . -type f ! -name '*-test.log' | sort)
    
    echo "Expected files:"
    echo "$expected_files" | sed 's/^/  /'
    echo ""
    echo "Actual files:"
    echo "$actual_files" | sed 's/^/  /'
    echo ""
    
    # Compare structures
    if [[ "$expected_files" == "$actual_files" ]]; then
        echo -e "${GREEN}✓ Folder structures are IDENTICAL${NC}"
        STRUCT_PASS=1
    else
        echo -e "${RED}✗ Folder structures DIFFER${NC}"
        STRUCT_FAIL=1
        
        # Show files only in expected
        comm -23 <(echo "$expected_files") <(echo "$actual_files") > /tmp/only_expected.txt
        if [[ -s /tmp/only_expected.txt ]]; then
            echo -e "${YELLOW}Files only in expected:${NC}"
            cat /tmp/only_expected.txt | sed 's/^/  /'
        fi
        
        # Show files only in actual
        comm -13 <(echo "$expected_files") <(echo "$actual_files") > /tmp/only_actual.txt
        if [[ -s /tmp/only_actual.txt ]]; then
            echo -e "${YELLOW}Files only in actual:${NC}"
            cat /tmp/only_actual.txt | sed 's/^/  /'
        fi
    fi
    echo ""
else
    echo -e "${YELLOW}⊘ No expected directory found. Skipping structure comparison.${NC}"
    echo ""
fi

# MD5 Comparison Function
compare_md5_sums() {
    local expected_file="$1"
    local actual_file="$2"
    
    if [[ ! -f "$expected_file" ]]; then
        echo -e "${YELLOW}⊘ Expected file not found: $expected_file${NC}"
        return 2
    fi
    
    if [[ ! -f "$actual_file" ]]; then
        echo -e "${RED}✗ Actual file not found: $actual_file${NC}"
        return 1
    fi
    
    local expected_md5=$(md5sum "$expected_file" | awk '{print $1}')
    local actual_md5=$(md5sum "$actual_file" | awk '{print $1}')
    
    if [[ "$expected_md5" == "$actual_md5" ]]; then
        echo -e "${GREEN}✓ MATCH${NC} (MD5: $expected_md5)"
        return 0
    else
        echo -e "${RED}✗ MISMATCH${NC}"
        echo "  Expected MD5: $expected_md5"
        echo "  Actual MD5:   $actual_md5"
        return 1
    fi
}

# Compare MD5 sums
echo -e "${BLUE}=== MD5 Checksum Comparison ===${NC}"
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Find all expected files and compare with actual
if [[ -d "${EXPECTED_DIR}" ]]; then
    # Store file list in array to avoid process substitution issues
    # Exclude *-test.log files as they contain run-specific timestamps
    mapfile -t expected_files < <(find "${EXPECTED_DIR}" -type f ! -name '*-test.log')
    
    for expected_file in "${expected_files[@]}"; do
        # Get relative path from expected directory
        rel_path="${expected_file#${EXPECTED_DIR}/}"
        actual_file="${ACTUAL_DIR}/${rel_path}"
        
        echo -n "Comparing: $rel_path ... "
        if compare_md5_sums "$expected_file" "$actual_file"; then
            ((PASS_COUNT++)) || true
        else
            ((FAIL_COUNT++)) || true
        fi
    done
else
    echo -e "${YELLOW}⊘ No expected directory found. Skipping comparison.${NC}"
    SKIP_COUNT=1
fi

echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo -e "Structure Check: $([ ${STRUCT_PASS:-0} -eq 1 ] && echo -e "${GREEN}PASSED${NC}" || echo -e "${RED}FAILED${NC}")"
echo -e "MD5 Passed: ${GREEN}${PASS_COUNT}${NC}"
echo -e "MD5 Failed: ${RED}${FAIL_COUNT}${NC}"
echo -e "MD5 Skipped: ${YELLOW}${SKIP_COUNT}${NC}"
echo ""

if [[ ${FAIL_COUNT} -eq 0 ]] && [[ ${PASS_COUNT} -gt 0 ]] && [[ ${STRUCT_FAIL:-0} -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests PASSED (structure + content)${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests FAILED${NC}"
    exit 1
fi
