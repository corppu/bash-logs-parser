# Quick Start - How to Run the Test

## One-Time Setup

### Option A: Using Docker (Recommended)

```bash
# Build and start the Docker container
docker-compose up -d

# Run the test script in the container
docker exec pattern-test bash /home/sshuser/test-move-pattern-matching-logs.sh

# View the test results
docker exec pattern-test ls -la /home/sshuser/shared-output/actual/
docker exec pattern-test ls -la /home/sshuser/shared-output/expected/

# Stop when done
docker-compose down
```

### Option B: Direct Bash (Linux/WSL/Mac)

```bash
# Make sure scripts are executable
chmod +x ./test-move-pattern-matching-logs.sh
chmod +x ./move-pattern-matching-logs.sh

# Run the test
./test-move-pattern-matching-logs.sh
```

---

## What Happens

### First Run
1. Extracts patterns from input log files
2. Creates `shared-output/expected/` with these results as baseline
3. Runs MD5 comparison (all match since just created)

### Second Run
1. Extracts patterns from input log files again
2. Compares new results against the baseline using MD5
3. Shows which tests pass/fail

---

## Test Results Location

```
shared-output/
├── actual/           ← Current test results
│   ├── ssn-patterns/
│   ├── phone-patterns/
│   └── combined-patterns/
└── expected/         ← Baseline for comparison
    ├── ssn-patterns/
    ├── phone-patterns/
    └── combined-patterns/
```

---

## Verifying Archive Extraction Works

The test automatically validates both:
- ✓ Regular files (app.log, audit.log)
- ✓ Archives (app.zip, app.tar, app.tar.gz, etc.)

All results are compared using MD5 checksum to ensure consistency.

---

## Example Output

```
=== SSN and Phone Number Extraction ===
Input Directory: /path/to/input/crud-logs
Expected Directory: /path/to/shared-output/expected
Actual Directory: /path/to/shared-output/actual
Main Script: /path/to/move-pattern-matching-logs.sh

Test Case 1: Extract entries containing SSN ([0-9]{3}-[0-9]{2}-[0-9]{4})
[extraction output...]

Test Case 2: Extract entries containing phone numbers
[extraction output...]

Test Case 3: Extract entries containing SSN OR phone numbers
[extraction output...]

=== MD5 Checksum Comparison ===
Comparing: combined-patterns/app.log ... ✓ MATCH (MD5: 5592260e34cf6d9f...)
Comparing: combined-patterns/audit.log ... ✓ MATCH (MD5: 7812f3a9b2c1e4d5...)
Comparing: phone-patterns/app.log ... ✓ MATCH (MD5: abc123...)
Comparing: phone-patterns/audit.log ... ✓ MATCH (MD5: def456...)
Comparing: ssn-patterns/app.log ... ✓ MATCH (MD5: ghi789...)
Comparing: ssn-patterns/audit.log ... ✓ MATCH (MD5: jkl012...)

=== Test Summary ===
Passed: 6
Failed: 0
Skipped: 0

✓ All tests PASSED
```

---

## If Tests Fail

1. **Check the diffs:**
   ```bash
   diff shared-output/actual/ssn-patterns/app.log \
        shared-output/expected/ssn-patterns/app.log
   ```

2. **Reset baseline** (if changes are intentional):
   ```bash
   rm -rf shared-output/expected/
   ./test-move-pattern-matching-logs.sh  # Creates new baseline
   ```

3. **Verify input files exist:**
   ```bash
   ls -la input/crud-logs/
   ```

---

## About Archive Extraction

The test validates that archive extraction uses the **same logic** as regular files:

- **ZIP Archives**: Extracted and processed identically to regular files
- **TAR Archives**: Extracted and processed identically to regular files  
- **TAR.GZ Archives**: Extracted and processed identically to regular files

By comparing MD5 checksums, the test confirms archives produce identical results to extracting from uncompressed files.
