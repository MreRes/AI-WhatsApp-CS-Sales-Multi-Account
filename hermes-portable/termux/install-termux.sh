#!/data/data/com.termux/files/usr/bin/bash
################################################################################
# Hermes Portable — Termux installer (run ON the Android phone, inside Termux)
#
# Installs Hermes (official termux support) + Android-MCP so the phone runs the
# agent AND controls itself over (wireless) ADB. 9router is optional — by default
# we point Hermes straight at a provider; set USE_9ROUTER=1 to run it locally too.
#
# Prereqs on the phone:
#   - Termux (from F-Droid, not Play Store)
#   - Android 11+ Wireless debugging ON (Settings > Developer options) for
#     self-control, OR a rooted device.
################################################################################
set -e

log() { printf '\033[0;36m==>\033[0m %s\n' "$1"; }
ok()  { printf '\033[0;32m[OK]\033[0m %s\n' "$1"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes-portable}"
mkdir -p "$HERMES_HOME"

log "1/5 Updating Termux packages..."
pkg update -y && pkg upgrade -y

log "2/5 Installing python, nodejs, adb, git, build tools..."
pkg install -y python nodejs-lts android-tools git rust binutils libjpeg-turbo

log "3/5 Installing Hermes (termux profile) + Android-MCP deps..."
pip install --upgrade pip wheel
# Hermes official termux extra (cli, mcp, pty, cron, acp, telegram)
pip install "hermes-agent[termux]" || warn "hermes-agent[termux] partial; retrying core"
# Android-MCP control deps
pip install uiautomator2 fastmcp pillow tabulate || warn "android-mcp deps partial"

log "4/5 (Optional) 9router local LLM gateway..."
if [ "${USE_9ROUTER:-0}" = "1" ]; then
    npm install 9router@latest --prefix "$HERMES_HOME/9router-app" --no-audit --no-fund
    ok "9router installed locally (run with: node $HERMES_HOME/9router-app/node_modules/9router/cli.js -n -l -p 20128)"
else
    warn "Skipping local 9router (set USE_9ROUTER=1 to install). Hermes will use the provider/base_url in your config."
fi

log "5/5 Seeding config..."
mkdir -p "$HERMES_HOME"
if [ ! -f "$HERMES_HOME/.env" ]; then
cat > "$HERMES_HOME/.env" <<EOF
# --- LLM (point at your provider or a remote 9router) ---
OPENROUTER_API_KEY=PUT_YOUR_KEY
OPENROUTER_BASE_URL=https://YOUR-9router-or-provider/v1
# --- Telegram ---
TELEGRAM_BOT_TOKEN=PUT_BOT_TOKEN
TELEGRAM_ALLOWED_USERS=PUT_YOUR_USER_ID
HERMES_HOME=$HERMES_HOME
HERMES_PORTABLE=true
EOF
fi
if [ ! -f "$HERMES_HOME/config.yaml" ]; then
cat > "$HERMES_HOME/config.yaml" <<EOF
model:
  provider: "custom"
  base_url: "https://YOUR-9router-or-provider/v1"
  api_key: "PUT_YOUR_KEY"
  model: "cc/claude-sonnet-4-6"
toolsets:
  - hermes-cli
  - mcp
gateway:
  platforms:
    telegram:
      enabled: true
mcp_servers:
  android:
    name: "android"
    enabled: true
    command: "python"
    args: ["-m", "android_mcp", "--wifi", "127.0.0.1:5555"]
    transport: "stdio"
EOF
fi

ok "Install complete."
echo ""
echo "Next:"
echo "  1. Edit $HERMES_HOME/.env and config.yaml (keys + provider URL)"
echo "  2. Enable Wireless debugging, then: bash start-termux.sh"
