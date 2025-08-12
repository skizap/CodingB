local path = require('tools.path')
local config = require('config')

local M = {}

-- Get policy configuration with secure defaults
local function get_policy()
  local cfg = config.get()
  return {
    allow = cfg.terminal_allow or { 'ls', 'rg', 'grep', 'sed', 'awk', 'python', 'lua', 'bash', 'sh', 'node', 'npm' },
    deny = cfg.terminal_deny or { 'rm -rf', 'shutdown', 'reboot', 'mkfs', 'dd if=', 'cryptsetup', 'sudo ' }
  }
end

-- Check if a command is allowed by policy
local function is_allowed(cmd)
  local policy = get_policy()
  
  -- First check deny list (takes precedence)
  for _, d in ipairs(policy.deny) do
    if cmd:find(d, 1, true) then 
      return false, 'command denied by policy: ' .. d 
    end
  end
  
  -- If allowlist is empty, allow everything not explicitly denied
  if #policy.allow == 0 then 
    return true 
  end
  
  -- Check allowlist
  for _, a in ipairs(policy.allow) do
    if cmd:find(a, 1, true) then 
      return true 
    end
  end
  
  return false, 'command not in allowlist'
end

-- Execute a shell command with policy enforcement and sandboxing
function M.run_command(cmd, cwd_rel)
  -- Validate command against policy
  local ok, reason = is_allowed(cmd)
  if not ok then
    return { error = reason }
  end
  
  -- Handle working directory if specified
  local cwd_abs
  if cwd_rel and cwd_rel ~= '' then
    local abs, err = path.to_abs(cwd_rel)
    if not abs then 
      return { error = err } 
    end
    
    local ok2, err2 = path.ensure_in_sandbox(abs)
    if not ok2 then 
      return { error = err2 } 
    end
    
    cwd_abs = abs
  end
  
  -- Construct command with directory change if needed
  local prefix = ''
  if cwd_abs then
    prefix = 'cd "' .. cwd_abs .. '" && '
  end
  
  -- Execute command
  local handle = io.popen(prefix .. cmd)
  if not handle then 
    return { error = 'failed to start command' } 
  end
  
  local out = handle:read('*all')
  local ok3, why, code = handle:close()
  
  local exit_code = 0
  if not ok3 then
    exit_code = tonumber(code) or 1
  end
  
  return { 
    exit_code = exit_code, 
    stdout = out or '' 
  }
end

return M
