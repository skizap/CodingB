-- CodingBuddy - GeanyLua plugin entry point (Phase 1)

local geany = rawget(_G, 'geany')

local analyzer = require('codingbuddy.analyzer')
local dialogs = require('codingbuddy.dialogs')
local config = require('codingbuddy.config')

local M = {}

local function analyze_current_buffer()
  local filename, text
  if geany then
    local buf = (geany.buffer and geany.buffer()) or (geany.fileinfo and geany.fileinfo())
    filename = (geany.filename and geany.filename()) or (buf and buf.name) or 'untitled'
    text = (geany.text and geany.text()) or ''
  else
    filename = 'untitled'
    text = ''
  end

  local ok, result = pcall(analyzer.analyze_code, {
    filename = filename,
    code = text
  })

  if not ok then
    dialogs.alert("CodingBuddy Error", tostring(result))
    return
  end

  if result and result.message then
    dialogs.show_text("CodingBuddy Analysis", result.message)
  else
    dialogs.alert("CodingBuddy", "No analysis response.")
  end
end

function M.init()
  -- register Tools menu item (only in Geany)
  if geany and geany.add_menu_item then
    geany.add_menu_item("CodingBuddy: Analyze Buffer", analyze_current_buffer)
    if geany.message then
      geany.message("CodingBuddy loaded. Use Tools > CodingBuddy: Analyze Buffer")
    end
  else
    print('CodingBuddy init (CLI mode)')
  end

  -- validate config
  local cfg = config.get()
  if not cfg.openrouter_api_key then
    if geany and geany.message then
      geany.message("CodingBuddy: OpenRouter API key not set. See README.md or config.json.")
    else
      print('CodingBuddy: OpenRouter API key not set. Set OPENROUTER_API_KEY or config.json')
    end
  end
end

return M

