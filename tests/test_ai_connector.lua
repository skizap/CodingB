-- test_ai_connector.lua - Unit tests for AI connector
-- Simple test framework for validating AI connector functionality

local M = {}

-- Simple test framework
local tests = {}
local test_count = 0
local passed_count = 0

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format("Assertion failed: %s\nExpected: %s\nActual: %s", 
      message or "values should be equal", tostring(expected), tostring(actual)))
  end
end

local function assert_table_equal(actual, expected, message)
  if type(actual) ~= 'table' or type(expected) ~= 'table' then
    error(string.format("Assertion failed: %s\nBoth values must be tables", message or ""))
  end
  
  for k, v in pairs(expected) do
    if type(v) == 'table' then
      assert_table_equal(actual[k], v, message)
    else
      assert_equal(actual[k], v, message)
    end
  end
  
  for k, v in pairs(actual) do
    if expected[k] == nil then
      error(string.format("Assertion failed: %s\nUnexpected key: %s", message or "", tostring(k)))
    end
  end
end

local function test(name, func)
  tests[#tests + 1] = { name = name, func = func }
end

local function run_tests()
  print("Running AI Connector Tests...")
  print("=" .. string.rep("=", 50))
  
  for _, t in ipairs(tests) do
    test_count = test_count + 1
    local success, err = pcall(t.func)
    if success then
      passed_count = passed_count + 1
      print(string.format("✓ %s", t.name))
    else
      print(string.format("✗ %s", t.name))
      print(string.format("  Error: %s", err))
    end
  end
  
  print("=" .. string.rep("=", 50))
  print(string.format("Tests: %d passed, %d failed, %d total", 
    passed_count, test_count - passed_count, test_count))
  
  return passed_count == test_count
end

-- Mock configuration for testing
local mock_config = {
  provider_models = {
    anthropic = 'claude-3-5-sonnet-latest',
    openai = 'gpt-4o-mini',
    openrouter = 'anthropic/claude-3.5-sonnet'
  },
  task_models = {
    analysis = 'anthropic/claude-3.5-sonnet'
  }
}

-- Mock the ai_connector module for testing internal functions
local function create_test_connector()
  -- We need to access internal functions, so we'll create a test version
  local connector = {}
  
  -- Copy the build_payload logic for testing
  connector.build_payload = function(p, opts, cfg)
    local default_system = 'You are a helpful coding assistant that produces concise, actionable analysis.'
    if p == 'anthropic' then
      local m = opts.model or cfg.provider_models.anthropic
      local sys = (opts.system ~= nil) and opts.system or default_system
      local pl = {
        model = m,
        max_tokens = opts.max_tokens or 1024,
        messages = {
          { role = 'user', content = opts.prompt or '' }
        },
      }
      
      -- Anthropic system prompt: string, content array, or content blocks
      if type(sys) == 'string' then
        pl.system = sys
      elseif type(sys) == 'table' then
        -- Check if it's an array of content blocks or a simple array
        if sys[1] and type(sys[1]) == 'table' and sys[1].type then
          -- Array of content blocks: [{ type = "text", text = "..." }, ...]
          pl.system = sys
        elseif sys[1] and type(sys[1]) == 'string' then
          -- Simple string array, convert to content blocks
          local content_blocks = {}
          for i = 1, #sys do
            if type(sys[i]) == 'string' then
              table.insert(content_blocks, { type = 'text', text = sys[i] })
            end
          end
          pl.system = content_blocks
        else
          -- Assume it's already properly formatted content blocks
          pl.system = sys
        end
      end
      
      -- Scaffold for tool use: pass tools/tool_choice if provided
      if opts.tools and type(opts.tools) == 'table' then pl.tools = opts.tools end
      if opts.tool_choice ~= nil then pl.tool_choice = opts.tool_choice end
      return pl
    else
      local m = opts.model or cfg.provider_models[p] or cfg.task_models.analysis
      local sys = (opts.system ~= nil) and opts.system or default_system
      -- For non-Anthropic providers, convert arrays to concatenated string
      if type(sys) == 'table' then
        if sys[1] and type(sys[1]) == 'table' and sys[1].text then
          -- Content blocks format, extract text
          local parts = {}
          for i = 1, #sys do
            if sys[i].text then table.insert(parts, sys[i].text) end
          end
          sys = table.concat(parts, '\n\n')
        elseif sys[1] and type(sys[1]) == 'string' then
          -- Simple string array
          sys = table.concat(sys, '\n\n')
        end
      end
      return { model = m, messages = {
        { role = 'system', content = sys },
        { role = 'user', content = opts.prompt or '' },
      }}
    end
  end
  
  -- Copy the extract_response logic for testing
  connector.extract_response = function(p, obj)
    if p == 'anthropic' then
      local content = obj and obj.content
      local result = { text = nil, tool_calls = {}, raw_content = content }
      
      if type(content) == 'table' then
        for i = 1, #content do
          local block = content[i]
          if type(block) == 'table' then
            if block.type == 'text' and type(block.text) == 'string' then
              if not result.text then result.text = block.text end
            elseif block.type == 'tool_use' then
              local tool_call = {
                id = block.id,
                name = block.name,
                input = block.input
              }
              table.insert(result.tool_calls, tool_call)
            end
          end
        end
      end
      
      return result
    else
      -- OpenAI/OpenRouter format
      local message = obj and obj.choices and obj.choices[1] and obj.choices[1].message
      local result = { text = nil, tool_calls = {}, raw_content = message }
      
      if message then
        result.text = message.content
        if message.tool_calls and type(message.tool_calls) == 'table' then
          for i = 1, #message.tool_calls do
            local tc = message.tool_calls[i]
            if tc['function'] then
              local tool_call = {
                id = tc.id,
                name = tc['function'].name,
                input = tc['function'].arguments -- Note: this might be a JSON string
              }
              table.insert(result.tool_calls, tool_call)
            end
          end
        end
      end
      
      return result
    end
  end
  
  return connector
end

-- Test cases
test("Anthropic payload formation with string system", function()
  local connector = create_test_connector()
  local opts = {
    prompt = "Analyze this code",
    system = "You are a code reviewer"
  }
  local payload = connector.build_payload('anthropic', opts, mock_config)
  
  assert_equal(payload.model, 'claude-3-5-sonnet-latest')
  assert_equal(payload.system, "You are a code reviewer")
  assert_equal(payload.messages[1].role, 'user')
  assert_equal(payload.messages[1].content, "Analyze this code")
  assert_equal(payload.max_tokens, 1024)
end)

test("Anthropic payload formation with content blocks system", function()
  local connector = create_test_connector()
  local opts = {
    prompt = "Analyze this code",
    system = {
      { type = "text", text = "You are a code reviewer." },
      { type = "text", text = "Focus on security issues." }
    }
  }
  local payload = connector.build_payload('anthropic', opts, mock_config)
  
  assert_equal(payload.model, 'claude-3-5-sonnet-latest')
  assert_equal(type(payload.system), 'table')
  assert_equal(payload.system[1].type, 'text')
  assert_equal(payload.system[1].text, "You are a code reviewer.")
  assert_equal(payload.system[2].text, "Focus on security issues.")
end)

test("Anthropic payload formation with string array system", function()
  local connector = create_test_connector()
  local opts = {
    prompt = "Analyze this code",
    system = { "You are a code reviewer.", "Focus on security issues." }
  }
  local payload = connector.build_payload('anthropic', opts, mock_config)
  
  assert_equal(payload.model, 'claude-3-5-sonnet-latest')
  assert_equal(type(payload.system), 'table')
  assert_equal(payload.system[1].type, 'text')
  assert_equal(payload.system[1].text, "You are a code reviewer.")
  assert_equal(payload.system[2].type, 'text')
  assert_equal(payload.system[2].text, "Focus on security issues.")
end)

test("OpenAI payload formation with string system", function()
  local connector = create_test_connector()
  local opts = {
    prompt = "Analyze this code",
    system = "You are a code reviewer"
  }
  local payload = connector.build_payload('openai', opts, mock_config)
  
  assert_equal(payload.model, 'gpt-4o-mini')
  assert_equal(payload.messages[1].role, 'system')
  assert_equal(payload.messages[1].content, "You are a code reviewer")
  assert_equal(payload.messages[2].role, 'user')
  assert_equal(payload.messages[2].content, "Analyze this code")
end)

test("OpenAI payload formation with array system (converted to string)", function()
  local connector = create_test_connector()
  local opts = {
    prompt = "Analyze this code",
    system = { "You are a code reviewer.", "Focus on security issues." }
  }
  local payload = connector.build_payload('openai', opts, mock_config)

  assert_equal(payload.model, 'gpt-4o-mini')
  assert_equal(payload.messages[1].role, 'system')
  assert_equal(payload.messages[1].content, "You are a code reviewer.\n\nFocus on security issues.")
end)

test("Anthropic tool scaffolding", function()
  local connector = create_test_connector()
  local opts = {
    prompt = "List files in directory",
    tools = {
      { name = "list_files", description = "List files", input_schema = { type = "object" } }
    },
    tool_choice = "auto"
  }
  local payload = connector.build_payload('anthropic', opts, mock_config)

  assert_equal(type(payload.tools), 'table')
  assert_equal(payload.tools[1].name, "list_files")
  assert_equal(payload.tool_choice, "auto")
end)

test("Anthropic response parsing - text only", function()
  local connector = create_test_connector()
  local mock_response = {
    content = {
      { type = "text", text = "This is the response text" }
    }
  }
  local result = connector.extract_response('anthropic', mock_response)

  assert_equal(result.text, "This is the response text")
  assert_equal(#result.tool_calls, 0)
  assert_equal(result.raw_content, mock_response.content)
end)

test("Anthropic response parsing - with tool calls", function()
  local connector = create_test_connector()
  local mock_response = {
    content = {
      { type = "text", text = "I'll list the files for you." },
      { type = "tool_use", id = "call_123", name = "list_files", input = { path = "/home" } }
    }
  }
  local result = connector.extract_response('anthropic', mock_response)

  assert_equal(result.text, "I'll list the files for you.")
  assert_equal(#result.tool_calls, 1)
  assert_equal(result.tool_calls[1].id, "call_123")
  assert_equal(result.tool_calls[1].name, "list_files")
  assert_table_equal(result.tool_calls[1].input, { path = "/home" })
end)

test("OpenAI response parsing - text only", function()
  local connector = create_test_connector()
  local mock_response = {
    choices = {
      {
        message = {
          content = "This is the response text"
        }
      }
    }
  }
  local result = connector.extract_response('openai', mock_response)

  assert_equal(result.text, "This is the response text")
  assert_equal(#result.tool_calls, 0)
end)

test("OpenAI response parsing - with tool calls", function()
  local connector = create_test_connector()
  local mock_response = {
    choices = {
      {
        message = {
          content = "I'll list the files for you.",
          tool_calls = {
            {
              id = "call_123",
              ['function'] = {
                name = "list_files",
                arguments = '{"path": "/home"}'
              }
            }
          }
        }
      }
    }
  }
  local result = connector.extract_response('openai', mock_response)

  assert_equal(result.text, "I'll list the files for you.")
  assert_equal(#result.tool_calls, 1)
  assert_equal(result.tool_calls[1].id, "call_123")
  assert_equal(result.tool_calls[1].name, "list_files")
  assert_equal(result.tool_calls[1].input, '{"path": "/home"}')
end)

test("Default system prompt fallback", function()
  local connector = create_test_connector()
  local opts = { prompt = "Analyze this code" }
  local payload = connector.build_payload('anthropic', opts, mock_config)

  assert_equal(payload.system, 'You are a helpful coding assistant that produces concise, actionable analysis.')
end)

test("Tool execution framework", function()
  local connector = create_test_connector()

  -- Mock tool registry
  local tool_registry = {
    list_files = function(input)
      return { files = { "file1.txt", "file2.txt" }, path = input.path }
    end,
    failing_tool = function(input)
      error("This tool always fails")
    end
  }

  -- Test successful tool execution
  local tool_calls = {
    { id = "call_123", name = "list_files", input = { path = "/home" } }
  }

  -- We need to add the execute_tools function to our test connector
  connector.execute_tools = function(calls, registry)
    if not calls or #calls == 0 or not registry then
      return {}
    end

    local results = {}
    for i = 1, #calls do
      local call = calls[i]
      local tool_func = registry[call.name]

      if tool_func and type(tool_func) == 'function' then
        local success, result = pcall(tool_func, call.input)
        if success then
          table.insert(results, {
            tool_use_id = call.id,
            type = 'tool_result',
            content = result
          })
        else
          table.insert(results, {
            tool_use_id = call.id,
            type = 'tool_result',
            content = { error = 'Tool execution failed: ' .. tostring(result) },
            is_error = true
          })
        end
      else
        table.insert(results, {
          tool_use_id = call.id,
          type = 'tool_result',
          content = { error = 'Tool not found: ' .. call.name },
          is_error = true
        })
      end
    end

    return results
  end

  local results = connector.execute_tools(tool_calls, tool_registry)

  assert_equal(#results, 1)
  assert_equal(results[1].tool_use_id, "call_123")
  assert_equal(results[1].type, "tool_result")
  assert_table_equal(results[1].content, { files = { "file1.txt", "file2.txt" }, path = "/home" })
end)

test("Tool execution error handling", function()
  local connector = create_test_connector()

  -- Mock tool registry with failing tool
  local tool_registry = {
    failing_tool = function(input)
      error("This tool always fails")
    end
  }

  -- Add execute_tools function
  connector.execute_tools = function(calls, registry)
    local results = {}
    for i = 1, #calls do
      local call = calls[i]
      local tool_func = registry[call.name]

      if tool_func and type(tool_func) == 'function' then
        local success, result = pcall(tool_func, call.input)
        if success then
          table.insert(results, {
            tool_use_id = call.id,
            type = 'tool_result',
            content = result
          })
        else
          table.insert(results, {
            tool_use_id = call.id,
            type = 'tool_result',
            content = { error = 'Tool execution failed: ' .. tostring(result) },
            is_error = true
          })
        end
      else
        table.insert(results, {
          tool_use_id = call.id,
          type = 'tool_result',
          content = { error = 'Tool not found: ' .. call.name },
          is_error = true
        })
      end
    end
    return results
  end

  local tool_calls = {
    { id = "call_456", name = "failing_tool", input = {} }
  }

  local results = connector.execute_tools(tool_calls, tool_registry)

  assert_equal(#results, 1)
  assert_equal(results[1].tool_use_id, "call_456")
  assert_equal(results[1].is_error, true)
  assert_equal(type(results[1].content.error), 'string')
end)

test("Tool not found error handling", function()
  local connector = create_test_connector()

  -- Empty tool registry
  local tool_registry = {}

  -- Add execute_tools function
  connector.execute_tools = function(calls, registry)
    local results = {}
    for i = 1, #calls do
      local call = calls[i]
      local tool_func = registry[call.name]

      if tool_func and type(tool_func) == 'function' then
        local success, result = pcall(tool_func, call.input)
        if success then
          table.insert(results, {
            tool_use_id = call.id,
            type = 'tool_result',
            content = result
          })
        else
          table.insert(results, {
            tool_use_id = call.id,
            type = 'tool_result',
            content = { error = 'Tool execution failed: ' .. tostring(result) },
            is_error = true
          })
        end
      else
        table.insert(results, {
          tool_use_id = call.id,
          type = 'tool_result',
          content = { error = 'Tool not found: ' .. call.name },
          is_error = true
        })
      end
    end
    return results
  end

  local tool_calls = {
    { id = "call_789", name = "nonexistent_tool", input = {} }
  }

  local results = connector.execute_tools(tool_calls, tool_registry)

  assert_equal(#results, 1)
  assert_equal(results[1].tool_use_id, "call_789")
  assert_equal(results[1].is_error, true)
  assert_equal(results[1].content.error, "Tool not found: nonexistent_tool")
end)

-- Export the test runner
M.run_tests = run_tests
M.test = test

return M
