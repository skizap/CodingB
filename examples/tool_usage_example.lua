#!/usr/bin/env lua
-- tool_usage_example.lua - Demonstrates the enhanced Anthropic Messages API integration

-- Add the parent directory to the path so we can require codingbuddy modules
package.path = package.path .. ';../?.lua'

local ai = require('codingbuddy.ai_connector')

-- Example tool registry
local tool_registry = {
  list_files = function(input)
    local path = input.path or "."
    local handle = io.popen("ls -la " .. path .. " 2>/dev/null")
    if handle then
      local result = handle:read("*a")
      handle:close()
      return { files = result, path = path }
    else
      return { error = "Could not list files in " .. path }
    end
  end,
  
  get_current_time = function(input)
    return { 
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      local_time = os.date("%Y-%m-%d %H:%M:%S"),
      timezone = input.timezone or "UTC"
    }
  end,
  
  calculate = function(input)
    local expr = input.expression
    if not expr then
      return { error = "No expression provided" }
    end
    
    -- Simple calculator (be careful with eval in real code!)
    local func, err = load("return " .. expr)
    if func then
      local success, result = pcall(func)
      if success then
        return { expression = expr, result = result }
      else
        return { error = "Calculation error: " .. tostring(result) }
      end
    else
      return { error = "Invalid expression: " .. tostring(err) }
    end
  end
}

-- Example 1: Basic usage with string system prompt
print("=== Example 1: Basic Usage ===")
local response1 = ai.chat({
  provider = 'anthropic',
  system = 'You are a helpful assistant that can use tools to help users.',
  prompt = 'What time is it?',
  tools = {
    {
      name = "get_current_time",
      description = "Get the current time",
      input_schema = {
        type = "object",
        properties = {
          timezone = { type = "string", description = "Timezone (optional)" }
        }
      }
    }
  },
  tool_registry = tool_registry,
  auto_execute_tools = true,
  return_structured = true
})

if response1 then
  print("Response:", response1.text or "No text response")
  if response1.tool_calls and #response1.tool_calls > 0 then
    print("Tools used:", #response1.tool_calls)
    for i, call in ipairs(response1.tool_calls) do
      print(string.format("  - %s (id: %s)", call.name, call.id))
    end
  end
else
  print("Error: No response received")
end

print("\n=== Example 2: Advanced System Prompt with Content Blocks ===")
local response2 = ai.chat({
  provider = 'anthropic',
  system = {
    { type = "text", text = "You are a file system assistant." },
    { type = "text", text = "Always be helpful and provide detailed information about files and directories." }
  },
  prompt = 'Can you list the files in the current directory?',
  tools = {
    {
      name = "list_files",
      description = "List files in a directory",
      input_schema = {
        type = "object",
        properties = {
          path = { type = "string", description = "Directory path to list" }
        }
      }
    }
  },
  tool_registry = tool_registry,
  auto_execute_tools = true,
  return_structured = true
})

if response2 then
  print("Response:", response2.text or "No text response")
  if response2.tool_results and #response2.tool_results > 0 then
    print("Tool results received:", #response2.tool_results)
  end
else
  print("Error: No response received")
end

print("\n=== Example 3: Multiple Tools in One Request ===")
local response3 = ai.chat({
  provider = 'anthropic',
  system = "You are a helpful assistant with access to file system and calculation tools.",
  prompt = 'Calculate 15 * 23 and also tell me what time it is.',
  tools = {
    {
      name = "calculate",
      description = "Perform mathematical calculations",
      input_schema = {
        type = "object",
        properties = {
          expression = { type = "string", description = "Mathematical expression to evaluate" }
        },
        required = { "expression" }
      }
    },
    {
      name = "get_current_time",
      description = "Get the current time",
      input_schema = {
        type = "object",
        properties = {
          timezone = { type = "string", description = "Timezone (optional)" }
        }
      }
    }
  },
  tool_registry = tool_registry,
  auto_execute_tools = true,
  return_structured = true
})

if response3 then
  print("Response:", response3.text or "No text response")
  if response3.tool_calls and #response3.tool_calls > 0 then
    print("Tools used:", #response3.tool_calls)
    for i, call in ipairs(response3.tool_calls) do
      print(string.format("  - %s", call.name))
    end
  end
else
  print("Error: No response received")
end

print("\n=== Example 4: Backward Compatibility (Simple String Response) ===")
local response4 = ai.chat({
  provider = 'anthropic',
  system = 'You are a helpful coding assistant.',
  prompt = 'Explain what Lua is in one sentence.'
  -- No tools, no auto_execute_tools, no return_structured
  -- Should return simple string like before
})

if response4 then
  print("Simple response:", response4)
else
  print("Error: No response received")
end

print("\n=== Example 5: Tool Error Handling ===")
local response5 = ai.chat({
  provider = 'anthropic',
  system = 'You are a calculator assistant.',
  prompt = 'Calculate the result of dividing by zero: 10 / 0',
  tools = {
    {
      name = "calculate",
      description = "Perform mathematical calculations",
      input_schema = {
        type = "object",
        properties = {
          expression = { type = "string", description = "Mathematical expression to evaluate" }
        },
        required = { "expression" }
      }
    }
  },
  tool_registry = tool_registry,
  auto_execute_tools = true,
  return_structured = true
})

if response5 then
  print("Response:", response5.text or "No text response")
  if response5.tool_results then
    print("Tool execution completed (may include errors)")
  end
else
  print("Error: No response received")
end

print("\n=== All Examples Complete ===")
