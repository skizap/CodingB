-- analyzer.lua - basic code analysis using OpenRouter (Phase 1)

local ai = require('codingbuddy.ai_connector')
local utils = require('codingbuddy.utils')

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

function M.analyze_code(input)
  local filename = input.filename or 'untitled'
  local code = input.code or ''

  local prompt = build_prompt(filename, code)
  local text, err = ai.chat({ prompt = prompt })
  if not text then
    return { ok = false, error = err, message = 'Error: '..tostring(err) }
  end

  return { ok = true, message = text }
end

return M

