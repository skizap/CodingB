-- codingbuddy/json.lua - Pure Lua JSON encoder/decoder with unicode + strict numbers
-- Public API: json.encode(value) -> string, json.decode(s) -> value or nil, err, pos
-- Focus: correctness for typical API payloads; error messages with index

local json = {}

-- Encode
local function utf8_encode(code)
  if code <= 0x7F then
    return string.char(code)
  elseif code <= 0x7FF then
    local b1 = 0xC0 + math.floor(code / 0x40)
    local b2 = 0x80 + (code % 0x40)
    return string.char(b1, b2)
  elseif code <= 0xFFFF then
    local b1 = 0xE0 + math.floor(code / 0x1000)
    local b2 = 0x80 + (math.floor(code / 0x40) % 0x40)
    local b3 = 0x80 + (code % 0x40)
    return string.char(b1, b2, b3)
  elseif code <= 0x10FFFF then
    local b1 = 0xF0 + math.floor(code / 0x40000)
    local b2 = 0x80 + (math.floor(code / 0x1000) % 0x40)
    local b3 = 0x80 + (math.floor(code / 0x40) % 0x40)
    local b4 = 0x80 + (code % 0x40)
    return string.char(b1, b2, b3, b4)
  else
    return ""
  end
end

local function is_array(tbl)
  local n = 0
  for k,_ in pairs(tbl) do
    if type(k) ~= 'number' then return false end
    n = n + 1
  end
  for i=1,n do if tbl[i] == nil then return false end end
  return true
end

local function esc_str(s)
  s = s:gsub('\\', '\\\\')
       :gsub('"', '\\"')
       :gsub('\b', '\\b')
       :gsub('\f', '\\f')
       :gsub('\n', '\\n')
       :gsub('\r', '\\r')
       :gsub('\t', '\\t')
  return '"'..s..'"'
end

local function enc(v)
  local t = type(v)
  if t == 'nil' then return 'null'
  elseif t == 'boolean' then return v and 'true' or 'false'
  elseif t == 'number' then
    -- Encode numbers as-is; assume number is finite
    if v ~= v or v == math.huge or v == -math.huge then return 'null' end
    return tostring(v)
  elseif t == 'string' then return esc_str(v)
  elseif t == 'table' then
    if is_array(v) then
      local parts = {}
      for i=1,#v do parts[#parts+1] = enc(v[i]) end
      return '['..table.concat(parts, ',')..']'
    else
      local parts = {}
      for k,val in pairs(v) do
        parts[#parts+1] = esc_str(tostring(k))..":"..enc(val)
      end
      return '{'..table.concat(parts, ',')..'}'
    end
  else
    return esc_str(tostring(v))
  end
end

function json.encode(v)
  return enc(v)
end

-- Decode
local function error_at(s, i, msg)
  return nil, string.format("JSON error at %d: %s", i, msg), i
end

local function skip_ws(s, i)
  local _,j = s:find('^[ \t\n\r]+', i); return (j or i-1)+1
end

local function parse_hex4(s, i)
  local hex = s:sub(i, i+3)
  if not hex:match('^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$') then
    return nil, i, 'bad unicode escape'
  end
  return tonumber(hex, 16), i+4
end

local function parse_string(s, i)
  i = i + 1 -- skip opening quote
  local out = {}
  while i <= #s do
    local c = s:sub(i,i)
    if c == '"' then return table.concat(out), i+1 end
    if c == '\\' then
      local n = s:sub(i+1,i+1)
      if n == '"' then out[#out+1] = '"'; i = i + 2
      elseif n == '\\' then out[#out+1] = '\\'; i = i + 2
      elseif n == '/' then out[#out+1] = '/'; i = i + 2
      elseif n == 'b' then out[#out+1] = '\b'; i = i + 2
      elseif n == 'f' then out[#out+1] = '\f'; i = i + 2
      elseif n == 'n' then out[#out+1] = '\n'; i = i + 2
      elseif n == 'r' then out[#out+1] = '\r'; i = i + 2
      elseif n == 't' then out[#out+1] = '\t'; i = i + 2
      elseif n == 'u' then
        local cp, ni, err = parse_hex4(s, i+2)
        if not cp then return error_at(s, i, err or 'unicode') end
        i = ni
        -- handle surrogate pairs
        if cp >= 0xD800 and cp <= 0xDBFF and s:sub(i,i+1) == '\\u' then
          local low, ni2, err2 = parse_hex4(s, i+2)
          if not low then return error_at(s, i, err2 or 'low surrogate') end
          if low < 0xDC00 or low > 0xDFFF then return error_at(s, i, 'invalid low surrogate') end
          cp = 0x10000 + ((cp - 0xD800) * 0x400) + (low - 0xDC00)
          i = ni2
        end
        out[#out+1] = utf8_encode(cp)
      else
        return error_at(s, i, 'invalid escape')
      end
    else
      out[#out+1] = c
      i = i + 1
    end
  end
  return error_at(s, i, 'unterminated string')
end

local function parse_number(s, i)
  local start = i
  -- JSON number: -?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?
  if s:sub(i,i) == '-' then i = i + 1 end
  if s:sub(i,i) == '0' then
    i = i + 1
  else
    if not s:sub(i,i):match('[1-9]') then return error_at(s, i, 'invalid number') end
    i = i + 1
    while i <= #s and s:sub(i,i):match('%d') do i = i + 1 end
  end
  if s:sub(i,i) == '.' then
    i = i + 1
    if not s:sub(i,i):match('%d') then return error_at(s, i, 'invalid fraction') end
    while i <= #s and s:sub(i,i):match('%d') do i = i + 1 end
  end
  local c = s:sub(i,i)
  if c == 'e' or c == 'E' then
    i = i + 1
    local c2 = s:sub(i,i)
    if c2 == '+' or c2 == '-' then i = i + 1 end
    if not s:sub(i,i):match('%d') then return error_at(s, i, 'invalid exponent') end
    while i <= #s and s:sub(i,i):match('%d') do i = i + 1 end
  end
  local num = tonumber(s:sub(start, i-1))
  if num == nil then return error_at(s, start, 'bad number') end
  return num, i
end

local parse_value -- fwd decl

local function parse_array(s, i)
  i = i + 1 -- skip [
  local arr = {}
  i = skip_ws(s, i)
  if s:sub(i,i) == ']' then return arr, i+1 end
  while true do
    local v; v, i = parse_value(s, i)
    if v == nil and type(i) == 'number' then return v, i end -- propagate error
    arr[#arr+1] = v
    i = skip_ws(s, i)
    local ch = s:sub(i,i)
    if ch == ']' then return arr, i+1 end
    if ch ~= ',' then return error_at(s, i, 'expected , or ]') end
    i = i + 1
  end
end

local function parse_object(s, i)
  i = i + 1 -- skip {
  local obj = {}
  i = skip_ws(s, i)
  if s:sub(i,i) == '}' then return obj, i+1 end
  while true do
    if s:sub(i,i) ~= '"' then return error_at(s, i, 'expected string key') end
    local k; k, i = parse_string(s, i)
    if k == nil then return k, i end
    i = skip_ws(s, i)
    if s:sub(i,i) ~= ':' then return error_at(s, i, 'expected :') end
    i = i + 1
    local v; v, i = parse_value(s, i)
    if v == nil and type(i) == 'number' then return v, i end
    obj[k] = v
    i = skip_ws(s, i)
    local ch = s:sub(i,i)
    if ch == '}' then return obj, i+1 end
    if ch ~= ',' then return error_at(s, i, 'expected , or }') end
    i = i + 1
  end
end

parse_value = function(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i,i)
  if c == '"' then return parse_string(s, i)
  elseif c == '{' then return parse_object(s, i)
  elseif c == '[' then return parse_array(s, i)
  elseif c == '-' or c:match('%d') then return parse_number(s, i)
  elseif s:sub(i,i+3) == 'true' then return true, i+4
  elseif s:sub(i,i+4) == 'false' then return false, i+5
  elseif s:sub(i,i+3) == 'null' then return nil, i+4
  else return error_at(s, i, 'unexpected char '..(c or 'EOF')) end
end

function json.decode(s)
  if type(s) ~= 'string' then return nil, 'expected string', 1 end
  local v, i_or_err, pos = parse_value(s, 1)
  if v == nil and type(i_or_err) == 'string' then
    return nil, i_or_err, pos
  end
  local i = i_or_err
  i = skip_ws(s, i)
  if i <= #s then
    return nil, string.format('trailing data at %d', i), i
  end
  return v
end

return json

