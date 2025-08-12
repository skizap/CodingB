-- crypto.lua - Encryption/decryption functionality for conversation files
-- Uses OpenSSL CLI as a dependable baseline for AES-256-CBC encryption

local utils = require('utils')
local M = {}

-- Creates a temporary passphrase file from environment variable
-- Returns the temporary file path on success, or nil and error message on failure
local function passfile_from_env()
  local pass = os.getenv('CODINGBUDDY_PASSPHRASE')
  if not pass or pass == '' then
    return nil, 'CODINGBUDDY_PASSPHRASE environment variable not set or empty'
  end
  
  -- Create temporary passphrase file in the codingbuddy directory
  local home = os.getenv('HOME') or '.'
  local tmp_dir = home .. '/.config/geany/plugins/geanylua/codingbuddy'
  
  -- Ensure the directory exists
  if not utils.ensure_dir(tmp_dir) then
    return nil, 'cannot create codingbuddy directory'
  end
  
  local tmp = tmp_dir .. '/.pass.tmp.' .. tostring(os.time()) .. '.' .. math.random(1000, 9999)
  
  local f, err = io.open(tmp, 'wb')
  if not f then 
    return nil, 'cannot write temporary passphrase file: ' .. tostring(err)
  end
  
  f:write(pass)
  f:close()
  
  -- Set restrictive permissions on the temporary passphrase file (Unix-like systems)
  if os.getenv('OS') ~= 'Windows_NT' then
    os.execute('chmod 600 "' .. tmp .. '"')
  end
  
  return tmp
end

-- Encrypts a file using AES-256-CBC with PBKDF2 key derivation
-- @param in_path: Path to the input (plaintext) file
-- @param out_path: Path to the output (encrypted) file
-- @return success (boolean), error_message (string or nil)
function M.encrypt_file(in_path, out_path)
  utils.log_debug('Encrypting file: ' .. tostring(in_path) .. ' -> ' .. tostring(out_path))
  
  if not in_path or not out_path then
    return false, 'invalid file paths provided'
  end
  
  local pfile, err = passfile_from_env()
  if not pfile then 
    utils.log_error('Failed to create passphrase file', err)
    return false, err 
  end
  
  -- Use OpenSSL with strong encryption parameters
  -- -aes-256-cbc: AES encryption with 256-bit key in CBC mode
  -- -salt: Add random salt to prevent rainbow table attacks  
  -- -pbkdf2: Use PBKDF2 for key derivation
  -- -iter 100000: Use 100,000 iterations for PBKDF2 (industry standard)
  local cmd = string.format(
    'openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 -in "%s" -out "%s" -pass file:%s 2>/dev/null',
    in_path:gsub('"', '\\"'),
    out_path:gsub('"', '\\"'), 
    pfile:gsub('"', '\\"')
  )
  
  utils.log_debug('Executing encryption command: openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 [paths hidden]')
  
  local result = os.execute(cmd)
  local success
  if type(result) == 'boolean' then
    success = result
  else
    success = result == 0
  end
  
  -- Always clean up the temporary passphrase file
  os.remove(pfile)
  
  if not success then
    utils.log_error('OpenSSL encryption failed')
    return false, 'openssl encryption failed'
  end
  
  utils.log_debug('File encryption completed successfully')
  return true
end

-- Decrypts a file using AES-256-CBC with PBKDF2 key derivation
-- @param in_path: Path to the input (encrypted) file  
-- @param out_path: Path to the output (plaintext) file
-- @return success (boolean), error_message (string or nil)
function M.decrypt_file(in_path, out_path)
  utils.log_debug('Decrypting file: ' .. tostring(in_path) .. ' -> ' .. tostring(out_path))
  
  if not in_path or not out_path then
    return false, 'invalid file paths provided'
  end
  
  local pfile, err = passfile_from_env()
  if not pfile then 
    utils.log_error('Failed to create passphrase file', err)
    return false, err 
  end
  
  -- Use OpenSSL decryption with same parameters as encryption
  local cmd = string.format(
    'openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "%s" -out "%s" -pass file:%s 2>/dev/null',
    in_path:gsub('"', '\\"'),
    out_path:gsub('"', '\\"'),
    pfile:gsub('"', '\\"')
  )
  
  utils.log_debug('Executing decryption command: openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 [paths hidden]')
  
  local result = os.execute(cmd)
  local success
  if type(result) == 'boolean' then
    success = result
  else
    success = result == 0
  end
  
  -- Always clean up the temporary passphrase file
  os.remove(pfile)
  
  if not success then
    utils.log_error('OpenSSL decryption failed')
    return false, 'openssl decryption failed'
  end
  
  utils.log_debug('File decryption completed successfully')
  return true
end

-- Utility function to check if OpenSSL is available
-- @return available (boolean), version_info (string or nil)
function M.check_openssl()
  local handle = io.popen('openssl version 2>/dev/null')
  if not handle then
    return false, 'openssl command not found'
  end
  
  local version = handle:read('*line')
  handle:close()
  
  if not version or version == '' then
    return false, 'openssl not available'
  end
  
  return true, version
end

-- Test encryption/decryption functionality
-- @return success (boolean), error_message (string or nil)
function M.test_crypto()
  utils.log_debug('Testing crypto functionality')
  
  -- Check if OpenSSL is available
  local openssl_ok, openssl_info = M.check_openssl()
  if not openssl_ok then
    return false, 'OpenSSL not available: ' .. tostring(openssl_info)
  end
  
  -- Check if passphrase is set
  local pass = os.getenv('CODINGBUDDY_PASSPHRASE')
  if not pass or pass == '' then
    return false, 'CODINGBUDDY_PASSPHRASE environment variable not set'
  end
  
  -- Create test data
  local test_data = '{"test": "crypto functionality", "timestamp": "' .. os.date('!%Y-%m-%dT%H:%M:%SZ') .. '"}'
  local tmp_dir = os.getenv('HOME') .. '/.config/geany/plugins/geanylua/codingbuddy'
  local plain_file = tmp_dir .. '/test_plain.tmp'
  local encrypted_file = tmp_dir .. '/test_encrypted.tmp'
  local decrypted_file = tmp_dir .. '/test_decrypted.tmp'
  
  -- Write test data
  local ok, err = utils.safe_write_all(plain_file, test_data)
  if not ok then
    return false, 'failed to write test data: ' .. tostring(err)
  end
  
  -- Test encryption
  local enc_ok, enc_err = M.encrypt_file(plain_file, encrypted_file)
  if not enc_ok then
    os.remove(plain_file)
    return false, 'encryption test failed: ' .. tostring(enc_err)
  end
  
  -- Test decryption
  local dec_ok, dec_err = M.decrypt_file(encrypted_file, decrypted_file)
  if not dec_ok then
    os.remove(plain_file)
    os.remove(encrypted_file)
    return false, 'decryption test failed: ' .. tostring(dec_err)
  end
  
  -- Verify data integrity
  local decrypted_data = utils.safe_read_all(decrypted_file)
  if decrypted_data ~= test_data then
    os.remove(plain_file)
    os.remove(encrypted_file) 
    os.remove(decrypted_file)
    return false, 'data integrity check failed'
  end
  
  -- Clean up test files
  os.remove(plain_file)
  os.remove(encrypted_file)
  os.remove(decrypted_file)
  
  utils.log_debug('Crypto functionality test passed')
  return true
end

return M
