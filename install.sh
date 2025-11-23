#!/bin/bash

# udwall Install Script

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (sudo ./install.sh)"
  exit 1
fi

echo "🚀 Installing udwall..."

# 1. Check dependencies
echo "🔍 Checking dependencies..."

if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed."
    echo "ℹ️  Please install Python 3 and try again (e.g., 'sudo apt install python3')."
    exit 1
fi

if ! command -v ufw &> /dev/null; then
    echo "❌ Error: UFW is not installed."
    echo "ℹ️  Please install UFW and try again (e.g., 'sudo apt install ufw')."
    exit 1
fi

echo "✅ Dependencies found."

# 2. Download and Install
echo "⬇️  Downloading udwall..."

# Ensure curl is installed
if ! command -v curl &> /dev/null; then
    echo "❌ Error: curl is not installed."
    echo "ℹ️  Please install curl and try again."
    exit 1
fi

REPO_URL="https://raw.githubusercontent.com/Hexmos/udwall/main"
INSTALL_PATH="/usr/local/bin/udwall"

# Download udwall.py directly to /usr/local/bin/udwall
curl -sSL "$REPO_URL/udwall.py" -o "$INSTALL_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Error downloading udwall.py"
    exit 1
fi

# Make executable
echo "🔑 Setting permissions..."
chmod +x "$INSTALL_PATH"

# 3. Setup global config
CONFIG_DIR="/etc/udwall"
CONFIG_FILE="$CONFIG_DIR/udwall.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚙️  Setting up default configuration at $CONFIG_FILE"
    mkdir -p "$CONFIG_DIR"
    # Download default config
    curl -sSL "$REPO_URL/udwall.conf" -o "$CONFIG_FILE"
else
    echo "⚠️  Configuration file already exists at $CONFIG_FILE. Skipping overwrite."
fi

echo "✅ Installation complete!"
echo "Run 'sudo udwall --help' to get started."
