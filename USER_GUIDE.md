# CodingBuddy User Guide

Complete guide to using CodingBuddy's AI-powered coding assistance features.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Interactive Chat Interface](#interactive-chat-interface)
3. [Code Analysis Features](#code-analysis-features)
4. [Configuration Options](#configuration-options)
5. [Advanced Features](#advanced-features)
6. [Tips and Best Practices](#tips-and-best-practices)
7. [Troubleshooting](#troubleshooting)

## Getting Started

### First Launch

After installation, restart Geany and look for CodingBuddy options in the **Tools** menu:

- **CodingBuddy: Open Chat** - Interactive AI chat interface
- **CodingBuddy: Analyze with Chat** - Analyze current file with chat context
- **CodingBuddy: Analyze Buffer** - Quick analysis (original feature)

### Quick Test

1. Open any code file in Geany
2. Select **Tools → CodingBuddy: Open Chat**
3. Type: "Hello, can you help me with coding?"
4. Press OK to send

You should receive an AI response confirming the connection works.

## Interactive Chat Interface

### Opening the Chat

**Tools → CodingBuddy: Open Chat** opens the interactive chat interface where you can:
- Have ongoing conversations with AI
- Get coding help and explanations
- Analyze and improve your code
- Generate new code snippets

### Chat Interface Layout

```
=== New Conversation ===
Messages: 0 | Tokens: 0 | Cost: $0.0000

--------------------------------------------------
What can I do for you?

Commands:
- Type your message and press OK to send
- Type '/new' to start a new conversation
- Type '/history' to see conversation list
- Type '/quit' to close chat

Your message: [Input dialog appears here]
```

### Chat Commands

| Command | Description | Example |
|---------|-------------|---------|
| `/new` | Start a new conversation | `/new` |
| `/history` | View recent conversations | `/history` |
| `/quit` or `/exit` | Close chat interface | `/quit` |
| `/help` | Show available commands | `/help` |
| `/task start` | Enable task mode (operations require approval) | `/task start` |
| `/task stop` | Disable task mode (operations execute normally) | `/task stop` |
| `/ops` | Show pending operations queue | `/ops` |
| `/approve <id>` | Approve operation by ID for execution | `/approve 1` |
| `/reject <id>` | Reject operation by ID (removes from queue) | `/reject 2` |
| `/clear` | Clear all completed operations | `/clear` |

### Conversation Flow

1. **Type your message** in the input dialog
2. **Press OK** to send to AI
3. **View response** in the message dialog
4. **Continue conversation** - context is preserved
5. **Use commands** for navigation and management

### Example Chat Session

```
Your message: Can you help me optimize this Python function?

[14:30] You: Can you help me optimize this Python function?
[14:30] Assistant: I'd be happy to help optimize your Python function! 
Could you please share the function code you'd like me to review?

Your message: def find_duplicates(lst):
    duplicates = []
    for i in range(len(lst)):
        for j in range(i+1, len(lst)):
            if lst[i] == lst[j] and lst[i] not in duplicates:
                duplicates.append(lst[i])
    return duplicates

[14:31] You: def find_duplicates(lst): ...
[14:31] Assistant: I can see several ways to optimize this function:

1. **Using set for O(n) complexity:**
```python
def find_duplicates(lst):
    seen = set()
    duplicates = set()
    for item in lst:
        if item in seen:
            duplicates.add(item)
        else:
            seen.add(item)
    return list(duplicates)
```

2. **Using Counter (most Pythonic):**
```python
from collections import Counter
def find_duplicates(lst):
    counts = Counter(lst)
    return [item for item, count in counts.items() if count > 1]
```

The original has O(n²) complexity, while these optimized versions are O(n).
```

## Code Analysis Features

### Analyze Current Buffer

**Tools → CodingBuddy: Analyze Buffer** provides quick analysis of the currently open file:

1. **Open any code file** in Geany
2. **Select the menu option**
3. **View analysis results** in a dialog

Analysis includes:
- Code quality assessment
- Potential bugs and issues
- Improvement suggestions
- Best practice recommendations

### Analyze with Chat Context

**Tools → CodingBuddy: Analyze with Chat** integrates analysis with the chat interface:

1. **Opens chat interface** if not already open
2. **Automatically analyzes** current buffer
3. **Adds analysis to conversation** for follow-up questions
4. **Allows interactive discussion** about the analysis

### Supported Languages

CodingBuddy works with any programming language that Geany supports:
- Python, JavaScript, TypeScript
- C, C++, Java, C#
- PHP, Ruby, Go, Rust
- HTML, CSS, SQL
- Shell scripts, Lua
- And many more...

## Configuration Options

### Configuration File Location

```
~/.config/geany/plugins/geanylua/codingbuddy/config.json
```

### Basic Configuration

```json
{
  "providers": {
    "openrouter": {
      "api_key": "your-api-key",
      "base_url": "https://openrouter.ai/api/v1",
      "models": ["anthropic/claude-3.5-sonnet", "openai/gpt-4"]
    }
  },
  "default_provider": "openrouter",
  "cache_enabled": true,
  "max_conversation_length": 50,
  "debug_mode": false
}
```

### Provider Configuration

#### OpenRouter (Recommended)
```json
{
  "openrouter": {
    "api_key": "sk-or-v1-your-key",
    "base_url": "https://openrouter.ai/api/v1",
    "models": [
      "anthropic/claude-3.5-sonnet",
      "openai/gpt-4",
      "meta-llama/llama-3.1-405b"
    ],
    "default_model": "anthropic/claude-3.5-sonnet"
  }
}
```

#### Multiple Providers with Fallback
```json
{
  "providers": {
    "openrouter": {
      "api_key": "sk-or-v1-your-key",
      "priority": 1
    },
    "anthropic": {
      "api_key": "sk-ant-your-key",
      "priority": 2
    },
    "openai": {
      "api_key": "sk-your-key",
      "priority": 3
    }
  },
  "fallback_enabled": true
}
```

### Advanced Settings

```json
{
  "conversation_settings": {
    "max_length": 50,
    "auto_save": true,
    "context_window": 10
  },
  "analysis_settings": {
    "include_suggestions": true,
    "include_examples": true,
    "detail_level": "medium"
  },
  "ui_settings": {
    "show_token_count": true,
    "show_cost": true,
    "timestamp_format": "HH:MM"
  }
}
```

## Advanced Features

### Conversation Management

#### Starting New Conversations
- Use `/new` command in chat
- Each conversation has unique ID and title
- Conversations auto-saved after each exchange

#### Browsing History
- Use `/history` command to see recent conversations
- Select conversation by number to resume
- Conversations persist across Geany sessions

#### Conversation Statistics
Each conversation tracks:
- Message count
- Token usage (prompt + completion)
- Estimated cost
- Model used
- Provider used

### Multi-Provider Support

CodingBuddy can use multiple AI providers with automatic fallback:

1. **Primary provider fails** → Automatically tries secondary
2. **Cost optimization** → Use cheaper models for simple tasks
3. **Model selection** → Different models for different tasks

### Caching System

- **Response caching** reduces API calls for similar requests
- **Configurable cache duration** in settings
- **Cache invalidation** when code changes significantly
- **Manual cache clearing** available

### Context Awareness

CodingBuddy maintains context across:
- **Current conversation** - Full message history
- **Current file** - Understands what you're working on
- **Project context** - Learns from your coding patterns

### Task Mode and Approvals

Task mode provides a safety mechanism for AI operations that modify files or execute commands:

#### Enabling Task Mode
```
User: /task start
System: Task mode enabled. AI requests for file operations will require approval.
```

#### Workflow Example
```
User: Create a hello world script in Python
AI: I'll create a Python hello world script for you.

Operation 1 (write_file) has been queued for approval. Use /approve 1 to execute or /reject 1 to cancel.

User: /ops
Operations Queue:
[10:30] ID:1 write_file - Write to: hello.py (PENDING)

User: /approve 1
System: Approved operation 1

User: Thanks!
System: Executed approved operations:
- Operation 1 (write_file): Success
```

#### Operations That Require Approval
When task mode is enabled, these operations are queued for approval:
- **write_file** - Writing content to files
- **apply_patch** - Applying code patches
- **run_command** - Executing terminal commands

Read-only operations (read_file, list_dir, search_code) continue normally.

#### Task Mode Commands
- `/task start` - Enable task mode
- `/task stop` - Disable task mode
- `/ops` - Show pending operations queue
- `/approve <id>` - Approve operation by ID
- `/reject <id>` - Reject operation by ID
- `/clear` - Clear completed operations

### Conversation Encryption

Protect your conversation history with AES-256-CBC encryption:

#### Setup Steps

1. **Install OpenSSL** (required for encryption):
   ```bash
   sudo apt install openssl  # Ubuntu/Debian
   brew install openssl      # macOS
   ```

2. **Set encryption passphrase**:
   ```bash
   export CODINGBUDDY_PASSPHRASE="your-very-secure-passphrase-here"
   # Add to ~/.bashrc or ~/.zshrc to persist across sessions
   ```

3. **Enable encryption in config**:
   ```json
   {
     "conversation_encryption": true,
     // ... other settings
   }
   ```

#### How It Works
- **New conversations** are automatically encrypted when saved
- **Existing conversations** remain in their current format until modified
- **Loading** automatically detects and handles both encrypted and unencrypted files
- **File extensions** distinguish formats: `.json` (unencrypted) vs `.json.enc` (encrypted)

#### Security Features
- **AES-256-CBC** encryption with PBKDF2 key derivation
- **100,000 iterations** for resistance against rainbow table attacks
- **Random salt** per file prevents identical plaintext producing identical ciphertext
- **Secure passphrase handling** via environment variables only

#### Important Security Notes
- Use a strong 20+ character passphrase with mixed case, numbers, and symbols
- Never store the passphrase in config files or version control
- If you lose your passphrase, encrypted conversations **cannot be recovered**
- Test decryption periodically to ensure your setup works
- Consider using a password manager to generate and store the passphrase

For detailed encryption information, see [ENCRYPTION.md](ENCRYPTION.md).

## Tips and Best Practices

### Effective Prompting

#### Be Specific
❌ "Fix my code"
✅ "This Python function is slow with large lists. Can you optimize it for better performance?"

#### Provide Context
❌ "How do I do this?"
✅ "I'm building a web scraper in Python. How do I handle rate limiting with requests?"

#### Ask Follow-up Questions
- "Can you explain why this approach is better?"
- "What are the trade-offs of this solution?"
- "Can you show me an alternative approach?"

### Code Analysis Tips

1. **Analyze before major changes** - Get AI review of your approach
2. **Use for learning** - Ask "why" questions about suggestions
3. **Compare alternatives** - Ask for multiple solutions
4. **Focus on specific areas** - Highlight problematic sections

### Conversation Management

1. **Use descriptive first messages** - Helps with auto-generated titles
2. **Start new conversations** for different topics
3. **Review conversation history** to track your learning
4. **Export important conversations** for future reference

### Performance Optimization

1. **Enable caching** for faster responses
2. **Use appropriate models** - simpler models for basic questions
3. **Manage conversation length** - trim old messages if needed
4. **Monitor token usage** - optimize prompts for efficiency

## Troubleshooting

### Common Issues

#### Chat Interface Won't Open
**Symptoms:** Menu item doesn't respond or shows error
**Solutions:**
1. Check GeanyLua plugin is enabled (Tools → Plugin Manager)
2. Verify configuration file exists and is valid JSON
3. Check logs: `~/.config/geany/plugins/geanylua/codingbuddy/logs/`

#### No AI Response
**Symptoms:** Message sent but no response received
**Solutions:**
1. Verify API key is correct in config.json
2. Check internet connection
3. Try different provider if fallback is configured
4. Enable debug mode to see detailed error messages

#### "JSON decode error"
**Symptoms:** Error when loading conversations or config
**Solutions:**
1. Check JSON syntax in config.json
2. Delete corrupted conversation files
3. Install dkjson for better JSON handling: `luarocks install dkjson`

#### Slow Performance
**Symptoms:** Long delays between message and response
**Solutions:**
1. Enable caching in configuration
2. Use faster models (e.g., GPT-3.5 instead of GPT-4)
3. Reduce conversation context window
4. Check network connection speed

### Debug Mode

Enable detailed logging:

1. **Edit config.json:**
   ```json
   {
     "debug_mode": true
   }
   ```

2. **Or set environment variable:**
   ```bash
   export CODINGBUDDY_DEBUG=1
   ```

3. **Check logs:**
   ```
   ~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log
   ```

### Log Files

| File | Purpose |
|------|---------|
| `codingbuddy.log` | General plugin activity |
| `api_requests.log` | AI provider API calls |
| `conversations.log` | Conversation management |
| `errors.log` | Error messages and stack traces |

### Getting Help

1. **Check this guide** for common solutions
2. **Review logs** for specific error messages
3. **Search GitHub issues** for similar problems
4. **Create new issue** with:
   - Operating system and version
   - Geany and GeanyLua versions
   - Configuration file (remove API keys)
   - Relevant log entries
   - Steps to reproduce the issue

### Reset to Defaults

If all else fails, reset CodingBuddy:

```bash
# Backup current setup
mv ~/.config/geany/plugins/geanylua/codingbuddy/config.json ~/codingbuddy-config-backup.json

# Copy fresh configuration
cp ~/.config/geany/plugins/geanylua/codingbuddy/config.sample.json \
   ~/.config/geany/plugins/geanylua/codingbuddy/config.json

# Edit with your API keys
nano ~/.config/geany/plugins/geanylua/codingbuddy/config.json
```

---

**Happy coding with AI assistance!** 🚀

For more advanced features and API reference, see [DEVELOPER.md](DEVELOPER.md).
