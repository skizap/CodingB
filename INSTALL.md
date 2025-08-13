# CodingBuddy Installation Guide

This guide provides detailed instructions for installing and configuring CodingBuddy on various platforms.

## Prerequisites

### Required Software

1. **Geany IDE** (version 1.36 or later)
   - Download from [geany.org](https://www.geany.org/download/releases/)
   - Most Linux distributions include Geany in their repositories

2. **GeanyLua Plugin**
   - Usually included with Geany installation
   - On some distributions, install separately: `geany-plugins`

3. **Lua Runtime** (version 5.1 or later)
   - Required for running the plugin
   - Usually pre-installed on most systems

### Recommended Libraries

1. **lua-socket** - For HTTP requests to AI providers
   ```bash
   # Ubuntu/Debian
   sudo apt-get install lua-socket
   
   # CentOS/RHEL/Fedora
   sudo yum install lua-socket  # or dnf install lua-socket
   
   # macOS with Homebrew
   brew install lua
   luarocks install luasocket
   
   # Windows (with LuaRocks)
   luarocks install luasocket
   ```

2. **luasec** - For HTTPS support (recommended)
   ```bash
   # Ubuntu/Debian
   sudo apt-get install lua-sec
   
   # Via LuaRocks
   luarocks install luasec
   ```

3. **dkjson** - For better JSON handling (optional)
   ```bash
   luarocks install dkjson
   ```

## Installation Methods

### Method 1: Automated Installation (Recommended)

The easiest way to install CodingBuddy is using the automated installation script that detects your Linux distribution and installs everything automatically.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/skizap/CodingBuddy.git
   cd CodingBuddy
   ```

2. **Run the automated installer:**
   ```bash
   ./install.sh
   ```

3. **Choose installation option:**
   - **Option 1:** Dependencies only
   - **Option 2:** Plugin only (if dependencies already installed)
   - **Option 3:** Full installation (recommended for first-time users)

The script will:
- Detect your Linux distribution (Ubuntu, Fedora, Arch, openSUSE, etc.)
- Install appropriate packages using your system's package manager
- Copy plugin files to the correct location
- Set up configuration files
- Run basic tests to verify installation

### Method 2: Manual Installation

If you prefer manual installation or the automated script doesn't work for your system:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/skizap/CodingBuddy.git
   cd CodingBuddy
   ```

2. **Install to Geany plugins directory:**
   ```bash
   # Create directory if it doesn't exist
   mkdir -p ~/.config/geany/plugins/geanylua/

   # Copy plugin files (run from CodingBuddy project root)
   cp -r codingbuddy ~/.config/geany/plugins/geanylua/
   ```

3. **Set permissions:**
   ```bash
   chmod +x ~/.config/geany/plugins/geanylua/codingbuddy/*.lua
   ```

### Method 3: Manual Download

1. **Download the latest release** from GitHub releases page
2. **Extract the archive:**
   ```bash
   unzip CodingBuddy-main.zip
   cd CodingBuddy-main
   ```
3. **Follow steps 2-3 from Method 2**

### Method 4: Development Installation

For developers who want to contribute:

1. **Fork the repository** on GitHub
2. **Clone your fork:**
   ```bash
   git clone https://github.com/skizap/CodingBuddy.git
   cd CodingBuddy
   ```
3. **Create a symlink** for easier development:
   ```bash
   mkdir -p ~/.config/geany/plugins/geanylua/
   ln -s $(pwd)/codingbuddy ~/.config/geany/plugins/geanylua/codingbuddy
   ```

## Platform-Specific Instructions

### Linux (Ubuntu/Debian)

1. **Install prerequisites:**
   ```bash
   sudo apt-get update
   sudo apt-get install geany geany-plugins lua5.1 lua-socket lua-sec
   ```

2. **Verify GeanyLua is available:**
   - Open Geany
   - Go to Tools → Plugin Manager
   - Ensure "GeanyLua" is checked

3. **Follow installation method above**

### Linux (CentOS/RHEL/Fedora)

1. **Install prerequisites:**
   ```bash
   # CentOS/RHEL
   sudo yum install geany geany-plugins lua lua-socket
   
   # Fedora
   sudo dnf install geany geany-plugins lua lua-socket
   ```

2. **Continue with standard installation**

### macOS

1. **Install Geany:**
   ```bash
   brew install geany
   ```

2. **Install Lua and dependencies:**
   ```bash
   brew install lua luarocks
   luarocks install luasocket luasec dkjson
   ```

3. **GeanyLua plugin** may need manual compilation:
   ```bash
   # Download geany-plugins source and compile
   # Or use pre-compiled binaries if available
   ```

### Windows

1. **Install Geany** from [geany.org](https://www.geany.org/download/releases/)
   - Download the installer with plugins included

2. **Install Lua:**
   - Download from [lua.org](https://www.lua.org/download.html)
   - Or use LuaForWindows distribution

3. **Install LuaRocks** and dependencies:
   ```cmd
   luarocks install luasocket
   luarocks install luasec
   luarocks install dkjson
   ```

4. **Plugin directory location:**
   ```
   %APPDATA%\geany\plugins\geanylua\
   ```

## Configuration

### 1. Create Configuration File

1. **Copy sample configuration:**
   ```bash
   cp ~/.config/geany/plugins/geanylua/codingbuddy/config.sample.json \
      ~/.config/geany/plugins/geanylua/codingbuddy/config.json
   ```

2. **Edit configuration file:**
   ```bash
   nano ~/.config/geany/plugins/geanylua/codingbuddy/config.json
   ```

### 2. API Key Configuration

#### OpenRouter.ai (Recommended)
1. Sign up at [openrouter.ai](https://openrouter.ai/)
2. Get your API key from the dashboard
3. Add to config.json:
   ```json
   {
     "providers": {
       "openrouter": {
         "api_key": "sk-or-v1-your-key-here",
         "base_url": "https://openrouter.ai/api/v1",
         "models": ["anthropic/claude-3.5-sonnet", "openai/gpt-4"]
       }
     },
     "default_provider": "openrouter"
   }
   ```

#### Anthropic Claude
1. Get API key from [console.anthropic.com](https://console.anthropic.com/)
2. Add to config:
   ```json
   {
     "providers": {
       "anthropic": {
         "api_key": "sk-ant-your-key-here",
         "base_url": "https://api.anthropic.com/v1"
       }
     }
   }
   ```

#### OpenAI
1. Get API key from [platform.openai.com](https://platform.openai.com/)
2. Add to config:
   ```json
   {
     "providers": {
       "openai": {
         "api_key": "sk-your-key-here",
         "base_url": "https://api.openai.com/v1"
       }
     }
   }
   ```

### 3. Environment Variables (Alternative)

Instead of config file, you can use environment variables:

```bash
# Add to ~/.bashrc or ~/.zshrc
export OPENROUTER_API_KEY="sk-or-v1-your-key-here"
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
export OPENAI_API_KEY="sk-your-key-here"
```

## Verification

### 1. Check Plugin Loading

1. **Restart Geany**
2. **Check Tools menu** - you should see:
   - CodingBuddy: Open Chat
   - CodingBuddy: Analyze with Chat
   - CodingBuddy: Analyze Buffer

### 2. Test Basic Functionality

1. **Open chat interface:**
   - Tools → CodingBuddy: Open Chat
   - Should show conversation interface

2. **Test AI connection:**
   - Type a simple message like "Hello"
   - Should receive AI response

### 3. Run Test Suite

```bash
cd ~/.config/geany/plugins/geanylua/codingbuddy/
lua -e "package.path = package.path .. ';./?.lua'; local t = require('tests.test_ai_connector'); t.run_tests()"
```

## Troubleshooting

### Common Issues

#### "GeanyLua plugin not found"
- Ensure geany-plugins package is installed
- Check Plugin Manager in Geany (Tools → Plugin Manager)
- Verify GeanyLua is checked/enabled

#### "No response from AI"
- Check API key configuration
- Verify internet connection
- Check logs: `~/.config/geany/plugins/geanylua/codingbuddy/logs/`

#### "lua-socket not found"
- Install lua-socket package for your system
- Verify with: `lua -e "require('socket.http')"`

#### "Permission denied"
- Check file permissions: `chmod +x ~/.config/geany/plugins/geanylua/codingbuddy/*.lua`
- Ensure directory is writable for logs and cache

#### "JSON decode error"
- Install dkjson: `luarocks install dkjson`
- Or use built-in JSON fallback (automatic)

### Debug Mode

Enable debug logging:

```bash
export CODINGBUDDY_DEBUG=1
```

Then check logs in:
```
~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log
```

### Getting Help

1. **Check documentation:** [docs/](docs/)
2. **Search issues:** [GitHub Issues](https://github.com/skizap/CodingBuddy/issues)
3. **Create new issue** with:
   - Operating system and version
   - Geany version
   - Error messages from logs
   - Steps to reproduce

## Uninstallation

To remove CodingBuddy:

```bash
rm -rf ~/.config/geany/plugins/geanylua/codingbuddy/
```

Configuration and conversation history will be removed as well.

## Next Steps

After successful installation:

1. **Read the [User Guide](USER_GUIDE.md)** for detailed usage instructions
2. **Explore the [examples/](examples/)** directory for usage examples
3. **Check [docs/](docs/)** for advanced features and API reference

---

**Need help?** Open an issue on GitHub or check the troubleshooting section above.
