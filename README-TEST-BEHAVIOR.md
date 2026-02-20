# Test Script Behavior - First Run vs Subsequent Runs

## Modified Test Script: test-move-pattern-matching-logs.sh

### First Run Behavior

When you run the test for the **first time**:

1. **Extract patterns** from input files (using move-pattern-matching-logs.sh)
   - Test Case 1: SSN Pattern → `shared-output/actual/ssn-patterns/`
   - Test Case 2: Phone Pattern → `shared-output/actual/phone-patterns/`
   - Test Case 3: Combined Pattern → `shared-output/actual/combined-patterns/`

2. **Check if expected directory exists**
   ```bash
   if [[ ! -d "${EXPECTED_DIR}" ]]; then
   ```

3. **First run: Create expected snapshots**
   ```
   First run detected: Creating expected snapshots from actual results...
   ✓ Expected snapshots created at: shared-output/expected
   Note: On next run, actual results will be compared with these expected snapshots
   ```
   - Copies all extracted results from `actual/` to `expected/`
   - These become the baseline for future comparisons

### Subsequent Run Behavior

When you run the test **again** (after first run):

1. **Extract patterns** from input files (same as before)
   - Results go to `shared-output/actual/`

2. **Check if expected directory exists**
   ```bash
   if [[ ! -d "${EXPECTED_DIR}" ]]; then
   ```
   - This time, expected directory EXISTS, so skip creation

3. **Compare MD5 checksums**
   ```
   === MD5 Checksum Comparison ===
   Comparing: ssn-patterns/app.log ... ✓ MATCH (MD5: abc123...)
   Comparing: ssn-patterns/audit.log ... ✓ MATCH (MD5: def456...)
   ...
   === Test Summary ===
   Passed: 6
   Failed: 0
   Skipped: 0
   
   ✓ All tests PASSED
   ```
   - Compares actual results with expected using MD5
   - Shows which tests pass and fail

---

## How to Use

### Run the Test
```bash
./test-move-pattern-matching-logs.sh
```

### First Run (Will create expected snapshots)
```
=== SSN and Phone Number Extraction ===
...
First run detected: Creating expected snapshots from actual results...
✓ Expected snapshots created at: shared-output/expected
Note: On next run, actual results will be compared with these expected snapshots

=== MD5 Checksum Comparison ===
Comparing: combined-patterns/app.log ... ✓ MATCH
Comparing: combined-patterns/audit.log ... ✓ MATCH
Comparing: combined-patterns/combined-test.log ... ✓ MATCH
Comparing: phone-patterns/app.log ... ✓ MATCH
Comparing: phone-patterns/audit.log ... ✓ MATCH
Comparing: phone-patterns/phone-test.log ... ✓ MATCH
Comparing: ssn-patterns/app.log ... ✓ MATCH
Comparing: ssn-patterns/audit.log ... ✓ MATCH
Comparing: ssn-patterns/ssn-test.log ... ✓ MATCH

=== Test Summary ===
Passed: 9
Failed: 0
Skipped: 0

✓ All tests PASSED
```

### Second Run (Will compare against expected)
```
=== SSN and Phone Number Extraction ===
...
[No "First run detected" message - expected directory already exists]

=== MD5 Checksum Comparison ===
Comparing: combined-patterns/app.log ... ✓ MATCH
Comparing: combined-patterns/audit.log ... ✓ MATCH
...
=== Test Summary ===
Passed: 9
Failed: 0
Skipped: 0

✓ All tests PASSED
```

---

## Archive Extraction Testing

The same test script processes **both**:
- ✓ **Regular files** (app.log, audit.log)
- ✓ **Archive files** (app.zip, app.tar, app.tar.gz if present)

All extracted results are compared with MD5 to ensure consistency.

---

## Test Files Generated

### Actual Directory (`shared-output/actual/`)
- Generated fresh each test run
- Contains extraction results
- Gets compared with expected

### Expected Directory (`shared-output/expected/`)
- Created on first run from actual results
- Baseline for future comparisons
- Used for MD5 validation

### Both Contain
```
expected/
├── ssn-patterns/
│   ├── app.log
│   └── audit.log
├── phone-patterns/
│   ├── app.log
│   └── audit.log
├── combined-patterns/
│   ├── app.log
│   └── audit.log
├── ssn-test.log
├── phone-test.log
└── combined-test.log
```

---

## Validation with MD5

Each run compares files byte-for-byte using MD5:
- **MATCH** → File content is identical (test passed)
- **MISMATCH** → File content differs (test failed)
- **File not found** → File missing (test skipped)

---

## Reset Test Baseline

If you want to **reset the expected baseline**:

```bash
# Remove the expected directory
rm -rf shared-output/expected/

# Next test run will create new expected snapshots
./test-move-pattern-matching-logs.sh
```

This will use the current execution as the new baseline for future comparisons.
