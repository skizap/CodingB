#!/bin/bash

# CodingBuddy Automated Installation Script - Phase 15 Enhanced
# Intelligently detects Linux distribution and installs dependencies
# Now includes enhanced package verification and system tool checking

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    else
        DISTRO="unknown"
    fi
    
    log_info "Detected distribution: $DISTRO"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. This script should be run as a regular user."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Install dependencies based on distribution
install_dependencies() {
    log_info "Installing dependencies for $DISTRO..."
    
    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            log_info "Using apt package manager..."
            sudo apt-get update
            # Install required packages for CodingBuddy Phase 0
            sudo apt-get install -y geany geany-plugins lua5.1 lua-socket lua-sec \
                dkjson ripgrep patch coreutils openssl
            
            # Install luarocks if not present for optional packages
            if ! command -v luarocks >/dev/null 2>&1; then
                sudo apt-get install -y luarocks
            fi
            
            if command -v luarocks >/dev/null 2>&1; then
                log_info "Installing recommended Lua packages..."
                sudo luarocks install dkjson || log_warning "Failed to install dkjson via luarocks (may already be installed via apt)"
                sudo luarocks install luaossl || log_warning "Failed to install luaossl (optional but recommended)"
            fi
            ;;
        fedora|centos|rhel|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                log_info "Using dnf package manager..."
                sudo dnf install -y geany geany-plugins lua lua-socket \
                    ripgrep patch coreutils openssl
                # Try to install luaossl via luarocks if available
                if command -v luarocks >/dev/null 2>&1; then
                    log_info "Installing recommended Lua packages..."
                    sudo luarocks install luaossl || log_warning "Failed to install luaossl (optional but recommended)"
                fi
            elif command -v yum >/dev/null 2>&1; then
                log_info "Using yum package manager..."
                sudo yum install -y geany geany-plugins lua lua-socket \
                    patch coreutils openssl
                # ripgrep may not be available on older RHEL/CentOS, try EPEL
                sudo yum install -y ripgrep || log_warning "ripgrep not available - install from EPEL if needed"
                if command -v luarocks >/dev/null 2>&1; then
                    log_info "Installing recommended Lua packages..."
                    sudo luarocks install luaossl || log_warning "Failed to install luaossl (optional but recommended)"
                fi
            else
                log_error "No suitable package manager found (dnf/yum)"
                exit 1
            fi
            ;;
        opensuse*|sles)
            log_info "Using zypper package manager..."
            sudo zypper install -y geany geany-plugins lua51 lua51-luasocket \
                ripgrep patch coreutils openssl
            # Try to install luaossl via luarocks if available
            if command -v luarocks >/dev/null 2>&1; then
                log_info "Installing recommended Lua packages..."
                sudo luarocks install luaossl || log_warning "Failed to install luaossl (optional but recommended)"
            fi
            ;;
        arch|manjaro)
            log_info "Using pacman package manager..."
            sudo pacman -S --noconfirm geany geany-plugins lua lua-socket \
                ripgrep patch coreutils openssl
            if command -v luarocks >/dev/null 2>&1; then
                log_info "Installing recommended Lua packages..."
                sudo luarocks install dkjson || log_warning "Failed to install dkjson (optional)"
                sudo luarocks install luaossl || log_warning "Failed to install luaossl (optional but recommended)"
            fi
            ;;
        *)
            log_warning "Unsupported distribution: $DISTRO"
            log_info "Please install manually:"
            log_info "  Required: geany, geany-plugins, lua, lua-socket, ripgrep, patch, coreutils, openssl"
            log_info "  Optional: luarocks (for luaossl package)"
            read -p "Continue with plugin installation? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
}

# Verify Geany and GeanyLua are available
verify_geany() {
    log_info "Verifying Geany installation..."
    
    if ! command -v geany >/dev/null 2>&1; then
        log_error "Geany is not installed or not in PATH"
        exit 1
    fi
    
    log_success "Geany found: $(geany --version | head -n1)"
    
    # Check for GeanyLua plugin
    GEANY_PLUGINS_DIR="/usr/lib/geany"
    if [ -d "/usr/lib/x86_64-linux-gnu/geany" ]; then
        GEANY_PLUGINS_DIR="/usr/lib/x86_64-linux-gnu/geany"
    elif [ -d "/usr/lib64/geany" ]; then
        GEANY_PLUGINS_DIR="/usr/lib64/geany"
    fi
    
    if [ -f "$GEANY_PLUGINS_DIR/geanylua.so" ] || [ -f "/usr/lib/geany/geanylua.so" ]; then
        log_success "GeanyLua plugin found"
    else
        log_warning "GeanyLua plugin not found in expected locations"
        log_info "Please ensure geany-plugins package is installed"
    fi
}

# Install CodingBuddy plugin
install_plugin() {
    log_info "Installing CodingBuddy plugin..."
    
    # Determine script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PLUGIN_SOURCE="$SCRIPT_DIR/codingbuddy"
    
    if [ ! -d "$PLUGIN_SOURCE" ]; then
        log_error "CodingBuddy source directory not found: $PLUGIN_SOURCE"
        log_info "Please run this script from the CodingBuddy project root directory"
        exit 1
    fi
    
    # Create target directory
    TARGET_DIR="$HOME/.config/geany/plugins/geanylua"
    mkdir -p "$TARGET_DIR"
    
    # Copy plugin files
    log_info "Copying plugin files to $TARGET_DIR/codingbuddy/"
    cp -r "$PLUGIN_SOURCE" "$TARGET_DIR/"
    
    # Set executable permissions
    chmod +x "$TARGET_DIR/codingbuddy"/*.lua
    
    log_success "Plugin files installed successfully"
}

# Setup configuration
setup_config() {
    log_info "Setting up configuration..."
    
    CONFIG_DIR="$HOME/.config/geany/plugins/geanylua/codingbuddy"
    CONFIG_FILE="$CONFIG_DIR/config.json"
    SAMPLE_CONFIG="$CONFIG_DIR/config.sample.json"
    
    if [ ! -f "$CONFIG_FILE" ] && [ -f "$SAMPLE_CONFIG" ]; then
        log_info "Creating configuration file from sample..."
        cp "$SAMPLE_CONFIG" "$CONFIG_FILE"
        log_warning "Please edit $CONFIG_FILE with your API keys"
        log_info "You can get API keys from:"
        log_info "  - OpenRouter: https://openrouter.ai/"
        log_info "  - Anthropic: https://console.anthropic.com/"
        log_info "  - OpenAI: https://platform.openai.com/"
    else
        log_info "Configuration file already exists: $CONFIG_FILE"
    fi
}

# Verify presence of required system tools
verify_system_tools() {
    log_info "Verifying presence of required system tools..."
    
    local missing_tools=()
    local required_tools=("realpath" "diff" "patch" "openssl")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
            log_warning "Missing required tool: $tool"
        else
            log_success "Found required tool: $tool"
        fi
    done
    
    # Check for optional but recommended tools
    local optional_tools=("rg" "ripgrep")
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "Found optional tool: $tool"
            break
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "The following required tools are missing: ${missing_tools[*]}"
        log_info "Please install them using your package manager before continuing."
        case $DISTRO in
            ubuntu|debian|linuxmint|pop)
                log_info "Try: sudo apt-get install ${missing_tools[*]}"
                ;;
            fedora|centos|rhel|rocky|almalinux)
                log_info "Try: sudo dnf install ${missing_tools[*]} (or yum on older systems)"
                ;;
            opensuse*|sles)
                log_info "Try: sudo zypper install ${missing_tools[*]}"
                ;;
            arch|manjaro)
                log_info "Try: sudo pacman -S ${missing_tools[*]}"
                ;;
        esac
        return 1
    fi
    
    log_success "All required system tools are available"
    return 0
}

# Run tests
run_tests() {
    log_info "Running basic tests..."
    
    TEST_DIR="$HOME/.config/geany/plugins/geanylua/codingbuddy"
    
    # Test Lua syntax
    if command -v lua >/dev/null 2>&1; then
        for lua_file in "$TEST_DIR"/*.lua; do
            if [ -f "$lua_file" ]; then
                if lua -e "dofile('$lua_file')" 2>/dev/null; then
                    log_success "Syntax OK: $(basename "$lua_file")"
                else
                    log_warning "Syntax issue in: $(basename "$lua_file")"
                fi
            fi
        done
    fi
    
    # Test lua-socket availability
    if lua -e "require('socket.http')" 2>/dev/null; then
        log_success "lua-socket is available"
    else
        log_warning "lua-socket not found - HTTP requests may not work"
    fi
    
    # Verify system tools
    verify_system_tools
}

# Main installation function
main() {
    echo "========================================"
    echo "  CodingBuddy Installation Script"
    echo "========================================"
    echo
    
    check_root
    detect_distro
    
    # Ask user what to install
    echo "What would you like to install?"
    echo "1) Dependencies only"
    echo "2) Plugin only (dependencies already installed)"
    echo "3) Full installation (dependencies + plugin)"
    echo "4) Exit"
    echo
    read -p "Choose option (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            install_dependencies
            verify_geany
            ;;
        2)
            verify_geany
            install_plugin
            setup_config
            run_tests
            ;;
        3)
            install_dependencies
            verify_geany
            install_plugin
            setup_config
            run_tests
            ;;
        4)
            log_info "Installation cancelled"
            exit 0
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
    
    echo
    echo "========================================"
    log_success "Installation completed!"
    echo "========================================"
    echo
    log_info "Next steps:"
    log_info "1. Restart Geany"
    log_info "2. Check Tools menu for CodingBuddy options"
    log_info "3. Configure API keys in: $HOME/.config/geany/plugins/geanylua/codingbuddy/config.json"
    log_info "4. Test with: Tools → CodingBuddy: Open Chat"
    echo
    log_info "For help, see: README.md, INSTALL.md, USER_GUIDE.md"
}

# Run main function
main "$@"
