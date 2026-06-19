#!/bin/bash
################################################################################
# Hermes Portable - STOP (Universal for Linux/macOS)
# Shutdown: 9router + Hermes + Cloudflare tunnels
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR_DIR="$SCRIPT_DIR/orchestrator"

if [ -f "$ORCHESTRATOR_DIR/stop_all.sh" ]; then
    chmod +x "$ORCHESTRATOR_DIR/stop_all.sh"
    bash "$ORCHESTRATOR_DIR/stop_all.sh"
else
    echo "[X] Stop script not found"
    exit 1
fi
