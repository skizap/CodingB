# Phase 19: MultiappV1 Tauri Sidecar Implementation

## Overview

Phase 19 introduces an **optional** Tauri-based sidecar application that provides a rich, dark-mode user interface for GeanyLua CodingBuddy. The sidecar offers operation approvals, real-time notifications, and an embedded terminal while maintaining the core GeanyLua plugin as the primary system.

## Key Features Delivered

### ✅ Optional Integration
- **Non-breaking installation**: Can be added without affecting existing GeanyLua plugin
- **Graceful degradation**: Plugin works normally when sidecar is unavailable
- **Configuration-controlled**: Easily enabled/disabled via config settings

### ✅ Dark Mode UI
- **Tailwind CSS-powered** modern dark theme optimized for coding
- **Professional styling** with glass morphism effects and smooth animations
- **Responsive design** that adapts to different window sizes
- **Accessibility-focused** with proper contrast and keyboard navigation

### ✅ Operation Approval System
- **Visual approval workflow** for file operations from GeanyLua
- **Detailed operation inspection** with JSON payload preview
- **Approve/Reject functionality** with status tracking
- **Operation history** showing completed, failed, and rejected operations
- **Auto-approval settings** for safe read-only operations

### ✅ Real-time Notifications
- **Event-driven notifications** for system events and updates
- **Categorized messages** (info, warning, error) with appropriate styling
- **Dismissible notifications** with centralized management
- **Real-time updates** from the backend via Tauri events

### ✅ Terminal Integration
- **xterm.js-powered** terminal emulator with dark theme
- **Terminal session management** with create/kill functionality
- **Mock implementation** ready for real PTY integration
- **Resizable interface** that adapts to window changes

### ✅ Encryption & Security
- **AES-GCM encryption** with Argon2 key derivation for state persistence
- **Environment-based passphrase** management (MULTIAPP_PASSPHRASE)
- **Per-file encryption** with unique salts and secure random nonces
- **Optional encryption** - works without passphrase for development

### ✅ Communication Bridge
- **HTTP API server** on localhost:8765 for GeanyLua communication
- **RESTful endpoints** for events, operations, and notifications
- **Health checking** and connection status monitoring
- **Graceful fallback** when sidecar is unavailable

## Architecture

```
┌─────────────────────┐                      ┌──────────────────────┐
│   GeanyLua Plugin   │                      │   Tauri Sidecar     │
│                     │                      │                      │
│  ┌─────────────────┐│    HTTP/8765         │  ┌─────────────────┐ │
│  │ sidecar_conn.lua││ ◄──────────────────► │  │   React UI      │ │
│  └─────────────────┘│                      │  │   (Dark Mode)   │ │
│  ┌─────────────────┐│                      │  └─────────────────┘ │
│  │ CodingBuddy     ││                      │  ┌─────────────────┐ │
│  │ (Main Plugin)   ││                      │  │  Rust Backend   │ │
│  └─────────────────┘│                      │  │  (Encrypted)    │ │
│                     │                      │  └─────────────────┘ │
└─────────────────────┘                      └──────────────────────┘
```

## Installation

### Prerequisites
- **Rust** (1.70+) and Cargo - [Install from rustup.rs](https://rustup.rs/)
- **Node.js** (16+) and npm - [Install from nodejs.org](https://nodejs.org/)
- **GeanyLua CodingBuddy** - The main plugin must already be installed

### Quick Install
```bash
# Navigate to CodingBuddy directory
cd /path/to/CodingBuddy

# Install the sidecar
cd multiapp-sidecar
chmod +x install.sh
./install.sh
```

### Manual Installation
```bash
cd multiapp-sidecar

# Install Node.js dependencies
npm install

# Install Tauri CLI (if needed)
cargo install tauri-cli --version "^2.0.0"

# Build the application
npm run tauri:build
```

## Configuration

### 1. Enable Sidecar in GeanyLua
Edit your `~/.config/geany/plugins/geanylua/codingbuddy/config.json`:

```json
{
  "sidecar_enabled": true,
  "sidecar_url": "http://localhost:8765",
  "sidecar_auto_approve_read_ops": true
}
```

### 2. Optional: Enable Encryption
```bash
# Set passphrase for encrypted state (optional)
export MULTIAPP_PASSPHRASE="your-secure-passphrase-here"

# Make it permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export MULTIAPP_PASSPHRASE="your-secure-passphrase-here"' >> ~/.bashrc
```

### 3. Start the Sidecar
```bash
cd multiapp-sidecar

# Development mode with hot reload
npm run tauri:dev

# Or production mode
npm run tauri:build
```

### 4. Restart Geany
The plugin will automatically detect and connect to the sidecar.

## Usage

### Starting the Sidecar
```bash
# Navigate to sidecar directory
cd multiapp-sidecar

# Development mode (with hot reload)
npm run tauri:dev

# Production build and run
npm run tauri:build
```

The sidecar provides:
- **Operations Panel**: Review and approve/reject file operations
- **Notifications Panel**: View system events and messages
- **Terminal Panel**: Embedded terminal emulator (mock implementation)
- **Settings Panel**: Configure sidecar preferences

### GeanyLua Integration
When the sidecar is running and enabled:

1. **Operation Requests**: File operations are sent to sidecar for approval
2. **Chat Messages**: Chat activity is displayed in notifications
3. **Status Updates**: Connection status shown in UI
4. **Graceful Fallback**: Works normally if sidecar is unavailable

## File Structure

```
multiapp-sidecar/
├── src/                          # React frontend
│   ├── components/
│   │   ├── Sidebar.jsx          # Navigation sidebar
│   │   ├── OperationsPanel.jsx  # Operation approval interface
│   │   ├── NotificationsPanel.jsx # Notification management
│   │   ├── TerminalPanel.jsx    # Terminal emulator
│   │   └── SettingsPanel.jsx    # Configuration interface
│   ├── App.jsx                  # Main application
│   ├── main.jsx                 # React entry point
│   └── index.css                # Tailwind CSS styles
├── src-tauri/                    # Rust backend
│   ├── src/
│   │   ├── main.rs              # Tauri main entry
│   │   ├── crypto.rs            # AES-GCM encryption
│   │   ├── server.rs            # HTTP API server
│   │   ├── state.rs             # State management
│   │   ├── events.rs            # Event handling
│   │   └── terminal.rs          # Terminal integration
│   └── Cargo.toml               # Rust dependencies
├── package.json                  # Node.js dependencies
├── tauri.conf.json              # Tauri configuration
├── tailwind.config.js           # Tailwind CSS config
├── install.sh                   # Installation script
└── README.md                    # Detailed documentation

codingbuddy/
└── sidecar_connector.lua        # GeanyLua connector module
```

## API Endpoints

The sidecar exposes these HTTP endpoints for GeanyLua:

### Health Check
```
GET /health
```
Returns service status and connection info.

### Event Submission
```
POST /events
Content-Type: application/json

{
  "type": "operation_request",
  "operation": "write_file",
  "payload": { "path": "/tmp/test.txt", "content": "Hello" },
  "timestamp": "2024-01-01T12:00:00Z",
  "source": "geanylua"
}
```

### Operations Management
```
GET /operations                   # List pending operations
POST /operations/approve          # Approve operation
POST /operations/reject           # Reject operation
```

### Notifications
```
GET /notifications                # Get current notifications
POST /notifications/clear         # Clear dismissed notifications
```

## Security Features

### Encryption
- **AES-256-GCM** encryption for all persistent state
- **Argon2** key derivation from passphrase
- **Unique salts** and nonces for each encryption operation
- **Key caching** for performance with automatic cleanup

### Network Security
- **Localhost only** - no external network access
- **CORS protection** and request validation
- **Timeout controls** to prevent hanging connections

### Operation Security
- **Explicit approval** required for all file operations
- **Payload inspection** before execution
- **Sandboxing** within configured workspace directory
- **Command filtering** via allow/deny lists

## Troubleshooting

### Common Issues

**Sidecar Won't Start**
```bash
# Check if port 8765 is in use
netstat -tlnp | grep 8765

# Check for missing dependencies
cargo check --manifest-path=multiapp-sidecar/src-tauri/Cargo.toml
npm install --cwd multiapp-sidecar
```

**GeanyLua Can't Connect**
```bash
# Test sidecar connectivity
curl http://localhost:8765/health

# Check configuration
grep sidecar ~/.config/geany/plugins/geanylua/codingbuddy/config.json

# Check GeanyLua logs
tail -f ~/.config/geany/plugins/geanylua/codingbuddy/logs/codingbuddy.log
```

**Encryption Issues**
```bash
# Verify passphrase is set
echo $MULTIAPP_PASSPHRASE

# Check state file permissions
ls -la ~/.local/share/com.multiappv1.sidecar/
```

### Debug Mode
```bash
# Enable debug logging
RUST_LOG=debug npm run tauri:dev

# Check backend logs in terminal
# Frontend logs in browser developer tools (F12)
```

## Development

### Frontend Development
```bash
# Start development server
npm run dev

# Build frontend only
npm run build

# Format and lint
npm run format
npm run lint
```

### Backend Development
```bash
# Run Rust tests
cargo test --manifest-path=src-tauri/Cargo.toml

# Check Rust code
cargo check --manifest-path=src-tauri/Cargo.toml

# Run clippy (linter)
cargo clippy --manifest-path=src-tauri/Cargo.toml
```

## Future Enhancements

### Planned Features
1. **Real Terminal Implementation**: Full PTY support with process management
2. **Unix Socket Communication**: Alternative to HTTP for better performance
3. **Enhanced Approval Workflows**: Batch operations and complex approval chains
4. **Theme Customization**: User-configurable themes and color schemes
5. **Plugin System**: Extensible architecture for additional functionality

### Contributing Areas
- **Terminal Emulation**: Implement real PTY with portable-pty
- **UI/UX Improvements**: Additional themes, animations, accessibility
- **Performance Optimization**: Caching, lazy loading, memory management
- **Testing**: Unit tests, integration tests, end-to-end tests
- **Documentation**: API docs, tutorials, examples

## Summary

Phase 19 successfully delivers an optional, feature-rich Tauri sidecar that enhances the GeanyLua CodingBuddy experience without breaking existing functionality. The implementation includes:

✅ **Professional dark-mode UI** with modern styling and smooth UX  
✅ **Operation approval system** with visual workflow and detailed inspection  
✅ **Real-time notifications** with categorized, dismissible messages  
✅ **Terminal integration** framework ready for full implementation  
✅ **AES-GCM encryption** with secure state persistence  
✅ **HTTP communication bridge** with health checking and graceful fallback  
✅ **Comprehensive documentation** and installation guides  
✅ **Non-breaking optional installation** that enhances without disrupting  

The sidecar provides a foundation for rich UI features while maintaining the lightweight, efficient GeanyLua plugin as the core system. Users can choose to install it for enhanced functionality or continue using the standard plugin interface.
