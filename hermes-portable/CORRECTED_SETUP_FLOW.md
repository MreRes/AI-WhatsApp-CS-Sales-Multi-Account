# Hermes Portable - CORRECTED Setup Flow

## ✅ The Problem (Fixed)

Previously, `INSTALL.bat` tried to setup Hermes before 9router API key was ready:
```
WRONG FLOW:
├─ Build 9router ✓
├─ Install Hermes ✗ (no API key yet)
├─ Start services ✗ (Hermes can't call 9router)
└─ Fail to connect
```

**Now fixed!** The correct flow is:
```
CORRECT FLOW:
├─ Build 9router ✓
├─ START 9router in setup
├─ Wait for 9router ready
├─ USER configures provider in dashboard
├─ USER copies API key
├─ Setup Hermes WITH API key ✓
├─ Generate config.yaml (Hermes → 9router)
├─ START.bat launches both services
└─ Success!
```

---

## 🚀 New Installation Steps

### Step 1: Run INSTALL.bat (once)

```bash
cd D:\hermes-agent-main\hermes-portable
INSTALL.bat
```

Progress:
- ✅ Step 1/6: Download Node.js, uv, cloudflared
- ✅ Step 2/6: Create Python venv
- ✅ Step 3/6: Build 9router (npm install + npm run build)
- ✅ Step 4/6: Install Hermes + MCPs
- **🟡 Step 5/6: Interactive Setup Wizard** ← YOU ARE HERE
- ⏳ Step 6/6: Mark installed

### Step 2: During Step 5/6 - Setup Wizard

When the wizard starts:

#### Phase 1: 9router boot
- Wizard automatically starts 9router on port 20128
- Waits for it to be healthy (~30-60 seconds)
- Shows: `[OK] 9router is healthy!`

#### Phase 2: Configure Provider
Wizard will prompt you:

```
1. Open in your browser: http://localhost:20128

2. In 9router dashboard:
   a) Go to "Providers" or "Configuration" menu
   b) Add a provider (OpenRouter, Anthropic, Google, etc.)
   c) Enter your API key for that provider

3. Generate API key for Hermes:
   a) Go to "API Keys" section
   b) Create new API key
   c) Copy the key (usually starts with 'sk-')

Press Enter when you have copied the 9router API key
```

**Do this now:**
1. Open browser → http://localhost:20128
2. Login (if needed)
3. Setup provider (add one LLM provider)
4. Generate API key
5. Copy it
6. Come back and paste in the prompt

#### Phase 3: Collect Credentials
Wizard will ask:
```
Paste the API key from 9router dashboard
[paste here]

Telegram bot token (optional, press Enter to skip)
[leave blank for now]
```

Paste the API key you copied. This is the critical step!

#### Phase 4: Generate Configuration
Wizard will automatically:
- ✅ Create `data/.env` with API key
- ✅ Create `data/config.yaml` pointing Hermes to 9router
- ✅ Create `services/9router/.env` with secrets
- ✅ Stop 9router (will restart via START.bat)

### Step 3: After Setup Complete

Run:
```bash
START.bat
```

This will:
- ✅ Start 9router (port 20128)
- ✅ Start Hermes (port 9119, uses API key to call 9router)
- ✅ Start Cloudflare tunnels (public URLs)
- ✅ Send Telegram notification (if configured)

---

## 📋 File Changes Summary

### New/Updated Files
| File | Purpose | Status |
|------|---------|--------|
| `setup-portable.ps1` | **CORRECTED** - 9router setup + API key collection | ✅ Updated |
| `installer/install.ps1` | Updated Step 5 to use corrected wizard | ✅ Updated |
| `config-setup.ps1` | (Unchanged) - Manage Telegram/Discord/Slack after setup | ✅ Ready |

### Architecture (Unchanged)
```
9router (port 20128) ← Hermes calls this
  ↓
  Provider: OpenRouter / Anthropic / Google
  ↓
  API Key: sk-xxxxx

Hermes (port 9119)
  ↓
  Uses API key to call 9router for LLM
```

---

## 🎯 Quick Test

After `INSTALL.bat` completes with setup wizard:

```bash
# Start services
START.bat

# Test in browser
http://localhost:20128        # 9router dashboard
http://localhost:9119         # Hermes frontend

# Check Telegram (if configured)
Should get message: "Hermes Portable is ONLINE!"
```

---

## 🐛 Troubleshooting

### "9router failed to start"
Check the log file printed in error message:
```
data/logs/9router-setup.log
```

**Common causes:**
- Port 20128 already in use
- npm install not completed
- Node.js not found

### "API key cannot be empty"
You need to:
1. Go to http://localhost:20128
2. Configure a provider (OpenRouter, Anthropic, etc.)
3. Generate API key
4. Paste it when prompted

### "Hermes can't reach 9router"
- Check `data/config.yaml` has `base_url: "http://localhost:20128"`
- Check 9router is running: `http://localhost:20128` in browser
- Check firewall isn't blocking port 20128

---

## ✅ What's Different from Before

| Before | Now |
|--------|-----|
| Setup wizard was skipped | Setup wizard required + interactive |
| 9router not started during install | 9router started + waiting for ready |
| API key collected later (if at all) | API key collected during setup |
| Hermes installed without API key | Hermes config generated WITH API key |
| START.bat would fail | START.bat works correctly |

---

## 📚 Next Steps (Phase 2)

After MVP validation:
- Add T-Dongle S3 USB auto-trigger
- Add macOS/Linux support
- Add ngrok as tunnel alternative
- Docker container support

For now: **Just get MVP working!** 🎉
