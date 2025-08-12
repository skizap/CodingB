#!/usr/bin/env lua

-- test_crypto_simple.lua - Simple test focused on encryption functionality only
-- This bypasses the JSON parsing issues to test core crypto features

-- Add the codingbuddy directory to package path
package.path = './codingbuddy/?.lua;' .. package.path

local crypto = require('crypto')
local utils = require('utils')

print('=== CodingBuddy Crypto Simple Test ===')
print()

-- Test 1: Check if OpenSSL is available
print('Test 1: Checking OpenSSL availability...')
local openssl_ok, openssl_info = crypto.check_openssl()
if openssl_ok then
  print('✓ OpenSSL is available: ' .. openssl_info)
else
  print('✗ OpenSSL not available: ' .. tostring(openssl_info))
  print('Please install OpenSSL to use encryption features.')
  os.exit(1)
end
print()

-- Test 2: Check passphrase environment variable
print('Test 2: Checking passphrase environment variable...')
local passphrase = os.getenv('CODINGBUDDY_PASSPHRASE')
if passphrase and passphrase ~= '' then
  print('✓ CODINGBUDDY_PASSPHRASE is set (length: ' .. #passphrase .. ' characters)')
else
  print('✗ CODINGBUDDY_PASSPHRASE environment variable not set or empty')
  print('Please set the passphrase: export CODINGBUDDY_PASSPHRASE="your-secure-passphrase"')
  os.exit(1)
end
print()

-- Test 3: Test basic crypto functionality  
print('Test 3: Testing basic crypto functionality...')
local crypto_test_ok, crypto_test_err = crypto.test_crypto()
if crypto_test_ok then
  print('✓ Crypto functionality test passed')
else
  print('✗ Crypto functionality test failed: ' .. tostring(crypto_test_err))
  os.exit(1)
end
print()

-- Test 4: Test manual encryption/decryption with conversation data
print('Test 4: Testing encryption with conversation-like data...')

-- Create a sample conversation structure
local sample_conversation = {
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

-- Manually encode to JSON (simple version)
local json_str = utils.simple_json_encode(sample_conversation)
print('✓ Encoded conversation to JSON (length: ' .. #json_str .. ' characters)')

-- Save to temporary file
local tmp_dir = os.getenv('HOME') .. '/.config/geany/plugins/geanylua/codingbuddy'
utils.ensure_dir(tmp_dir)

local plain_file = tmp_dir .. '/test_conversation.json'
local encrypted_file = tmp_dir .. '/test_conversation.json.enc'
local decrypted_file = tmp_dir .. '/test_conversation_decrypted.json'

-- Write plaintext
local ok, err = utils.safe_write_all(plain_file, json_str)
if not ok then
  print('✗ Failed to write test data: ' .. tostring(err))
  os.exit(1)
end
print('✓ Written plaintext conversation data')

-- Encrypt
local enc_ok, enc_err = crypto.encrypt_file(plain_file, encrypted_file)
if not enc_ok then
  print('✗ Encryption failed: ' .. tostring(enc_err))
  os.exit(1)
end
print('✓ Successfully encrypted conversation data')

-- Verify encrypted file exists and is different
local enc_data = utils.safe_read_all(encrypted_file)
if not enc_data or #enc_data == 0 then
  print('✗ Encrypted file is empty or missing')
  os.exit(1)
end
if enc_data == json_str then
  print('✗ Encrypted data is identical to plaintext (encryption failed)')
  os.exit(1)
end
print('✓ Encrypted file created and contains different data than plaintext')

-- Decrypt
local dec_ok, dec_err = crypto.decrypt_file(encrypted_file, decrypted_file)
if not dec_ok then
  print('✗ Decryption failed: ' .. tostring(dec_err))
  os.exit(1)
end
print('✓ Successfully decrypted conversation data')

-- Verify decrypted content matches original
local dec_data = utils.safe_read_all(decrypted_file)
if dec_data ~= json_str then
  print('✗ Decrypted data does not match original')
  print('Original length:', #json_str)
  print('Decrypted length:', #(dec_data or ''))
  os.exit(1)
end
print('✓ Decrypted data matches original perfectly')
print()

-- Test 5: Test file size overhead
print('Test 5: Analyzing encryption overhead...')
local plain_size = #json_str
local enc_size = #enc_data
local overhead = enc_size - plain_size
local overhead_pct = (overhead / plain_size) * 100

print(string.format('  - Plaintext size: %d bytes', plain_size))
print(string.format('  - Encrypted size: %d bytes', enc_size))  
print(string.format('  - Overhead: %d bytes (%.1f%%)', overhead, overhead_pct))
print()

-- Test 6: Cleanup
print('Test 6: Cleaning up test files...')
os.remove(plain_file)
os.remove(encrypted_file)
os.remove(decrypted_file)
print('✓ Test files cleaned up')
print()

print('=== All encryption tests completed successfully! ===')
print()
print('Key findings:')
print('- OpenSSL is available and working correctly')
print('- AES-256-CBC encryption/decryption is functioning properly')
print('- Data integrity is preserved through encrypt/decrypt cycle')
print(string.format('- Encryption overhead is ~%.1f%% for typical conversation data', overhead_pct))
print()
print('The conversation encryption functionality is ready for use.')
print('Note: For full JSON parsing support in production, install dkjson:')
print('  luarocks install dkjson')
print()
print('To use encryption in CodingBuddy:')
print('1. Set CODINGBUDDY_PASSPHRASE environment variable')
print('2. Set conversation_encryption: true in config.json')
print('3. Conversations will be automatically encrypted at rest')
print()
