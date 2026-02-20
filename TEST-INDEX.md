# Test Suite Index

## Quick Start

```bash
# Run original pattern tests (SSN, Phone, Combined patterns)
bash test-move-pattern-matching-logs.sh

# Run log level and UUID filtering tests
bash test-multiformat-logs.sh
```

## Test Files

### Input Data
- **input/crud-logs/** - Original CRUD application logs
  - `app.log`, `audit.log` (regular files)
  - `app.zip`, `app.tar`, `audit.zip`, `audit.tar` (archives)
  - `app_and_audit.zip`, `app_and_audit.tar` (combined archives)

- **input/multiformat-logs/** - Application logs with levels and UUIDs
  - `app-user1.log` (UUID: 550e8400-e29b-41d4-a716-446655440000)
  - `app-user2.log` (UUID: 6ba7b810-9dad-11d1-80b4-00c04fd430c8)
  - `app-user3.log` (UUID: 6ba7b811-9dad-11d1-80b4-00c04fd430c8)

### Test Scripts
| Script | Purpose | Input | Output Dirs |
|--------|---------|-------|-------------|
| `test-move-pattern-matching-logs.sh` | Extract by SSN/Phone patterns | input/crud-logs/ | shared-output/actual/ |
| `test-multiformat-logs.sh` | Extract by log level & UUID | input/multiformat-logs/ | shared-output/actual-multiformat/ |

### Documentation
| File | Description |
|------|-------------|
| `README-TESTING.md` | Original test methodology |
| `README-MULTIFORMAT.md` | Log level & UUID test details |
| `TEST-SUMMARY.md` | Comprehensive test results |
| `move-pattern-matching-logs.sh` | Main extraction script |

## Test Coverage

### Test 1: Pattern Extraction (CRUD Logs)
- **3 pattern types:** SSN, Phone, Combined
- **3 archive formats:** ZIP, TAR, Regular files  
- **Output:** 24 files with identical MD5 checksums

```
Patterns:
├── ssn-patterns/          (SSN: [0-9]{3}-[0-9]{2}-[0-9]{4})
├── phone-patterns/        (Phone: +358401234567, (555) 123-4567, etc.)
└── combined-patterns/     (Both SSN and Phone)

Each pattern contains:
├── app.log
├── app.tar/app.log
├── app.zip/app.log
└── app_and_audit.zip/ (both app.log + audit.log)
```

### Test 2: Log Level & UUID Filtering
- **4 log levels:** INFO, WARNING, ERROR, CRITICAL
- **3 users:** app-user1, app-user2, app-user3
- **12 entries per level** (4 per user)
- **3 entries for CRITICAL** (1 per user)
- **Combined filters:** UUID + Level

```
Output directories:
├── warning-level/         (4 entries per file, 12 total)
├── error-level/           (4 entries per file, 12 total)
├── info-level/            (4 entries per file, 12 total)
├── critical-level/        (1 entry per file, 3 total)
├── user1-warning/         (4 entries: UUID1 + [WARNING])
└── user2-error/           (4 entries: UUID2 + [ERROR])
```

## Results

### Original Tests
- ✓ 24 files extracted
- ✓ 24/24 MD5 checksums matched
- ✓ Folder structures identical
- ✓ All archive formats processed

### Multiformat Tests
- ✓ 14 files extracted
- ✓ Correct log level filtering
- ✓ UUID-based filtering working
- ✓ Combined filters (UUID + level) validated

## Pattern Examples

### Extract by Log Level
```bash
# WARNING entries
./move-pattern-matching-logs.sh -p '\[WARNING\]' -i input/multiformat-logs -o output/warnings

# ERROR entries
./move-pattern-matching-logs.sh -p '\[ERROR\]' -i input/multiformat-logs -o output/errors

# Both WARNING and ERROR
./move-pattern-matching-logs.sh -p '\[WARNING\]|\[ERROR\]' -i input/multiformat-logs -o output/warnings-errors
```

### Extract by User + Level
```bash
# User 1 WARNING entries only
./move-pattern-matching-logs.sh \
  -p '550e8400-e29b-41d4-a716-446655440000.*\[WARNING\]|\[WARNING\].*550e8400-e29b-41d4-a716-446655440000' \
  -i input/multiformat-logs \
  -o output/user1-warnings
```

### Extract SSN/Phone Patterns
```bash
# Social Security Numbers
./move-pattern-matching-logs.sh -p '[0-9]{3}-[0-9]{2}-[0-9]{4}' -i input/crud-logs -o output/ssn

# Phone Numbers (multiple formats)
./move-pattern-matching-logs.sh \
  -p '[+][0-9]{6,}|\([0-9]{3}\) [0-9]{3}-[0-9]{4}|[0-9]{3}-[0-9]{3}-[0-9]{4}' \
  -i input/crud-logs \
  -o output/phone
```

## Key Features

1. ✓ Archive format support (ZIP, TAR)
2. ✓ Multi-line entry preservation
3. ✓ Pattern-based extraction
4. ✓ User UUID filtering
5. ✓ Log level filtering
6. ✓ MD5 validation
7. ✓ Complete entry extraction
8. ✓ Same logic across all file types

## Bug Fixes

1. **Missing last line:** Fixed line counting for files without trailing newline
2. **ZIP archives:** Fixed pattern detection for patterns with alternation

## Test Validation

All tests use baseline comparison:
1. **First run:** Create expected snapshots from actual results
2. **Subsequent runs:** Compare actual vs expected using MD5
3. **Validation:** Ensure identical results across runs

## File Statistics

```
Input Files:        11 total
  - Regular logs:   5 files
  - Archives:       6 files

Output Files:       38 total  
  - Original tests: 24 files
  - Multiformat:    14 files

Test Scripts:       2 total
Documentation:      4 files
```

## Next Steps

1. Run original tests: `bash test-move-pattern-matching-logs.sh`
2. Run multiformat tests: `bash test-multiformat-logs.sh`
3. Review results in `shared-output/actual*/` directories
4. Check documentation files for detailed results
