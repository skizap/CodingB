local config = require('config')
local utils = require('utils')

local M = {}

local function get_workspace_root()
  local cfg = config.get()
  local root = cfg.workspace_root or os.getenv('CODINGBUDDY_WORKSPACE') or (os.getenv('PWD') or '.')
  return root
end

local function realpath_best_effort(p)
  local handle = io.popen('realpath -m -- "' .. p .. '"')
  if handle then
    local out = handle:read('*l')
    handle:close()
    if out and out ~= '' then return out end
  end
  -- Fallback naive normalization
  local path = p
  path = path:gsub('/%./', '/')
  while true do
    local n = path:gsub('/[^/]+/%.%./', '/')
    if n == path then break end
    path = n
  end
  path = path:gsub('//+', '/')
  return path
end

function M.to_abs(rel)
  if not rel or rel == '' then return nil, 'empty path' end
  local base = get_workspace_root()
  local abs = rel
  if not rel:match('^/') then
    abs = base .. '/' .. rel
  end
  return realpath_best_effort(abs), nil
end

function M.ensure_in_sandbox(abs)
  local root = realpath_best_effort(get_workspace_root())
  local target = realpath_best_effort(abs)
  if target:sub(1, #root) ~= root then
    return false, 'path escapes sandbox'
  end
  return true, nil
end

return M
