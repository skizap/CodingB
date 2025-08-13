# CodingBuddy Automated Test Suite

This directory contains automated tests for critical surfaces of the CodingBuddy system. All tests are written in Lua and can be run directly or via the test runner.

## Test Files

### test_path.lua
Tests sandbox path logic functionality:
- Basic path resolution (e.g., 'README.md' → absolute path)
- Sandbox validation to prevent path escaping
- Relative path handling
- Edge cases (empty/nil paths)

### test_fs.lua
Tests atomic write and read operations:
- Atomic file writing with temporary files and rename
- File reading functionality
- Empty and multi-line content handling
- File existence checking
- Proper cleanup after operations

### test_terminal.lua
Tests terminal command allowlist functionality:
- Basic command execution (echo, ls, which)
- Command allowlist enforcement
- Command denylist enforcement (rm -rf, shutdown, etc.)
- Command argument handling
- Error handling for unknown commands

### test_crypto.lua
Tests crypto functionality (requires CODINGBUDDY_PASSPHRASE):
- File encryption using OpenSSL AES-256-CBC
- File decryption and content integrity verification
- Large file handling
- Empty file handling
- OpenSSL availability checking
- Proper cleanup of temporary files

## Running Tests

### Individual Tests
Run individual test files from the project root:

```bash
cd /path/to/CodingBuddy
lua -e "package.path = package.path .. ';./codingbuddy/?.lua'" tests/test_path.lua
lua -e "package.path = package.path .. ';./codingbuddy/?.lua'" tests/test_fs.lua
lua -e "package.path = package.path .. ';./codingbuddy/?.lua'" tests/test_terminal.lua
lua -e "package.path = package.path .. ';./codingbuddy/?.lua'" tests/test_crypto.lua
```

### All Tests
Run all tests using the test runner:

```bash
cd /path/to/CodingBuddy
lua tests/run_all_tests.lua
```

### Crypto Tests
Crypto tests require the CODINGBUDDY_PASSPHRASE environment variable:

```bash
cd /path/to/CodingBuddy
CODINGBUDDY_PASSPHRASE="your_passphrase_here" lua tests/run_all_tests.lua
```

If CODINGBUDDY_PASSPHRASE is not set, crypto tests will be skipped with an informative message.

## Test Requirements

- **Lua**: Tests require Lua to be installed and available in PATH
- **OpenSSL**: Crypto tests require OpenSSL to be installed for encryption/decryption
- **System Commands**: Terminal tests require basic system commands (echo, ls, which)
- **File System**: Tests create temporary files and require write permissions

## Test Design

All tests follow these principles:

- **Real Functionality**: Tests exercise actual production code paths
- **Runnable**: Tests can be executed directly without complex setup
- **Clean**: Tests clean up any temporary files/resources they create
- **Clear Output**: Tests provide clear success/failure messages
- **Safe**: Tests use secure patterns and don't compromise system security

## Expected Output

Successful test runs will show:
- ✓ marks for passing tests
- Clear descriptions of what was tested
- Summary of results at the end
- Exit code 0 for success, non-zero for failures

## Adding New Tests

When adding new tests:

1. Create a new `test_<component>.lua` file
2. Include comprehensive assertions with descriptive messages
3. Add cleanup code to remove any temporary files/resources
4. Add the test file to `run_all_tests.lua`
5. Document the test purpose and requirements in this README
