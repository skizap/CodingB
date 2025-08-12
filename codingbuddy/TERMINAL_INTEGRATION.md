# Terminal Integration with Policy Enforcement

This document describes the terminal integration feature in CodingBuddy, which provides a controlled way to run shell commands with allowlist and blocklist policies.

## Overview

The terminal integration consists of:
- `tools/terminal.lua` - Core terminal execution module with policy enforcement
- Policy configuration in `config.json` via `terminal_allow` and `terminal_deny` arrays
- Integration with the tools registry for AI model access

## Security Features

### Policy Enforcement
- **Allowlist**: Commands must begin with one of the allowed prefixes to execute
- **Blocklist**: Commands containing denied patterns are rejected regardless of allowlist
- **Precedence**: Deny list takes precedence over allow list

### Sandboxing
- All commands execute within the configured workspace root
- Working directory changes are restricted to sandbox boundaries
- Path traversal attempts are blocked

## Configuration

### Default Policies

**Allowed Commands** (safe for most development tasks):
```json
["ls", "rg", "grep", "sed", "awk", "python", "lua", "bash", "sh", "node", "npm", "cat", "head", "tail", "wc", "sort", "uniq", "find", "which", "echo", "pwd", "date", "git"]
```

**Denied Commands** (potentially dangerous operations):
```json
["rm -rf", "shutdown", "reboot", "mkfs", "dd if=", "cryptsetup", "sudo ", "su ", "chmod 777", "chown", "mount", "umount", "fdisk", "parted", "format"]
```

### Customization

Add to your `config.json`:
```json
{
  "terminal_allow": ["ls", "git", "npm", "python"],
  "terminal_deny": ["rm -rf", "sudo", "shutdown"]
}
```

## Usage

### Direct Module Usage
```lua
local terminal = require('tools.terminal')

-- Execute command
local result = terminal.run_command('ls -la')
if result.error then
    print("Error: " .. result.error)
else
    print("Exit code: " .. result.exit_code)
    print("Output: " .. result.stdout)
end

-- Execute with custom working directory
local result = terminal.run_command('pwd', 'subdir')
```

### Via Tools Registry
```lua
local registry = require('tools.registry')
local run_cmd_tool = registry.get_tool('run_command')

local result = run_cmd_tool.handler({
    cmd = 'echo "Hello World"',
    cwd_rel = '.'  -- optional
})
```

## API Reference

### terminal.run_command(cmd, cwd_rel)

**Parameters:**
- `cmd` (string): Command to execute
- `cwd_rel` (string, optional): Relative working directory

**Returns:**
- Success: `{ exit_code = number, stdout = string }`
- Error: `{ error = string }`

## Examples

### Safe Commands
```lua
-- These will execute successfully
terminal.run_command('ls -la')
terminal.run_command('git status') 
terminal.run_command('python --version')
terminal.run_command('echo "Hello"')
```

### Blocked Commands
```lua
-- These will be denied
terminal.run_command('sudo rm -rf /')     -- sudo denied
terminal.run_command('rm -rf *')          -- rm -rf denied
terminal.run_command('shutdown now')      -- shutdown denied
```

## Testing

Run the test suite:
```bash
cd codingbuddy
lua test_terminal.lua    # Test terminal module
lua test_registry.lua    # Test registry integration
```

## Security Considerations

1. **Policy Design**: Start with restrictive policies and expand as needed
2. **Command Validation**: Policies check command prefixes, not exact matches
3. **Workspace Isolation**: All operations are confined to the configured workspace
4. **Error Handling**: Failed commands return error messages instead of throwing exceptions
5. **Path Security**: Directory changes are validated against sandbox boundaries

## Future Enhancements

- Command timeout support
- Resource usage monitoring  
- Audit logging of executed commands
- Dynamic policy updates
- Command result caching
