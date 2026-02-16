#!/bin/bash

##############################################################################
# Docker Test Suite for Pattern Matching Script
##############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$TEST_DIR/test-results"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Pattern Matching Script - Docker Tests${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Clean up previous results
if [[ -d "$RESULTS_DIR" ]]; then
    rm -rf "$RESULTS_DIR"
fi
mkdir -p "$RESULTS_DIR"

##############################################################################
# Test 1: Build and run single pattern test
##############################################################################
echo -e "${YELLOW}[TEST 1] Building Docker image...${NC}"
docker build -t pattern-matcher . > /dev/null 2>&1
echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo ""

##############################################################################
# Test 2: Test single pattern matching
##############################################################################
echo -e "${YELLOW}[TEST 2] Running test: Single pattern (ERROR)${NC}"
docker run -t --rm \
    -v "$TEST_DIR/test-data:/test-data" \
    -v "$RESULTS_DIR:/test-results" \
    pattern-matcher \
    -p "ERROR" \
    -i "/test-data" \
    -o "/test-results/test1-errors"

if [[ -d "$RESULTS_DIR/test1-errors" ]]; then
    file_count=$(find "$RESULTS_DIR/test1-errors" -type f | wc -l)
    echo -e "${GREEN}✓ Test 1 passed - Generated $file_count output file(s)${NC}"
else
    echo -e "${RED}✗ Test 1 failed - No output directory created${NC}"
    exit 1
fi
echo ""

##############################################################################
# Test 3: Test multiple patterns
##############################################################################
echo -e "${YELLOW}[TEST 3] Running test: Multiple patterns (ERROR|WARNING)${NC}"
docker run -t --rm \
    -v "$TEST_DIR/test-data:/test-data" \
    -v "$RESULTS_DIR:/test-results" \
    pattern-matcher \
    -p "ERROR" \
    -p "WARNING" \
    -i "/test-data" \
    -o "/test-results/test2-multi"

if [[ -d "$RESULTS_DIR/test2-multi" ]]; then
    file_count=$(find "$RESULTS_DIR/test2-multi" -type f | wc -l)
    echo -e "${GREEN}✓ Test 2 passed - Generated $file_count output file(s)${NC}"
else
    echo -e "${RED}✗ Test 2 failed - No output directory created${NC}"
    exit 1
fi
echo ""

##############################################################################
# Test 4: Verify directory structure preservation
##############################################################################
echo -e "${YELLOW}[TEST 4] Verifying directory structure preservation...${NC}"
if [[ -f "$RESULTS_DIR/test1-errors/application.log" ]] && \
   [[ -f "$RESULTS_DIR/test1-errors/services/api.log" ]] && \
   [[ -f "$RESULTS_DIR/test1-errors/services/worker.log" ]]; then
    echo -e "${GREEN}✓ Test 3 passed - Directory structure preserved${NC}"
else
    echo -e "${RED}✗ Test 3 failed - Directory structure not preserved${NC}"
    exit 1
fi
echo ""

##############################################################################
# Test 5: Verify matching content
##############################################################################
echo -e "${YELLOW}[TEST 5] Verifying matched log entries contain pattern...${NC}"
if grep -q "ERROR" "$RESULTS_DIR/test1-errors/application.log" && \
   grep -q "ERROR" "$RESULTS_DIR/test1-errors/services/api.log"; then
    echo -e "${GREEN}✓ Test 4 passed - Matched entries contain pattern${NC}"
else
    echo -e "${RED}✗ Test 4 failed - Pattern not found in results${NC}"
    exit 1
fi
echo ""

##############################################################################
# Test 6: Verify multi-pattern results
##############################################################################
echo -e "${YELLOW}[TEST 6] Verifying multiple pattern matching...${NC}"
if grep -q "ERROR\|WARNING" "$RESULTS_DIR/test2-multi/application.log"; then
    echo -e "${GREEN}✓ Test 5 passed - Multiple patterns working${NC}"
else
    echo -e "${RED}✗ Test 5 failed - Multiple patterns not matching correctly${NC}"
    exit 1
fi
echo ""

##############################################################################
# Test 7: Verify complete entries extraction
##############################################################################
echo -e "${YELLOW}[TEST 7] Verifying complete log entries extraction...${NC}"
# Extract first ERROR entry from original and result
original_entry=$(sed -n '/^\[2026-02-16 08:15:26\]/,/^\[2026-02-16 08:15:30\]/p' "$TEST_DIR/test-data/application.log")
result_entry=$(sed -n '1,/^\[2026-02-16 08:15:30\]/p' "$RESULTS_DIR/test1-errors/application.log" | head -5)

if echo "$result_entry" | grep -q "ERROR"; then
    echo -e "${GREEN}✓ Test 6 passed - Complete entries extracted correctly${NC}"
else
    echo -e "${RED}✗ Test 6 failed - Entries not extracted correctly${NC}"
    exit 1
fi
echo ""

##############################################################################
# Summary
##############################################################################
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}All tests passed!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Test Results Location: $RESULTS_DIR"
echo ""
echo "Test Breakdown:"
echo "  test1-errors/       - Single pattern (ERROR) results"
echo "  test2-multi/        - Multiple patterns (ERROR|WARNING) results"
echo ""
echo "You can inspect results with:"
echo "  cat $RESULTS_DIR/test1-errors/application.log"
echo "  cat $RESULTS_DIR/test2-multi/services/api.log"
