# Pattern Matching Log Extraction - Testing Guide

## Overview

This project provides a bash script for extracting complete log entries that match specific patterns (SSN, phone numbers, etc.) from log files and archives. A comprehensive Docker-based test suite validates the extraction functionality.

## Prerequisites

- **Docker** - For containerized testing environment
- **Docker Compose** - For orchestrating test containers
- **Bash** - Required for running scripts
- **Standard Unix utilities** - `grep`, `sed`, `awk`, etc.

## Quick Start

### 1. Start the Test Environment

```bash
docker-compose up -d
```

This starts a containerized Ubuntu environment with SSH access and all necessary tools pre-installed.

### 2. Run the Tests

```bash
docker exec pattern-test bash /home/sshuser/test-move-pattern-matching-logs.sh
```

### 3. View Results

Test results are stored in `./shared-output/actual/` with subdirectories for each pattern type:

- `ssn-patterns/` - Extracted SSN entries
- `phone-patterns/` - Extracted phone number entries  
- `combined-patterns/` - Entries matching either SSN or phone

### 4. Stop the Test Environment

```bash
docker-compose down
```

## Test Cases

The test suite runs three comprehensive test cases:

### Test Case 1: SSN Extraction

**Pattern:** `[0-9]{3}-[0-9]{2}-[0-9]{4}`

Extracts complete log entries containing U.S. Social Security numbers in format `XXX-XX-XXXX`.

**Expected Output Files:**

- `actual/ssn-patterns/app.log` - Entries from app.log
- `actual/ssn-patterns/audit.log` - Entries from audit.log

### Test Case 2: Phone Number Extraction

**Pattern:** `[+][0-9]{6,}|\([0-9]{3}\)[[:space:]][0-9]{3}-[0-9]{4}|[0-9]{3}-[0-9]{3}-[0-9]{4}`

Extracts complete log entries containing phone numbers in three formats:

- International: `+358401234567` (plus sign followed by 6+ digits)
- US Parentheses: `(555) 123-4567`
- US Dashes: `555-234-5678`

**Expected Output Files:**

- `actual/phone-patterns/app.log` - Entries from app.log
- `actual/phone-patterns/audit.log` - Entries from audit.log

### Test Case 3: Combined Pattern Extraction

**Pattern:** `[0-9]{3}-[0-9]{2}-[0-9]{4}|[+][0-9]{6,}|\([0-9]{3}\)[[:space:]][0-9]{3}-[0-9]{4}|[0-9]{3}-[0-9]{3}-[0-9]{4}`

Extracts entries matching either SSN OR phone number patterns.

**Expected Output Files:**

- `actual/combined-patterns/app.log` - Entries from app.log
- `actual/combined-patterns/audit.log` - Entries from audit.log

## Understanding Test Results

### MD5 Checksum Verification

Each test file is compared against a baseline using MD5 checksums:

```
=== MD5 Checksum Comparison ===
Comparing: combined-patterns/app.log ... ✓ MATCH (MD5: 5592260e34cf6d9f0e5a3b1f13cc03ba)
```

**What this means:**

- **✓ MATCH** - Actual output matches expected baseline (test passed)
- **✗ MISMATCH** - Actual output differs from baseline (test failed)

### Test Summary

```
=== Test Summary ===
Passed: 6
Failed: 0
Skipped: 0

✓ All tests PASSED
```

- **Passed** - Number of test files with matching MD5 checksums
- **Failed** - Number of test files with mismatching checksums
- **Skipped** - Number of tests that couldn't run (missing files, etc.)

## Directory Structure

```
ubuntu-bash/
├── move-pattern-matching-logs.sh          # Main extraction script
├── test-move-pattern-matching-logs.sh     # Test runner script
├── docker-compose.yml                     # Docker Compose configuration
├── Dockerfile                             # Container image definition
├── input/
│   └── crud-logs/
│       ├── app.log                        # Test data with SSN, US phones, intl phone
│       └── audit.log                      # Test data with SSN and US phones
├── shared-output/
│   ├── expected/                          # Baseline/expected test results
│   │   ├── ssn-patterns/
│   │   │   ├── app.log
│   │   │   └── audit.log
│   │   ├── phone-patterns/
│   │   │   ├── app.log
│   │   │   └── audit.log
│   │   └── combined-patterns/
│   │       ├── app.log
│   │       └── audit.log
│   └── actual/                            # Actual test results (generated)
│       ├── ssn-patterns/
│       ├── phone-patterns/
│       └── combined-patterns/
└── README-TESTING.md                      # This file
```

## Using the Main Script

### Basic Usage

```bash
./move-pattern-matching-logs.sh -p PATTERN -i INPUT_DIR [-o OUTPUT_DIR]
```

### Examples

**Extract SSN entries:**

```bash
./move-pattern-matching-logs.sh \
  -p "[0-9]{3}-[0-9]{2}-[0-9]{4}" \
  -i ./input/crud-logs \
  -o ./output/ssn-results
```

**Extract phone entries:**

```bash
./move-pattern-matching-logs.sh \
  -p "[+][0-9]{6,}|\([0-9]{3}\)[[:space:]][0-9]{3}-[0-9]{4}|[0-9]{3}-[0-9]{3}-[0-9]{4}" \
  -i ./input/crud-logs \
  -o ./output/phone-results
```

**Combine multiple patterns:**

```bash
./move-pattern-matching-logs.sh \
  -p "[0-9]{3}-[0-9]{2}-[0-9]{4}" \
  -p "[0-9]{3}-[0-9]{3}-[0-9]{4}" \
  -i ./input/crud-logs \
  -o ./output/combined-results
```

**Enable verbose output:**

```bash
./move-pattern-matching-logs.sh \
  -p "ERROR" \
  -i ./logs \
  -v
```

### Command-Line Options

```
-p PATTERN           Pattern to search for (regex, can be used multiple times)
-i INPUT_DIR         Input directory to search in (REQUIRED)
-o OUTPUT_DIR        Output directory for results (default: INPUT_DIR/matched)
-t TIMESTAMP_REGEX   Regex to identify log entry start
                     (default: ^\[?[0-9]{4}-[0-9]{2}-[0-9]{2})
-v                   Verbose output (shows skipped files)
-h                   Display help message
```

## Test Data Format

The test input files contain CRUD log entries with the following format:

```
YYYY-MM-DD HH:MM:SS.milliseconds OPERATION key=value key=value...
```

**Example entries:**

```
2024-01-15 08:30:45.123 CREATE user id=1 name=John Doe email=john@example.com ssn=123-45-6789
2024-01-15 08:32:20.789 UPDATE user id=1 {"name":"John Smith","phone":"(555) 123-4567"}
2024-01-15 10:48:55.456 DELETE product id=501
+358401234567
```

The script extracts complete entries from the timestamp of the matching line through the timestamp of the next entry (or end of file).

## Supported Archive Formats

The main script automatically detects and processes:

- **ZIP** - `.zip` files using `zipgrep`
- **GZIP** - `.gz` files using `zgrep`
- **TAR** - `.tar` files using `tar` + `grep`
- **TAR.GZ** - `.tar.gz` or `.tgz` files using `tar` + `grep`
- **Uncompressed** - Regular log files using `grep`

Archive detection is MIME-type based (via `file -b --mime-type`).

## Troubleshooting

### Container Won't Start

```bash
# Check if container is already running
docker ps -a

# Remove stale containers
docker-compose down
docker container prune

# Rebuild image
docker-compose up --build
```

### Tests Show "MISMATCH"

This typically means the extraction results differ from the baseline:

1. **Check actual output:**

   ```bash
   cat shared-output/actual/phone-patterns/app.log
   ```

2. **Compare with expected:**

   ```bash
   cat shared-output/expected/phone-patterns/app.log
   ```

3. **Generate new baseline** (if changes are correct):

   ```bash
   docker exec pattern-test bash -c \
     "cp shared-output/actual/* shared-output/expected/ -r"
   ```

### Pattern Not Matching

Test the pattern directly in the container:

```bash
docker exec pattern-test bash -c \
  "grep -nE 'YOUR_PATTERN' /home/sshuser/input/crud-logs/app.log"
```

**Remember:** Bash extended regex patterns use:

- Character classes: `[0-9]`, `[a-z]`, `[[:space:]]`
- Quantifiers: `+` (1 or more), `*` (0 or more), `{n,m}` (range)
- Alternation: `|` (OR operator)

### Extended Regex Not Working

Ensure scripts use the `-E` flag with grep:

```bash
grep -E "pattern" file    # ✓ Extended regex enabled
grep "pattern" file        # ✗ Basic regex only
```

## Advanced Usage

### Running Individual Test Cases Manually

```bash
# Test only SSN extraction
docker exec pattern-test bash -c \
  "/home/sshuser/move-pattern-matching-logs.sh \
   -p '[0-9]{3}-[0-9]{2}-[0-9]{4}' \
   -i /home/sshuser/input/crud-logs \
   -o /home/sshuser/shared-output/actual/ssn-patterns -v"
```

### Debugging with Line Numbers

Verbose output shows which lines are extracted:

```
✓ Extracted 3 lines [Lines: 3/26 - 11%] to: app.log
  ↳ Lines 1-1 from: /home/sshuser/input/crud-logs/app.log
  ↳ Lines 3-3 from: /home/sshuser/input/crud-logs/app.log
  ↳ Lines 5-5 from: /home/sshuser/input/crud-logs/app.log
```

This shows which input lines matched the pattern.

### Interactive Testing in Container

```bash
# Open shell in running container
docker exec -it pattern-test bash

# Inside container, you can now test interactively
grep -nE "[0-9]{3}-[0-9]{2}-[0-9]{4}" /home/sshuser/input/crud-logs/app.log
```

## Performance Notes

- **Large files:** Processing time scales linearly with file size
- **Many patterns:** Multiple `-p` flags increase processing time
- **Verbose mode:** `-v` adds line extraction logging (slight overhead)
- **Archives:** Compressed files are extracted to memory (faster than disk)

## Known Limitations

1. **Binary files:** Script assumes text-based log files
2. **Encoding:** Best results with UTF-8 encoded files
3. **Newlines:** Log entries should end with newlines for proper line counting
4. **Custom timestamps:** Requires `-t` flag if logs use non-standard timestamp format

## Test Validation Checklist

- [ ] Docker containers start without errors
- [ ] All 3 test cases execute successfully
- [ ] MD5 checksums show "MATCH" for all files
- [ ] Test summary shows 6 PASSED, 0 FAILED
- [ ] International phone number `+358401234567` appears in phone-patterns output
- [ ] SSN entries correctly extracted
- [ ] Combined pattern includes both SSN and phone entries

## Exit Codes

- **0** - All tests passed
- **1** - One or more tests failed

## Further Reading

See [move-pattern-matching-logs.sh](move-pattern-matching-logs.sh) for detailed source code and inline documentation.

---

**Last Updated:** February 20, 2026
