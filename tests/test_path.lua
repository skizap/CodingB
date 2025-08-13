-- test_path.lua - Tests sandbox path logic
local path = require('tools.path')

-- Ensure os.setenv exists (compatibility for some Lua versions)
os.setenv = os.setenv or function() end

-- Test 1: Basic path resolution for README.md
local abs, err = path.to_abs('README.md')
assert(abs and not err, 'Failed to resolve README.md path: ' .. tostring(err))
print('✓ Path resolution test passed: ' .. abs)

-- Test 2: Ensure resolved path is in sandbox
local ok, e = path.ensure_in_sandbox(abs)
assert(ok, 'Path should be in sandbox: ' .. tostring(e))
print('✓ Sandbox validation test passed')

-- Test 3: Test relative path resolution
local rel_path = 'codingbuddy/config.lua'
local abs2, err2 = path.to_abs(rel_path)
assert(abs2 and not err2, 'Failed to resolve relative path: ' .. tostring(err2))
print('✓ Relative path test passed: ' .. abs2)

-- Test 4: Ensure relative path is also in sandbox
local ok2, e2 = path.ensure_in_sandbox(abs2)
assert(ok2, 'Relative path should be in sandbox: ' .. tostring(e2))
print('✓ Relative path sandbox test passed')

-- Test 5: Test empty path handling
local abs_empty, err_empty = path.to_abs('')
assert(not abs_empty and err_empty, 'Empty path should return error')
print('✓ Empty path handling test passed')

-- Test 6: Test nil path handling
local abs_nil, err_nil = path.to_abs(nil)
assert(not abs_nil and err_nil, 'Nil path should return error')
print('✓ Nil path handling test passed')

print('All path tests passed successfully!')
