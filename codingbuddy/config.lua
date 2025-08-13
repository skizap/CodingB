-- config.lua - loads user configuration for CodingBuddy
local M = {}

local defaults = {
  provider = 'openrouter',
  fallback_chain = { 'openrouter', 'openai', 'anthropic', 'deepseek', 'ollama' },
  task_models = {
    analysis = 'anthropic/claude-3.5-sonnet',
  },
  provider_models = {
    openrouter = 'anthropic/claude-3.5-sonnet',
    openai = 'gpt-4o-mini',
    anthropic = 'claude-3-5-sonnet-latest',
    deepseek = 'deepseek-chat',
    ollama = 'llama3.1',
  },
  workspace_root = nil, -- defaults to PWD or current working directory
  cache_enabled = false,
  log_enabled = true,
  timeout = 30,
  conversation_encryption = false, -- Encrypt conversation files at rest (requires CODINGBUDDY_PASSPHRASE env var)
  -- Terminal policy configuration with safe defaults
  terminal_allow = { 'ls', 'rg', 'grep', 'sed', 'awk', 'python', 'lua', 'bash', 'sh', 'node', 'npm', 'cat', 'head', 'tail', 'wc', 'sort', 'uniq', 'find', 'which', 'echo', 'pwd', 'date', 'git' },
  terminal_deny = { 'rm -rf', 'shutdown', 'reboot', 'mkfs', 'dd if=', 'cryptsetup', 'sudo ', 'su ', 'chmod 777', 'chown', 'mount', 'umount', 'fdisk', 'parted', 'format' },
  cost = {
    enabled = true,
    prices_per_1k = {
      openai = { default_input = 0.003, default_output = 0.006 },
      anthropic = { default_input = 0.003, default_output = 0.015 },
      openrouter = { default_input = 0.0, default_output = 0.0 },
      deepseek = { default_input = 0.002, default_output = 0.002 },
      ollama = { default_input = 0.0, default_output = 0.0 }
    },
    currency = 'USD'
  },
  -- Optional MultiappV1 Tauri Sidecar integration
  sidecar_enabled = false,
  sidecar_url = 'http://localhost:8765',
  sidecar_auto_approve_read_ops = true
}

local function expanduser(path)
  local home = os.getenv('HOME') or ''
  return path:gsub('^~', home)
end

local function read_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local c = f:read('*a')
  f:close()
  return c
end

local function parse_json(s)
  -- prefer dkjson if available.
  local ok, dkjson = pcall(require, 'dkjson')
  if ok and dkjson then
    local obj = dkjson.decode(s, 1, nil)
    if obj then return obj end
  end
  return nil
end

local cached

function M.get()
  if cached then return cached end
  -- load config.json
  local path = expanduser('~/.config/geany/plugins/geanylua/codingbuddy/config.json')
  local s = read_file(path)
  local obj = s and parse_json(s) or {}

  -- merge defaults (shallow)
  for k,v in pairs(defaults) do
    if obj[k] == nil then obj[k] = v end
  end

  -- env overrides for keys
  obj.openrouter_api_key = os.getenv('OPENROUTER_API_KEY') or obj.openrouter_api_key
  obj.openai_api_key = os.getenv('OPENAI_API_KEY') or obj.openai_api_key
  obj.anthropic_api_key = os.getenv('ANTHROPIC_API_KEY') or obj.anthropic_api_key
  obj.deepseek_api_key = os.getenv('DEEPSEEK_API_KEY') or obj.deepseek_api_key

  cached = obj
  return cached
end

return M

