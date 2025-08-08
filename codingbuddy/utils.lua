-- utils.lua - helpers
local M = {}

function M.sha1(s)
  -- try to use openssl via io.popen for simplicity (dev env)
  local f = io.popen("printf '%s' '"..s:gsub("'","'\\''").."' | sha1sum 2>/dev/null | awk '{print $1}'")
  if f then
    local out = f:read('*l')
    f:close()
    return out
  end
  return tostring(#s)..'_'..string.sub(s,1,8)
end

function M.write_file(path, content)
  local dir = path:match('^(.+)/[^/]+$')
  if dir then os.execute("mkdir -p '"..dir.."'") end
  local f, err = io.open(path, 'w')
  if not f then return nil, err end
  f:write(content)
  f:close()
  return true
end

function M.append_file(path, content)
  local dir = path:match('^(.+)/[^/]+$')
  if dir then os.execute("mkdir -p '"..dir.."'") end
  local f, err = io.open(path, 'a')
  if not f then return nil, err end
  f:write(content)
  f:close()
  return true
end

function M.read_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local c = f:read('*a')
  f:close()
  return c
end

function M.expanduser(path)
  local home = os.getenv('HOME') or ''
  return path:gsub('^~', home)
end

function M.log(tag, message)
  local home = os.getenv('HOME') or '.'
  local base = home..'/.config/geany/plugins/geanylua/codingbuddy/logs'
  local ts = os.date('!%Y-%m-%dT%H:%M:%SZ')
  local line = string.format('[%s] %s: %s\n', ts, tag or 'LOG', tostring(message))
  M.append_file(base..'/codingbuddy.log', line)
end

return M

