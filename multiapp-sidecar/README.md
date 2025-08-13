# MultiappV1 Tauri Sidecar

An optional dark-mode UI sidecar for GeanyLua CodingBuddy that provides rich user interface features including operation approvals, notifications, and an embedded terminal emulator.

## Features

### 🌓 Dark Mode UI
- **Modern dark theme** with carefully crafted colors optimized for coding environments
- **Glass morphism effects** and smooth animations
- **Responsive design** that adapts to different window sizes
- **Accessibility focused** with proper contrast and keyboard navigation

### ✅ Operation Approval System
- **Visual approval interface** for file operations from GeanyLua
- **Detailed operation inspection** with JSON payload preview
- **Batch approval/rejection** capabilities
- **Auto-approval settings** for safe read-only operations
- **Operation history** with status tracking

### 🔔 Real-time Notifications
- **System notifications** for events and status updates
- **Notification center** with categorized messages (info, warning, error)
- **Dismissible notifications** with automatic cleanup
- **Real-time updates** via WebSocket-like event system

### 💻 Embedded Terminal
- **Full terminal emulator** powered by xterm.js
- **Dark theme integration** matching the overall UI
- **Multiple session support** (framework ready)
- **Resizable and responsive** terminal pane
- **Shell customization** via settings

### 🔒 Security & Encryption
- **AES-GCM encryption** for persistent state with Argon2 key derivation
- **Per-file encryption** with unique salts
- **Environment-based passphrase** management
- **Optional encryption** - works without passphrase
- **Secure state persistence** with encrypted JSON storage

### 🔧 Communication Bridge
- **HTTP API server** on localhost:8765 for GeanyLua communication
- **Unix socket support** (framework ready)
- **Event-driven architecture** with real-time updates
- **Graceful degradation** when sidecar is unavailable
- **Health checking** and connection status monitoring

## Architecture

```
┌─────────────────────┐    HTTP/Unix Socket    ┌──────────────────────┐
│                     │◄──────────────────────►│                      │
│   GeanyLua Plugin   │                        │   Tauri Sidecar     │
│   (CodingBuddy)     │                        │                      │
│                     │                        │  ┌─────────────────┐ │
└─────────────────────┘                        │  │   React UI      │ │
                                               │  │   (Dark Mode)   │ │
                                               │  └─────────────────┘ │
                                               │  ┌─────────────────┐ │
                                               │  │  Rust Backend   │ │
                                               │  │  (Encrypted)    │ │
                                               │  └─────────────────┘ │
                                               └──────────────────────┘
```

## Installation

### Prerequisites
- **Rust** (1.70+) and Cargo - [Install from rustup.rs](https://rustup.rs/)
- **Node.js** (16+) and npm - [Install from nodejs.org](https://nodejs.org/)
- **Tauri CLI** - Will be installed automatically

### Quick Install
```bash
# Navigate to the sidecar directory
cd multiapp-sidecar

# Run the installation script
chmod +x install.sh
./install.sh
```

### Manual Installation
```bash
# Install dependencies
npm install

# Install Tauri CLI (if not already installed)
cargo install tauri-cli --version "^2.0.0"

# Build the application
npm run tauri:build
```

## Usage

### Starting the Sidecar
```bash
# Development mode with hot reload
npm run tauri:dev

# Production build and run
npm run tauri:build
```

### Enabling in GeanyLua
1. **Optional**: Set encryption passphrase
   ```bash
   export MULTIAPP_PASSPHRASE="your-secure-passphrase-here"
   ```

2. **Enable in config**: Add to your CodingBuddy `config.json`:
   ```json
   {
     "sidecar_enabled": true,
     "sidecar_url": "http://localhost:8765"
   }
   ```

3. **Restart Geany**: The plugin will automatically detect and connect to the sidecar

### Configuration

The sidecar stores its configuration in an encrypted JSON file (when passphrase is provided) at:
- Linux: `~/.local/share/com.multiappv1.sidecar/sidecar_state.json`
- macOS: `~/Library/Application Support/com.multiappv1.sidecar/sidecar_state.json`
- Windows: `%APPDATA%/com.multiappv1.sidecar/sidecar_state.json`

## API Endpoints

The sidecar exposes the following HTTP endpoints for GeanyLua communication:

### Health Check
```
GET /health
```
Returns connection status and service information.

### Event Submission
```
POST /events
```
Submit events from GeanyLua (operation requests, chat messages, etc.).

### Operations Management
```
GET /operations              # Get pending operations
POST /operations/approve     # Approve an operation
POST /operations/reject      # Reject an operation
```

### Notifications
```
GET /notifications           # Get current notifications
POST /notifications/clear    # Clear dismissed notifications
```

## Development

### Project Structure
```
multiapp-sidecar/
├── src/                    # React frontend source
│   ├── components/         # UI components
│   ├── App.jsx            # Main application component
│   └── main.jsx           # React entry point
├── src-tauri/             # Rust backend source
│   ├── src/
│   │   ├── main.rs        # Tauri main entry point
│   │   ├── crypto.rs      # Encryption module
│   │   ├── server.rs      # HTTP server
│   │   ├── state.rs       # Application state management
│   │   ├── events.rs      # Event handling
│   │   └── terminal.rs    # Terminal emulation
│   └── Cargo.toml         # Rust dependencies
├── package.json           # Node.js dependencies
└── tauri.conf.json       # Tauri configuration
```

### Building from Source
```bash
# Development with hot reload
npm run dev

# Build frontend only
npm run build

# Build Tauri app
npm run tauri:build

# Run tests
cargo test --manifest-path=src-tauri/Cargo.toml
```

### Security Notes

- **Encryption**: All persistent state can be encrypted using AES-GCM with Argon2 key derivation
- **Environment Variables**: Never store the passphrase in config files
- **Network**: The sidecar only accepts connections from localhost
- **Operations**: All file operations are sandboxed and require explicit approval

## Integration with GeanyLua

The sidecar is designed to be completely optional. The GeanyLua plugin (`sidecar_connector.lua`) will:

1. **Auto-detect** if the sidecar is running
2. **Gracefully degrade** if sidecar is unavailable  
3. **Queue operations** for approval when sidecar is active
4. **Provide fallback** behavior for all operations

### Example Integration
```lua
local sidecar = require('sidecar_connector')

-- Send operation for approval
local success, operation_id = sidecar.send_operation_request('write_file', {
    path = '/path/to/file.txt',
    content = 'Hello, World!'
})

-- Check if sidecar is available
if sidecar.is_available() then
    sidecar.send_chat_message('Analysis complete!')
end
```

## Troubleshooting

### Common Issues

**Sidecar won't start**
- Check that ports 8765 is available
- Ensure Rust and Node.js are properly installed
- Check the console output for specific errors

**GeanyLua can't connect**
- Verify the sidecar is running and health endpoint responds
- Check firewall settings (though it only uses localhost)
- Ensure `sidecar_enabled = true` in config.json

**Encryption issues**
- Verify `MULTIAPP_PASSPHRASE` environment variable is set
- Use a strong passphrase (20+ characters recommended)
- Check file permissions on the state directory

**Terminal not working**
- This is a mock implementation - real terminal requires additional development
- Check shell path in settings
- Verify terminal dependencies are installed

### Debug Mode
```bash
# Enable debug logging
RUST_LOG=debug npm run tauri:dev

# Check sidecar connectivity from command line
curl http://localhost:8765/health
```

## Contributing

This sidecar is part of the MultiappV1 ecosystem. Key areas for contribution:

1. **Real terminal implementation** with full PTY support
2. **Unix socket communication** as alternative to HTTP
3. **Enhanced approval workflows** with operation queuing
4. **Theme customization** and additional UI themes
5. **Performance optimizations** and caching improvements

## License

MIT License - see LICENSE file for details.

---

**Note**: This sidecar is completely optional and designed to enhance the GeanyLua CodingBuddy experience without breaking existing functionality. The core plugin will work perfectly fine without the sidecar installed.
