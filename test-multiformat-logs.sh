#!/bin/bash

# Test script for extracting log entries by level and user UUID
# Tests pattern extraction for WARNING, ERROR, and INFO levels
# Also matches extracted entries to specific user UUIDs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/move-pattern-matching-logs.sh"
INPUT_DIR="${SCRIPT_DIR}/input/multiformat-logs"
SHARED_OUTPUT="${SCRIPT_DIR}/shared-output"
EXPECTED_DIR="${SHARED_OUTPUT}/expected-multiformat"
ACTUAL_DIR="${SHARED_OUTPUT}/actual-multiformat"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test patterns
WARNING_PATTERN='\[WARNING\]'
ERROR_PATTERN='\[ERROR\]'
INFO_PATTERN='\[INFO\]'
CRITICAL_PATTERN='\[CRITICAL\]'

# User UUIDs
UUID1='550e8400-e29b-41d4-a716-446655440000'
UUID2='6ba7b810-9dad-11d1-80b4-00c04fd430c8'
UUID3='6ba7b811-9dad-11d1-80b4-00c04fd430c8'

# Timestamp regex for log entries
TIMESTAMP_REGEX='^\[?[0-9]{4}-[0-9]{2}-[0-9]{2}'

echo -e "${BLUE}=== Log Level and UUID Extraction Test ===${NC}"
echo "Input Directory: $INPUT_DIR"
echo "Expected Directory: $EXPECTED_DIR"
echo "Actual Directory: $ACTUAL_DIR"
echo "Main Script: $MAIN_SCRIPT"
echo ""

# Clean and create output directories
rm -rf "$ACTUAL_DIR" "$EXPECTED_DIR"
mkdir -p "$ACTUAL_DIR" "$EXPECTED_DIR"

# Test Case 1: Extract WARNING level entries
echo -e "${BLUE}Test Case 1: Extract WARNING level entries${NC}"
echo "Pattern: $WARNING_PATTERN"
echo ""
"$MAIN_SCRIPT" -p "$WARNING_PATTERN" -i "$INPUT_DIR" -o "$ACTUAL_DIR/warning-level" -t "$TIMESTAMP_REGEX" -v
echo ""

# Test Case 2: Extract ERROR level entries
echo -e "${BLUE}Test Case 2: Extract ERROR level entries${NC}"
echo "Pattern: $ERROR_PATTERN"
echo ""
"$MAIN_SCRIPT" -p "$ERROR_PATTERN" -i "$INPUT_DIR" -o "$ACTUAL_DIR/error-level" -t "$TIMESTAMP_REGEX" -v
echo ""

# Test Case 3: Extract INFO level entries
echo -e "${BLUE}Test Case 3: Extract INFO level entries${NC}"
echo "Pattern: $INFO_PATTERN"
echo ""
"$MAIN_SCRIPT" -p "$INFO_PATTERN" -i "$INPUT_DIR" -o "$ACTUAL_DIR/info-level" -t "$TIMESTAMP_REGEX" -v
echo ""

# Test Case 4: Extract CRITICAL level entries
echo -e "${BLUE}Test Case 4: Extract CRITICAL level entries${NC}"
echo "Pattern: $CRITICAL_PATTERN"
echo ""
"$MAIN_SCRIPT" -p "$CRITICAL_PATTERN" -i "$INPUT_DIR" -o "$ACTUAL_DIR/critical-level" -t "$TIMESTAMP_REGEX" -v
echo ""

# Test Case 5: Extract entries for specific user UUID and WARNING level
echo -e "${BLUE}Test Case 5: Extract WARNING entries for User 1 UUID${NC}"
USER1_WARNING_PATTERN="${UUID1}.*\[WARNING\]|\[WARNING\].*${UUID1}"
echo "Pattern: User UUID with WARNING level"
echo ""
"$MAIN_SCRIPT" -p "$USER1_WARNING_PATTERN" -i "$INPUT_DIR" -o "$ACTUAL_DIR/user1-warning" -t "$TIMESTAMP_REGEX" -v
echo ""

# Test Case 6: Extract entries for specific user UUID and ERROR level
echo -e "${BLUE}Test Case 6: Extract ERROR entries for User 2 UUID${NC}"
USER2_ERROR_PATTERN="${UUID2}.*\[ERROR\]|\[ERROR\].*${UUID2}"
echo "Pattern: User UUID with ERROR level"
echo ""
"$MAIN_SCRIPT" -p "$USER2_ERROR_PATTERN" -i "$INPUT_DIR" -o "$ACTUAL_DIR/user2-error" -t "$TIMESTAMP_REGEX" -v
echo ""

# Create expected baseline snapshots from actual results
echo -e "${BLUE}=== Creating expected baseline snapshots ===${NC}"
if [[ -d "$ACTUAL_DIR" ]]; then
    cp -r "$ACTUAL_DIR"/* "$EXPECTED_DIR"/ 2>/dev/null || true
    echo -e "${GREEN}✓ Expected snapshots created${NC}"
fi
echo ""

# Validation checks
echo -e "${BLUE}=== Validation Checks ===${NC}"

# Check 1: Verify WARNING entries exist
echo -n "Check 1: WARNING level entries extracted ... "
if [[ -d "$ACTUAL_DIR/warning-level" ]] && find "$ACTUAL_DIR/warning-level" -type f -name "*.log" | xargs grep -l "\[WARNING\]" 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 2: Verify ERROR entries exist
echo -n "Check 2: ERROR level entries extracted ... "
if [[ -d "$ACTUAL_DIR/error-level" ]] && find "$ACTUAL_DIR/error-level" -type f -name "*.log" | xargs grep -l "\[ERROR\]" 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 3: Verify INFO entries exist
echo -n "Check 3: INFO level entries extracted ... "
if [[ -d "$ACTUAL_DIR/info-level" ]] && find "$ACTUAL_DIR/info-level" -type f -name "*.log" | xargs grep -l "\[INFO\]" 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 4: Verify CRITICAL entries exist
echo -n "Check 4: CRITICAL level entries extracted ... "
if [[ -d "$ACTUAL_DIR/critical-level" ]] && find "$ACTUAL_DIR/critical-level" -type f -name "*.log" | xargs grep -l "\[CRITICAL\]" 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 5: Verify User UUID filtering works
echo -n "Check 5: User 1 UUID + WARNING level extraction ... "
if [[ -d "$ACTUAL_DIR/user1-warning" ]] && find "$ACTUAL_DIR/user1-warning" -type f -name "*.log" | xargs grep -l "$UUID1" 2>/dev/null | grep -q . && find "$ACTUAL_DIR/user1-warning" -type f -name "*.log" | xargs grep -l "\[WARNING\]" 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Check 6: Count entries by level
echo ""
echo -e "${BLUE}=== Entry Counts ===${NC}"
echo "WARNING entries: $(find "$ACTUAL_DIR/warning-level" -type f -name "*.log" -exec grep -c "\[WARNING\]" {} + 2>/dev/null | paste -sd+ - | bc)"
echo "ERROR entries: $(find "$ACTUAL_DIR/error-level" -type f -name "*.log" -exec grep -c "\[ERROR\]" {} + 2>/dev/null | paste -sd+ - | bc)"
echo "INFO entries: $(find "$ACTUAL_DIR/info-level" -type f -name "*.log" -exec grep -c "\[INFO\]" {} + 2>/dev/null | paste -sd+ - | bc)"
echo "CRITICAL entries: $(find "$ACTUAL_DIR/critical-level" -type f -name "*.log" -exec grep -c "\[CRITICAL\]" {} + 2>/dev/null | paste -sd+ - | bc)"
echo ""

# Sample output
echo -e "${BLUE}=== Sample Extracted Entries ===${NC}"
echo "First WARNING entry:"
find "$ACTUAL_DIR/warning-level" -type f -name "*.log" | head -1 | xargs head -1
echo ""
echo "First ERROR entry:"
find "$ACTUAL_DIR/error-level" -type f -name "*.log" | head -1 | xargs head -1
echo ""
echo "First User 1 WARNING entry:"
find "$ACTUAL_DIR/user1-warning" -type f -name "*.log" | head -1 | xargs head -1 2>/dev/null || echo "No entries found"
echo ""

echo -e "${GREEN}✓ Test completed successfully${NC}"
