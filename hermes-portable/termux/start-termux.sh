#!/data/data/com.termux/files/usr/bin/bash
################################################################################
# Hermes Portable — Termux launcher (run ON the phone, inside Termux)
# Connects ADB to the device (self-control), optionally starts local 9router,
# then runs the Hermes gateway. Keeps the phone's Termux session awake.
################################################################################
set -e

log() { printf '\033[0;36m==>\033[0m %s\n' "$1"; }
ok()  { printf '\033[0;32m[OK]\033[0m %s\n' "$1"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes-portable}"
export HERMES_HOME HERMES_PORTABLE=true

# Keep Termux alive while running (needs Termux:API: pkg install termux-api)
if command -v termux-wake-lock >/dev/null 2>&1; then termux-wake-lock; ok "wake-lock held"; fi

# 1) Wireless ADB self-connect (Android 11+). Pair once via Developer options;
#    set ADB_PORT to the "Wireless debugging" port shown there (NOT the pair port).
ADB_HOST="${ADB_HOST:-127.0.0.1}"
ADB_PORT="${ADB_PORT:-5555}"
log "ADB connect $ADB_HOST:$ADB_PORT (self-control)..."
adb start-server >/dev/null 2>&1 || true
adb connect "$ADB_HOST:$ADB_PORT" || warn "adb connect failed — enable Wireless debugging & set ADB_PORT"
adb devices

# 2) Optional local 9router
if [ -f "$HERMES_HOME/9router-app/node_modules/9router/cli.js" ]; then
    log "Starting local 9router (port 20128)..."
    node "$HERMES_HOME/9router-app/node_modules/9router/cli.js" -n -l -p 20128 > "$HERMES_HOME/9router.log" 2>&1 &
    for i in $(seq 1 20); do curl -sf http://localhost:20128 >/dev/null 2>&1 && { ok "9router up"; break; }; sleep 1; done
fi

# 3) Hermes gateway (Telegram bot + Android-MCP)
log "Starting Hermes gateway..."
hermes gateway run --accept-hooks > "$HERMES_HOME/gateway.log" 2>&1 &
GW=$!
ok "Hermes gateway started (PID $GW)"

echo ""
ok "Hermes Portable (Termux) running. Logs in $HERMES_HOME/"
echo "  Stop: kill $GW ; pkill -f 9router ; termux-wake-unlock"
echo "  Test: message your Telegram bot, e.g. 'buka pengaturan' (controls THIS phone via Android-MCP)"
wait $GW
