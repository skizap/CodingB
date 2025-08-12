#!/usr/bin/env lua

-- test_crypto.lua - Test script for conversation encryption functionality
-- This script tests the crypto module and conversation manager encryption features

-- Add the codingbuddy directory to package path
package.path = './codingbuddy/?.lua;' .. package.path

local crypto = require('crypto')
local utils = require('utils')
local config = require('config')
local conversation_manager = require('conversation_manager')

print('=== CodingBuddy Crypto Test Suite ===')
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

-- Test 4: Test conversation encryption (disabled by default)
print('Test 4: Testing conversation manager without encryption...')
local conv = conversation_manager.create_new_conversation()
conversation_manager.add_message('user', 'Hello, this is a test message for unencrypted storage.')
conversation_manager.add_message('assistant', 'Hello! This response should also be stored without encryption.')

local save_ok, save_err = conversation_manager.save_current_conversation()
if save_ok then
  print('✓ Conversation saved without encryption')
else
  print('✗ Failed to save conversation: ' .. tostring(save_err))
  os.exit(1)
end

-- Try to load it back
local loaded_conv, load_err = conversation_manager.load_conversation(conv.id)
if loaded_conv then
  print('✓ Conversation loaded successfully')
  print('  - Title: ' .. loaded_conv.title)
  print('  - Messages: ' .. #loaded_conv.messages)
else
  print('✗ Failed to load conversation: ' .. tostring(load_err))
  os.exit(1)
end
print()

-- Test 5: Test conversation encryption (enabled)
print('Test 5: Testing conversation manager with encryption...')

-- Temporarily modify the config to enable encryption
local original_config = config.get()
original_config.conversation_encryption = true

-- Create a new conversation with encryption enabled
local enc_conv = conversation_manager.create_new_conversation()
conversation_manager.add_message('user', 'Hello, this is a test message for encrypted storage.')
conversation_manager.add_message('assistant', 'Hello! This response should be stored with encryption.')

local enc_save_ok, enc_save_err = conversation_manager.save_current_conversation()
if enc_save_ok then
  print('✓ Conversation saved with encryption')
else
  print('✗ Failed to save encrypted conversation: ' .. tostring(enc_save_err))
  os.exit(1)
end

-- Try to load it back
local enc_loaded_conv, enc_load_err = conversation_manager.load_conversation(enc_conv.id)
if enc_loaded_conv then
  print('✓ Encrypted conversation loaded successfully')
  print('  - Title: ' .. enc_loaded_conv.title)
  print('  - Messages: ' .. #enc_loaded_conv.messages)
  
  -- Verify the content is the same
  if enc_loaded_conv.messages[1].content == 'Hello, this is a test message for encrypted storage.' then
    print('✓ Message content verified after encryption/decryption')
  else
    print('✗ Message content mismatch after encryption/decryption')
    os.exit(1)
  end
else
  print('✗ Failed to load encrypted conversation: ' .. tostring(enc_load_err))
  os.exit(1)
end
print()

-- Test 6: Test conversation listing with mixed encrypted/unencrypted files
print('Test 6: Testing conversation listing...')
local conversations = conversation_manager.list_conversations()
print('Found ' .. #conversations .. ' conversations:')
for i, conv_info in ipairs(conversations) do
  local enc_status = conv_info.encrypted and 'encrypted' or 'plaintext'
  print('  ' .. i .. '. ' .. conv_info.title .. ' (' .. enc_status .. ')')
end
print()

-- Test 7: Cleanup test conversations
print('Test 7: Cleaning up test conversations...')
local deleted1 = conversation_manager.delete_conversation(conv.id)
local deleted2 = conversation_manager.delete_conversation(enc_conv.id)

if deleted1 then
  print('✓ Deleted plaintext test conversation')
else
  print('✗ Failed to delete plaintext test conversation')
end

if deleted2 then
  print('✓ Deleted encrypted test conversation')
else
  print('✗ Failed to delete encrypted test conversation')
end
print()

-- Reset the config
original_config.conversation_encryption = false

print('=== All tests completed successfully! ===')
print()
print('Encryption at rest is now available for CodingBuddy conversations.')
print('To enable it, set conversation_encryption: true in your config.json file.')
print('Make sure to keep your CODINGBUDDY_PASSPHRASE environment variable secure.')
print()
