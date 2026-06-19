# Hermes Portable — Setup Guide

A single plug-and-play bundle that runs **two services** and exposes them to the internet:

- **9router** — LLM API gateway (port `20128`)
- **Hermes** — AI agent + Windows-MCP desktop automation (frontend port `9119`)
- **Cloudflare tunnels** — public HTTPS URLs for both services (no account needed)

Hermes uses 9router as its LLM `base_url`, so all model traffic flows through 9router.

---

## Requirements

- Windows 10 / 11 (x64)
- ~5 GB free disk space
- Internet connection (for first install + tunnels)
- Python 3.11+ installed ([python.org](https://www.python.org/downloads/))

Everything else (Node.js, cloudflared, Python deps) is **downloaded automatically** by the installer.

---

## Quick Start

### 1. Install once

Double-click **`INSTALL.bat`**.

This will:
1. Download portable **Node.js** → `runtime/node/`
2. Install **uv** + create a Python venv → `data/.venv/`
3. Download **cloudflared.exe** → `runtime/bin/`
4. Build **9router** (`npm install` + `npm run build`)
5. Install **Hermes** (`uv pip install .[portable-windows]`)
6. Run the **setup wizard** (collects API key / Telegram, generates configs, auto-generates 9router secrets)
7. Write `data/.installed` flag

> Runs once. Re-running is safe (idempotent) — pass `-Force` to rebuild.

### 2. Start every time

Double-click **`START.bat`**.

This boots everything in order:
```
9router (:20128)  ->  wait healthy
Hermes  (:9119)   ->  wait healthy
Cloudflare tunnel -> 9router   (public URL)
Cloudflare tunnel -> Hermes    (public URL)
↓ (if Telegram configured)
Telegram notification → sends public URLs to your chat
```

You'll see a summary on screen like:
```
Hermes Portable is ONLINE!

9router (LLM gateway):
  Local:  http://localhost:20128
  Public: https://abc-def.trycloudflare.com

Hermes (AI agent):
  Local:  http://localhost:9119
  Public: https://xyz-uvw.trycloudflare.com
```

**Telegram Notification:** If you configured Telegram during setup, the bot will automatically send you a message with both URLs. Check your Telegram chat — you'll get:

```
Hermes Portable is ONLINE!

9router (LLM gateway):
  Local:  http://localhost:20128
  Public: https://abc-def.trycloudflare.com

Hermes (AI agent):
  Local:  http://localhost:9119
  Public: https://xyz-uvw.trycloudflare.com

Ready for commands!
```

Public URLs are also saved to `data/tunnel_urls.txt` for manual access.

### 3. Stop

Double-click **`STOP.bat`** (terminates 9router, Hermes, and both tunnels).

---

## Configuration: Three Tiers

All credentials stored in **one file**: `data/.env` (MASTER CREDENTIALS FILE)

### Tier 1: Essentials (Setup wizard — INSTALL.bat)

Done automatically during setup:

| Config | Auto-Generated? | How |
|--------|-----------------|-----|
| `HERMES_API_KEY` | ❌ User input (or demo) | Wizard asks, saved to `.env` |
| `HERMES_TELEGRAM_TOKEN` | ❌ User input (or skip) | Wizard asks, saved to `.env` |
| `HERMES_TELEGRAM_CHAT_ID` | ❌ User input (or skip) | Wizard asks, saved to `.env` |
| `JWT_SECRET` (9router) | ✅ Auto-generated | Random secret for 9router security |
| `INITIAL_PASSWORD` (9router) | ✅ Auto-generated | Printed during setup — **SAVE THIS!** |
| `HERMES_BASE_URL` | ✅ Auto-set | Hardcoded to `http://localhost:20128` |

### Tier 2: Messaging Platforms (Optional — config-setup.bat)

Add AFTER install if you want to control Hermes via messaging:

**Run anytime:**
```
config-setup.bat
```

Then select from menu:
- **[1] Telegram** — Already done? Update token/chat ID
- **[2] WhatsApp** — Twilio account (phone control)
- **[3] Discord** — Discord bot token (Discord commands)
- **[4] Slack** — Slack bot token (Slack integration)

Or skip all — Hermes works fine with just LLM.

### Tier 3: LLM Providers (9router Dashboard)

**Only place to configure LLM provider keys:**

```
1. Open: http://localhost:20128
2. Login: admin / [password from setup]
3. Click menu: "Providers"
4. Add provider: OpenRouter / Anthropic / Google / etc
5. Paste API key from provider (get from https://openrouter.ai, https://console.anthropic.com, etc)
6. Click "Save"
7. Done! Hermes now can call LLM
```

---

## Summary: Easy Credential Management

| When | What | Where | How |
|------|------|-------|-----|
| **INSTALL.bat** | Tier 1 (essentials) | Wizard prompts | Interactive or auto |
| **After install** | Tier 2 (messaging) | config-setup.bat | Menu-driven tool |
| **START.bat** | Tier 3 (LLM provider) | 9router dashboard | Web UI at localhost:20128 |

**All credentials persist in:** `data/.env` (backup this file!)

---

## Folder Layout

```
hermes-portable/
├── INSTALL.bat              <- run once
├── START.bat                <- run to launch everything
├── STOP.bat                 <- run to stop
├── setup-portable.ps1       <- setup wizard (called by installer)
├── installer/
│   ├── install.ps1          <- master installer
│   └── download_runtimes.ps1
├── orchestrator/
│   ├── start_all.ps1        <- boot sequence
│   ├── stop_all.ps1
│   └── healthcheck.ps1
├── runtime/                 <- auto-populated
│   ├── node/                <- portable Node.js
│   └── bin/cloudflared.exe
├── services/
│   ├── 9router/             <- 9router source (copy here)
│   └── hermes/              <- hermes core (copy here)
├── embedded-mcps/
│   └── windows_mcp/         <- Windows-MCP source (copy here)
├── portable-config/         <- config templates
└── data/                    <- persistent state
    ├── config.yaml
    ├── .env
    ├── .installed
    ├── pids.txt
    ├── tunnel_urls.txt
    └── logs/
```

---

## Before First Install — Place the Sources

The installer expects these source trees to be present:

| Copy from | Into |
|-----------|------|
| `9router-master/` | `services/9router/` |
| hermes core | `services/hermes/` |
| `Windows-MCP/src/windows_mcp/` | `embedded-mcps/windows_mcp/` |

(If you received a pre-bundled package, these are already in place.)

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Python not found" | Install Python 3.11+ and re-run INSTALL.bat |
| 9router won't start | Check `data/logs/9router.err.log` |
| Hermes won't start | Check `data/logs/hermes.err.log` |
| No tunnel URL | Check `data/logs/cloudflared-*.log`; ensure internet works |
| Defender quarantines files | Run setup as Admin and accept the exclusion prompt |
| Port 20128 / 9119 in use | Stop the conflicting app, or edit ports in configs |
| Drive letter changed (USB) | Works automatically — paths are relative to bundle root |

### Useful logs (under `data/logs/`)
- `9router.log` / `9router.err.log`
- `hermes.log` / `hermes.err.log`
- `cloudflared-9router.log` / `cloudflared-hermes.log`

---

## Reinstall / Reset

```
REM Full reinstall (rebuild everything)
INSTALL.bat -Force

REM Reset config only — delete then re-run setup
del data\config.yaml data\.env
setup-portable.ps1
```

---

## Phase 2 (Roadmap)
- ngrok as an alternative tunnel
- macOS / Linux / Docker variants
- Additional MCPs (macOS-MCP, Android-MCP) and Use frameworks
- Single-exe launcher (Nuitka)
