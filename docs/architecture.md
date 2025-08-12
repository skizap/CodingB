# CodingBuddy Chat Interface Architecture Design

## Overview

This document outlines the comprehensive architecture design for the CodingBuddy chat interface, transforming it from a simple menu-driven plugin into an interactive AI coding assistant similar to Cline/Augment.

## System Architecture

### High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Geany Text Editor                        │
├─────────────────────────────────────────────────────────────┤
│                    GeanyLua Plugin                          │
├─────────────────────────────────────────────────────────────┤
│  CodingBuddy Plugin Architecture                            │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   main.lua      │    │ chat_interface  │                │
│  │   - Plugin init │◄──►│ - UI logic      │                │
│  │   - Menu items  │    │ - Chat loop     │                │
│  └─────────────────┘    │ - Commands      │                │
│                         └─────────────────┘                │
│                                 │                           │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │conversation_mgr │◄──►│  ai_connector   │                │
│  │- State mgmt     │    │ - Multi-provider│                │
│  │- Persistence    │    │ - Context aware │                │
│  │- History        │    │ - Tool support  │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   File System  │    │   AI Providers  │                │
│  │ - JSON storage  │    │ - Anthropic     │                │
│  │ - Conversations │    │ - OpenAI        │                │
│  │ - Logs/Cache    │    │ - OpenRouter    │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Chat Interface Layer (`chat_interface.lua`)

**Responsibilities:**
- User interaction management
- Chat session orchestration
- Command processing (`/new`, `/history`, `/quit`)
- UI state management
- Error handling and user feedback

**Key Functions:**
- `open_chat()` - Main interactive chat loop
- `quick_chat(message)` - Single interaction mode
- `process_chat_command(input)` - Command routing
- `process_chat_message(input)` - AI interaction handling
- `get_chat_status()` - Status reporting

**Design Patterns:**
- **Command Pattern** for chat commands
- **State Machine** for chat session states
- **Observer Pattern** for UI updates

### 2. Conversation Management Layer (`conversation_manager.lua`)

**Responsibilities:**
- Conversation lifecycle management
- Message history tracking
- Metadata collection (tokens, costs, timestamps)
- Persistence coordination
- Context extraction for AI

**Data Structures:**
```lua
Conversation = {
  id = "conv_timestamp_random",
  title = "Auto-generated from first message",
  created_at = "ISO8601 timestamp",
  updated_at = "ISO8601 timestamp",
  messages = [
    {
      role = "user|assistant",
      content = "message text",
      timestamp = "ISO8601",
      tokens = {usage_info},
      cost = number
    }
  ],
  metadata = {
    total_tokens = number,
    total_cost = number,
    model_used = "model_name",
    provider = "provider_name"
  }
}
```

**Key Functions:**
- `create_new_conversation()` - Initialize new session
- `add_message(role, content, metadata)` - Message tracking
- `get_conversation_context(max_messages)` - AI context preparation
- `save_current_conversation()` - Persistence
- `list_conversations()` - History browsing

### 3. AI Integration Layer (`ai_connector.lua` - Enhanced)

**Responsibilities:**
- Multi-provider AI communication
- Context-aware request formation
- Response parsing and structuring
- Cost and usage tracking
- Tool execution framework

**Enhanced Features:**
- **Conversation Context Support**: `messages` parameter for multi-turn conversations
- **System Prompt Flexibility**: String, array, or content blocks
- **Structured Responses**: Text + metadata extraction
- **Provider Abstraction**: Unified interface for multiple AI providers

**Integration Points:**
```lua
-- Chat interface calls ai_connector with:
ai_request = {
  provider = 'anthropic',
  system = 'You are CodingBuddy...',
  messages = conversation_context,  -- Multi-message history
  return_structured = true,
  max_tokens = 2048
}
```

### 4. Storage Layer

**File System Organization:**
```
~/.config/geany/plugins/geanylua/codingbuddy/
├── conversations/              # Chat history storage
│   ├── conv_1234567890_1234.json
│   ├── conv_1234567891_5678.json
│   └── ...
├── logs/                      # Existing logging
│   ├── codingbuddy.log
│   └── usage.jsonl
├── cache/                     # Existing cache
└── config.json               # Existing configuration
```

**Storage Strategy:**
- **JSON format** for human readability and debugging
- **One file per conversation** for scalability
- **Atomic writes** to prevent corruption
- **Lazy loading** for performance
- **Fallback JSON handling** when dkjson unavailable

## UI Architecture

### Constraint-Driven Design

Due to GeanyLua's limited GTK bindings, the UI architecture uses:

**Input Layer:**
- `geany.input()` dialogs for user input
- Command-based navigation for advanced features
- Text-based conversation display

**Display Layer:**
- `geany.message()` for responses and status
- Formatted text with timestamps and role indicators
- Conversation statistics display

**Navigation Layer:**
- Menu integration via `geany.add_menu_item()`
- Command processing (`/new`, `/history`, `/quit`)
- Context-sensitive help and prompts

### UI Flow Diagram

```
┌─────────────────┐
│   User Action   │
│ (Menu/Command)  │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ chat_interface  │
│   .open_chat()  │
└─────────┬───────┘
          │
┌─────────▼───────┐    ┌─────────────────┐
│  Input Dialog   │◄──►│ Command Parser  │
│ geany.input()   │    │ /new /history   │
└─────────┬───────┘    └─────────────────┘
          │
┌─────────▼───────┐
│ Message Process │
│ - Add to conv   │
│ - Get AI resp   │
│ - Update state  │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Response Display│
│ geany.message() │
│ + conversation  │
│ + statistics    │
└─────────────────┘
```

## Data Flow Architecture

### Message Processing Pipeline

```
User Input → Command Check → Message Storage → Context Prep → AI Request → Response Parse → Storage → Display
     │              │              │              │              │              │           │         │
     │              │              │              │              │              │           │         │
     ▼              ▼              ▼              ▼              ▼              ▼           ▼         ▼
┌─────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│Raw Text │ │Command/Chat │ │conversation │ │AI Context   │ │AI Provider  │ │Parsed   │ │Updated  │ │User     │
│         │ │Distinction  │ │_manager     │ │Preparation  │ │Request      │ │Response │ │Storage  │ │Display  │
└─────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘ └─────────┘ └─────────┘
```

### State Management

**Conversation State:**
- Current active conversation
- Message history buffer
- UI state (chat window open/closed)
- Error states and recovery

**Persistence State:**
- Auto-save after each message
- Lazy loading of conversation list
- Cache invalidation on updates
- Backup and recovery mechanisms

## Integration Architecture

### Existing System Integration

**Backward Compatibility:**
- Original `analyze_current_buffer()` preserved
- Existing configuration system reused
- Current AI connector enhanced, not replaced
- Menu structure extended, not modified

**New Integration Points:**
- `analyze_current_buffer_with_chat()` - Enhanced analysis with chat context
- `quick_chat()` - Single-interaction mode
- Chat status reporting for external monitoring

### Extension Points

**Future Enhancement Architecture:**
- **Plugin Interface**: Modular design for additional features
- **Provider Extension**: Easy addition of new AI providers
- **UI Enhancement**: Ready for advanced GTK when available
- **Tool Integration**: Framework for external tool integration

## Security and Privacy Architecture

**Data Protection:**
- Local storage only (no cloud sync)
- API keys in secure configuration
- Conversation data encrypted at rest (future)
- User consent for data collection

**Error Handling:**
- Graceful degradation on API failures
- Conversation recovery mechanisms
- User-friendly error messages
- Debug logging for troubleshooting

## Performance Architecture

**Optimization Strategies:**
- Lazy loading of conversation history
- Context window management (last N messages)
- Efficient JSON parsing with fallbacks
- Memory management for long conversations

**Scalability Considerations:**
- File-per-conversation for large histories
- Conversation archiving mechanisms
- Cache management and cleanup
- Resource usage monitoring

## Testing Architecture

**Component Testing:**
- Unit tests for each module
- Integration tests for AI connector
- UI flow testing with mock inputs
- Error condition testing

**System Testing:**
- End-to-end conversation flows
- Cross-platform compatibility
- Performance under load
- Recovery from failures

This architecture provides a solid foundation for the interactive chat interface while maintaining flexibility for future enhancements and ensuring robust operation within GeanyLua's constraints.
