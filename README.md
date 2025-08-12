# CodingBuddy

**An AI-powered interactive coding assistant for Geany IDE**

CodingBuddy transforms Geany into an intelligent development environment with AI-powered code analysis, interactive chat interface, and multi-provider AI support. Think of it as having Cline/Augment directly integrated into your favorite lightweight IDE.

## ✨ Features

### 🤖 Interactive AI Chat Interface
- **Persistent conversations** with full history tracking
- **Context-aware interactions** that remember your coding session
- **Command-based interface** (`/new`, `/history`, `/quit`)
- **Multi-turn conversations** for complex problem solving
- **Cost and token tracking** for usage monitoring

### 🔧 Code Analysis & Generation
- **Real-time code analysis** with AI-powered suggestions
- **Multi-language support** for error detection and improvements
- **Code generation** with context awareness
- **Documentation generation** for functions and classes
- **Refactoring suggestions** with AI recommendations

### 🌐 Multi-Provider AI Support
- **Primary**: OpenRouter.ai (400+ models, single API key)
- **Secondary**: Anthropic Claude, OpenAI GPT, DeepSeek
- **Automatic fallback** when providers are unavailable
- **Cost optimization** through intelligent model selection
- **Local model support** via Ollama integration

### 💾 Smart Persistence
- **Conversation history** automatically saved and restored
- **Cross-session continuity** - conversations survive Geany restarts
- **JSON-based storage** for human-readable conversation files
- **Caching system** for improved performance and reduced API costs

## 🚀 Quick Start

### Prerequisites
- Geany IDE with GeanyLua plugin
- Lua 5.1+ with lua-socket library
- API key for at least one AI provider

### Installation

#### Automated Installation (Recommended)
```bash
git clone https://github.com/yourusername/CodingBuddy.git
cd CodingBuddy
./install.sh
```

The automated installer will:
- Detect your Linux distribution
- Install all dependencies automatically
- Set up the plugin and configuration
- Run tests to verify installation

#### Manual Installation
1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/CodingBuddy.git
   cd CodingBuddy
   ```

2. **Install to Geany:**
   ```bash
   cp -r codingbuddy ~/.config/geany/plugins/geanylua/
   ```

3. **Configure API keys:**
   ```bash
   cp codingbuddy/config.sample.json ~/.config/geany/plugins/geanylua/codingbuddy/config.json
   # Edit config.json with your API keys
   ```

4. **Restart Geany** and look for CodingBuddy in the Tools menu

> **For detailed installation instructions, see [INSTALL.md](INSTALL.md)**

### First Steps

1. **Open the chat interface:** Tools → CodingBuddy: Open Chat
2. **Start chatting:** Type your coding questions or requests
3. **Analyze code:** Tools → CodingBuddy: Analyze with Chat
4. **Explore commands:** Type `/help` in the chat interface

## 💬 Usage Examples

### Interactive Chat Session
```
=== New Conversation ===
Messages: 0 | Tokens: 0 | Cost: $0.0000

Your message: Can you help me optimize this Python function?

[12:34] You: Can you help me optimize this Python function?
[12:34] Assistant: I'd be happy to help! Please share the function code.

Your message: def find_max(numbers):
    max_val = numbers[0]
    for num in numbers:
        if num > max_val:
            max_val = num
    return max_val

[12:35] Assistant: Here are several optimizations:

1. **Use built-in max()** (most Pythonic):
   ```python
   def find_max(numbers):
       return max(numbers)
   ```

2. **Handle edge cases**:
   ```python
   def find_max(numbers):
       if not numbers:
           raise ValueError("Cannot find max of empty list")
       return max(numbers)
   ```
```

### Code Analysis
- Open any code file in Geany
- Select Tools → CodingBuddy: Analyze with Chat
- Get AI-powered analysis with suggestions for improvements

### Chat Commands
- `/new` - Start a new conversation
- `/history` - Browse previous conversations
- `/quit` - Close chat interface
- `/help` - Show available commands

## 📁 Project Structure

```
CodingBuddy/
├── README.md                    # This file
├── INSTALL.md                   # Detailed installation guide
├── USER_GUIDE.md               # Comprehensive user manual
├── DEVELOPER.md                # API reference and development guide
├── codingbuddy/                # Main plugin directory
│   ├── main.lua                # Plugin entry point
│   ├── ai_connector.lua        # Multi-provider AI interface
│   ├── analyzer.lua            # Code analysis engine
│   ├── chat_interface.lua      # Interactive chat system
│   ├── conversation_manager.lua # Conversation state management
│   ├── config.lua              # Configuration management
│   ├── config.sample.json      # Sample configuration
│   ├── dialogs.lua             # UI components
│   ├── json.lua                # JSON utilities
│   ├── utils.lua               # Utility functions
│   └── prompts/                # AI prompt templates
├── docs/                       # Additional documentation
├── examples/                   # Usage examples
└── tests/                      # Test suite
```

## 🔧 Configuration

CodingBuddy supports multiple AI providers with automatic fallback:

```json
{
  "providers": {
    "openrouter": {
      "api_key": "your-openrouter-key",
      "base_url": "https://openrouter.ai/api/v1",
      "models": ["anthropic/claude-3.5-sonnet", "openai/gpt-4"]
    },
    "anthropic": {
      "api_key": "your-anthropic-key",
      "base_url": "https://api.anthropic.com/v1"
    }
  },
  "default_provider": "openrouter",
  "cache_enabled": true,
  "max_conversation_length": 50
}
```

## 📚 Documentation

- **[Installation Guide](INSTALL.md)** - Detailed setup instructions
- **[User Guide](USER_GUIDE.md)** - Complete usage manual with examples
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Fix common issues
- **[Developer Guide](DEVELOPER.md)** - API reference and development info
- **[Chat Interface](docs/chat_interface.md)** - Interactive chat system details
- **[AI Enhancements](docs/anthropic_enhancements.md)** - Advanced AI features

## 🧪 Testing

Run the test suite to verify installation:

```bash
cd tests
lua test_ai_connector.lua
lua test_chat_interface.lua
```

## 🤝 Contributing

We welcome contributions! Please see [DEVELOPER.md](DEVELOPER.md) for:
- Development setup
- API documentation
- Coding standards
- Contribution guidelines

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Geany IDE** - Lightweight and powerful text editor
- **GeanyLua** - Lua scripting support for Geany
- **OpenRouter.ai** - Multi-provider AI access platform
- **Anthropic, OpenAI, DeepSeek** - AI model providers

## 🔗 Links

- [Geany IDE](https://www.geany.org/)
- [GeanyLua Plugin](https://plugins.geany.org/geanylua.html)
- [OpenRouter.ai](https://openrouter.ai/)
- [Project Issues](https://github.com/yourusername/CodingBuddy/issues)

---

**Transform your coding experience with AI-powered assistance directly in Geany!**
