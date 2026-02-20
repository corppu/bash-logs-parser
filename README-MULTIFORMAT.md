# Multi-Format Log Extraction Test

## Overview

This test suite validates the ability to extract log entries by **log level** and **user UUID identifier**, demonstrating advanced pattern matching capabilities for structured log analysis.

## Test Data

Three test log files have been created with the following characteristics:

- **app-user1.log** - User UUID: `550e8400-e29b-41d4-a716-446655440000`
- **app-user2.log** - User UUID: `6ba7b810-9dad-11d1-80b4-00c04fd430c8`
- **app-user3.log** - User UUID: `6ba7b811-9dad-11d1-80b4-00c04fd430c8`

Each file contains 16 log entries with the following structure:
```
YYYY-MM-DD HH:MM:SS.mmm [LEVEL] User UUID - Message
```

### Log Levels Present

- **[INFO]** - 4 entries per file, 12 total
- **[WARNING]** - 4 entries per file, 12 total
- **[ERROR]** - 4 entries per file, 12 total
- **[DEBUG]** - 2 entries per file (not tested)
- **[CRITICAL]** - 1 entry per file, 3 total

## Test Cases

### Test Case 1: Extract WARNING Level Entries
**Pattern:** `\[WARNING\]`
- Extracts all log entries containing `[WARNING]`
- **Result:** 12 entries across 3 files (4 from each user)
- **Output Directory:** `shared-output/actual-multiformat/warning-level/`

### Test Case 2: Extract ERROR Level Entries
**Pattern:** `\[ERROR\]`
- Extracts all log entries containing `[ERROR]`
- **Result:** 12 entries across 3 files (4 from each user)
- **Output Directory:** `shared-output/actual-multiformat/error-level/`

### Test Case 3: Extract INFO Level Entries
**Pattern:** `\[INFO\]`
- Extracts all log entries containing `[INFO]`
- **Result:** 12 entries across 3 files (4 from each user)
- **Output Directory:** `shared-output/actual-multiformat/info-level/`

### Test Case 4: Extract CRITICAL Level Entries
**Pattern:** `\[CRITICAL\]`
- Extracts all log entries containing `[CRITICAL]`
- **Result:** 3 entries across 3 files (1 from each user)
- **Output Directory:** `shared-output/actual-multiformat/critical-level/`

### Test Case 5: Extract WARNING Entries for Specific User (UUID + Level)
**Pattern:** `550e8400-e29b-41d4-a716-446655440000.*\[WARNING\]|\[WARNING\].*550e8400-e29b-41d4-a716-446655440000`
- Filters entries by BOTH user UUID AND log level
- Matches either: `UUID....[WARNING]` or `[WARNING]....UUID`
- **Result:** 4 entries from app-user1.log matching WARNING level
- **Output Directory:** `shared-output/actual-multiformat/user1-warning/`

Example:
```
2024-01-15 08:31:05.789 [WARNING] User 550e8400-e29b-41d4-a716-446655440000 - High memory usage detected (85%)
2024-01-15 08:34:15.678 [WARNING] User 550e8400-e29b-41d4-a716-446655440000 - Slow query detected: SELECT * FROM users took 2.5s
2024-01-15 08:39:10.123 [WARNING] User 550e8400-e29b-41d4-a716-446655440000 - Connection pool exhausted, waiting for available connection
2024-01-15 08:43:55.345 [WARNING] User 550e8400-e29b-41d4-a716-446655440000 - Disk space low on /var/data (92% full)
```

### Test Case 6: Extract ERROR Entries for Specific User (UUID + Level)
**Pattern:** `6ba7b810-9dad-11d1-80b4-00c04fd430c8.*\[ERROR\]|\[ERROR\].*6ba7b810-9dad-11d1-80b4-00c04fd430c8`
- Filters entries for User 2 with ERROR level
- **Result:** 4 entries from app-user2.log matching ERROR level
- **Output Directory:** `shared-output/actual-multiformat/user2-error/`

## Validation Checks

The test script performs the following validations:

1. ✓ WARNING level entries extracted
2. ✓ ERROR level entries extracted
3. ✓ INFO level entries extracted
4. ✓ CRITICAL level entries extracted
5. ✓ User UUID + level filtering works correctly

## Extraction Results

```
Test Case       | Pattern              | Output Files | Total Lines
----------------|----------------------|--------------|-------------
WARNING Level   | \[WARNING\]         | 3 files      | 12 lines
ERROR Level     | \[ERROR\]           | 3 files      | 12 lines
INFO Level      | \[INFO\]            | 3 files      | 12 lines
CRITICAL Level  | \[CRITICAL\]        | 3 files      | 3 lines
User1 WARNING   | UUID1 + \[WARNING\] | 1 file       | 4 lines
User2 ERROR     | UUID2 + \[ERROR\]   | 1 file       | 4 lines
```

## Running the Test

```bash
# Run the multiformat logs test
bash test-multiformat-logs.sh

# Check specific extracted entries
cat shared-output/actual-multiformat/warning-level/app-user1.log
cat shared-output/actual-multiformat/user1-warning/app-user1.log
```

## Key Features Demonstrated

1. **Log Level Filtering** - Extract entries by severity level (INFO, WARNING, ERROR, CRITICAL)
2. **UUID-Based Filtering** - Extract entries for specific users using UUIDs
3. **Combined Filtering** - Extract entries matching BOTH UUID AND log level
4. **Regex Alternation** - Use OR operators to match patterns in any order
5. **Complete Entry Extraction** - Full log entries extracted across line boundaries
6. **Multi-File Processing** - Process multiple files simultaneously with consistent logic

## Expected Output Directory Structure

```
shared-output/actual-multiformat/
├── warning-level/
│   ├── app-user1.log (4 entries)
│   ├── app-user2.log (4 entries)
│   └── app-user3.log (4 entries)
├── error-level/
│   ├── app-user1.log (4 entries)
│   ├── app-user2.log (4 entries)
│   └── app-user3.log (4 entries)
├── info-level/
│   ├── app-user1.log (4 entries)
│   ├── app-user2.log (4 entries)
│   └── app-user3.log (4 entries)
├── critical-level/
│   ├── app-user1.log (1 entry)
│   ├── app-user2.log (1 entry)
│   └── app-user3.log (1 entry)
├── user1-warning/
│   └── app-user1.log (4 entries, UUID1 + WARNING only)
└── user2-error/
    └── app-user2.log (4 entries, UUID2 + ERROR only)
```

## Pattern Matching Examples

### Extract by Log Level
```bash
# WARNING entries
./move-pattern-matching-logs.sh -p '\[WARNING\]' -i input/multiformat-logs -o output/warnings

# ERROR entries
./move-pattern-matching-logs.sh -p '\[ERROR\]' -i input/multiformat-logs -o output/errors

# Multiple levels (SSN pattern is combined)
./move-pattern-matching-logs.sh -p '\[WARNING\]|\[ERROR\]' -i input/multiformat-logs -o output/warnings-and-errors
```

### Extract by User and Level
```bash
# User 1 WARNING entries
./move-pattern-matching-logs.sh \
  -p '550e8400-e29b-41d4-a716-446655440000.*\[WARNING\]|\[WARNING\].*550e8400-e29b-41d4-a716-446655440000' \
  -i input/multiformat-logs \
  -o output/user1-warnings
```

## Summary

This test validates the `move-pattern-matching-logs.sh` script's ability to:
- Extract log entries by severity level
- Filter entries by user identifier
- Combine multiple regex patterns with alternation
- Process multiple files with consistent extraction logic
- Preserve complete log entries across line boundaries
