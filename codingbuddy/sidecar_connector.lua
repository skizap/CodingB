-- sidecar_connector.lua - GeanyLua connector for MultiappV1 Tauri Sidecar
-- Provides optional communication bridge to the sidecar for rich UI features

local M = {}

local utils = require('utils')
local config = require('config')
local json = require('json')

-- Sidecar configuration
local SIDECAR_HOST = '127.0.0.1'
local SIDECAR_PORT = 8765
local SIDECAR_BASE_URL = 'http://' .. SIDECAR_HOST .. ':' .. SIDECAR_PORT

-- Check if sidecar is available
local sidecar_available = false
local last_check_time = 0

local function check_sidecar_availability()
    local now = os.time()
    
    -- Only check every 30 seconds to avoid spam
    if now - last_check_time < 30 then
        return sidecar_available
    end
    
    last_check_time = now
    
    -- Try to make a health check request
    local health_url = SIDECAR_BASE_URL .. '/health'
    local cmd = string.format('curl -s --connect-timeout 1 --max-time 2 "%s" 2>/dev/null', health_url)
    
    local success, exit_code = utils.execute_command(cmd)
    if success and exit_code == 0 then
        sidecar_available = true
        utils.log_debug('Sidecar is available at ' .. SIDECAR_BASE_URL)
    else
        sidecar_available = false
        utils.log_debug('Sidecar not available at ' .. SIDECAR_BASE_URL)
    end
    
    return sidecar_available
end

-- Send an HTTP POST request to the sidecar
local function send_sidecar_request(endpoint, data)
    if not check_sidecar_availability() then
        return false, 'Sidecar not available'
    end
    
    local url = SIDECAR_BASE_URL .. endpoint
    local json_data = json.encode(data or {})
    
    -- Create temporary file for POST data
    local temp_file = '/tmp/sidecar_post_' .. os.time() .. '_' .. math.random(1000, 9999)
    local f = io.open(temp_file, 'w')
    if not f then
        return false, 'Failed to create temporary file'
    end
    f:write(json_data)
    f:close()
    
    -- Make POST request using curl
    local cmd = string.format(
        'curl -s --connect-timeout 2 --max-time 5 -X POST -H "Content-Type: application/json" --data @%s "%s" 2>/dev/null',
        temp_file, url
    )
    
    local success, exit_code, output = utils.execute_command(cmd, true)
    
    -- Clean up temporary file
    os.remove(temp_file)
    
    if not success or exit_code ~= 0 then
        return false, 'HTTP request failed: ' .. (output or 'unknown error')
    end
    
    return true, output
end

-- Send operation request to sidecar for approval
function M.send_operation_request(operation_type, payload)
    if not config.get().sidecar_enabled then
        return false, 'Sidecar integration disabled'
    end
    
    local event_data = {
        type = 'operation_request',
        operation = operation_type,
        payload = payload,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        source = 'geanylua'
    }
    
    utils.log_info('Sending operation request to sidecar: ' .. operation_type)
    
    local success, response = send_sidecar_request('/events', event_data)
    if not success then
        utils.log_warning('Failed to send operation to sidecar: ' .. response)
        return false, response
    end
    
    -- Parse response
    local response_data = json.decode(response)
    if response_data and response_data.status == 'queued' then
        utils.log_info('Operation queued in sidecar: ' .. (response_data.operation_id or 'unknown'))
        return true, response_data.operation_id
    else
        utils.log_warning('Unexpected sidecar response: ' .. response)
        return false, 'Unexpected response from sidecar'
    end
end

-- Send chat message to sidecar for display
function M.send_chat_message(message)
    if not config.get().sidecar_enabled then
        return false, 'Sidecar integration disabled'
    end
    
    local event_data = {
        type = 'chat_message',
        message = message,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        source = 'geanylua'
    }
    
    local success, response = send_sidecar_request('/events', event_data)
    if not success then
        utils.log_debug('Failed to send chat message to sidecar: ' .. response)
        return false, response
    end
    
    return true, response
end

-- Get operation status from sidecar
function M.get_pending_operations()
    if not config.get().sidecar_enabled then
        return {}
    end
    
    local url = SIDECAR_BASE_URL .. '/operations'
    local cmd = string.format('curl -s --connect-timeout 2 --max-time 5 "%s" 2>/dev/null', url)
    
    local success, exit_code, output = utils.execute_command(cmd, true)
    if not success or exit_code ~= 0 then
        utils.log_debug('Failed to get operations from sidecar')
        return {}
    end
    
    local operations = json.decode(output)
    return operations or {}
end

-- Check if sidecar is enabled and available
function M.is_available()
    local cfg = config.get()
    if not cfg.sidecar_enabled then
        return false
    end
    
    return check_sidecar_availability()
end

-- Enable sidecar integration
function M.enable()
    utils.log_info('Enabling sidecar integration')
    
    -- This would typically update the config
    local cfg = config.get()
    cfg.sidecar_enabled = true
    
    if check_sidecar_availability() then
        utils.log_info('Sidecar integration enabled and connected')
        
        -- Send an initial ping to establish connection
        M.send_chat_message('GeanyLua CodingBuddy connected')
        return true
    else
        utils.log_warning('Sidecar integration enabled but sidecar not available')
        return false
    end
end

-- Disable sidecar integration  
function M.disable()
    utils.log_info('Disabling sidecar integration')
    
    local cfg = config.get()
    cfg.sidecar_enabled = false
    sidecar_available = false
end

-- Wrapper function for operations that should be sent to sidecar for approval
function M.wrap_operation(operation_name, original_function, auto_approve_types)
    auto_approve_types = auto_approve_types or {}
    
    return function(...)
        local args = {...}
        
        -- If sidecar is not available, just execute normally
        if not M.is_available() then
            return original_function(...)
        end
        
        -- Check if this operation type should be auto-approved
        local should_auto_approve = false
        for _, auto_type in ipairs(auto_approve_types) do
            if operation_name == auto_type then
                should_auto_approve = true
                break
            end
        end
        
        if should_auto_approve then
            utils.log_debug('Auto-approving operation: ' .. operation_name)
            return original_function(...)
        end
        
        -- Send to sidecar for approval
        local payload = {
            function_name = operation_name,
            arguments = args
        }
        
        local success, operation_id = M.send_operation_request(operation_name, payload)
        if not success then
            utils.log_warning('Failed to send operation for approval, executing directly: ' .. operation_id)
            return original_function(...)
        end
        
        utils.log_info('Operation sent to sidecar for approval: ' .. operation_id)
        
        -- For now, we'll just execute the operation
        -- In a full implementation, you might want to queue it and wait for approval
        return original_function(...)
    end
end

-- Get status information for display
function M.get_status()
    return {
        enabled = config.get().sidecar_enabled or false,
        available = sidecar_available,
        url = SIDECAR_BASE_URL,
        last_check = last_check_time
    }
end

return M
