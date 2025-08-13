-- CodingBuddy - GeanyLua plugin entry point (Phase 1)

local geany = rawget(_G, 'geany')

-- Load utilities first for logging
local utils = require('utils')

-- Initialize Sentry error tracking (optional)
local sentry = nil
local ok, sentry_module = pcall(require, 'sentry')
if ok then
  sentry = sentry_module
  -- Initialize Sentry if DSN is configured
  local sentry_dsn = os.getenv('SENTRY_DSN')
  if sentry_dsn then
    sentry.init({
      dsn = sentry_dsn,
      environment = os.getenv('CODINGBUDDY_ENV') or 'development',
      release = 'codingbuddy@1.0.0'
    })
    sentry.integrate_with_logging()
    utils.log_info('Sentry error tracking enabled')
  else
    utils.log_debug('Sentry DSN not configured, error tracking disabled')
  end
else
  utils.log_debug('Sentry module not available: ' .. tostring(sentry_module))
end

-- Safe module loading with error handling
local function safe_require(module_name)
  local ok, module = pcall(require, module_name)
  if not ok then
    utils.log_error('Failed to load module: ' .. module_name, module)

    -- Report to Sentry if available
    if sentry then
      sentry.capture_exception(module, {
        module_name = module_name,
        context = 'module_loading'
      })
    end

    if geany and geany.message then
      geany.message('CodingBuddy: Failed to load ' .. module_name .. '\nError: ' .. tostring(module))
    end
    return nil
  end
  utils.log_debug('Successfully loaded module: ' .. module_name)
  return module
end

-- Load modules with error handling
local analyzer = safe_require('analyzer')
local dialogs = safe_require('dialogs')
local config = safe_require('config')
local chat_interface = safe_require('chat_interface')
local sidecar_connector = safe_require('sidecar_connector')  -- Optional sidecar integration

local M = {}

-- Check if all required modules loaded successfully
local function check_modules()
  local missing = {}
  if not analyzer then table.insert(missing, 'analyzer') end
  if not dialogs then table.insert(missing, 'dialogs') end
  if not config then table.insert(missing, 'config') end
  if not chat_interface then table.insert(missing, 'chat_interface') end

  if #missing > 0 then
    local error_msg = 'CodingBuddy: Missing required modules: ' .. table.concat(missing, ', ')
    utils.log_error(error_msg)
    if geany and geany.message then
      geany.message(error_msg .. '\n\nPlease check installation and dependencies.')
    end
    return false
  end
  return true
end

local function analyze_current_buffer()
  utils.log_info('Starting buffer analysis')

  -- Check if modules are available
  if not check_modules() then
    return
  end

  local filename, text
  if geany then
    local buf = (geany.buffer and geany.buffer()) or (geany.fileinfo and geany.fileinfo())
    filename = (geany.filename and geany.filename()) or (buf and buf.name) or 'untitled'
    text = (geany.text and geany.text()) or ''
  else
    filename = 'untitled'
    text = ''
  end

  utils.log_debug('Analyzing file: ' .. filename .. ' (' .. #text .. ' characters)')

  local ok, result = pcall(analyzer.analyze_code, {
    filename = filename,
    code = text
  })

  if not ok then
    utils.log_error('Analysis failed', result)
    if dialogs then
      dialogs.alert("CodingBuddy Error", tostring(result))
    end
    return
  end

  if result and result.message then
    utils.log_info('Analysis completed successfully')
    if dialogs then
      dialogs.show_text("CodingBuddy Analysis", result.message)
    end
  else
    utils.log_warning('Analysis returned no results')
    if dialogs then
      dialogs.alert("CodingBuddy", "No analysis response.")
    end
  end
end

function M.init()
  -- Bootstrap required directories
  local home = os.getenv('HOME') or '.'
  local base_dir = home .. '/.config/geany/plugins/geanylua/codingbuddy'
  
  -- Ensure required directories exist
  local required_dirs = {
    base_dir .. '/conversations',
    base_dir .. '/logs',
    base_dir .. '/cache'
  }
  
  for _, dir in ipairs(required_dirs) do
    local success, err = utils.ensure_dir(dir)
    if success then
      utils.log_debug('Directory ensured: ' .. dir)
    else
      utils.log_error('Failed to create directory: ' .. dir, err)
      -- Don't fail initialization for directory creation errors
    end
  end
  
  -- register Tools menu items (only in Geany)
  if geany and geany.add_menu_item then
    geany.add_menu_item("CodingBuddy: Analyze Buffer", analyze_current_buffer)
    geany.add_menu_item("CodingBuddy: Open Chat", chat_interface.open_chat)
    geany.add_menu_item("CodingBuddy: Analyze with Chat", chat_interface.analyze_current_buffer_with_chat)
    if geany.message then
      geany.message("CodingBuddy loaded. Use Tools menu for CodingBuddy options")
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

