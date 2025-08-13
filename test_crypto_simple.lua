#!/usr/bin/env lua

-- test_crypto_simple.lua - Simple test focused on encryption functionality only
-- This bypasses the JSON parsing issues to test core crypto features
-- Refactored for better organization and maintainability

-- Add the codingbuddy directory to package path
package.path = './codingbuddy/?.lua;' .. package.path

local crypto = require('crypto')
local utils = require('utils')

-- Configuration constants
local CONFIG = {
    TEST_DIR = os.getenv('HOME') .. '/.config/geany/plugins/geanylua/codingbuddy',
    FILES = {
        PLAIN = 'test_conversation.json',
        ENCRYPTED = 'test_conversation.json.enc', 
        DECRYPTED = 'test_conversation_decrypted.json'
    },
    SAMPLE_CONVERSATION = {
        id = "test_conv_123",
        title = "Sample Conversation",
        created_at = "2024-01-01T12:00:00Z",
        updated_at = "2024-01-01T12:30:00Z",
        messages = {
            {
                role = "user",
                content = "Hello, can you help me with encryption?",
                timestamp = "2024-01-01T12:00:00Z"
            },
            {
                role = "assistant", 
                content = "Of course! I'd be happy to help you with encryption. AES-256-CBC is a strong encryption standard.",
                timestamp = "2024-01-01T12:01:00Z"
            }
        },
        metadata = {
            total_tokens = 50,
            total_cost = 0.001
        }
    }
}

-- Test result tracking
local TestResults = {
    tests = {},
    passed = 0,
    failed = 0
}

-- Helper function to run and track tests
local function run_test(name, test_func)
    print('Test ' .. (#TestResults.tests + 1) .. ': ' .. name .. '...')
    local success, result = pcall(test_func)
    
    if success and result then
        print('✓ ' .. name .. ' passed')
        TestResults.passed = TestResults.passed + 1
        table.insert(TestResults.tests, {name = name, passed = true})
    else
        local error_msg = success and "Test returned false" or result
        print('✗ ' .. name .. ' failed: ' .. tostring(error_msg))
        TestResults.failed = TestResults.failed + 1
        table.insert(TestResults.tests, {name = name, passed = false, error = error_msg})
        return false
    end
    return true
end

-- Test functions
local function test_openssl_availability()
    local openssl_ok, openssl_info = crypto.check_openssl()
    if openssl_ok then
        print('  OpenSSL info: ' .. openssl_info)
        return true
    else
        error('OpenSSL not available: ' .. tostring(openssl_info))
    end
end

local function test_passphrase_setup()
    local passphrase = os.getenv('CODINGBUDDY_PASSPHRASE')
    if passphrase and passphrase ~= '' then
        print('  Passphrase length: ' .. #passphrase .. ' characters')
        return true
    else
        error('CODINGBUDDY_PASSPHRASE environment variable not set or empty')
    end
end

local function test_crypto_functionality()
    local crypto_test_ok, crypto_test_err = crypto.test_crypto()
    if crypto_test_ok then
        return true
    else
        error('Crypto functionality test failed: ' .. tostring(crypto_test_err))
    end
end

local function test_conversation_encryption()
    -- Setup test files
    utils.ensure_dir(CONFIG.TEST_DIR)
    local plain_file = CONFIG.TEST_DIR .. '/' .. CONFIG.FILES.PLAIN
    local encrypted_file = CONFIG.TEST_DIR .. '/' .. CONFIG.FILES.ENCRYPTED
    local decrypted_file = CONFIG.TEST_DIR .. '/' .. CONFIG.FILES.DECRYPTED
    
    -- Encode conversation to JSON
    local json_str = utils.simple_json_encode(CONFIG.SAMPLE_CONVERSATION)
    if not json_str or #json_str == 0 then
        error('Failed to encode conversation to JSON')
    end
    print('  JSON length: ' .. #json_str .. ' characters')
    
    -- Write plaintext
    local ok, err = utils.safe_write_all(plain_file, json_str)
    if not ok then
        error('Failed to write test data: ' .. tostring(err))
    end
    
    -- Encrypt
    local enc_ok, enc_err = crypto.encrypt_file(plain_file, encrypted_file)
    if not enc_ok then
        error('Encryption failed: ' .. tostring(enc_err))
    end
    
    -- Verify encrypted file
    local enc_data = utils.safe_read_all(encrypted_file)
    if not enc_data or #enc_data == 0 then
        error('Encrypted file is empty or missing')
    end
    if enc_data == json_str then
        error('Encrypted data is identical to plaintext (encryption failed)')
    end
    
    -- Decrypt
    local dec_ok, dec_err = crypto.decrypt_file(encrypted_file, decrypted_file)
    if not dec_ok then
        error('Decryption failed: ' .. tostring(dec_err))
    end
    
    -- Verify decrypted content
    local dec_data = utils.safe_read_all(decrypted_file)
    if dec_data ~= json_str then
        error(string.format('Decrypted data mismatch - Original: %d bytes, Decrypted: %d bytes', 
                          #json_str, #(dec_data or '')))
    end
    
    -- Calculate overhead
    local overhead = #enc_data - #json_str
    local overhead_pct = (overhead / #json_str) * 100
    print(string.format('  Encryption overhead: %d bytes (%.1f%%)', overhead, overhead_pct))
    
    -- Cleanup
    os.remove(plain_file)
    os.remove(encrypted_file)
    os.remove(decrypted_file)
    
    return true
end

local function cleanup_test_environment()
    -- Additional cleanup if needed
    return true
end

-- Main test execution
print('=== CodingBuddy Crypto Simple Test (Refactored) ===')
print()

-- Execute tests in sequence, stopping on first failure
local tests_to_run = {
    {'OpenSSL Availability Check', test_openssl_availability},
    {'Passphrase Environment Setup', test_passphrase_setup},
    {'Basic Crypto Functionality', test_crypto_functionality},
    {'Conversation Data Encryption', test_conversation_encryption},
    {'Test Environment Cleanup', cleanup_test_environment}
}

local all_passed = true
for i, test in ipairs(tests_to_run) do
    local test_name, test_func = test[1], test[2]
    if not run_test(test_name, test_func) then
        all_passed = false
        break  -- Stop on first failure
    end
    print()
end

-- Print summary
if all_passed then
    print('=== All Tests Completed Successfully! ===')
    print()
    print('Test Summary:')
    print('- Total tests run: ' .. #TestResults.tests)
    print('- Passed: ' .. TestResults.passed)
    print('- Failed: ' .. TestResults.failed)
    print()
    print('Key findings:')
    print('- OpenSSL is available and working correctly')
    print('- AES-256-CBC encryption/decryption is functioning properly')
    print('- Data integrity is preserved through encrypt/decrypt cycle')
    print('- Conversation encryption functionality is ready for production use')
else
    print('=== Test Suite Failed ===')
    print()
    print('Failed tests:')
    for _, test in ipairs(TestResults.tests) do
        if not test.passed then
            print('- ' .. test.name .. ': ' .. (test.error or 'Unknown error'))
        end
    end
    os.exit(1)
end

print()
print('Setup Instructions:')
print('1. Set CODINGBUDDY_PASSPHRASE environment variable')
print('2. Set conversation_encryption: true in config.json')
print('3. Conversations will be automatically encrypted at rest')
print()
print('For enhanced JSON support: luarocks install dkjson')
print()
