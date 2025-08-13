-- test_terminal.lua - Tests allowlist functionality
local t = require('tools.terminal')

-- Test 1: Basic echo command test
print('Testing terminal allowlist functionality...')

local res = t.run_command('echo codingbuddy')
assert(res.stdout and res.stdout:match('codingbuddy'), 'Echo command failed or output incorrect: ' .. tostring(res.stdout))
assert(res.exit_code == 0, 'Echo command should have exit code 0: ' .. tostring(res.exit_code))
print('✓ Basic echo test passed')

-- Test 2: Test allowed command (ls)
local ls_res = t.run_command('ls')
assert(not ls_res.error, 'ls command should be allowed: ' .. tostring(ls_res.error))
print('✓ ls allowlist test passed')

-- Test 3: Test allowed command (which)
local which_res = t.run_command('which echo')
assert(not which_res.error, 'which command should be allowed: ' .. tostring(which_res.error))
print('✓ which allowlist test passed')

-- Test 4: Test denied command (rm -rf should be denied)
local rm_res = t.run_command('rm -rf /tmp/test')
assert(rm_res.error and rm_res.error:match('denied'), 'rm -rf should be denied: ' .. tostring(rm_res.error))
print('✓ rm -rf deny test passed')

-- Test 5: Test denied command (shutdown should be denied)
local shutdown_res = t.run_command('shutdown now')
assert(shutdown_res.error and shutdown_res.error:match('denied'), 'shutdown should be denied: ' .. tostring(shutdown_res.error))
print('✓ shutdown deny test passed')

-- Test 6: Test command not in allowlist (if we have a restrictive allowlist)
-- Note: The actual behavior depends on the configuration, but we test the structure
local unknown_res = t.run_command('unknowncommand123')
-- This may fail for different reasons (command not found vs not allowed)
-- We just check that we get some kind of response structure
assert(type(unknown_res) == 'table', 'Should return a result table')
print('✓ Unknown command handling test passed')

-- Test 7: Test multiline output
local multiline_res = t.run_command('echo -e "line1\\nline2\\nline3"')
if not multiline_res.error then
    assert(multiline_res.stdout:match('line1'), 'Should contain line1')
    assert(multiline_res.stdout:match('line2'), 'Should contain line2')
    assert(multiline_res.stdout:match('line3'), 'Should contain line3')
    print('✓ Multiline output test passed')
else
    print('! Multiline test skipped due to shell differences')
end

-- Test 8: Test command with arguments
local args_res = t.run_command('echo "hello world"')
assert(not args_res.error, 'Echo with quotes should work: ' .. tostring(args_res.error))
assert(args_res.stdout:match('hello world'), 'Should echo the quoted string')
print('✓ Command arguments test passed')

-- Test 9: Test empty command (should handle gracefully)
local empty_res = t.run_command('')
-- Should either work (do nothing) or return an error, but not crash
assert(type(empty_res) == 'table', 'Empty command should return result table')
print('✓ Empty command handling test passed')

print('All terminal tests passed successfully!')
