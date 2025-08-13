#!/usr/bin/env lua

-- manual_test_phase10.lua - Manual test examples for Phase 10
-- Demonstrates multi-provider parity and robustness with example requests

print("=== Phase 10 Manual Test Examples ===\n")

-- Example 1: OpenRouter with Anthropic model
print("1. OpenRouter with Anthropic model:")
local openrouter_anthropic_example = {
  provider = "openrouter",
  model = "anthropic/claude-3.5-sonnet",
  prompt = "Explain recursion in Python briefly",
  system = "You are a helpful coding tutor",
  return_structured = true
}

print("Request:")
print("  provider: " .. openrouter_anthropic_example.provider)
print("  model: " .. openrouter_anthropic_example.model)
print("  return_structured: " .. tostring(openrouter_anthropic_example.return_structured))
print("\nExpected behavior:")
print("  - OpenRouter detects anthropic/ prefix")
print("  - Uses Anthropic API format internally")
print("  - Returns structured response with usage, cost, model, provider")
print()

-- Example 2: OpenRouter with OpenAI model  
print("2. OpenRouter with OpenAI model:")
local openrouter_openai_example = {
  provider = "openrouter",
  model = "openai/gpt-4o-mini",
  prompt = "What are the benefits of type hints in Python?",
  system = {"You are a Python expert", "Be concise and practical"},
  return_structured = true
}

print("Request:")
print("  provider: " .. openrouter_openai_example.provider)
print("  model: " .. openrouter_openai_example.model)
print("  system: array format")
print("\nExpected behavior:")
print("  - OpenRouter detects openai/ prefix")
print("  - Uses OpenAI API format internally")
print("  - Converts system array to concatenated string")
print("  - Returns structured response")
print()

-- Example 3: Multi-turn conversation
print("3. Multi-turn conversation:")
local conversation_example = {
  provider = "anthropic",
  messages = {
    { role = "user", content = "What is a closure in JavaScript?" },
    { role = "assistant", content = "A closure is a function that has access to variables from an outer scope..." },
    { role = "user", content = "Can you show me an example?" }
  },
  system = {
    { type = "text", text = "You are a JavaScript expert" },
    { type = "text", text = "Use practical examples" }
  },
  return_structured = true
}

print("Request:")
print("  provider: " .. conversation_example.provider)
print("  messages: 3-turn conversation")
print("  system: content blocks format")
print("\nExpected behavior:")
print("  - Maintains conversation context")
print("  - Anthropic format used with content blocks")
print("  - Usage tracking includes all turns")
print()

-- Example 4: Tool use example
print("4. Tool use with different providers:")
local tool_example = {
  provider = "openrouter",
  model = "anthropic/claude-3.5-sonnet",
  prompt = "List the files in the current directory",
  tools = {
    list_files = {
      description = "List files and directories",
      input_schema = {
        type = "object",
        properties = {
          path = { type = "string", description = "Directory path" }
        }
      },
      handler = function(args)
        return { files = { "file1.txt", "file2.py", "dir1/" } }
      end
    }
  },
  tool_choice = "auto",
  return_structured = true
}

print("Request:")
print("  provider: openrouter (-> anthropic)")
print("  tools: list_files with handler")
print("  tool_choice: auto")
print("\nExpected behavior:")
print("  - Tool definition converted to Anthropic format")
print("  - AI can call list_files tool")
print("  - Structured response includes tool_calls")
print()

-- Example 5: Cost and usage tracking
print("5. Usage and cost tracking:")
local usage_example = {
  -- Mock usage data that would be returned
  usage = {
    prompt_tokens = 150,
    completion_tokens = 75,
    total_tokens = 225
  },
  cost_per_1k = {
    input = 0.003,
    output = 0.015
  }
}

local estimated_cost = (usage_example.usage.prompt_tokens / 1000) * usage_example.cost_per_1k.input +
                      (usage_example.usage.completion_tokens / 1000) * usage_example.cost_per_1k.output

print("Usage tracking:")
print(string.format("  Tokens: %d prompt + %d completion = %d total", 
  usage_example.usage.prompt_tokens, 
  usage_example.usage.completion_tokens,
  usage_example.usage.total_tokens))
print(string.format("  Cost: (150/1000)*$0.003 + (75/1000)*$0.015 = $%.6f", estimated_cost))
print("\nExpected behavior:")
print("  - Usage normalized across all providers")
print("  - Cost calculated using configured rates")
print("  - Logged to usage.jsonl for tracking")
print()

print("=== Summary of Phase 10 Enhancements ===")
print("✓ OpenRouter model parsing and pass-through")
print("✓ Normalized usage extraction (prompt_tokens, completion_tokens, total_tokens)")
print("✓ Consistent cost estimation across providers")
print("✓ Structured responses always include: text, tool_calls, usage, cost, model, provider")
print("✓ Multi-turn conversation context support")
print("✓ Flexible system prompt formats (string, array, content blocks)")
print("✓ Tool format conversion (Anthropic vs OpenAI formats)")
print("✓ Provider fallback chain with explicit overrides")
print()

print("Ready for manual testing with real API keys!")
print("To test with real APIs, ensure your config.json has:")
print("  - openrouter_api_key")
print("  - anthropic_api_key") 
print("  - openai_api_key")
print("  - cost.prices_per_1k configuration")
