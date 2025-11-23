#!/bin/bash

# udwall Install Script

set -e

REPO_URL="https://raw.githubusercontent.com/HexmosTech/udwall/main"
INSTALL_PATH="/usr/local/bin/udwall"
CONFIG_DIR="/etc/udwall"
CONFIG_FILE="$CONFIG_DIR/udwall.conf"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ Please run as root (sudo ./install.sh)"
        exit 1
    fi
}

check_dependencies() {
    echo "🔍 Checking dependencies..."
    local dependencies=("python3" "ufw" "curl")
    local missing=0

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "❌ Error: $dep is not installed."
            echo "ℹ️  Please install $dep and try again."
            missing=1
        fi
    done

    if [ $missing -eq 1 ]; then
        exit 1
    fi
    echo "✅ Dependencies found."
}

fetch_script() {
    echo "⬇️  Downloading udwall..."
    # Download udwall directly to /usr/local/bin/udwall
    if ! curl -fsSL "$REPO_URL/udwall" -o "$INSTALL_PATH"; then
        echo "❌ Error: Failed to download udwall from GitHub."
        echo "ℹ️  Please check your internet connection or if the repository/file exists."
        exit 1
    fi

    # Make executable
    echo "🔑 Setting permissions..."
    chmod +x "$INSTALL_PATH"
}

setup_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "⚙️  Setting up default configuration at $CONFIG_FILE"
        mkdir -p "$CONFIG_DIR"
        # Download default config
        if ! curl -fsSL "$REPO_URL/udwall.conf" -o "$CONFIG_FILE"; then
             echo "⚠️  Warning: Failed to download default config. You may need to create one manually."
        fi
    else
        echo "⚠️  Configuration file already exists at $CONFIG_FILE. Skipping overwrite."
    fi
}

main() {
    echo "🚀 Installing udwall..."
    check_root
    check_dependencies
    fetch_script
    setup_config
    echo "✅ Installation complete!"
    echo "Run 'sudo udwall --help' to get started."
}

main
