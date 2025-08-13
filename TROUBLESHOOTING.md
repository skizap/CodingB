# CodingBuddy Troubleshooting Guide

Complete guide to diagnosing and fixing CodingBuddy plugin issues.

## 🚨 Quick Diagnostics

### Step 1: Run the Diagnostic Script

```bash
cd /path/to/CodingBuddy
./diagnose.sh
```

This will check:
- Geany and GeanyLua installation
- Lua dependencies (lua-socket, luasec, dkjson)
- System tool dependencies (openssl, patch, diff, ripgrep)
- CodingBuddy plugin files and permissions
- Configuration file validity
- Log directories and recent errors

### Step 2: Enable Debug Logging

```bash
export CODINGBUDDY_DEBUG=1
```

Then restart Geany and try using CodingBuddy. Check logs at:
```
~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log
```

## 🔍 Common Issues and Solutions

### 1. "CodingBuddy menu items don't appear"

**Symptoms:** No CodingBuddy options in Tools menu

**Causes & Solutions:**
- **GeanyLua not enabled:** Tools → Plugin Manager → Check "GeanyLua"
- **Plugin files missing:** Run `./install.sh` or copy files manually
- **Syntax errors in Lua files:** Check logs for syntax errors

**Diagnostic commands:**
```bash
# Check if GeanyLua plugin exists
find /usr -name "geanylua.so" 2>/dev/null

# Test Lua syntax
lua -e "dofile('~/.config/geany/plugins/geanylua/codingbuddy/main.lua')"
```

### 2. "Menu items appear but clicking does nothing"

**Symptoms:** Menu items visible but no response when clicked

**Causes & Solutions:**
- **Missing dependencies:** Install lua-socket: `sudo apt-get install lua-socket`
- **Module loading failures:** Check debug logs for require() errors
- **Configuration issues:** Verify config.json exists and is valid JSON

**Diagnostic commands:**
```bash
# Test lua-socket
lua -e "require('socket.http')"

# Test module loading
lua -e "package.path = package.path .. ';~/.config/geany/plugins/geanylua/codingbuddy/?.lua'; require('codingbuddy.utils')"
```

### 3. "Error dialogs appear when using CodingBuddy"

**Symptoms:** Error messages in Geany dialogs

**Common error messages and solutions:**

#### "Failed to load module: codingbuddy.xyz"
- **Cause:** Missing or corrupted plugin files
- **Solution:** Reinstall plugin with `./install.sh`

#### "lua-socket not found"
- **Cause:** Missing lua-socket dependency
- **Solution:** `sudo apt-get install lua-socket` (Ubuntu/Debian)

#### "No API key configured"
- **Cause:** Missing or invalid API keys
- **Solution:** Edit `~/.config/geany/plugins/geanylua/codingbuddy/config.json`

#### "JSON decode error"
- **Cause:** Corrupted configuration or conversation files
- **Solution:** Delete corrupted files and recreate from samples

### 4. "No response from AI"

**Symptoms:** Chat interface opens but AI doesn't respond

**Causes & Solutions:**
- **Invalid API keys:** Check API key in config.json
- **Network issues:** Test internet connection
- **Provider downtime:** Try different provider in config
- **Rate limiting:** Wait and try again

**Diagnostic commands:**
```bash
# Test API connectivity (replace with your key)
curl -H "Authorization: Bearer YOUR_API_KEY" https://openrouter.ai/api/v1/models

# Check network connectivity
ping openrouter.ai
```

### 5. "Permission denied" errors

**Symptoms:** Cannot create logs, save conversations, or read config

**Causes & Solutions:**
- **File permissions:** Fix with `chmod -R 755 ~/.config/geany/plugins/geanylua/codingbuddy/`
- **Directory permissions:** Ensure ~/.config/geany exists and is writable
- **SELinux/AppArmor:** Check security policies if on enterprise Linux

### 6. "System tool not found" errors

**Symptoms:** Errors about missing openssl, patch, diff, or ripgrep

**System Tool Dependencies:**
CodingBuddy uses these system tools for advanced features:

#### OpenSSL (Required for conversation encryption)
```bash
# Test if available
openssl version

# Install if missing
sudo apt install openssl         # Ubuntu/Debian
sudo yum install openssl         # CentOS/RHEL
brew install openssl             # macOS
```

#### patch and diff (Required for code patching)
```bash
# Test if available
which patch && which diff

# Install if missing (usually pre-installed on most systems)
sudo apt install patch diffutils # Ubuntu/Debian
sudo yum install patch diffutils # CentOS/RHEL
# macOS: Usually pre-installed with Xcode Command Line Tools
```

#### ripgrep (Optional, improves code search performance)
```bash
# Test if available
rg --version

# Install if missing
sudo apt install ripgrep         # Ubuntu/Debian 19.04+
brew install ripgrep             # macOS
# Or download from: https://github.com/BurntSushi/ripgrep/releases
```

**Feature Impact:**
- **Missing OpenSSL:** Conversation encryption will be unavailable
- **Missing patch/diff:** AI code modifications will use fallback methods
- **Missing ripgrep:** Code search will use slower grep fallback

## 📊 Debug Logging

### Enable Debug Mode

**Method 1: Environment Variable**
```bash
export CODINGBUDDY_DEBUG=1
geany  # Start Geany from terminal
```

**Method 2: Configuration File**
```json
{
  "debug_mode": true,
  "providers": { ... }
}
```

### Log File Locations

| Log File | Purpose |
|----------|---------|
| `codingbuddy.log` | Main plugin activity and errors |
| `api_requests.log` | AI provider API calls (if enabled) |
| `conversations.log` | Conversation management events |

### Reading Debug Logs

```bash
# View recent logs
tail -f ~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log

# Search for errors
grep ERROR ~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log

# View logs with timestamps
cat ~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log | grep "$(date '+%Y-%m-%d')"
```

## 🔧 Manual Fixes

### Reset Configuration

```bash
cd ~/.config/geany/plugins/geanylua/codingbuddy/
cp config.sample.json config.json
# Edit config.json with your API keys
```

### Clear Conversation History

```bash
rm -rf ~/.config/geany/plugins/geanylua/codingbuddy/conversations/
# Conversations will be recreated automatically
```

### Reinstall Plugin

```bash
cd /path/to/CodingBuddy
rm -rf ~/.config/geany/plugins/geanylua/codingbuddy/
./install.sh
```

### Fix File Permissions

```bash
chmod -R 755 ~/.config/geany/plugins/geanylua/codingbuddy/
chmod +x ~/.config/geany/plugins/geanylua/codingbuddy/*.lua
```

## 🐛 Advanced Debugging

### Test Individual Components

```bash
cd ~/.config/geany/plugins/geanylua/codingbuddy/

# Test utilities
lua -e "package.path = package.path .. ';./?.lua'; local u = require('utils'); u.log('TEST', 'Logging works')"

# Test configuration
lua -e "package.path = package.path .. ';./?.lua'; local c = require('config'); print(c.get().default_provider)"

# Test AI connector
lua -e "package.path = package.path .. ';./?.lua'; local ai = require('ai_connector'); print('AI connector loaded')"
```

### Check Lua Environment

```bash
# Check Lua version
lua -v

# Check available packages
lua -e "for k,v in pairs(package.loaded) do print(k) end"

# Check Lua path
lua -e "print(package.path)"
```

### Geany-Specific Debugging

1. **Start Geany from terminal** to see console output
2. **Check Geany's plugin directory** for GeanyLua
3. **Verify GeanyLua version compatibility**

```bash
# Start Geany with verbose output
geany --verbose

# Check plugin loading
geany --list-plugins
```

## 📋 Information to Collect for Bug Reports

When reporting issues, please include:

### System Information
```bash
# Operating system
lsb_release -a

# Geany version
geany --version

# Lua version
lua -v

# Installed packages
dpkg -l | grep -E "(geany|lua)"  # Ubuntu/Debian
rpm -qa | grep -E "(geany|lua)"  # CentOS/RHEL/Fedora
```

### CodingBuddy Information
```bash
# Plugin files
ls -la ~/.config/geany/plugins/geanylua/codingbuddy/

# Configuration (remove API keys before sharing)
cat ~/.config/geany/plugins/geanylua/codingbuddy/config.json

# Recent logs
tail -50 ~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log
```

### Error Details
- Exact error messages
- Steps to reproduce
- When the error occurs (startup, menu click, during chat, etc.)
- Any recent changes to system or configuration

## 🆘 Getting Help

### Self-Help Resources
1. **Run diagnostic script:** `./diagnose.sh`
2. **Check this troubleshooting guide**
3. **Review USER_GUIDE.md** for usage instructions
4. **Check GitHub issues** for similar problems

### Community Support
1. **GitHub Issues:** [Create new issue](https://github.com/yourusername/CodingBuddy/issues)
2. **Include diagnostic information** from above
3. **Search existing issues** first
4. **Provide minimal reproduction steps**

### Professional Support
For enterprise users or complex deployments, consider:
- Custom installation support
- Configuration management
- Integration with existing development workflows
- Training and documentation

---

**Most issues can be resolved by running the diagnostic script and following the solutions above.** 🔧
