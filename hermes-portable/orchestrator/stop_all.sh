#!/bin/bash
################################################################################
# Hermes Portable - Stop All Services (Linux/macOS)
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$BUNDLE_ROOT/data"
PIDS_FILE="$DATA_DIR/pids.txt"
TUNNEL_FILE="$DATA_DIR/tunnel_urls.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo ""
echo -e "${YELLOW}Stopping Hermes Portable services...${NC}"
echo ""

if [ ! -f "$PIDS_FILE" ]; then
    log_warn "No pids.txt found - nothing to stop (or already stopped)"
    exit 0
fi

STOPPED=0
while IFS='=' read -r name pid; do
    if [ -z "$pid" ]; then
        continue
    fi

    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        log_ok "Stopped $name (PID $pid)"
        ((STOPPED++))
    fi
done < "$PIDS_FILE"

rm -f "$PIDS_FILE" "$TUNNEL_FILE"

echo ""
log_ok "Stopped $STOPPED service(s). Hermes Portable is down."
echo ""
