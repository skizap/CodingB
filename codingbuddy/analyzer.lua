-- analyzer.lua - basic code analysis using OpenRouter (Phase 1)

local ai = require('ai_connector')
local config = require('config')
local utils = require('utils')

local M = {}

local function detect_language(filename)
  if filename:match('%.lua$') then return 'Lua' end
  if filename:match('%.py$') then return 'Python' end
  if filename:match('%.js$') then return 'JavaScript' end
  if filename:match('%.ts$') then return 'TypeScript' end
  if filename:match('%.rb$') then return 'Ruby' end
  if filename:match('%.go$') then return 'Go' end
  if filename:match('%.c$') or filename:match('%.h$') then return 'C' end
  if filename:match('%.cpp$') or filename:match('%.hpp$') then return 'C++' end
  if filename:match('%.java$') then return 'Java' end
  return 'Unknown'
end

local function build_prompt(filename, code)
  local lang = detect_language(filename)
  local header = (
    'You are reviewing a single file. Provide concise, actionable suggestions (max 10 bullets).\n'
    ..'Focus on correctness, readability, potential bugs, and small refactors.\n'
    ..'If there are obvious tests to add, mention them. Be brief.\n'
  )
  local body = string.format('Filename: %s\nLanguage: %s\n\nCode:\n%s', filename, lang, code)
  return header..'\n'..body
end

local function cache_path_for(code)
  local home = os.getenv('HOME') or '.'
  local base = home..'/.config/geany/plugins/geanylua/codingbuddy/cache'
  local key = utils.sha1(code)
  return base..'/'..key..'.txt'
end

local function read_cache(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local c = f:read('*a'); f:close(); return c
end

local function write_cache(path, content)
  local dir = path:match('^(.+)/[^/]+$')
  if dir then os.execute("mkdir -p '"..dir.."'") end
  local f = io.open(path, 'w'); if not f then return end
  f:write(content); f:close()
end

function M.analyze_code(input)
  local filename = input.filename or 'untitled'
  local code = input.code or ''

  local cfg = config.get()
  if cfg.cache_enabled then
    local p = cache_path_for(code)
    local cached = read_cache(p)
    if cached and #cached > 0 then
      return { ok = true, message = cached }
    end
  end

  local prompt = build_prompt(filename, code)
  local text, err = ai.chat({ prompt = prompt })
  if not text then
    return { ok = false, error = err, message = 'Error: '..tostring(err) }
  end

  if cfg.cache_enabled then
    local p = cache_path_for(code)
    local ts = os.date('!%Y-%m-%dT%H:%M:%SZ')
    local body = string.format('# CodingBuddy Analysis\n# Timestamp: %s\n# File: %s\n\n%s\n', ts, filename, text)
    write_cache(p, body)
  end

  return { ok = true, message = text }
end

return M

