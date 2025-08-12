# Conversation Encryption at Rest

CodingBuddy now supports encryption of conversation files at rest using industry-standard AES-256-CBC encryption with PBKDF2 key derivation.

## Features

- **Strong Encryption**: Uses OpenSSL with AES-256-CBC encryption
- **Key Derivation**: PBKDF2 with 100,000 iterations for resistance against rainbow table attacks
- **Salt**: Random salt is added to each encrypted file to prevent identical plaintext from producing identical ciphertext
- **Backward Compatibility**: Can read both encrypted and unencrypted conversation files
- **Secure Passphrase Handling**: Passphrase is provided via environment variable, never stored in config files

## Setup

### 1. Install OpenSSL

Encryption relies on the OpenSSL command-line tool being available in your system PATH.

**Ubuntu/Debian:**
```bash
sudo apt install openssl
```

**macOS:**
```bash
# OpenSSL is usually pre-installed, but you can install via Homebrew if needed
brew install openssl
```

**Windows:**
Install OpenSSL from https://slproweb.com/products/Win32OpenSSL.html or use WSL.

### 2. Set Your Passphrase

Set a strong passphrase as an environment variable:

```bash
export CODINGBUDDY_PASSPHRASE="your-very-secure-passphrase-here"
```

**Important**: 
- Use a long, complex passphrase (recommend 20+ characters with mixed case, numbers, and symbols)
- Never store this passphrase in your config files or version control
- Consider using a password manager to generate and store this passphrase
- Add the export command to your shell profile (~/.bashrc, ~/.zshrc, etc.) to persist across sessions

### 3. Enable Encryption in Config

Edit your CodingBuddy configuration file:
`~/.config/geany/plugins/geanylua/codingbuddy/config.json`

Add or modify the following setting:
```json
{
  "conversation_encryption": true,
  // ... other settings
}
```

## Usage

Once configured, encryption works automatically:

- **New Conversations**: Will be encrypted when saved if `conversation_encryption` is `true`
- **Existing Conversations**: Will remain in their current format (encrypted/unencrypted) until re-saved
- **Loading**: The system automatically detects and handles both encrypted and unencrypted files
- **Listing**: Both encrypted and unencrypted conversations appear in conversation lists

## File Extensions

- **Unencrypted**: `conversation_id.json`
- **Encrypted**: `conversation_id.json.enc`

## Security Considerations

### Passphrase Security
- **Never** commit your passphrase to version control
- Use a unique, strong passphrase not used elsewhere
- Consider using a dedicated passphrase manager
- Rotate your passphrase periodically for maximum security

### File System Security
- The temporary files during encryption/decryption are created with restrictive permissions (600 on Unix systems)
- Temporary files are automatically cleaned up after operations
- Consider using full-disk encryption as an additional layer of security

### Backup and Recovery
- **Important**: If you lose your passphrase, encrypted conversations cannot be recovered
- Consider securely backing up your passphrase
- Test decryption periodically to ensure your passphrase works

## Migration Between Encryption States

### Enabling Encryption (Unencrypted → Encrypted)
1. Set `conversation_encryption: true` in config
2. Set `CODINGBUDDY_PASSPHRASE` environment variable
3. New conversations will be encrypted automatically
4. Existing unencrypted conversations remain accessible and will be encrypted when modified

### Disabling Encryption (Encrypted → Unencrypted)
1. Ensure `CODINGBUDDY_PASSPHRASE` is still set
2. Set `conversation_encryption: false` in config
3. Existing encrypted conversations remain accessible
4. New conversations will be stored unencrypted

## Testing

Use the provided test script to verify encryption functionality:

```bash
# Set your passphrase
export CODINGBUDDY_PASSPHRASE="test-passphrase-123"

# Run the test
lua test_crypto.lua
```

The test script will:
- Verify OpenSSL availability
- Check passphrase configuration
- Test basic crypto operations
- Test conversation saving/loading with both encryption modes
- Clean up test files

## Troubleshooting

### Common Issues

**"OpenSSL not available"**
- Install OpenSSL and ensure it's in your system PATH
- Test with: `openssl version`

**"CODINGBUDDY_PASSPHRASE environment variable not set"**
- Set the environment variable: `export CODINGBUDDY_PASSPHRASE="your-passphrase"`
- Make sure it's exported (visible to the Lua process)

**"openssl encryption/decryption failed"**
- Verify your passphrase is correct
- Check that you have read/write permissions to the conversations directory
- Ensure sufficient disk space

**"Failed to decrypt conversation for listing"**
- Usually indicates wrong passphrase or corrupted encrypted file
- Check the logs in `~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log`

### Debug Mode

Enable debug logging to troubleshoot issues:

```bash
export CODINGBUDDY_DEBUG=1
```

This will provide detailed logging of encryption/decryption operations.

## Technical Details

### Encryption Specifications
- **Algorithm**: AES-256-CBC (Cipher Block Chaining)
- **Key Derivation**: PBKDF2 with SHA-256
- **Iterations**: 100,000 (industry standard for 2024)
- **Salt**: Random 8-byte salt per file
- **Implementation**: OpenSSL command-line tool

### File Format
Encrypted files are binary and contain:
1. Salt (8 bytes)
2. Encrypted conversation data
3. Authentication data (HMAC)

### Performance
- Encryption/decryption adds minimal overhead for typical conversation sizes
- Listing conversations requires temporary decryption of encrypted files (slightly slower)
- File sizes increase slightly due to encryption overhead

## Best Practices

1. **Use Strong Passphrases**: Minimum 20 characters with mixed case, numbers, and symbols
2. **Environment Variable**: Always use environment variables for passphrases, never config files
3. **Backup Strategy**: Securely backup both your conversations directory and passphrase
4. **Regular Testing**: Periodically test decryption to ensure your setup works
5. **Migration Planning**: Plan encryption rollout carefully for existing conversation archives
6. **Monitoring**: Monitor logs for encryption/decryption errors

## API Changes

The conversation manager API remains unchanged. Encryption is handled transparently:

```lua
local conversation_manager = require('conversation_manager')

-- These functions work the same regardless of encryption status
conversation_manager.save_current_conversation()
conversation_manager.load_conversation(id)
conversation_manager.list_conversations()
conversation_manager.delete_conversation(id)
```

The `list_conversations()` function now returns an additional `encrypted` field indicating the storage format of each conversation.
