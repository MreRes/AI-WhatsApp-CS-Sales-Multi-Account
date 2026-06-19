#!/bin/bash
################################################################################
# Hermes Portable - Interactive Config Setup (Universal)
# Manage credentials: Telegram, WhatsApp, Discord, Slack, Providers
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/portable-config"

if [ -f "$CONFIG_DIR/config-setup.ps1" ]; then
    # Try PowerShell if available (Windows Subsystem for Linux)
    if command -v pwsh &> /dev/null; then
        pwsh -NoProfile -ExecutionPolicy Bypass -File "$CONFIG_DIR/config-setup.ps1"
    elif command -v powershell &> /dev/null; then
        powershell -NoProfile -ExecutionPolicy Bypass -File "$CONFIG_DIR/config-setup.ps1"
    else
        # Fall back to shell version (future)
        echo "[!] PowerShell not available. Falling back to manual edit:"
        echo "    Edit: $SCRIPT_DIR/data/.env"
        exit 0
    fi
else
    echo "[X] Config setup script not found"
    exit 1
fi
