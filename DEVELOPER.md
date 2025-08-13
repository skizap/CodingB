# CodingBuddy Developer Guide

Complete reference for developers working with or contributing to CodingBuddy.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [API Reference](#api-reference)
3. [Development Setup](#development-setup)
4. [Contributing Guidelines](#contributing-guidelines)
5. [Testing](#testing)
6. [Plugin Development](#plugin-development)

## Architecture Overview

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Geany Text Editor                        │
├─────────────────────────────────────────────────────────────┤
│                    GeanyLua Plugin                          │
├─────────────────────────────────────────────────────────────┤
│  CodingBuddy Plugin Architecture                            │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                 │ 
│  │   main.lua      │    │ chat_interface  │                 │
│  │   - Plugin init │◄──►│ - UI logic      │                 │
│  │   - Menu items  │    │ - Chat loop     │                 │
│  └─────────────────┘    │ - Commands      │                 │
│                         └─────────────────┘                 │
│                                 │                           │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │conversation_mgr │◄──►│  ai_connector   │                 │
│  │- State mgmt     │    │ - Multi-provider│                 │
│  │- Persistence    │    │ - Context aware │                 │
│  │- History        │    │ - Tool support  │                 │
│  └─────────────────┘    └─────────────────┘                 │
│           │                       │                         │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │   File System        │   AI Providers  │                 │
│  │ - JSON storage  │    │ - Anthropic     │                 │
│  │ - Conversations │    │ - OpenAI        │                 │
│  │ - Logs/Cache    │    │ - OpenRouter    │                 │
│  └─────────────────┘    └─────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

### Core Components

| Component | File | Purpose |
|-----------|------|---------|
| Plugin Entry | `main.lua` | Geany integration, menu registration |
| Chat Interface | `chat_interface.lua` | User interaction, chat loop |
| Conversation Manager | `conversation_manager.lua` | State management, persistence |
| AI Connector | `ai_connector.lua` | Multi-provider AI communication |
| Configuration | `config.lua` | Settings management |
| Utilities | `utils.lua` | Helper functions |
| Dialogs | `dialogs.lua` | UI components |

## API Reference

### ai_connector.lua

#### M.chat(opts)

Main AI communication function with multi-provider support.

**Parameters:**
```lua
opts = {
  -- Required
  prompt = "string",              -- User message or prompt
  
  -- Provider selection
  provider = "openrouter",        -- "openrouter", "anthropic", "openai"
  model = "claude-3.5-sonnet",    -- Specific model (optional)
  
  -- Conversation context
  system = "string or table",     -- System prompt
  messages = {                    -- Multi-message context
    {role = "user", content = "..."},
    {role = "assistant", content = "..."}
  },
  
  -- Response options
  return_structured = false,      -- Return structured response
  max_tokens = 2048,             -- Maximum response tokens
  
  -- Tool support (advanced)
  tools = {},                    -- Tool definitions
  tool_registry = {},            -- Tool execution functions
  auto_execute_tools = false     -- Auto-execute tool calls
}
```

**Returns:**
```lua
-- Simple response (default)
"AI response text"

-- Structured response (return_structured = true)
{
  text = "AI response text",
  tool_calls = {...},           -- Tool calls if any
  usage = {                     -- Token usage
    prompt_tokens = 50,
    completion_tokens = 100,
    total_tokens = 150
  },
  cost = 0.001234,             -- Estimated cost
  provider = "anthropic",       -- Provider used
  model = "claude-3.5-sonnet"  -- Model used
}
```

**Example:**
```lua
local ai = require('codingbuddy.ai_connector')

-- Simple chat
local response = ai.chat({
  prompt = "Explain recursion in Python",
  provider = "openrouter"
})

-- Conversation with context
local response = ai.chat({
  system = "You are a helpful coding assistant",
  messages = {
    {role = "user", content = "What is Python?"},
    {role = "assistant", content = "Python is a programming language..."},
    {role = "user", content = "Show me a simple example"}
  },
  return_structured = true
})
```

### conversation_manager.lua

#### create_new_conversation()

Creates a new conversation session.

**Returns:**
```lua
{
  id = "conv_1234567890_1234",
  title = "",
  created_at = "2024-01-01T12:00:00Z",
  updated_at = "2024-01-01T12:00:00Z",
  messages = {},
  metadata = {
    total_tokens = 0,
    total_cost = 0,
    model_used = "",
    provider = ""
  }
}
```

#### add_message(role, content, metadata)

Adds a message to the current conversation.

**Parameters:**
- `role` (string): "user" or "assistant"
- `content` (string): Message content
- `metadata` (table, optional): Token usage, cost, etc.

#### get_conversation_context(max_messages)

Gets conversation context for AI requests.

**Parameters:**
- `max_messages` (number): Maximum messages to include

**Returns:**
```lua
{
  {role = "user", content = "..."},
  {role = "assistant", content = "..."},
  -- ... up to max_messages
}
```

#### save_current_conversation()

Saves current conversation to disk.

**Returns:**
- `true, nil` on success
- `false, error_message` on failure

#### list_conversations()

Lists all saved conversations.

**Returns:**
```lua
{
  {
    id = "conv_1234567890_1234",
    title = "Python optimization help",
    created_at = "2024-01-01T12:00:00Z",
    message_count = 6,
    total_cost = 0.001234
  },
  -- ... more conversations
}
```

### chat_interface.lua

#### open_chat()

Opens the interactive chat interface.

#### quick_chat(message)

Single-message interaction without opening full chat.

**Parameters:**
- `message` (string): Message to send to AI

#### get_chat_status()

Gets current chat interface status.

**Returns:**
```lua
{
  active = true,
  conversation_id = "conv_1234567890_1234",
  message_count = 5,
  total_tokens = 1250,
  total_cost = 0.001234
}
```

### config.lua

#### load_config()

Loads configuration from file or environment variables.

#### get_provider_config(provider_name)

Gets configuration for specific AI provider.

#### get_setting(key, default)

Gets configuration setting with fallback.

## Development Setup

### Prerequisites

1. **Geany with GeanyLua** plugin
2. **Lua 5.1+** with development headers
3. **Git** for version control
4. **Text editor** with Lua syntax highlighting

### Clone and Setup

```bash
# Fork the repository on GitHub first
git clone https://github.com/skizap/CodingBuddy.git
cd CodingBuddy

# Create development symlink
mkdir -p ~/.config/geany/plugins/geanylua/
ln -s $(pwd)/codingbuddy ~/.config/geany/plugins/geanylua/codingbuddy

# Copy sample configuration
cp codingbuddy/config.sample.json codingbuddy/config.json
# Edit config.json with your API keys
```

### Development Workflow

1. **Make changes** to Lua files
2. **Restart Geany** to reload plugin
3. **Test changes** using Tools menu
4. **Check logs** for errors: `~/.config/geany/plugins/geanylua/codingbuddy/logs/`
5. **Run tests** to verify functionality

### Debugging

#### Enable Debug Mode

```bash
export CODINGBUDDY_DEBUG=1
```

Or in config.json:
```json
{
  "debug_mode": true
}
```

#### Debug Output

Debug information is logged to:
- Console (if running Geany from terminal)
- `~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log`

#### Common Debug Techniques

```lua
-- Add debug prints
local utils = require('codingbuddy.utils')
utils.log("Debug: variable value = " .. tostring(variable))

-- Check function parameters
local function my_function(param1, param2)
  utils.log("my_function called with: " .. tostring(param1) .. ", " .. tostring(param2))
  -- ... function body
end

-- Catch and log errors
local ok, result = pcall(risky_function, param)
if not ok then
  utils.log("Error in risky_function: " .. tostring(result))
end
```

## Contributing Guidelines

### Code Style

#### Lua Conventions

```lua
-- Use snake_case for variables and functions
local my_variable = "value"
local function my_function()
end

-- Use PascalCase for modules/classes
local MyModule = {}

-- Constants in UPPER_CASE
local MAX_RETRIES = 3

-- Indentation: 2 spaces
if condition then
  do_something()
  if nested_condition then
    do_nested_thing()
  end
end

-- Function documentation
--- Brief description of function
-- @param param1 string Description of parameter
-- @param param2 number Optional parameter (optional)
-- @return string Description of return value
local function documented_function(param1, param2)
  -- Implementation
end
```

#### File Organization

```lua
-- File header comment
-- filename.lua - Brief description of module purpose

-- Imports at top
local utils = require('codingbuddy.utils')
local config = require('codingbuddy.config')

-- Module table
local M = {}

-- Private functions first
local function private_helper()
  -- Implementation
end

-- Public functions
function M.public_function()
  -- Implementation
end

-- Export module
return M
```

### Commit Guidelines

#### Commit Message Format

```
type(scope): brief description

Longer description if needed.

- List specific changes
- Reference issues: Fixes #123
```

#### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (no logic changes)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

#### Examples

```
feat(chat): add conversation history browsing

- Implement /history command
- Add conversation selection dialog
- Update conversation_manager with list_conversations()

Fixes #45
```

### Pull Request Process

1. **Create feature branch** from main
2. **Make changes** following code style
3. **Add tests** for new functionality
4. **Update documentation** if needed
5. **Test thoroughly** on your system
6. **Submit pull request** with clear description

### Testing Requirements

All contributions must include:

1. **Unit tests** for new functions
2. **Integration tests** for new features
3. **Manual testing** instructions
4. **Documentation updates** if applicable

## Testing

### Running Tests

```bash
cd tests

# Run all tests
lua test_ai_connector.lua
lua test_chat_interface.lua
lua test_gtk_capabilities.lua

# Run specific test
lua -e "local t = require('test_ai_connector'); t.test_payload_formation()"
```

### Writing Tests

#### Test File Structure

```lua
-- test_mymodule.lua
local mymodule = require('codingbuddy.mymodule')

local function test_basic_functionality()
  print("=== Testing Basic Functionality ===")
  
  local result = mymodule.my_function("test_input")
  assert(result == "expected_output", "Function should return expected output")
  
  print("✓ Basic functionality works")
end

local function test_error_handling()
  print("=== Testing Error Handling ===")
  
  local ok, err = pcall(mymodule.my_function, nil)
  assert(not ok, "Function should fail with nil input")
  
  print("✓ Error handling works")
end

local function run_all_tests()
  print("MyModule Test Suite")
  print("==================")
  
  test_basic_functionality()
  test_error_handling()
  
  print("\n✓ All tests passed")
end

-- Export for use as module
local M = {}
M.run_all_tests = run_all_tests
M.test_basic_functionality = test_basic_functionality

-- Run if executed directly
if not package.loaded[...] then
  run_all_tests()
end

return M
```

### Test Coverage

Aim for comprehensive test coverage:

- **Happy path** - Normal usage scenarios
- **Edge cases** - Boundary conditions
- **Error conditions** - Invalid inputs, network failures
- **Integration** - Component interactions

## Plugin Development

### Adding New Features

#### 1. Plan the Feature

- Define clear requirements
- Consider user experience
- Plan API changes
- Update documentation

#### 2. Implement Core Logic

```lua
-- Add to appropriate module
local function new_feature_function(params)
  -- Validate inputs
  if not params or not params.required_field then
    return nil, "Missing required parameter"
  end
  
  -- Implement logic
  local result = process_data(params)
  
  -- Return result
  return result
end
```

#### 3. Add UI Integration

```lua
-- In main.lua or chat_interface.lua
local function handle_new_feature()
  local input = geany.input("Enter parameters:")
  if not input then return end
  
  local result, err = mymodule.new_feature_function({required_field = input})
  if not result then
    geany.message("Error: " .. tostring(err))
    return
  end
  
  geany.message("Result: " .. tostring(result))
end

-- Register menu item
geany.add_menu_item("CodingBuddy: New Feature", handle_new_feature)
```

#### 4. Add Tests

```lua
local function test_new_feature()
  local result = mymodule.new_feature_function({required_field = "test"})
  assert(result, "New feature should work with valid input")
end
```

#### 5. Update Documentation

- Add to API reference
- Update user guide
- Add examples

### Best Practices

1. **Maintain backward compatibility** when possible
2. **Use existing patterns** and conventions
3. **Add comprehensive error handling**
4. **Include debug logging** for troubleshooting
5. **Test on multiple platforms** if possible
6. **Update configuration schema** if needed

---

**Ready to contribute?** Check out the [open issues](https://github.com/skizap/CodingBuddy/issues) or propose new features!
