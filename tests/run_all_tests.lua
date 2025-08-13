#!/usr/bin/env lua
-- run_all_tests.lua - Test runner for CodingBuddy automated tests

-- Set up the Lua path to find the codingbuddy modules
package.path = package.path .. ';./codingbuddy/?.lua'

-- Test files to run
local test_files = {
    'tests/test_path.lua',
    'tests/test_fs.lua', 
    'tests/test_terminal.lua',
    'tests/test_crypto.lua'
}

local total_tests = 0
local passed_tests = 0
local failed_tests = 0

print('=' .. string.rep('=', 60))
print('CodingBuddy Automated Test Suite')
print('=' .. string.rep('=', 60))
print()

for _, test_file in ipairs(test_files) do
    local test_name = test_file:match('test_(%w+)%.lua$')
    total_tests = total_tests + 1
    
    print(string.format('Running %s tests...', test_name))
    print(string.rep('-', 40))
    
    -- Run the test file
    local success, err = pcall(dofile, test_file)
    
    if success then
        passed_tests = passed_tests + 1
        print(string.format('✓ %s tests PASSED', test_name))
    else
        failed_tests = failed_tests + 1
        print(string.format('✗ %s tests FAILED: %s', test_name, tostring(err)))
    end
    
    print()
end

-- Print summary
print('=' .. string.rep('=', 60))
print('Test Summary')
print('=' .. string.rep('=', 60))
print(string.format('Total test suites: %d', total_tests))
print(string.format('Passed: %d', passed_tests))
print(string.format('Failed: %d', failed_tests))
print()

if failed_tests == 0 then
    print('🎉 All test suites passed successfully!')
    os.exit(0)
else
    print('❌ Some test suites failed!')
    os.exit(1)
end
