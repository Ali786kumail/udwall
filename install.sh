#!/bin/bash

# udwall Install Script

set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (sudo ./install.sh)"
  exit 1
fi

echo "🚀 Installing udwall..."

# 1. Install dependencies
echo "📦 Installing dependencies..."
apt-get update -qq
apt-get install -y ufw python3

# 2. Create installation directory
INSTALL_DIR="/opt/udwall"
echo "📂 Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 3. Copy files
echo "COPY Copying files..."
cp udwall.py "$INSTALL_DIR/"
cp udwall.conf "$INSTALL_DIR/udwall.conf.example"

# 4. Create symlink
echo "🔗 Creating symlink..."
ln -sf "$INSTALL_DIR/udwall.py" /usr/local/bin/udwall

# 5. Make executable
chmod +x "$INSTALL_DIR/udwall.py"

# 6. Setup global config
CONFIG_DIR="/etc/udwall"
if [ ! -f "$CONFIG_DIR/udwall.conf" ]; then
    echo "⚙️  Setting up default configuration at $CONFIG_DIR/udwall.conf"
    mkdir -p "$CONFIG_DIR"
    cp udwall.conf "$CONFIG_DIR/udwall.conf"
else
    echo "⚠️  Configuration file already exists at $CONFIG_DIR/udwall.conf. Skipping overwrite."
fi

echo "✅ Installation complete!"
echo "Run 'sudo udwall --help' to get started."
