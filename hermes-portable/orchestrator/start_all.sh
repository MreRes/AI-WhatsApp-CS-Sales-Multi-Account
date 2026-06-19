#!/bin/bash
################################################################################
# Hermes Portable - Start All Services (Linux/macOS)
# Boots: 9router + Hermes + Cloudflare tunnels + send Telegram notification
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(dirname "$SCRIPT_DIR")"
RUNTIME_DIR="$BUNDLE_ROOT/runtime"
NODE_DIR="$RUNTIME_DIR/node"
BIN_DIR="$RUNTIME_DIR/bin"
SERVICES_DIR="$BUNDLE_ROOT/services"
ROUTER9_DIR="$SERVICES_DIR/9router"
HERMES_DIR="$SERVICES_DIR/hermes"
DATA_DIR="$BUNDLE_ROOT/data"
VENV_DIR="$DATA_DIR/.venv"
LOGS_DIR="$DATA_DIR/logs"
PIDS_FILE="$DATA_DIR/pids.txt"
TUNNEL_FILE="$DATA_DIR/tunnel_urls.txt"
ENV_FILE="$DATA_DIR/.env"

ROUTER9_PORT=20128
HERMES_PORT=9119

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_header() { echo ""; echo -e "${CYAN}===================================${NC}"; echo -e "${CYAN} $1${NC}"; echo -e "${CYAN}===================================${NC}"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err() { echo -e "${RED}[X]${NC} $1"; }

mkdir -p "$LOGS_DIR"

log_header "Starting Hermes Portable"

# 1. Start 9router (official npm package — prebuilt + self-updating)
log_header "1/4 Starting 9router (port $ROUTER9_PORT)"
export NODE_ENV=production
export PORT=$ROUTER9_PORT
# Portable DB: 9router honors DATA_DIR for its sqlite + secrets, so credentials persist
# in the bundle (not ~/.9router) and survive auto-updates / travel with the USB.
# Applied inline at the launch line below (not exported globally, to avoid clobbering
# $DATA_DIR used elsewhere in this script).
ROUTER9_DATA_DIR="$DATA_DIR/9router"
ROUTER9_LOG="$LOGS_DIR/9router.log"
NODE="$NODE_DIR/bin/node"
NPM="$NODE_DIR/bin/npm"
ROUTER9_APP_DIR="$RUNTIME_DIR/9router-app"
ROUTER9_CLI="$ROUTER9_APP_DIR/node_modules/9router/cli.js"

if [ ! -f "$ROUTER9_CLI" ]; then
    log_err "9router npm package not found. Run install first."
    exit 1
fi

# Best-effort refresh to @latest (non-fatal if offline)
export npm_config_cache="$DATA_DIR/.npm"
"$NPM" install 9router@latest --prefix "$ROUTER9_APP_DIR" --no-audit --no-fund --silent > /dev/null 2>&1 \
    && log_ok "9router up to date" || log_warn "9router update skipped (offline?)"

# Launch: -n no-browser, -l logs, -p port
DATA_DIR="$ROUTER9_DATA_DIR" "$NODE" "$ROUTER9_CLI" -n -l -p "$ROUTER9_PORT" > "$ROUTER9_LOG" 2>&1 &
ROUTER9_PID=$!
log_ok "9router started (PID $ROUTER9_PID)"

# Wait for 9router health
log_ok "Waiting for 9router health..."
for i in {1..90}; do
    if curl -sf "http://localhost:$ROUTER9_PORT" > /dev/null 2>&1; then
        log_ok "9router is healthy"
        break
    fi
    sleep 1
    if [ $i -eq 90 ]; then
        log_err "9router failed to start"
        exit 1
    fi
done

# 2. Start Hermes
log_header "2/4 Starting Hermes (port $HERMES_PORT)"
export HERMES_HOME=$DATA_DIR
export HERMES_PORTABLE=true
# Embedded-MCPs import path, computed from this bundle's location (drive/location-independent;
# replaces an absolute site-packages .pth). Dashboard + gateway inherit it, and the MCP
# subprocesses they spawn inherit it too, so `python -m windows_mcp` resolves anywhere.
export PYTHONPATH="$BUNDLE_ROOT/embedded-mcps${PYTHONPATH:+:$PYTHONPATH}"

HERMES_BIN="$VENV_DIR/bin/hermes"
HERMES_LOG="$LOGS_DIR/hermes.log"

cd "$HERMES_DIR"
# Launch the Hermes web dashboard (frontend + API) on $HERMES_PORT.
# --skip-build serves prebuilt web_dist; --no-open keeps it headless.
# NOTE: this Hermes build's `dashboard` has no --trust-proxy flag. Do not add it.
"$HERMES_BIN" dashboard --port "$HERMES_PORT" --host 127.0.0.1 --no-open --skip-build > "$HERMES_LOG" 2>&1 &
HERMES_PID=$!
log_ok "Hermes dashboard started (PID $HERMES_PID)"

# Wait for Hermes health
log_ok "Waiting for Hermes health..."
for i in {1..90}; do
    if curl -sf "http://127.0.0.1:$HERMES_PORT/api/status" > /dev/null 2>&1; then
        log_ok "Hermes is healthy"
        break
    fi
    sleep 1
    if [ $i -eq 90 ]; then
        log_warn "Hermes health endpoint not responding (may still be booting)"
        break
    fi
done

# 2b. Always start the Hermes messaging gateway (Telegram/Discord/etc.)
log_header "Starting Hermes messaging gateway"
GATEWAY_LOG="$LOGS_DIR/gateway.log"
"$HERMES_BIN" gateway run --accept-hooks > "$GATEWAY_LOG" 2>&1 &
GATEWAY_PID=$!
log_ok "Hermes gateway started (PID $GATEWAY_PID)"

# 3. Start Cloudflare tunnels
log_header "3/4 Starting Cloudflare tunnels"
CLOUDFLARED="$BIN_DIR/cloudflared"

if [ -f "$CLOUDFLARED" ]; then
    CF_LOG_9ROUTER="$LOGS_DIR/cloudflared-9router.log"
    CF_LOG_HERMES="$LOGS_DIR/cloudflared-hermes.log"

    log_ok "Tunnel -> 9router..."
    $CLOUDFLARED tunnel --no-autoupdate --protocol http2 --retries 10 --url "http://localhost:$ROUTER9_PORT" > "$CF_LOG_9ROUTER" 2>&1 &
    CF_PID_9ROUTER=$!

    log_ok "Tunnel -> Hermes..."
    # --http-host-header rewrites Host to the bound hostname so the dashboard's Host-header
    # validation accepts tunnel requests (this build has no --trust-proxy).
    $CLOUDFLARED tunnel --no-autoupdate --protocol http2 --retries 10 --http-host-header "127.0.0.1:$HERMES_PORT" --url "http://localhost:$HERMES_PORT" > "$CF_LOG_HERMES" 2>&1 &
    CF_PID_HERMES=$!

    # Capture public URLs from logs
    sleep 5
    ROUTER9_URL=$(grep -oP 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$CF_LOG_9ROUTER" | head -1 || echo "")
    HERMES_URL=$(grep -oP 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$CF_LOG_HERMES" | head -1 || echo "")

    [ -n "$ROUTER9_URL" ] && log_ok "9router public: $ROUTER9_URL" || log_warn "9router tunnel URL not captured"
    [ -n "$HERMES_URL" ] && log_ok "Hermes public: $HERMES_URL" || log_warn "Hermes tunnel URL not captured"
else
    log_warn "cloudflared not found (local-only mode)"
fi

# 4. Save state + Telegram notification
log_header "4/4 Ready"
{
    echo "9router=$ROUTER9_PID"
    echo "hermes=$HERMES_PID"
    [ -n "$GATEWAY_PID" ] && echo "hermes-gateway=$GATEWAY_PID"
    [ -n "$CF_PID_9ROUTER" ] && echo "cloudflared-9router=$CF_PID_9ROUTER"
    [ -n "$CF_PID_HERMES" ] && echo "cloudflared-hermes=$CF_PID_HERMES"
} > "$PIDS_FILE"

# Save tunnel URLs
cat > "$TUNNEL_FILE" << EOF
9router_local=http://localhost:$ROUTER9_PORT
9router_public=$ROUTER9_URL
hermes_local=http://localhost:$HERMES_PORT
hermes_public=$HERMES_URL
EOF

# Send Telegram notification
if [ -f "$ENV_FILE" ]; then
    TG_TOKEN=$(grep "^HERMES_TELEGRAM_TOKEN=" "$ENV_FILE" | cut -d= -f2-)
    TG_CHAT=$(grep "^HERMES_TELEGRAM_CHAT_ID=" "$ENV_FILE" | cut -d= -f2-)

    if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT" ]; then
        log_ok "Sending Telegram notification..."
        MSG="<b>Hermes Portable is ONLINE!</b>%0A%0A<b>9router (LLM gateway):</b>%0ALocal: http://localhost:$ROUTER9_PORT%0APublic: $ROUTER9_URL%0A%0A<b>Hermes (AI Agent):</b>%0ALocal: http://localhost:$HERMES_PORT%0APublic: $HERMES_URL%0A%0AReady for commands!"
        curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
            -d "chat_id=$TG_CHAT&text=$MSG&parse_mode=HTML" > /dev/null 2>&1 || true
    fi
fi

# Print summary
echo ""
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN} Hermes Portable is RUNNING${NC}"
echo -e "${GREEN}===============================================${NC}"
echo ""
echo -e "${CYAN}  9router (LLM gateway):${NC}"
echo "    Local:  http://localhost:$ROUTER9_PORT"
[ -n "$ROUTER9_URL" ] && echo -e "    Public: ${YELLOW}$ROUTER9_URL${NC}"
echo ""
echo -e "${CYAN}  Hermes (AI agent):${NC}"
echo "    Local:  http://localhost:$HERMES_PORT"
[ -n "$HERMES_URL" ] && echo -e "    Public: ${YELLOW}$HERMES_URL${NC}"
echo ""
echo "  Logs:  $LOGS_DIR"
echo "  Stop:  bash stop.sh"
echo ""
echo -e "${CYAN}Keep this window open, or close it - services run in background.${NC}"
echo ""
