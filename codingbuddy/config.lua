-- config.lua - loads user configuration for CodingBuddy
local M = {}

local defaults = {
  provider = 'openrouter',
  task_models = {
    analysis = 'anthropic/claude-3.5-sonnet',
  },
  cache_enabled = false,
  log_enabled = true,
  timeout = 30,
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
  -- minimal JSON parsing via lua's load - expect simple objects only
  -- For safety, prefer dkjson if available.
  local ok, dkjson = pcall(require, 'dkjson')
  if ok and dkjson then
    local obj, pos, err = dkjson.decode(s, 1, nil)
    if obj then return obj end
    return nil
  end
  return nil
end

local cached

function M.get()
  if cached then return cached end
  local cfg = {}
  -- load config.json
  local path = expanduser('~/.config/geany/plugins/geanylua/codingbuddy/config.json')
  local s = read_file(path)
  local obj = s and parse_json(s) or {}

  -- merge defaults
  for k,v in pairs(defaults) do
    if obj[k] == nil then obj[k] = v end
  end

  -- env override for key
  obj.openrouter_api_key = os.getenv('OPENROUTER_API_KEY') or obj.openrouter_api_key

  cached = obj
  return cached
end

return M

