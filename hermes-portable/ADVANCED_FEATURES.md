# Hermes Portable — Advanced Features (Watchdog, Named Tunnel, Termux, Observability)

## 1. Watchdog / auto-restart  ✅ built-in
`orchestrator/watchdog.ps1` — launched automatically by `START.bat`, killed by `STOP.bat`.
- Every 15s health-checks 9router (:20128), Hermes (:9119), gateway (PID).
- **Restarts any service that dies** (rate-limited: max 5 restarts / 5 min / service).
- Re-applies the sql.js WASM fix on 9router restart.
- Writes `data/health.json` and `data/logs/watchdog.log`.
- STOP kills the watchdog FIRST so it doesn't fight shutdown.

Verified: kill 9router → back up within ~15s automatically.

## 2. Observability  ✅ built-in
- `STATUS.bat` → live health: 9router/Hermes probes, tracked PIDs (alive/dead),
  watchdog snapshot, public URLs.
- `data/health.json` → machine-readable health (updated every watchdog cycle).
- `data/logs/watchdog.log` → restart event history.

## 3. Named tunnel (stable URL + uptime)  ✅ optional setup
Replaces the random/ephemeral `trycloudflare` URLs with a permanent one.

Requires a **free Cloudflare account** + a domain added to Cloudflare.
```powershell
powershell -ExecutionPolicy Bypass -File tunnel\named-tunnel-setup.ps1 -Domain yourdomain.com
```
This logs in, creates a tunnel, routes DNS, and writes `data/cloudflared/config.yml`:
```
hermes.yourdomain.com  -> Hermes  (9119)
router.yourdomain.com  -> 9router (20128)
```
After setup, `START.bat` **auto-detects** the named tunnel and uses it (same URL
every time, Cloudflare-backed uptime). Without it, START falls back to quick tunnels.

## 4. Termux / mobile (run Hermes ON the phone)  ✅ scripts ready
Run the agent on Android, controlling the phone itself via Android-MCP over
(wireless) ADB. Copy the `termux/` folder to the phone (or `git clone`), then in Termux:
```bash
bash termux/install-termux.sh          # python, nodejs, hermes[termux], android-mcp
# edit ~/.hermes-portable/.env + config.yaml (keys + provider URL)
bash termux/start-termux.sh            # adb self-connect + gateway
```
Notes:
- Needs **Android 11+ Wireless debugging** ON (or root). Set `ADB_PORT` to the
  port shown under Settings > Developer options > Wireless debugging.
- `USE_9ROUTER=1 bash install-termux.sh` to also run 9router locally on the phone;
  otherwise point `config.yaml` at a remote 9router/provider.
- Install `termux-api` for the wake-lock (keeps the phone session alive).

---

## Quick reference
| Action | Command |
|--------|---------|
| Start everything (+watchdog +keep-awake) | `START.bat` |
| Stop everything (watchdog first) | `STOP.bat` |
| Check health | `STATUS.bat` |
| Stable public URL | `tunnel\named-tunnel-setup.ps1 -Domain ...` |
| Run on Android | `termux/install-termux.sh` then `start-termux.sh` |
