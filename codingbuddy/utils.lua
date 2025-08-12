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

-- Enhanced logging with debug mode support
M.debug_mode = os.getenv("CODINGBUDDY_DEBUG") == "1" or false

function M.log(tag, message, error_obj)
  local home = os.getenv('HOME') or '.'
  local base = home..'/.config/geany/plugins/geanylua/codingbuddy/logs'
  local ts = os.date('!%Y-%m-%dT%H:%M:%SZ')
  local line = string.format('[%s] %s: %s', ts, tag or 'LOG', tostring(message))

  -- Add error details if provided
  if error_obj then
    line = line .. '\nError details: ' .. tostring(error_obj)
  end

  line = line .. '\n'

  -- Always log errors and warnings, only log debug/info if debug mode enabled
  if tag == 'ERROR' or tag == 'WARNING' or M.debug_mode then
    M.append_file(base..'/codingbuddy.log', line)

    -- Print to console if debug mode
    if M.debug_mode then
      print(line:gsub('\n$', ''))
    end
  end

  -- Show errors in Geany if available
  if tag == 'ERROR' and geany and geany.message then
    geany.message('CodingBuddy Error: ' .. tostring(message))
  end
end

-- Convenience logging functions
function M.log_debug(message) M.log('DEBUG', message) end
function M.log_info(message) M.log('INFO', message) end
function M.log_warning(message) M.log('WARNING', message) end
function M.log_error(message, error_obj) M.log('ERROR', message, error_obj) end

-- Safe function execution with error handling
function M.safe_execute(func, func_name, ...)
  local args = {...}
  func_name = func_name or 'unknown function'

  M.log_debug('Executing: ' .. func_name)

  local ok, result = pcall(func, unpack(args))
  if not ok then
    M.log_error('Failed to execute ' .. func_name, result)
    return nil, result
  end

  M.log_debug('Successfully executed: ' .. func_name)
  return result
end

-- Directory and file operations
function M.ensure_dir(path)
  if not path or path == '' then
    return false, 'invalid path'
  end
  
  -- Use mkdir -p for reliable directory creation
  local cmd = 'mkdir -p "' .. path:gsub('"', '\\"') .. '"'
  local result = os.execute(cmd)
  
  -- os.execute returns different values on different Lua versions
  -- In Lua 5.1, it returns exit status directly
  -- In Lua 5.2+, it returns true/false, "exit", exit_code
  if type(result) == 'boolean' then
    return result
  else
    -- Lua 5.1 behavior - 0 means success
    return result == 0
  end
end

function M.safe_read_all(path)
  if not path or path == '' then
    return nil, 'invalid path'
  end
  
  local f, err = io.open(path, 'rb')
  if not f then
    return nil, 'cannot open file for reading: ' .. tostring(path) .. ' (' .. tostring(err) .. ')'
  end
  
  local data = f:read('*all') or ''
  f:close()
  return data
end

function M.safe_write_all(path, data)
  if not path or path == '' then
    return false, 'invalid path'
  end
  
  data = data or ''
  
  -- Create a temporary file with timestamp to avoid conflicts
  local tmp = path .. '.tmp.' .. tostring(os.time()) .. '.' .. math.random(1000, 9999)
  
  local f, err = io.open(tmp, 'wb')
  if not f then
    return false, 'cannot open temp file: ' .. tostring(err)
  end
  
  f:write(data)
  f:flush()
  f:close()
  
  -- Atomic move from temporary to final location
  local move_cmd
  if os.getenv('OS') == 'Windows_NT' then
    move_cmd = 'move "' .. tmp .. '" "' .. path .. '"'
  else
    move_cmd = 'mv "' .. tmp:gsub('"', '\\"') .. '" "' .. path:gsub('"', '\\"') .. '"'
  end
  
  local result = os.execute(move_cmd)
  local success
  if type(result) == 'boolean' then
    success = result
  else
    success = result == 0
  end
  
  if not success then
    -- Clean up temp file on failure
    os.remove(tmp)
    return false, 'atomic rename/move failed'
  end
  
  return true
end

-- Simple JSON encoding/decoding fallback (when dkjson is not available)
function M.simple_json_encode(obj)
  local function encode_value(val)
    local t = type(val)
    if t == 'string' then
      return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif t == 'number' then
      return tostring(val)
    elseif t == 'boolean' then
      return val and 'true' or 'false'
    elseif t == 'nil' then
      return 'null'
    elseif t == 'table' then
      -- Check if it's an array
      local is_array = true
      local max_idx = 0
      for k, _ in pairs(val) do
        if type(k) ~= 'number' or k <= 0 or k ~= math.floor(k) then
          is_array = false
          break
        end
        max_idx = math.max(max_idx, k)
      end

      if is_array then
        local parts = {}
        for i = 1, max_idx do
          table.insert(parts, encode_value(val[i]))
        end
        return '[' .. table.concat(parts, ',') .. ']'
      else
        local parts = {}
        for k, v in pairs(val) do
          table.insert(parts, encode_value(tostring(k)) .. ':' .. encode_value(v))
        end
        return '{' .. table.concat(parts, ',') .. '}'
      end
    else
      return 'null'
    end
  end

  return encode_value(obj)
end

function M.simple_json_decode(str)
  -- Very basic JSON decoder - only handles simple cases
  -- For production use, dkjson should be preferred
  if not str or str == '' then
    return nil
  end

  -- Remove leading/trailing whitespace
  str = str:gsub('^%s+', ''):gsub('%s+$', '')
  
  -- Very simple approach: try to parse it using our knowledge of the structure
  -- This is a workaround until dkjson is available
  if str:match('^%s*{.*}%s*$') then
    -- It's an object - try a simple substitution approach
    local lua_str = str
      :gsub('null', 'nil')
      :gsub('true', 'true') 
      :gsub('false', 'false')
    
    -- Convert "key": to ["key"] = for object keys
    lua_str = lua_str:gsub('"([^"]+)":', '[%1]=')
    
    -- Try to evaluate it as a Lua table
    local loader = loadstring or load
    if loader then
      local ok, compiled_func = pcall(loader, 'return ' .. lua_str)
      if ok and compiled_func then
        local success, result = pcall(compiled_func)
        if success then
          return result
        end
      end
    end
  elseif str:match('^%s*%[.*%]%s*$') then
    -- It's an array
    local lua_str = str
      :gsub('null', 'nil')
      :gsub('true', 'true')
      :gsub('false', 'false')
    
    local loader = loadstring or load
    if loader then
      local ok, compiled_func = pcall(loader, 'return ' .. lua_str)
      if ok and compiled_func then
        local success, result = pcall(compiled_func)
        if success then
          return result
        end
      end
    end
  end
  
  -- If all else fails, return nil
  return nil
end

return M

