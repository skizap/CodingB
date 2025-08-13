-- usage_analyzer.lua - Usage logging and analysis utilities
-- Provides functions to read and analyze token usage and costs from usage.jsonl

local M = {}

-- Get usage log file path
local function get_usage_log_path()
  local home = os.getenv('HOME') or '.'
  return home .. '/.config/geany/plugins/geanylua/codingbuddy/logs/usage.jsonl'
end

-- Safe JSON decoder
local function get_json_decoder()
  local ok, dkjson = pcall(require, 'dkjson')
  if ok and dkjson and dkjson.decode then
    return function(str) return dkjson.decode(str) end
  end
  
  -- Try our bundled JSON module
  local ok2, pj = pcall(require, 'codingbuddy.json')
  if ok2 and pj and pj.decode then
    return pj.decode
  end
  
  -- Fallback manual parser for basic entries
  return function(str)
    local entry = {}
    entry.timestamp = str:match('"timestamp":"([^"]*)"')
    entry.provider = str:match('"provider":"([^"]*)"')
    entry.model = str:match('"model":"([^"]*)"')
    entry.prompt_tokens = tonumber(str:match('"prompt_tokens":(%d+)')) or 0
    entry.completion_tokens = tonumber(str:match('"completion_tokens":(%d+)')) or 0
    entry.total_tokens = tonumber(str:match('"total_tokens":(%d+)')) or 0
    entry.estimated_cost = tonumber(str:match('"estimated_cost":([%d%.]+)')) or 0
    entry.currency = str:match('"currency":"([^"]*)"') or 'USD'
    return entry
  end
end

-- Read and parse usage log entries
function M.read_usage_log()
  local log_path = get_usage_log_path()
  local file = io.open(log_path, 'r')
  if not file then
    return {}
  end
  
  local entries = {}
  local decoder = get_json_decoder()
  
  for line in file:lines() do
    if line and line ~= '' then
      local ok, entry = pcall(decoder, line)
      if ok and entry and entry.timestamp then
        table.insert(entries, entry)
      end
    end
  end
  
  file:close()
  return entries
end

-- Parse ISO timestamp to components for filtering
local function parse_timestamp(timestamp)
  if not timestamp then return nil end
  local year, month, day, hour, min, sec = timestamp:match('(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)')
  if not year then return nil end
  return {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
    timestamp = timestamp
  }
end

-- Check if timestamp is within time range (in hours from now)
local function is_within_hours(timestamp, hours)
  if not timestamp or not hours then return true end
  
  local parsed = parse_timestamp(timestamp)
  if not parsed then return true end
  
  -- Simple check: last 24 hours = today and yesterday
  local now = os.time()
  local today = os.date('!%Y-%m-%d', now)
  local yesterday = os.date('!%Y-%m-%d', now - 24*3600)
  local entry_date = timestamp:match('(%d%d%d%d%-%d%d%-%d%d)')
  
  if hours <= 24 then
    return entry_date == today or (hours > 12 and entry_date == yesterday)
  else
    -- For longer periods, accept entries from last N days approximately
    local days = math.ceil(hours / 24)
    for i = 0, days - 1 do
      local check_date = os.date('!%Y-%m-%d', now - i*24*3600)
      if entry_date == check_date then
        return true
      end
    end
    return false
  end
end

-- Export a function to format numbers with commas (basic implementation)
local function format_number(n)
  local formatted = tostring(math.floor(n))
  local k
  while true do
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if k == 0 then break end
  end
  return formatted
end

-- Analyze usage entries and generate summary
function M.analyze_usage(entries, time_filter_hours)
  local summary = {
    total_requests = 0,
    total_prompt_tokens = 0,
    total_completion_tokens = 0,
    total_tokens = 0,
    total_cost = 0,
    by_provider = {},
    by_model = {},
    time_range = time_filter_hours and (time_filter_hours .. ' hours') or 'all time',
    currency = 'USD'
  }
  
  -- Filter entries by time if specified
  local filtered_entries = {}
  for _, entry in ipairs(entries) do
    if not time_filter_hours or is_within_hours(entry.timestamp, time_filter_hours) then
      table.insert(filtered_entries, entry)
    end
  end
  
  -- Analyze filtered entries
  for _, entry in ipairs(filtered_entries) do
    summary.total_requests = summary.total_requests + 1
    summary.total_prompt_tokens = summary.total_prompt_tokens + (entry.prompt_tokens or 0)
    summary.total_completion_tokens = summary.total_completion_tokens + (entry.completion_tokens or 0)
    summary.total_tokens = summary.total_tokens + (entry.total_tokens or 0)
    summary.total_cost = summary.total_cost + (entry.estimated_cost or 0)
    
    if entry.currency and entry.currency ~= summary.currency then
      summary.currency = 'MIXED'
    end
    
    -- By provider
    local provider = entry.provider or 'unknown'
    if not summary.by_provider[provider] then
      summary.by_provider[provider] = {
        requests = 0,
        prompt_tokens = 0,
        completion_tokens = 0,
        total_tokens = 0,
        cost = 0
      }
    end
    local prov = summary.by_provider[provider]
    prov.requests = prov.requests + 1
    prov.prompt_tokens = prov.prompt_tokens + (entry.prompt_tokens or 0)
    prov.completion_tokens = prov.completion_tokens + (entry.completion_tokens or 0)
    prov.total_tokens = prov.total_tokens + (entry.total_tokens or 0)
    prov.cost = prov.cost + (entry.estimated_cost or 0)
    
    -- By model
    local model = entry.model or 'unknown'
    if not summary.by_model[model] then
      summary.by_model[model] = {
        requests = 0,
        prompt_tokens = 0,
        completion_tokens = 0,
        total_tokens = 0,
        cost = 0
      }
    end
    local mod = summary.by_model[model]
    mod.requests = mod.requests + 1
    mod.prompt_tokens = mod.prompt_tokens + (entry.prompt_tokens or 0)
    mod.completion_tokens = mod.completion_tokens + (entry.completion_tokens or 0)
    mod.total_tokens = mod.total_tokens + (entry.total_tokens or 0)
    mod.cost = mod.cost + (entry.estimated_cost or 0)
  end
  
  return summary
end

-- Format usage summary for display
function M.format_usage_summary(summary)
  local lines = {}
  
  -- Header
  table.insert(lines, "=== CodingBuddy Usage Summary ===")
  table.insert(lines, "Time Range: " .. summary.time_range)
  table.insert(lines, "")
  
  -- Overall totals
  table.insert(lines, "Overall Usage:")
  table.insert(lines, string.format("  Total Requests: %d", summary.total_requests))
  table.insert(lines, string.format("  Prompt Tokens: %s", format_number(summary.total_prompt_tokens)))
  table.insert(lines, string.format("  Completion Tokens: %s", format_number(summary.total_completion_tokens)))
  table.insert(lines, string.format("  Total Tokens: %s", format_number(summary.total_tokens)))
  table.insert(lines, string.format("  Estimated Cost: $%.4f %s", summary.total_cost, summary.currency))
  
  if summary.total_requests > 0 then
    table.insert(lines, string.format("  Average Cost per Request: $%.4f", summary.total_cost / summary.total_requests))
    table.insert(lines, string.format("  Average Tokens per Request: %.1f", summary.total_tokens / summary.total_requests))
  end
  table.insert(lines, "")
  
  -- By provider
  table.insert(lines, "Usage by Provider:")
  local provider_names = {}
  for provider, _ in pairs(summary.by_provider) do
    table.insert(provider_names, provider)
  end
  table.sort(provider_names)
  
  for _, provider in ipairs(provider_names) do
    local prov = summary.by_provider[provider]
    table.insert(lines, string.format("  %s:", provider))
    table.insert(lines, string.format("    Requests: %d (%.1f%%)", 
      prov.requests, summary.total_requests > 0 and (prov.requests / summary.total_requests) * 100 or 0))
    table.insert(lines, string.format("    Tokens: %s (%.1f%%)", 
      format_number(prov.total_tokens), summary.total_tokens > 0 and (prov.total_tokens / summary.total_tokens) * 100 or 0))
    table.insert(lines, string.format("    Cost: $%.4f (%.1f%%)", 
      prov.cost, summary.total_cost > 0 and (prov.cost / summary.total_cost) * 100 or 0))
  end
  table.insert(lines, "")
  
  -- By model (top 5 most used)
  table.insert(lines, "Usage by Model (Top 5):")
  local model_usage = {}
  for model, data in pairs(summary.by_model) do
    table.insert(model_usage, {model = model, data = data})
  end
  table.sort(model_usage, function(a, b) return a.data.requests > b.data.requests end)
  
  for i = 1, math.min(5, #model_usage) do
    local model_info = model_usage[i]
    local model = model_info.model
    local data = model_info.data
    table.insert(lines, string.format("  %s:", model))
    table.insert(lines, string.format("    Requests: %d", data.requests))
    table.insert(lines, string.format("    Tokens: %s", format_number(data.total_tokens)))
    table.insert(lines, string.format("    Cost: $%.4f", data.cost))
  end
  
  return table.concat(lines, '\n')
end

-- Get usage summary for specific time period
function M.get_session_summary(hours)
  local entries = M.read_usage_log()
  local summary = M.analyze_usage(entries, hours)
  return M.format_usage_summary(summary)
end

-- Get all-time usage summary
function M.get_total_summary()
  local entries = M.read_usage_log()
  local summary = M.analyze_usage(entries)
  return M.format_usage_summary(summary)
end

return M
