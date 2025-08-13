local utils = require('utils')
local path = require('tools.path')

local M = {}

function M.read_file(abs)
  local f = io.open(abs, 'rb')
  if not f then return nil, 'cannot open file' end
  local data = f:read('*all')
  f:close()
  return data
end

function M.write_file_atomic(abs, content)
  local dir = abs:match('^(.*)/[^/]+$')
  if dir then os.execute('mkdir -p "' .. dir .. '"') end
  local tmp = abs .. '.tmp.' .. tostring(os.time())
  local f, err = io.open(tmp, 'wb')
  if not f then return false, 'open temp failed: ' .. tostring(err) end
  f:write(content or '')
  f:flush()
  f:close()
  local ok, rerr = os.rename(tmp, abs)
  if not ok then return false, 'rename failed: ' .. tostring(rerr) end
  return true
end

function M.mkdir_p_for_file(abs)
  local dir = abs:match('^(.*)/[^/]+$')
  if dir then os.execute('mkdir -p "' .. dir .. '"') end
end

function M.list_dir(abs)
  local handle = io.popen('ls -a "' .. abs .. '"')
  if not handle then return nil, 'ls failed' end
  local out = handle:read('*all')
  handle:close()
  local entries = {}
  for line in out:gmatch('[^\n]+') do
    if line ~= '.' and line ~= '..' then
      table.insert(entries, line)
    end
  end
  return entries
end

function M.exists(abs)
  local f = io.open(abs, 'r')
  if f then
    f:close()
    return true
  end
  return false
end

function M.search(root_abs, query)
  local cmd = 'rg --no-heading --line-number --color never "' .. query:gsub('"', '\\"') .. '" "' .. root_abs .. '"'
  local h = io.popen(cmd)
  if not h then return nil, 'ripgrep not available' end
  local out = h:read('*all'); h:close()
  local results = {}
  for line in out:gmatch('[^\n]+') do
    local file, lineno, text = line:match('^(.-):(%d+):(.*)$')
    if file and lineno then
      table.insert(results, { file = file, line = tonumber(lineno), text = text })
    end
  end
  return results
end

return M
