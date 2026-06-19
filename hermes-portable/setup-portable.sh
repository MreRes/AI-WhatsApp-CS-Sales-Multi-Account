#!/bin/bash
################################################################################
# Hermes Portable Setup Wizard - Shell Version (Linux/macOS)
# TIER 1 ESSENTIALS ONLY
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
CONFIG_DIR="$SCRIPT_DIR/portable-config"
CONFIG_FILE="$DATA_DIR/config.yaml"
ENV_FILE="$DATA_DIR/.env"
ROUTER9_DIR="$SCRIPT_DIR/services/9router"
ROUTER9_ENV_FILE="$ROUTER9_DIR/.env"
ROUTER9_DATA_DIR="$DATA_DIR/9router"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_header() { echo ""; echo -e "${CYAN}==========================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}==========================================${NC}"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_info() { echo -e "${CYAN}[*]${NC} $1"; }

log_header "Hermes Portable Setup Wizard (Linux/macOS)"

# Pre-flight
log_info "Checking dependencies..."
for cmd in python3 git; do
  if ! command -v "$cmd" &> /dev/null; then
    echo -e "${RED}[X]${NC} $cmd not found"
    exit 1
  fi
done
log_ok "Dependencies OK"

# Ensure data dir
mkdir -p "$DATA_DIR" "$ROUTER9_DATA_DIR"

# Collect configuration
log_header "Configuration (Tier 1: Essentials)"

MODE="${1:-Interactive}"

if [ "$MODE" = "Auto" ]; then
    log_info "Automatic mode (demo)"
    API_KEY="${HERMES_API_KEY:-sk-or-test-demo-key-no-api-configured}"
    TELEGRAM_TOKEN=""
else
    echo ""
    echo "1. LLM API Key (for Hermes to call 9router)"
    read -p "   Enter API key [demo]: " API_KEY
    API_KEY="${API_KEY:-sk-or-test-demo-key-no-api-configured}"

    echo ""
    echo "2. Telegram Bot Token (optional, for notifications)"
    read -p "   Enter token (or press Enter to skip): " TELEGRAM_TOKEN

    if [ -n "$TELEGRAM_TOKEN" ]; then
        echo "   Telegram Chat ID (who receives notifications)"
        read -p "   Enter chat ID: " TELEGRAM_CHAT_ID
    fi
fi

# Generate .env (Tier 1)
log_header "Generating Configuration"

# Auto-generate secrets
JWT_SECRET=$(head -c 32 /dev/urandom | base64 | tr -d '=+/' | cut -c1-43)
INITIAL_PASSWORD=$(head -c 12 /dev/urandom | base64 | tr -d '=+/' | cut -c1-16)

log_info "Creating .env..."
cat > "$ENV_FILE" << EOF
# Hermes Portable Environment - Tier 1 (Essentials)
HERMES_API_KEY=$API_KEY
HERMES_BASE_URL=http://localhost:20128
HERMES_TELEGRAM_TOKEN=$TELEGRAM_TOKEN
HERMES_TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID:-}
HERMES_HOME=$DATA_DIR
HERMES_PORTABLE=true
HERMES_LOG_LEVEL=INFO
NODE_ENV=production
EOF
log_ok "Created .env"

# Generate Hermes config.yaml
log_info "Creating config.yaml..."
cat > "$CONFIG_FILE" << EOF
# Hermes Portable Config - Tier 1
router:
  base_url: "http://localhost:20128"
  api_key: "$API_KEY"
  default_model: "openai/gpt-4o-mini"

mcp_servers:
  windows:
    name: "windows"
    enabled: true
    command: "python"
    args: ["-m", "windows_mcp", "serve"]
    transport: "stdio"

gateway:
  platforms:
    telegram:
      enabled: $([ -n "$TELEGRAM_TOKEN" ] && echo "true" || echo "false")

portable:
  enabled: true
EOF
log_ok "Created config.yaml"

# Generate 9router .env
log_info "Configuring 9router..."
mkdir -p "$ROUTER9_DATA_DIR"
cat > "$ROUTER9_ENV_FILE" << EOF
# 9router (Service #1) - auto-generated
JWT_SECRET=$JWT_SECRET
INITIAL_PASSWORD=$INITIAL_PASSWORD
PORT=20128
NODE_ENV=production
DATA_DIR=$ROUTER9_DATA_DIR
BASE_URL=http://localhost:20128
NEXT_PUBLIC_BASE_URL=http://localhost:20128
EOF
log_ok "Generated 9router secrets"
log_warn "Save this 9router login password: $INITIAL_PASSWORD"

# Summary
log_header "Setup Complete!"
echo ""
log_ok "Configuration saved to:"
echo "    Data dir:      $DATA_DIR"
echo "    Hermes config: $CONFIG_FILE"
echo "    Hermes env:    $ENV_FILE"
[ -n "$TELEGRAM_TOKEN" ] && log_ok "Telegram: Enabled" || log_warn "Telegram: Disabled"
echo ""
log_warn "Next: bash start.sh to launch"
echo ""
