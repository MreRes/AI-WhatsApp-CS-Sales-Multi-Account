#!/bin/bash
################################################################################
# Hermes Portable - START (Universal for Linux/macOS)
# Boots: 9router (Node) + Hermes (Python) + Cloudflare tunnels
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$SCRIPT_DIR"
DATA_DIR="$BUNDLE_ROOT/data"
INSTALLED_FLAG="$DATA_DIR/.installed"
ORCHESTRATOR_DIR="$BUNDLE_ROOT/orchestrator"

# Check if installed
if [ ! -f "$INSTALLED_FLAG" ]; then
    echo "[*] Not installed yet - running installer..."
    bash "$BUNDLE_ROOT/install.sh"
fi

# Run orchestrator
if [ -f "$ORCHESTRATOR_DIR/start_all.sh" ]; then
    chmod +x "$ORCHESTRATOR_DIR/start_all.sh"
    bash "$ORCHESTRATOR_DIR/start_all.sh" "$@"
else
    echo "[X] Orchestrator not found"
    exit 1
fi
