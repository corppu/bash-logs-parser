# Docker Test Setup for Pattern Matching Script

This directory contains a complete Docker test environment for the `move-pattern-matching-logs.sh` script.

## Files

- **Dockerfile** - Container image definition with all required tools
- **docker-compose.yml** - Multi-test orchestration setup
- **test.sh** - Comprehensive test suite
- **test-data/** - Sample log files for testing
  - `application.log` - Main application logs
  - `services/api.log` - API service logs
  - `services/worker.log` - Worker service logs

## Quick Start

### Option 1: Run Full Test Suite (Recommended)

```bash
chmod +x test.sh
./test.sh
```

This will:

1. Build the Docker image
2. Run 7 comprehensive tests
3. Verify directory structure preservation
4. Check pattern matching accuracy
5. Display results summary

### Option 2: Using Docker Compose

```bash
# Run all predefined tests
docker-compose up

# Or run individual tests
docker-compose up test-error-pattern
docker-compose up test-multi-pattern
docker-compose up test-custom-timestamp
```

### Option 3: Manual Docker Testing

```bash
# Build the image
docker build -t pattern-matcher .

# Run a single test
docker run -it --rm \
  -v $(pwd)/test-data:/test-data \
  -v $(pwd)/test-results:/test-results \
  pattern-matcher \
  -p "ERROR" \
  -i "/test-data" \
  -o "/test-results/my-test"

# Check results
cat test-results/my-test/application.log
```

## Test Scenarios

### Test 1: Single Pattern

- Pattern: `ERROR`
- Input: `/test-data`
- Output: `test1-errors`
- Expected: All complete ERROR entries with context

### Test 2: Multiple Patterns

- Patterns: `ERROR`, `WARNING`
- Input: `/test-data`
- Output: `test2-multi`
- Expected: All entries matching either pattern

### Test 3: Custom Timestamp Regex

- Pattern: `Database`
- Timestamp Regex: `^\[`
- Input: `/test-data`
- Output: `test3-custom-timestamp`
- Expected: All Database-related entries

## Test Data

Each test log file contains:

- Timestamped log entries in format: `[YYYY-MM-DD HH:MM:SS]`
- Multiple log levels: INFO, DEBUG, WARNING, ERROR
- Multi-line error entries with stack traces
- Nested directory structure to test path preservation

## Sample Output

After running tests, check results:

```bash
# View directory structure
tree test-results/

# View matched entries
cat test-results/test1-errors/application.log
cat test-results/test1-errors/services/api.log

# Count extracted entries
find test-results/test1-errors -type f -exec wc -l {} +
```

## Customizing Tests

Edit `test.sh` to add more test cases:

```bash
docker run -t --rm \
    -v "$TEST_DIR/test-data:/test-data" \
    -v "$RESULTS_DIR:/test-results" \
    pattern-matcher \
    -p "YOUR_PATTERN" \
    -i "/test-data" \
    -o "/test-results/your-test-name"
```

Or edit `docker-compose.yml` to add new services:

```yaml
test-custom:
    build: .
    volumes:
      - ./test-data:/test-data
      - ./test-results:/test-results
    command: ["-p", "PATTERN", "-i", "/test-data", "-o", "/test-results/custom"]
```

## Cleanup

```bash
# Remove test results
rm -rf test-results/

# Remove Docker image
docker rmi pattern-matcher

# Stop containers
docker-compose down

# Clean up all build artifacts
docker system prune
```

## Troubleshooting

### Docker not found

Install Docker: [https://docs.docker.com/get-docker/](https://docs.docker.com/get-docker/)

### Permission denied

Make test script executable:

```bash
chmod +x test.sh
```

### Tests failing

Check Docker logs:

```bash
docker-compose logs test-error-pattern
```

Run script directly to see errors:

```bash
bash test.sh -x
```
