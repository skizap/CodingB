# Anthropic Messages API Enhancements

This document describes the enhanced Anthropic Messages API integration in `codingbuddy/ai_connector.lua`, including tool-use support, advanced system prompts, and automatic tool execution.

## Overview

The enhanced AI connector now provides:

1. **Proper Anthropic Messages API support** with top-level system prompts
2. **Tool-use response parsing** for structured data extraction
3. **Advanced system prompt support** with content blocks
4. **Automatic tool execution framework** with conversation continuation
5. **Comprehensive unit tests** for all functionality
6. **Full backward compatibility** with existing code

## Features

### 1. Enhanced Response Parsing

The connector now returns structured responses that include both text content and tool calls:

```lua
local response = ai.chat({
  provider = 'anthropic',
  prompt = 'List files in /home',
  tools = { ... },
  return_structured = true
})

-- Response structure:
{
  text = "I'll list the files for you.",
  tool_calls = {
    { id = "call_123", name = "list_files", input = { path = "/home" } }
  },
  raw_content = { ... }, -- Original API response content
  usage = { prompt_tokens = 50, completion_tokens = 25, total_tokens = 75 },
  cost = 0.001234
}
```

### 2. Advanced System Prompt Support

Anthropic's Messages API supports rich system prompts with content blocks:

```lua
-- String system prompt (backward compatible)
ai.chat({
  system = "You are a helpful assistant.",
  prompt = "Hello"
})

-- Array of strings (converted to content blocks)
ai.chat({
  system = { "You are a helpful assistant.", "Focus on being concise." },
  prompt = "Hello"
})

-- Content blocks (advanced)
ai.chat({
  system = {
    { type = "text", text = "You are a helpful assistant." },
    { type = "text", text = "Always provide examples when explaining concepts." }
  },
  prompt = "Explain recursion"
})
```

### 3. Tool Execution Framework

The connector can automatically execute tool calls and continue conversations:

```lua
local tool_registry = {
  list_files = function(input)
    local handle = io.popen("ls " .. (input.path or "."))
    local result = handle:read("*a")
    handle:close()
    return { files = result, path = input.path }
  end,
  
  calculate = function(input)
    local func = load("return " .. input.expression)
    return { result = func() }
  end
}

local response = ai.chat({
  provider = 'anthropic',
  prompt = 'Calculate 15 * 23 and list files in /tmp',
  tools = {
    {
      name = "calculate",
      description = "Perform calculations",
      input_schema = {
        type = "object",
        properties = { expression = { type = "string" } },
        required = { "expression" }
      }
    },
    {
      name = "list_files", 
      description = "List directory contents",
      input_schema = {
        type = "object",
        properties = { path = { type = "string" } }
      }
    }
  },
  tool_registry = tool_registry,
  auto_execute_tools = true,
  return_structured = true
})
```

### 4. Error Handling

The framework provides comprehensive error handling for tool execution:

```lua
-- Tool execution errors are captured and returned
{
  tool_use_id = "call_123",
  type = "tool_result",
  content = { error = "Tool execution failed: division by zero" },
  is_error = true
}

-- Missing tools are handled gracefully
{
  tool_use_id = "call_456", 
  type = "tool_result",
  content = { error = "Tool not found: nonexistent_tool" },
  is_error = true
}
```

## API Reference

### M.chat(opts)

Enhanced options:

- `system` (string|table): System prompt (string, array of strings, or content blocks)
- `tools` (table): Array of tool definitions for the AI model
- `tool_choice` (string|table): Tool choice preference ("auto", "none", or specific tool)
- `tool_registry` (table): Map of tool names to execution functions
- `auto_execute_tools` (boolean): Whether to automatically execute tool calls
- `return_structured` (boolean): Return structured response instead of just text
- `max_tokens` (number): Maximum tokens for response (Anthropic only)

### Tool Definition Format

```lua
{
  name = "tool_name",
  description = "What the tool does",
  input_schema = {
    type = "object",
    properties = {
      param1 = { type = "string", description = "Parameter description" },
      param2 = { type = "number", description = "Another parameter" }
    },
    required = { "param1" }
  }
}
```

### Tool Function Format

```lua
function(input)
  -- input contains the parameters from the AI model
  -- Return any serializable data structure
  return { result = "success", data = input.param1 }
end
```

## Backward Compatibility

All existing code continues to work unchanged:

```lua
-- This still works exactly as before
local text = ai.chat({
  prompt = "Analyze this code",
  provider = "anthropic"
})
-- Returns: string
```

New features are opt-in through additional parameters.

## Testing

Run the comprehensive unit tests:

```bash
cd tests
lua -e 'local t = require("test_ai_connector"); t.run_tests()'
```

Tests cover:
- Payload formation for all providers
- System message handling (strings, arrays, content blocks)
- Response parsing (text and tool calls)
- Tool scaffolding and execution
- Error handling scenarios

## Examples

See `examples/tool_usage_example.lua` for complete working examples demonstrating:
- Basic tool usage
- Advanced system prompts
- Multiple tool execution
- Error handling
- Backward compatibility

## Provider Support

| Feature | Anthropic | OpenAI | OpenRouter |
|---------|-----------|--------|------------|
| Basic chat | ✅ | ✅ | ✅ |
| System prompts | ✅ (top-level) | ✅ (message role) | ✅ (message role) |
| Content blocks | ✅ | ❌ (converted to string) | ❌ (converted to string) |
| Tool calls | ✅ | ✅ | ✅ |
| Tool execution | ✅ | ✅ | ✅ |

## Migration Guide

To use the new features in existing code:

1. **Add tool support**: Define tools and tool_registry
2. **Enable auto-execution**: Set `auto_execute_tools = true`
3. **Get structured responses**: Set `return_structured = true`
4. **Use advanced system prompts**: Pass arrays or content blocks to `system`

No changes required for basic usage - everything remains backward compatible.
