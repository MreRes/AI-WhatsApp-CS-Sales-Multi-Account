#!/bin/bash
################################################################################
# Hermes Portable - Cross-Platform Runtime Downloader
# Downloads Node.js, cloudflared, ADB for Linux/macOS
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(dirname "$SCRIPT_DIR")"
RUNTIME_DIR="$BUNDLE_ROOT/runtime"
NODE_DIR="$RUNTIME_DIR/node"
BIN_DIR="$RUNTIME_DIR/bin"

# Detect OS + Architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
NODE_VERSION="22.11.0"

# Map architecture names
case "$ARCH" in
  x86_64) ARCH_MAPPED="x64" ;;
  aarch64) ARCH_MAPPED="arm64" ;;
  arm64) ARCH_MAPPED="arm64" ;;  # macOS M1/M2/M3
  *) echo "[X] Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
  linux) NODE_OS="linux" ;;
  darwin) NODE_OS="darwin" ;;
  *) echo "[X] Unsupported OS: $OS"; exit 1 ;;
esac

echo "[*] Downloading runtimes for $OS/$ARCH..."
mkdir -p "$NODE_DIR" "$BIN_DIR"

# 1. Node.js
NODE_ZIP="node-v$NODE_VERSION-$NODE_OS-$ARCH_MAPPED.tar.xz"
NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/$NODE_ZIP"
NODE_TAR="$RUNTIME_DIR/$NODE_ZIP"

if [ ! -f "$NODE_DIR/bin/node" ]; then
    echo "[*] Downloading Node.js $NODE_VERSION ($NODE_OS/$ARCH_MAPPED)..."
    curl -fsSL "$NODE_URL" -o "$NODE_TAR"
    echo "[*] Extracting Node.js..."
    tar xf "$NODE_TAR" -C "$RUNTIME_DIR"
    # Move contents of node-vX-os-arch/ into node/
    mv "$RUNTIME_DIR/node-v$NODE_VERSION-$NODE_OS-$ARCH_MAPPED"/* "$NODE_DIR/" 2>/dev/null || true
    rm -rf "$RUNTIME_DIR/node-v$NODE_VERSION-$NODE_OS-$ARCH_MAPPED" "$NODE_TAR"
    echo "[OK] Node.js installed: $($NODE_DIR/bin/node --version)"
else
    echo "[OK] Node.js already present: $($NODE_DIR/bin/node --version)"
fi

# 2. cloudflared
CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-$OS-$ARCH"
CF_BIN="$BIN_DIR/cloudflared"

if [ ! -f "$CF_BIN" ]; then
    echo "[*] Downloading cloudflared ($OS/$ARCH)..."
    curl -fsSL "$CF_URL" -o "$CF_BIN"
    chmod +x "$CF_BIN"
    echo "[OK] cloudflared installed: $CF_BIN"
else
    echo "[OK] cloudflared already present"
fi

# 3. ADB (Android platform-tools)
if [ "$OS" = "linux" ]; then
    ADB_URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
elif [ "$OS" = "darwin" ]; then
    ADB_URL="https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"
fi

ADB_BIN="$BIN_DIR/platform-tools/adb"
if [ ! -f "$ADB_BIN" ]; then
    echo "[*] Downloading ADB ($OS/$ARCH)..."
    TMP_ADB="/tmp/platform-tools-$$.zip"
    curl -fsSL "$ADB_URL" -o "$TMP_ADB"
    unzip -q "$TMP_ADB" -d "$BIN_DIR"
    rm "$TMP_ADB"
    echo "[OK] ADB installed: $ADB_BIN"
else
    echo "[OK] ADB already present"
fi

echo ""
echo "[OK] All runtimes ready:"
echo "    Node.js:     $NODE_DIR"
echo "    cloudflared: $CF_BIN"
echo "    ADB:         $ADB_BIN"
