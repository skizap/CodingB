-- test_crypto.lua - Tests crypto functionality (guarded by CODINGBUDDY_PASSPHRASE)
local crypto = require('crypto')

-- Check if CODINGBUDDY_PASSPHRASE is set before running tests
local passphrase = os.getenv('CODINGBUDDY_PASSPHRASE')
if not passphrase or passphrase == '' then
    print('CODINGBUDDY_PASSPHRASE not set - skipping crypto tests')
    print('To run crypto tests, set CODINGBUDDY_PASSPHRASE environment variable')
    return
end

print('Testing crypto functionality with CODINGBUDDY_PASSPHRASE...')

-- Test file paths
local src = '/tmp/cb_plain.txt'
local enc = '/tmp/cb_plain.txt.enc'
local dec = '/tmp/cb_plain.txt.dec'

-- Clean up any existing test files first
os.remove(src)
os.remove(enc)
os.remove(dec)

-- Test 1: Create source file with test data
local f = io.open(src, 'wb')
assert(f, 'Failed to create source file: ' .. src)
f:write('secret')
f:close()
print('✓ Source file created')

-- Test 2: Encrypt the file
local encrypt_ok = crypto.encrypt_file(src, enc)
assert(encrypt_ok, 'Encryption failed')
print('✓ File encryption test passed')

-- Verify encrypted file exists and is different from source
local enc_f = io.open(enc, 'rb')
assert(enc_f, 'Encrypted file was not created')
local enc_content = enc_f:read('*all')
enc_f:close()
assert(enc_content ~= 'secret', 'Encrypted content should be different from plaintext')
assert(#enc_content > 6, 'Encrypted content should be larger than plaintext due to encryption overhead')
print('✓ Encryption output validation passed')

-- Test 3: Decrypt the file
local decrypt_ok = crypto.decrypt_file(enc, dec)
assert(decrypt_ok, 'Decryption failed')
print('✓ File decryption test passed')

-- Test 4: Verify decrypted content matches original
local rf = io.open(dec, 'rb')
assert(rf, 'Decrypted file was not created')
local txt = rf:read('*all')
rf:close()
assert(txt == 'secret', 'Decrypted content does not match original: ' .. tostring(txt))
print('✓ Content integrity test passed')

-- Test 5: Test with larger content
local large_content = string.rep('This is a longer test string with multiple lines.\n', 50)
local src2 = '/tmp/cb_large.txt'
local enc2 = '/tmp/cb_large.txt.enc' 
local dec2 = '/tmp/cb_large.txt.dec'

local f2 = io.open(src2, 'wb')
f2:write(large_content)
f2:close()

assert(crypto.encrypt_file(src2, enc2), 'Large file encryption failed')
assert(crypto.decrypt_file(enc2, dec2), 'Large file decryption failed')

local rf2 = io.open(dec2, 'rb')
local large_decrypted = rf2:read('*all')
rf2:close()

assert(large_decrypted == large_content, 'Large file content integrity failed')
print('✓ Large file test passed')

-- Test 6: Test OpenSSL availability check
local openssl_ok, openssl_info = crypto.check_openssl()
assert(openssl_ok, 'OpenSSL should be available: ' .. tostring(openssl_info))
print('✓ OpenSSL availability test passed: ' .. tostring(openssl_info))

-- Test 7: Test with empty file
local empty_src = '/tmp/cb_empty.txt'
local empty_enc = '/tmp/cb_empty.txt.enc'
local empty_dec = '/tmp/cb_empty.txt.dec'

local fe = io.open(empty_src, 'wb')
fe:write('')
fe:close()

assert(crypto.encrypt_file(empty_src, empty_enc), 'Empty file encryption failed')
assert(crypto.decrypt_file(empty_enc, empty_dec), 'Empty file decryption failed')

local rfe = io.open(empty_dec, 'rb')
local empty_content = rfe:read('*all')
rfe:close()

assert(empty_content == '', 'Empty file should decrypt to empty content')
print('✓ Empty file test passed')

-- Clean up all test files
os.remove(src)
os.remove(enc) 
os.remove(dec)
os.remove(src2)
os.remove(enc2)
os.remove(dec2)
os.remove(empty_src)
os.remove(empty_enc)
os.remove(empty_dec)

print('✓ Cleanup completed')
print('All crypto tests passed successfully!')
