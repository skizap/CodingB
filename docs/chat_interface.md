# CodingBuddy Chat Interface - Technical Reference

This document provides technical details about the chat interface implementation for developers and advanced users.

> **For user documentation, see [USER_GUIDE.md](../USER_GUIDE.md)**
> **For API reference, see [DEVELOPER.md](../DEVELOPER.md)**

## Technical Overview

The chat interface transforms CodingBuddy from a simple menu-driven tool into an interactive AI coding assistant with persistent conversation management.

## Implementation Architecture

### Core Components

| Component | File | Responsibility |
|-----------|------|----------------|
| Chat Interface | `chat_interface.lua` | User interaction, command processing |
| Conversation Manager | `conversation_manager.lua` | State management, persistence |
| AI Integration | `ai_connector.lua` | Multi-provider AI communication |
| Storage Layer | JSON files | Conversation persistence |

### Data Flow

```
User Input → Command Parser → Conversation Manager → AI Connector → Response Display
     ↓              ↓                ↓                    ↓              ↓
Input Dialog → /new, /history → Message Storage → API Request → Message Dialog
```

### Storage Structure

```
~/.config/geany/plugins/geanylua/codingbuddy/
├── conversations/           # Conversation history storage
│   ├── conv_1234567890_1234.json
│   ├── conv_1234567891_5678.json
│   └── ...
├── logs/                   # Debug and error logs
└── cache/                  # Response caching
```

## Command Processing

### Command Parser Implementation

The chat interface processes user input through a command parser that distinguishes between:

- **Chat commands** (starting with `/`) - Interface control
- **Regular messages** - AI interaction

```lua
local function process_chat_command(input)
  if input:match("^/new") then
    return handle_new_conversation()
  elseif input:match("^/history") then
    return handle_conversation_history()
  elseif input:match("^/quit") or input:match("^/exit") then
    return handle_quit()
  else
    return process_chat_message(input)
  end
end
```

### State Management

The chat interface maintains several state variables:

- `current_conversation` - Active conversation object
- `chat_active` - Boolean flag for chat session status
- `conversation_context` - Message history for AI context

## Conversation Data Model

### JSON Schema

Each conversation is stored as a JSON file with the following structure:

```json
{
  "id": "conv_1234567890_1234",
  "title": "Auto-generated from first user message",
  "created_at": "2024-01-01T12:00:00Z",
  "updated_at": "2024-01-01T12:30:00Z",
  "messages": [
    {
      "role": "user|assistant",
      "content": "Message text content",
      "timestamp": "ISO8601 timestamp",
      "tokens": {
        "prompt_tokens": 25,
        "completion_tokens": 150,
        "total_tokens": 175
      },
      "cost": 0.001234
    }
  ],
  "metadata": {
    "total_tokens": 175,
    "total_cost": 0.001234,
    "model_used": "claude-3-sonnet",
    "provider": "anthropic"
  }
}
```

### Conversation Lifecycle

1. **Creation** - `create_new_conversation()` generates unique ID
2. **Message Addition** - `add_message()` appends to messages array
3. **Auto-save** - Conversation saved after each message exchange
4. **Context Extraction** - `get_conversation_context()` for AI requests

### UI Limitations and Solutions

Due to GeanyLua's limited GTK bindings, the current implementation uses:

1. **geany.input()** dialogs for user input
2. **geany.message()** for displaying responses
3. **Text-based conversation display** with timestamps
4. **Command-based navigation** for advanced features

### Future Enhancements

When more advanced GTK bindings become available:

1. **Dedicated chat window** with proper text areas
2. **Syntax highlighting** for code responses
3. **Real-time typing indicators** during AI processing
4. **Sidebar integration** within Geany's interface
5. **Rich text formatting** for better readability

## UI Implementation Details

### GeanyLua Constraints

Due to GeanyLua's limited GTK bindings, the implementation uses:

1. **Input Dialogs** - `geany.input()` for user message entry
2. **Message Dialogs** - `geany.message()` for response display
3. **Text-based Interface** - No rich text or custom widgets
4. **Modal Interaction** - Sequential dialog-based conversation flow

### Dialog Flow

```
User Action → geany.input() → Process Input → AI Request → geany.message() → Loop
```

### Error Handling

The interface includes comprehensive error handling for:

- **Network failures** - Graceful degradation with user notification
- **API errors** - Provider-specific error message parsing
- **JSON corruption** - Fallback parsing and recovery
- **File system issues** - Permission and storage error handling

## Performance Considerations

### Memory Management

- **Conversation context** limited to configurable window size
- **Message history** loaded on-demand from disk
- **Cache management** for frequently accessed conversations

### Optimization Strategies

- **Lazy loading** of conversation list
- **Incremental saves** after each message
- **Context window management** for large conversations
- **Response caching** to reduce API calls

## Integration Points

### Geany Integration

- **Menu registration** via `geany.add_menu_item()`
- **Buffer access** through `geany.text()` and `geany.filename()`
- **File monitoring** for context-aware analysis

### AI Connector Integration

- **Multi-message context** passed to `ai_connector.chat()`
- **Structured responses** with metadata extraction
- **Provider fallback** handled transparently

## Testing

### Unit Tests

The chat interface includes comprehensive tests:

```bash
cd tests
lua test_chat_interface.lua
```

### Test Coverage

- **Conversation management** - Creation, saving, loading
- **Message handling** - Adding, context extraction
- **Command processing** - All chat commands
- **Error scenarios** - Network failures, invalid input
- **JSON handling** - Encoding, decoding, corruption recovery

### Manual Testing

1. **Basic chat flow** - Open chat, send message, receive response
2. **Command functionality** - Test `/new`, `/history`, `/quit`
3. **Conversation persistence** - Restart Geany, verify history
4. **Error handling** - Invalid API keys, network issues

## Future Enhancements

### Planned Features

- **Rich text display** when GTK bindings improve
- **Syntax highlighting** for code responses
- **Real-time typing indicators**
- **Sidebar integration** within Geany
- **Conversation export/import**

### Extension Points

The architecture supports future enhancements:

- **Custom UI widgets** when GeanyLua expands
- **Plugin system** for additional chat commands
- **External tool integration** via tool execution framework
- **Advanced conversation analytics**

---

**For user documentation:** [USER_GUIDE.md](../USER_GUIDE.md)
**For API reference:** [DEVELOPER.md](../DEVELOPER.md)
**For troubleshooting:** [USER_GUIDE.md#troubleshooting](../USER_GUIDE.md#troubleshooting)
