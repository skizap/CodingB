-- test_fs.lua - Tests atomic write and read operations
local path = require('tools.path')
local fs = require('tools.fs')

-- Test 1: Basic atomic write and read test
print('Testing atomic write and read operations...')

local test_file = 'tests_tmp.txt'
local abs = path.to_abs(test_file)
assert(abs, 'Failed to resolve test file path')

-- Write test data atomically
local write_ok = fs.write_file_atomic(abs, 'hello')
assert(write_ok, 'Atomic write failed')
print('✓ Atomic write test passed')

-- Read the data back
local data = fs.read_file(abs)
assert(data == 'hello', 'Read data does not match written data: ' .. tostring(data))
print('✓ Read test passed')

-- Clean up
os.remove(abs)
print('✓ Cleanup completed')

-- Test 2: Write empty content
local empty_file = 'tests_empty_tmp.txt'
local abs_empty = path.to_abs(empty_file)
local write_empty_ok = fs.write_file_atomic(abs_empty, '')
assert(write_empty_ok, 'Failed to write empty content')

local empty_data = fs.read_file(abs_empty)
assert(empty_data == '', 'Empty file should return empty string')
print('✓ Empty content test passed')

-- Clean up empty file
os.remove(abs_empty)

-- Test 3: Write nil content (should be treated as empty)
local nil_file = 'tests_nil_tmp.txt'
local abs_nil = path.to_abs(nil_file)
local write_nil_ok = fs.write_file_atomic(abs_nil, nil)
assert(write_nil_ok, 'Failed to write nil content')

local nil_data = fs.read_file(abs_nil)
assert(nil_data == '', 'Nil content should result in empty file')
print('✓ Nil content test passed')

-- Clean up nil file
os.remove(abs_nil)

-- Test 4: Multi-line content test
local multiline_file = 'tests_multiline_tmp.txt'
local abs_multiline = path.to_abs(multiline_file)
local multiline_content = 'line1\nline2\nline3\n'
local write_multiline_ok = fs.write_file_atomic(abs_multiline, multiline_content)
assert(write_multiline_ok, 'Failed to write multiline content')

local multiline_data = fs.read_file(abs_multiline)
assert(multiline_data == multiline_content, 'Multiline content mismatch')
print('✓ Multiline content test passed')

-- Clean up multiline file  
os.remove(abs_multiline)

-- Test 5: File existence check
local exist_file = 'tests_exist_tmp.txt'
local abs_exist = path.to_abs(exist_file)

-- File should not exist initially
assert(not fs.exists(abs_exist), 'File should not exist initially')

-- Create the file
fs.write_file_atomic(abs_exist, 'exists')
assert(fs.exists(abs_exist), 'File should exist after creation')
print('✓ File existence test passed')

-- Clean up existence test file
os.remove(abs_exist)

print('All filesystem tests passed successfully!')
