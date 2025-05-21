#!/bin/bash

# Exit on error
set -e

# Configuration
EXTENSION_DIR="$HOME/.config/chromium/BrowserToolMCP"
EXTENSION_URL="https://github.com/yourusername/BrowserToolMCP/releases/latest/download/browsertoolmcp.crx"

# Create extension directory
mkdir -p "$EXTENSION_DIR"

# Download the extension
echo "Downloading BrowserToolMCP extension..."
curl -L "$EXTENSION_URL" -o "$EXTENSION_DIR/browsertoolmcp.crx"

# Extract the extension
echo "Extracting extension..."
unzip -o "$EXTENSION_DIR/browsertoolmcp.crx" -d "$EXTENSION_DIR"

# Enable the service
echo "Enabling Chromium service..."
systemctl --user enable chromium-browsertoolmcp.service

echo "Installation complete! BrowserToolMCP will start automatically at login." 