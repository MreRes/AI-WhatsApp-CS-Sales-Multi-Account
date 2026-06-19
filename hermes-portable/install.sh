#!/bin/bash
################################################################################
# Hermes Portable - Universal Installer
# Detects OS (Windows/Linux/macOS) and runs appropriate installer
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$SCRIPT_DIR"

echo ""
echo "========================================"
echo "  Hermes Portable - Universal Installer"
echo "========================================"
echo ""

# Detect OS
OS_TYPE=$(uname -s)
ARCH=$(uname -m)

case "$OS_TYPE" in
  Linux)
    echo "[*] Detected: Linux ($ARCH)"
    INSTALLER_SCRIPT="$BUNDLE_ROOT/installer/install-linux.sh"
    ;;
  Darwin)
    echo "[*] Detected: macOS ($ARCH)"
    INSTALLER_SCRIPT="$BUNDLE_ROOT/installer/install-macos.sh"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "[*] Detected: Windows (Git Bash / MSYS2)"
    echo "[!] On Windows, please use: INSTALL.bat"
    exit 1
    ;;
  *)
    echo "[X] Unsupported OS: $OS_TYPE"
    echo "[!] Supported: Linux, macOS"
    exit 1
    ;;
esac

# Run OS-specific installer
if [ -f "$INSTALLER_SCRIPT" ]; then
  chmod +x "$INSTALLER_SCRIPT"
  "$INSTALLER_SCRIPT" "$@"
else
  echo "[X] Installer not found: $INSTALLER_SCRIPT"
  exit 1
fi
