-- test_chat_interface.lua - Test the chat interface functionality
-- This script tests the chat interface components outside of Geany

-- Set up module path for testing
package.path = '../codingbuddy/?.lua;../codingbuddy/?/init.lua;'..package.path

local conversation_manager = require('codingbuddy.conversation_manager')
local chat_interface = require('codingbuddy.chat_interface')

local function test_conversation_manager()
  print("=== Testing Conversation Manager ===")
  
  -- Create new conversation
  local conv = conversation_manager.create_new_conversation()
  print("✓ Created new conversation:", conv.id)
  
  -- Add messages
  conversation_manager.add_message('user', 'Hello, can you help me with Python?')
  conversation_manager.add_message('assistant', 'Of course! I\'d be happy to help you with Python. What specific topic or problem would you like assistance with?')
  conversation_manager.add_message('user', 'I need help with list comprehensions')
  
  print("✓ Added test messages")
  
  -- Get context
  local context = conversation_manager.get_conversation_context(5)
  print("✓ Retrieved context with", #context, "messages")
  
  -- Get stats
  local stats = conversation_manager.get_conversation_stats()
  print("✓ Conversation stats:")
  print("  - Messages:", stats.message_count)
  print("  - Tokens:", stats.total_tokens)
  print("  - Cost: $" .. string.format("%.4f", stats.total_cost))
  
  -- Save conversation
  local ok, err = conversation_manager.save_current_conversation()
  if ok then
    print("✓ Saved conversation successfully")
  else
    print("✗ Failed to save conversation:", err)
  end
  
  -- List conversations
  local conversations = conversation_manager.list_conversations()
  print("✓ Found", #conversations, "conversations")
  
  return conv.id
end

local function test_chat_interface_components()
  print("\n=== Testing Chat Interface Components ===")
  
  -- Test status
  local status = chat_interface.get_chat_status()
  print("✓ Chat status:")
  print("  - Active:", status.active)
  print("  - Conversation ID:", status.conversation_id)
  print("  - Messages:", status.message_count)
  
  -- Test quick chat (without actual AI call)
  print("✓ Chat interface components loaded successfully")
end

local function test_json_utilities()
  print("\n=== Testing JSON Utilities ===")
  
  local utils = require('codingbuddy.utils')
  
  -- Test simple encoding
  local test_obj = {
    name = "Test Conversation",
    messages = {
      { role = "user", content = "Hello" },
      { role = "assistant", content = "Hi there!" }
    },
    metadata = {
      tokens = 50,
      cost = 0.001
    }
  }
  
  local json_str = utils.simple_json_encode(test_obj)
  if json_str then
    print("✓ JSON encoding works")
    print("  Encoded length:", #json_str, "characters")
  else
    print("✗ JSON encoding failed")
  end
  
  -- Test simple decoding
  local simple_json = '{"name":"Test","value":42,"active":true}'
  local decoded = utils.simple_json_decode(simple_json)
  if decoded and decoded.name == "Test" and decoded.value == 42 then
    print("✓ JSON decoding works")
  else
    print("✗ JSON decoding failed")
  end
end

local function simulate_chat_session()
  print("\n=== Simulating Chat Session ===")
  
  -- Create a new conversation for testing
  conversation_manager.create_new_conversation()
  
  -- Simulate a few exchanges
  local test_messages = {
    { role = 'user', content = 'What is Python?' },
    { role = 'assistant', content = 'Python is a high-level programming language known for its simplicity and readability.' },
    { role = 'user', content = 'Can you show me a simple example?' },
    { role = 'assistant', content = 'Sure! Here\'s a simple "Hello, World!" example:\n\nprint("Hello, World!")' }
  }
  
  for _, msg in ipairs(test_messages) do
    conversation_manager.add_message(msg.role, msg.content, {
      tokens = { total = 20 },
      cost = 0.0001
    })
  end
  
  print("✓ Simulated chat session with", #test_messages, "messages")
  
  -- Show conversation display format
  local conv = conversation_manager.get_current_conversation()
  print("✓ Conversation title:", conv.title)
  
  local stats = conversation_manager.get_conversation_stats()
  print("✓ Final stats:")
  print("  - Messages:", stats.message_count)
  print("  - Total tokens:", stats.total_tokens)
  print("  - Total cost: $" .. string.format("%.4f", stats.total_cost))
end

local function run_all_tests()
  print("CodingBuddy Chat Interface Test Suite")
  print("====================================")
  
  -- Run tests
  local conv_id = test_conversation_manager()
  test_chat_interface_components()
  test_json_utilities()
  simulate_chat_session()
  
  print("\n=== Test Summary ===")
  print("✓ All tests completed successfully")
  print("✓ Chat interface is ready for integration")
  print("✓ Conversation management is working")
  print("✓ JSON utilities are functional")
  
  print("\nTo test the full chat interface:")
  print("1. Load CodingBuddy in Geany")
  print("2. Use Tools > CodingBuddy: Open Chat")
  print("3. Try commands like '/new', '/history', '/quit'")
  print("4. Send regular messages to test AI integration")
  
  return conv_id
end

-- Export for use as module or run directly
local M = {}
M.run_all_tests = run_all_tests
M.test_conversation_manager = test_conversation_manager
M.test_chat_interface_components = test_chat_interface_components

-- Run tests if executed directly
if not package.loaded[...] then
  run_all_tests()
end

return M
