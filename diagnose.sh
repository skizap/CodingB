#!/bin/bash

# CodingBuddy Diagnostic Script
# Helps troubleshoot GeanyLua plugin issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "========================================"
echo "  CodingBuddy Diagnostic Tool"
echo "========================================"
echo

# 1. Check Geany installation
log_info "Checking Geany installation..."
if command -v geany >/dev/null 2>&1; then
    GEANY_VERSION=$(geany --version | head -n1)
    log_success "Geany found: $GEANY_VERSION"
else
    log_error "Geany not found in PATH"
    exit 1
fi

# 2. Check GeanyLua plugin
log_info "Checking GeanyLua plugin..."
PLUGIN_PATHS=(
    "/usr/lib/geany/geanylua.so"
    "/usr/lib/x86_64-linux-gnu/geany/geanylua.so"
    "/usr/lib64/geany/geanylua.so"
    "/usr/local/lib/geany/geanylua.so"
)

GEANYLUA_FOUND=false
for path in "${PLUGIN_PATHS[@]}"; do
    if [ -f "$path" ]; then
        log_success "GeanyLua plugin found: $path"
        GEANYLUA_FOUND=true
        break
    fi
done

if [ "$GEANYLUA_FOUND" = false ]; then
    log_error "GeanyLua plugin not found"
    log_info "Install with: sudo apt-get install geany-plugins (Ubuntu/Debian)"
    log_info "Or: sudo dnf install geany-plugins (Fedora)"
fi

# 3. Check Lua installation
log_info "Checking Lua installation..."
if command -v lua >/dev/null 2>&1; then
    LUA_VERSION=$(lua -v 2>&1 | head -n1)
    log_success "Lua found: $LUA_VERSION"
else
    log_error "Lua not found in PATH"
fi

# 4. Check Lua dependencies
log_info "Checking Lua dependencies..."

# Check lua-socket
if lua -e "require('socket.http')" 2>/dev/null; then
    log_success "lua-socket available"
else
    log_error "lua-socket not found"
    log_info "Install with: sudo apt-get install lua-socket"
fi

# Check luasec (optional)
if lua -e "require('ssl.https')" 2>/dev/null; then
    log_success "luasec available (optional)"
else
    log_warning "luasec not found (optional but recommended)"
fi

# Check dkjson (optional)
if lua -e "require('dkjson')" 2>/dev/null; then
    log_success "dkjson available (optional)"
else
    log_warning "dkjson not found (using fallback JSON parser)"
fi

# 5. Check CodingBuddy installation
log_info "Checking CodingBuddy installation..."
CODINGBUDDY_DIR="$HOME/.config/geany/plugins/geanylua/codingbuddy"

if [ -d "$CODINGBUDDY_DIR" ]; then
    log_success "CodingBuddy directory found: $CODINGBUDDY_DIR"
    
    # Check main files
    REQUIRED_FILES=("main.lua" "ai_connector.lua" "chat_interface.lua" "conversation_manager.lua" "config.lua")
    for file in "${REQUIRED_FILES[@]}"; do
        if [ -f "$CODINGBUDDY_DIR/$file" ]; then
            log_success "Found: $file"
        else
            log_error "Missing: $file"
        fi
    done
    
    # Check file permissions
    if [ -r "$CODINGBUDDY_DIR/main.lua" ]; then
        log_success "Files are readable"
    else
        log_error "Permission issues with plugin files"
    fi
    
else
    log_error "CodingBuddy directory not found: $CODINGBUDDY_DIR"
    log_info "Run the installation script or copy files manually"
fi

# 6. Check configuration
log_info "Checking configuration..."
CONFIG_FILE="$CODINGBUDDY_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    log_success "Configuration file found"
    
    # Validate JSON syntax
    if command -v python3 >/dev/null 2>&1; then
        if python3 -m json.tool "$CONFIG_FILE" >/dev/null 2>&1; then
            log_success "Configuration JSON is valid"
        else
            log_error "Configuration JSON has syntax errors"
        fi
    fi
else
    log_warning "Configuration file not found: $CONFIG_FILE"
    log_info "Copy from config.sample.json and add your API keys"
fi

# 7. Test Lua syntax
log_info "Testing Lua file syntax..."
if [ -d "$CODINGBUDDY_DIR" ]; then
    for lua_file in "$CODINGBUDDY_DIR"/*.lua; do
        if [ -f "$lua_file" ]; then
            filename=$(basename "$lua_file")
            if lua -e "dofile('$lua_file')" 2>/dev/null; then
                log_success "Syntax OK: $filename"
            else
                log_error "Syntax error in: $filename"
                log_info "Run: lua -e \"dofile('$lua_file')\" for details"
            fi
        fi
    done
fi

# 8. Check log directories
log_info "Checking log directories..."
LOG_DIR="$CODINGBUDDY_DIR/logs"
if [ -d "$LOG_DIR" ]; then
    log_success "Log directory exists: $LOG_DIR"
    
    # List recent log files
    if [ "$(ls -A $LOG_DIR 2>/dev/null)" ]; then
        log_info "Recent log files:"
        ls -la "$LOG_DIR"
    else
        log_info "No log files found (normal for new installation)"
    fi
else
    log_warning "Log directory not found, will be created on first run"
fi

# 9. Environment variables
log_info "Checking environment variables..."
if [ -n "$OPENROUTER_API_KEY" ]; then
    log_success "OPENROUTER_API_KEY is set"
elif [ -n "$ANTHROPIC_API_KEY" ]; then
    log_success "ANTHROPIC_API_KEY is set"
elif [ -n "$OPENAI_API_KEY" ]; then
    log_success "OPENAI_API_KEY is set"
else
    log_warning "No API key environment variables found"
    log_info "Configure API keys in config.json or set environment variables"
fi

# 10. Test basic Lua module loading
log_info "Testing module loading..."
if [ -f "$CODINGBUDDY_DIR/utils.lua" ]; then
    if lua -e "package.path = package.path .. ';$CODINGBUDDY_DIR/?.lua'; require('utils')" 2>/dev/null; then
        log_success "Module loading works"
    else
        log_error "Module loading failed"
        log_info "Check Lua path and file permissions"
    fi
fi

echo
echo "========================================"
log_info "Diagnostic Summary"
echo "========================================"
echo
log_info "If you see errors above, address them before running CodingBuddy"
log_info "For detailed troubleshooting, see USER_GUIDE.md"
log_info "To enable debug logging, set: export CODINGBUDDY_DEBUG=1"
echo
log_info "Next steps:"
log_info "1. Fix any errors shown above"
log_info "2. Restart Geany"
log_info "3. Try Tools → CodingBuddy: Open Chat"
log_info "4. Check logs in: $LOG_DIR"
echo
