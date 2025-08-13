#!/bin/bash

# MultiappV1 Sidecar Installation Script
# Optional installation of the Tauri sidecar for GeanyLua CodingBuddy

set -e

echo "=========================================="
echo "MultiappV1 Tauri Sidecar Installation"
echo "=========================================="
echo

# Check prerequisites
echo "Checking prerequisites..."

# Check for Rust and Cargo
if ! command -v cargo &> /dev/null; then
    echo "❌ Rust/Cargo is required but not installed."
    echo "Please install Rust from: https://rustup.rs/"
    exit 1
fi
echo "✅ Rust/Cargo found"

# Check for Node.js and npm
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "❌ Node.js and npm are required but not installed."
    echo "Please install Node.js from: https://nodejs.org/"
    exit 1
fi
echo "✅ Node.js/npm found"

# Check for Tauri CLI
if ! cargo install --list | grep -q tauri-cli; then
    echo "📦 Installing Tauri CLI..."
    cargo install tauri-cli --version "^2.0.0"
else
    echo "✅ Tauri CLI found"
fi

# Install dependencies
echo
echo "Installing dependencies..."
echo "📦 Installing npm dependencies..."
npm install

echo "📦 Installing Rust dependencies..."
cd src-tauri
cargo check
cd ..

# Build the application
echo
echo "Building sidecar application..."
npm run tauri:build

echo
echo "=========================================="
echo "Installation completed successfully! 🎉"
echo "=========================================="
echo
echo "To start the sidecar:"
echo "  npm run tauri:dev      # Development mode"
echo "  npm run tauri:build    # Production build"
echo
echo "The sidecar will be available at:"
echo "  http://localhost:8765  # HTTP API"
echo "  GUI Application        # Tauri desktop app"
echo
echo "To enable sidecar integration in GeanyLua:"
echo "  1. Set MULTIAPP_PASSPHRASE environment variable (optional, for encryption)"
echo "  2. Add 'sidecar_enabled = true' to your CodingBuddy config.json"
echo "  3. Restart Geany"
echo
echo "For more information, see README.md"
