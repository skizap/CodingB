-- sentry.lua - Sentry error tracking integration for CodingBuddy
-- Automatically captures and reports runtime errors to help with debugging

local M = {}

local utils = require('utils')
local json = require('json')

-- Sentry configuration
M.config = {
  dsn = nil,  -- Set via environment variable or config
  enabled = false,
  environment = 'production',
  release = 'codingbuddy@1.0.0',
  sample_rate = 1.0,
  max_breadcrumbs = 100
}

-- Internal state
local breadcrumbs = {}
local context = {}

-- Initialize Sentry integration
function M.init(opts)
  opts = opts or {}
  
  -- Get DSN from environment or config
  M.config.dsn = opts.dsn or os.getenv('SENTRY_DSN')
  
  if not M.config.dsn then
    utils.log_debug('Sentry DSN not configured, error tracking disabled')
    return false
  end
  
  -- Update configuration
  for k, v in pairs(opts) do
    M.config[k] = v
  end
  
  M.config.enabled = true
  utils.log_info('Sentry error tracking initialized')
  
  -- Set up global error handler
  M.setup_error_handler()
  
  return true
end

-- Parse Sentry DSN
local function parse_dsn(dsn)
  local protocol, public_key, secret_key, host, port, path, project_id = 
    dsn:match('([^:]+)://([^:]+):?([^@]*)@([^:/]+):?(%d*)(.*)/(%d+)')
  
  if not protocol then
    utils.log_error('Invalid Sentry DSN format')
    return nil
  end
  
  return {
    protocol = protocol,
    public_key = public_key,
    secret_key = secret_key,
    host = host,
    port = port ~= '' and tonumber(port) or (protocol == 'https' and 443 or 80),
    path = path,
    project_id = project_id
  }
end

-- Add breadcrumb for debugging context
function M.add_breadcrumb(message, category, level, data)
  if not M.config.enabled then return end
  
  local breadcrumb = {
    timestamp = os.time(),
    message = message,
    category = category or 'default',
    level = level or 'info',
    data = data or {}
  }
  
  table.insert(breadcrumbs, breadcrumb)
  
  -- Keep only recent breadcrumbs
  if #breadcrumbs > M.config.max_breadcrumbs then
    table.remove(breadcrumbs, 1)
  end
  
  utils.log_debug('Added breadcrumb: ' .. message)
end

-- Set user context
function M.set_user(user_data)
  context.user = user_data
end

-- Set additional context
function M.set_context(key, data)
  context[key] = data
end

-- Capture exception
function M.capture_exception(error_obj, extra_data)
  if not M.config.enabled then
    utils.log_debug('Sentry disabled, not capturing exception: ' .. tostring(error_obj))
    return
  end
  
  utils.log_info('Capturing exception for Sentry: ' .. tostring(error_obj))
  
  local event = M.create_event('error', {
    exception = {
      values = {
        {
          type = 'LuaError',
          value = tostring(error_obj),
          stacktrace = M.get_stacktrace()
        }
      }
    },
    extra = extra_data or {}
  })
  
  M.send_event(event)
end

-- Capture message
function M.capture_message(message, level, extra_data)
  if not M.config.enabled then return end
  
  local event = M.create_event('message', {
    message = {
      message = message,
      params = {}
    },
    level = level or 'info',
    extra = extra_data or {}
  })
  
  M.send_event(event)
end

-- Create Sentry event
function M.create_event(event_type, data)
  local event = {
    event_id = M.generate_uuid(),
    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    platform = 'lua',
    sdk = {
      name = 'codingbuddy-lua',
      version = '1.0.0'
    },
    environment = M.config.environment,
    release = M.config.release,
    contexts = {
      runtime = {
        name = 'Lua',
        version = _VERSION
      },
      os = {
        name = M.get_os_name()
      }
    },
    breadcrumbs = {
      values = breadcrumbs
    }
  }
  
  -- Add user context if available
  if context.user then
    event.user = context.user
  end
  
  -- Add additional context
  for k, v in pairs(context) do
    if k ~= 'user' then
      event.contexts[k] = v
    end
  end
  
  -- Merge event-specific data
  for k, v in pairs(data) do
    event[k] = v
  end
  
  return event
end

-- Get simple stacktrace
function M.get_stacktrace()
  local frames = {}
  local level = 3  -- Skip this function and pcall
  
  while true do
    local info = debug.getinfo(level, 'Sln')
    if not info then break end
    
    table.insert(frames, {
      filename = info.source or 'unknown',
      function_name = info.name or 'anonymous',
      lineno = info.currentline or 0
    })
    
    level = level + 1
    if level > 20 then break end  -- Prevent infinite loops
  end
  
  return { frames = frames }
end

-- Generate UUID for event ID
function M.generate_uuid()
  local chars = '0123456789abcdef'
  local uuid = ''
  for i = 1, 32 do
    local rand = math.random(1, 16)
    uuid = uuid .. chars:sub(rand, rand)
    if i == 8 or i == 12 or i == 16 or i == 20 then
      uuid = uuid .. '-'
    end
  end
  return uuid
end

-- Get OS name
function M.get_os_name()
  local handle = io.popen('uname -s 2>/dev/null')
  if handle then
    local result = handle:read('*l')
    handle:close()
    return result or 'unknown'
  end
  return 'unknown'
end

-- Send event to Sentry
function M.send_event(event)
  local dsn_info = parse_dsn(M.config.dsn)
  if not dsn_info then
    utils.log_error('Cannot send to Sentry: invalid DSN')
    return false
  end
  
  -- Serialize event to JSON
  local event_json = json.encode(event)
  if not event_json then
    utils.log_error('Failed to serialize Sentry event to JSON')
    return false
  end
  
  -- Prepare HTTP request
  local url = string.format('%s://%s:%d%s/api/%s/store/',
    dsn_info.protocol, dsn_info.host, dsn_info.port, dsn_info.path, dsn_info.project_id)
  
  local auth_header = string.format('Sentry sentry_version=7,sentry_key=%s,sentry_client=codingbuddy-lua/1.0.0',
    dsn_info.public_key)
  
  -- Send via lua-socket if available
  local ok, result = pcall(function()
    local http = require('socket.http')
    local ltn12 = require('ltn12')
    
    local response_body = {}
    
    local result, status = http.request{
      url = url,
      method = 'POST',
      headers = {
        ['Content-Type'] = 'application/json',
        ['X-Sentry-Auth'] = auth_header,
        ['Content-Length'] = #event_json
      },
      source = ltn12.source.string(event_json),
      sink = ltn12.sink.table(response_body)
    }
    
    return status == 200
  end)
  
  if ok and result then
    utils.log_debug('Successfully sent event to Sentry')
    return true
  else
    utils.log_warning('Failed to send event to Sentry: ' .. tostring(result))
    return false
  end
end

-- Set up global error handler
function M.setup_error_handler()
  -- Override global error handler if possible
  if debug and debug.sethook then
    local original_error = error
    
    _G.error = function(message, level)
      M.capture_exception(message, {
        level = level or 1,
        source = 'global_error'
      })
      return original_error(message, level)
    end
  end
end

-- Wrap function with error tracking
function M.wrap_function(func, func_name)
  return function(...)
    local args = {...}
    
    M.add_breadcrumb('Function called: ' .. (func_name or 'anonymous'), 'function', 'info')
    
    local ok, result = pcall(func, unpack(args))
    if not ok then
      M.capture_exception(result, {
        function_name = func_name,
        arguments = args
      })
      error(result)  -- Re-raise the error
    end
    
    return result
  end
end

-- Integration with CodingBuddy utils logging
function M.integrate_with_logging()
  local original_log_error = utils.log_error
  
  utils.log_error = function(message, error_obj)
    -- Call original logging
    original_log_error(message, error_obj)
    
    -- Also send to Sentry
    M.capture_exception(message, {
      error_object = tostring(error_obj or ''),
      source = 'utils_log_error'
    })
  end
end

return M
