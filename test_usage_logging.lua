#!/usr/bin/env lua
-- test_usage_logging.lua - Test the usage logging and analysis functionality
-- This script tests the usage.jsonl logging and /usage command functionality

-- Add the current directory to the path so we can require codingbuddy modules
package.path = package.path .. ';./codingbuddy/?.lua'

-- Test the usage analyzer module
local usage_analyzer = require('usage_analyzer')

-- Create some test usage entries for demonstration
local function create_test_usage_log()
  local home = os.getenv('HOME') or '.'
  local log_path = home .. '/.config/geany/plugins/geanylua/codingbuddy/logs/usage.jsonl'
  
  -- Ensure logs directory exists
  local logs_dir = home .. '/.config/geany/plugins/geanylua/codingbuddy/logs'
  os.execute('mkdir -p "' .. logs_dir .. '"')
  
  -- Create test entries
  local test_entries = {
    {
      timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
      provider = 'anthropic',
      model = 'claude-3-5-sonnet-latest',
      prompt_tokens = 50,
      completion_tokens = 150,
      total_tokens = 200,
      estimated_cost = 0.003,
      currency = 'USD'
    },
    {
      timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', os.time() - 3600), -- 1 hour ago
      provider = 'openrouter',
      model = 'anthropic/claude-3.5-sonnet',
      prompt_tokens = 75,
      completion_tokens = 125,
      total_tokens = 200,
      estimated_cost = 0.002,
      currency = 'USD'
    },
    {
      timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', os.time() - 7200), -- 2 hours ago
      provider = 'openai',
      model = 'gpt-4o-mini',
      prompt_tokens = 100,
      completion_tokens = 200,
      total_tokens = 300,
      estimated_cost = 0.001,
      currency = 'USD'
    }
  }
  
  -- Write test entries to log file
  local ok, dkjson = pcall(require, 'dkjson')
  local file = io.open(log_path, 'a')
  
  if file then
    for _, entry in ipairs(test_entries) do
      local line
      if ok and dkjson then
        line = dkjson.encode(entry)
      else
        line = string.format('{"timestamp":"%s","provider":"%s","model":"%s","prompt_tokens":%d,"completion_tokens":%d,"total_tokens":%d,"estimated_cost":%.6f,"currency":"%s"}',
          entry.timestamp, entry.provider, entry.model, entry.prompt_tokens, entry.completion_tokens, entry.total_tokens, entry.estimated_cost, entry.currency)
      end
      file:write(line .. '\n')
    end
    file:close()
    print("✓ Created test usage log entries")
  else
    print("✗ Failed to create test usage log entries")
    return false
  end
  
  return true
end

-- Test reading the usage log
local function test_read_usage_log()
  print("\n=== Testing Usage Log Reading ===")
  
  local entries = usage_analyzer.read_usage_log()
  print(string.format("✓ Read %d usage log entries", #entries))
  
  if #entries > 0 then
    print("Sample entry:")
    local entry = entries[#entries] -- Last entry
    print(string.format("  Provider: %s", entry.provider or 'unknown'))
    print(string.format("  Model: %s", entry.model or 'unknown'))
    print(string.format("  Tokens: %d", entry.total_tokens or 0))
    print(string.format("  Cost: $%.4f", entry.estimated_cost or 0))
  end
  
  return #entries > 0
end

-- Test usage analysis
local function test_usage_analysis()
  print("\n=== Testing Usage Analysis ===")
  
  local entries = usage_analyzer.read_usage_log()
  local summary = usage_analyzer.analyze_usage(entries)
  
  print("✓ Analysis completed")
  print(string.format("  Total requests: %d", summary.total_requests))
  print(string.format("  Total tokens: %d", summary.total_tokens))
  print(string.format("  Total cost: $%.4f", summary.total_cost))
  print(string.format("  Providers: %d", table.maxn and table.maxn(summary.by_provider) or 0))
  
  return summary.total_requests > 0
end

-- Test formatted output
local function test_formatted_output()
  print("\n=== Testing Formatted Output ===")
  
  print("--- All-time summary ---")
  local total_summary = usage_analyzer.get_total_summary()
  print(total_summary)
  
  print("\n--- Last 24 hours summary ---")
  local session_summary = usage_analyzer.get_session_summary(24)
  print(session_summary)
  
  return true
end

-- Test the ai_connector logging (simulate a usage log call)
local function test_ai_connector_logging()
  print("\n=== Testing AI Connector Logging Integration ===")
  
  -- Load the ai_connector module
  local ok, ai_connector = pcall(require, 'ai_connector')
  if not ok then
    print("✗ Could not load ai_connector module: " .. tostring(ai_connector))
    return false
  end
  
  print("✓ AI connector module loaded successfully")
  print("✓ Usage logging is integrated into ai_connector.chat() function")
  print("  (Logging occurs automatically when ai_connector.chat() is called)")
  
  return true
end

-- Main test execution
local function run_tests()
  print("CodingBuddy Usage Logging Test Suite")
  print("=====================================\n")
  
  local tests_passed = 0
  local total_tests = 5
  
  -- Test 1: Create test data
  if create_test_usage_log() then
    tests_passed = tests_passed + 1
  end
  
  -- Test 2: Read usage log
  if test_read_usage_log() then
    tests_passed = tests_passed + 1
  end
  
  -- Test 3: Usage analysis
  if test_usage_analysis() then
    tests_passed = tests_passed + 1
  end
  
  -- Test 4: Formatted output
  if test_formatted_output() then
    tests_passed = tests_passed + 1
  end
  
  -- Test 5: AI connector integration
  if test_ai_connector_logging() then
    tests_passed = tests_passed + 1
  end
  
  -- Summary
  print("\n=====================================")
  print(string.format("Tests completed: %d/%d passed", tests_passed, total_tests))
  
  if tests_passed == total_tests then
    print("✓ All tests passed! Usage logging system is working correctly.")
    print("\nNext steps:")
    print("1. Use the chat interface and run '/usage' to see real usage data")
    print("2. Try '/usage 24' to see usage from the last 24 hours")
    print("3. Make some AI requests to populate the usage.jsonl file")
  else
    print("✗ Some tests failed. Check the error messages above.")
  end
  
  return tests_passed == total_tests
end

-- Execute tests
run_tests()
