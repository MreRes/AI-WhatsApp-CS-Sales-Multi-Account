#Requires -Version 5.1
<#
.SYNOPSIS
    Hermes Portable Setup Wizard - CORRECTED FLOW.

.DESCRIPTION
    Two-phase setup:
    Phase 1: Start 9router, wait for ready
    Phase 2: Prompt user to setup provider in 9router dashboard, collect API key, setup Hermes

    Generates:
    - data/.env (Hermes + 9router credentials)
    - data/config.yaml (Hermes config pointing to 9router)
    - services/9router/.env (9router secrets)

.PARAMETER Mode
    'Auto' (demo defaults) or 'Interactive' (prompts). Default: Interactive.
#>

param(
    [ValidateSet('Auto', 'Interactive')]
    [string]$Mode = 'Interactive',

    [string]$AutoApi = $env:HERMES_API_KEY,
    [string]$AutoTelegram = $env:HERMES_TELEGRAM_TOKEN
)

$ErrorActionPreference = 'Stop'

$ColorSuccess = 'Green'; $ColorWarn = 'Yellow'; $ColorError = 'Red'
$ColorInfo = 'Cyan'; $ColorQuestion = 'Magenta'

function Write-Header { Write-Host "=============================================" -ForegroundColor $ColorInfo }
function Write-Success { Write-Host "[OK] $args" -ForegroundColor $ColorSuccess }
function Write-Warn { Write-Host "[!] $args" -ForegroundColor $ColorWarn }
function Write-Err2 { Write-Host "[X] $args" -ForegroundColor $ColorError }
function Write-Info { Write-Host "[*] $args" -ForegroundColor $ColorInfo }

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot = $ScriptDir  # This is the bundle root
$RuntimeDir = Join-Path $BundleRoot 'runtime'
$NodeDir = Join-Path $RuntimeDir 'node'
$BinDir = Join-Path $RuntimeDir 'bin'
$DataDir = Join-Path $BundleRoot 'data'
$ConfigDir = Join-Path $BundleRoot 'portable-config'
$ConfigFile = Join-Path $DataDir 'config.yaml'
$EnvFile = Join-Path $DataDir '.env'
$Router9Dir = Join-Path $BundleRoot 'services\9router'
$Router9EnvFile = Join-Path $Router9Dir '.env'
$Router9DataDir = Join-Path $DataDir '9router'

# 9router is the official npm package under runtime/9router-app
$Router9AppDir = Join-Path $RuntimeDir '9router-app'
$Router9Cli    = Join-Path $Router9AppDir 'node_modules\9router\cli.js'

$NodeExe = Join-Path $NodeDir 'node.exe'
$NpmCmd = Join-Path $NodeDir 'npm.cmd'

function New-RandomSecret {
    param([int]$Length = 43)
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
    return ([Convert]::ToBase64String($bytes).Substring(0, $Length) -replace '[/+=]', 'x')
}

Write-Host ""
Write-Host "Hermes Portable Setup Wizard" -ForegroundColor $ColorInfo
Write-Header

# Pre-flight
Write-Host ""
Write-Info "Running pre-flight checks..."

if (!(Test-Path $NodeExe)) {
    Write-Err2 "Node.js not found at $NodeExe"
    Write-Warn "Run INSTALL.bat first to download runtimes."
    Read-Host "Press Enter to exit"
    exit 1
}

if (!(Test-Path $Router9Cli)) {
    Write-Err2 "9router npm package not found at $Router9Cli"
    Write-Warn "Run INSTALL.bat first to install 9router."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Success "Prerequisites OK"

# Ensure data dir
if (!(Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
if (!(Test-Path (Join-Path $DataDir 'logs'))) { New-Item -ItemType Directory -Path (Join-Path $DataDir 'logs') -Force | Out-Null }

# =========================================================================
# PHASE 1: Start 9router and wait for ready
# =========================================================================
Write-Host ""
Write-Host "PHASE 1: Start 9router" -ForegroundColor $ColorInfo
Write-Header

Write-Info "Starting 9router on port 20128..."
$Router9LogFile = Join-Path $DataDir 'logs\9router-setup.log'

try {
    # Launch the official 9router CLI (prebuilt, -n no-browser, -l logs).
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $NodeExe
    $psi.Arguments = "`"$Router9Cli`" -n -l -p 20128"
    $psi.WorkingDirectory = $Router9AppDir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.Environment['NODE_ENV'] = 'production'
    $psi.Environment['PORT'] = '20128'
    [System.Diagnostics.Process]::Start($psi) | Out-Null
    Start-Sleep -Seconds 3
    Write-Success "9router process started"
} catch {
    Write-Err2 "Failed to start 9router: $_"
    exit 1
}

# Wait for port 20128
Write-Info "Waiting for 9router health check (timeout 120 seconds)..."
Write-Info "Logs: $Router9LogFile"
$ready = $false
for ($i = 0; $i -lt 120; $i++) {
    try {
        $response = Invoke-WebRequest -Uri 'http://localhost:20128' -UseBasicParsing -ErrorAction SilentlyContinue -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            Write-Success "9router is healthy!"
            $ready = $true
            break
        }
    } catch {
        # Not ready yet, keep waiting
    }
    Write-Host '.' -NoNewline -ForegroundColor $ColorWarn
    Start-Sleep -Seconds 1
}
Write-Host ""

if (!$ready) {
    Write-Err2 "9router failed to start after 120 seconds"
    Write-Warn "Port 20128 not responding. Check logs:"
    Write-Warn "Log file: $Router9LogFile"
    Write-Warn ""
    Write-Warn "Last 30 lines of output:"
    if (Test-Path $Router9LogFile) {
        Get-Content $Router9LogFile | Select-Object -Last 30 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Warn "  (log file not found)"
    }
    Write-Warn ""
    Write-Warn "Common fixes:"
    Write-Warn "  1. Port 20128 already in use: netstat -ano | find ':20128'"
    Write-Warn "  2. npm build incomplete: check 'npm run build' output"
    Write-Warn "  3. Module missing: try 'npm install' manually in $Router9Dir"
    exit 1
}

# =========================================================================
# PHASE 2: Collect API key from 9router
# =========================================================================
Write-Host ""
Write-Host "PHASE 2: Setup 9router Provider & Collect API Key" -ForegroundColor $ColorInfo
Write-Header

$ApiKey = ''
$TelegramToken = ''
$TelegramChatId = ''

if ($Mode -eq 'Auto') {
    Write-Info "Automatic mode (using demo API key)"
    $ApiKey = 'sk-auto-demo-key-replace-with-real-key'
    Write-Warn "IMPORTANT: This is a demo key. Go to http://localhost:20128 to configure real providers!"
} else {
    Write-Host ""
    Write-Host "MANUAL SETUP: Configure 9router Provider" -ForegroundColor $ColorQuestion
    Write-Host ""
    Write-Host "1. Open in your browser: http://localhost:20128" -ForegroundColor $ColorWarn
    Write-Host ""
    Write-Host "2. In 9router dashboard:" -ForegroundColor Gray
    Write-Host "   a) Go to 'Providers' or 'Configuration' menu" -ForegroundColor Gray
    Write-Host "   b) Add a provider (e.g., OpenRouter, Anthropic, Google, etc.)" -ForegroundColor Gray
    Write-Host "   c) Enter your API key for that provider" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Generate API key for Hermes:" -ForegroundColor Gray
    Write-Host "   a) Go to 'API Keys' section in 9router" -ForegroundColor Gray
    Write-Host "   b) Create new API key" -ForegroundColor Gray
    Write-Host "   c) Copy the key (usually starts with 'sk-' or similar)" -ForegroundColor Gray
    Write-Host ""

    Read-Host "Press Enter when you have copied the 9router API key"

    Write-Host ""
    $ApiKey = Read-Host "Paste the API key from 9router dashboard"
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        Write-Err2 "API key cannot be empty!"
        exit 1
    }
    Write-Success "API key saved"

    Write-Host ""
    Write-Host "Optional: Configure Telegram for remote control" -ForegroundColor $ColorQuestion
    $TelegramToken = Read-Host "Telegram bot token (or press Enter to skip)"
    if (![string]::IsNullOrEmpty($TelegramToken)) {
        $TelegramChatId = Read-Host "Telegram chat ID (get from https://t.me/userinfobot)"
        Write-Success "Telegram configured"
    }
}

# =========================================================================
# Generate configuration files
# =========================================================================
Write-Host ""
Write-Host "Generating Configuration" -ForegroundColor $ColorInfo
Write-Header

# Generate 9router .env with auto-generated secrets
Write-Info "Configuring 9router secrets..."
if (Test-Path $Router9Dir) {
    $JwtSecret = New-RandomSecret -Length 43
    $InitialPassword = New-RandomSecret -Length 16

    if (Test-Path $Router9EnvFile) {
        $existing = Get-Content $Router9EnvFile -Raw
        if ($existing -match 'JWT_SECRET=(.+)$') { $JwtSecret = $Matches[1].Trim() }
        if ($existing -match 'INITIAL_PASSWORD=(.+)$') { $InitialPassword = $Matches[1].Trim() }
        Write-Info "Reusing existing 9router secrets"
    }
    if (!(Test-Path $Router9DataDir)) { New-Item -ItemType Directory -Force -Path $Router9DataDir | Out-Null }

    $Router9Env = @"
# 9router (Service 1) - Auto-generated secrets
JWT_SECRET=$JwtSecret
INITIAL_PASSWORD=$InitialPassword
PORT=20128
NODE_ENV=production
DATA_DIR=$Router9DataDir
BASE_URL=http://localhost:20128
NEXT_PUBLIC_BASE_URL=http://localhost:20128
"@
    Set-Content -Path $Router9EnvFile -Value $Router9Env -Encoding UTF8
    Write-Success "Created 9router .env"
    Write-Warn "9router dashboard password: $InitialPassword"
}

# Generate Hermes .env
Write-Info "Creating Hermes environment file..."
$TelegramEnabled = if ([string]::IsNullOrEmpty($TelegramToken)) { 'false' } else { 'true' }

$EnvContent = @"
# Hermes Portable Environment - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
HERMES_API_KEY=$ApiKey
HERMES_BASE_URL=http://localhost:20128
HERMES_HOME=$DataDir
HERMES_PORTABLE=true
HERMES_LOG_LEVEL=INFO
NODE_ENV=production

# ------ LLM via 9router (WORKING wiring) ------
# Hermes picks the 'openrouter' provider when OPENROUTER_API_KEY is set, and the
# openrouter client honours OPENROUTER_BASE_URL. Pointed at 9router so all calls
# flow Hermes -> 9router -> upstream. Set config.yaml `model:` to an id 9router
# serves (http://localhost:20128 -> Models, e.g. cc/claude-sonnet-4-6).
# Routing is driven by config.yaml's `model:` dict (provider/base_url/api_key),
# so no OPENROUTER_*/OPENAI_* vars are needed here.

# ------ Telegram gateway ------
# IMPORTANT: the messaging gateway reads TELEGRAM_BOT_TOKEN and
# TELEGRAM_ALLOWED_USERS (NOT the HERMES_TELEGRAM_* names). Without the
# allowlist, every user is denied. Set TELEGRAM_ALLOWED_USERS to your numeric
# Telegram user id (from @userinfobot).
TELEGRAM_BOT_TOKEN=$TelegramToken
TELEGRAM_ALLOWED_USERS=$TelegramChatId

# Kept for wizard display / backward-compat (not read by the gateway):
HERMES_TELEGRAM_TOKEN=$TelegramToken
HERMES_TELEGRAM_CHAT_ID=$TelegramChatId
"@
Set-Content -Path $EnvFile -Value $EnvContent -Encoding UTF8
Write-Success "Created .env at $EnvFile"

# Generate Hermes config.yaml using the REAL Hermes schema.
# Hermes routes the primary model through a custom OpenAI-compatible endpoint
# defined as a `model:` DICT (provider/base_url/api_key/model). This is the
# proper "custom" wiring - the api_key lives here, so no OPENROUTER_*/OPENAI_*
# env vars are involved. base_url points at 9router's /v1.
Write-Info "Creating Hermes config file..."
$UserProfile = $env:USERPROFILE  # e.g. C:\Users\USER
$ConfigYaml = @"
# Hermes Portable Config - generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Custom OpenAI-compatible model via 9router.
#   provider : "custom" (generic OpenAI-compatible client)
#   base_url : 9router's local OpenAI endpoint
#   api_key  : your 9router API key
#   model    : an id 9router serves (http://localhost:20128 -> Models),
#              e.g. cc/claude-sonnet-4-6, cx/gpt-5.4-mini
model:
  provider: "custom"
  base_url: "http://localhost:20128/v1"
  api_key: "$ApiKey"
  model: "cc/claude-sonnet-4-6"

# Toolsets loaded for the agent (ALL enabled).
#   portable: send_file/screenshot/webcam/mic/clipboard/screen_monitor
#   web+search+browser: internet research & browsing
#   memory: persistent memory across sessions
#   cronjob: scheduled / proactive tasks
#   tts: voice replies   | vision/video: media understanding
#   todo/kanban: task mgmt | delegation: sub-agents | skills: skill library
# Heavy backends (voice STT/whisper, browser engine) lazy-install on first use.
toolsets:
  - hermes-cli
  - portable
  - web
  - search
  - browser
  - vision
  - video
  - terminal
  - memory
  - cronjob
  - tts
  - todo
  - kanban
  - delegation
  - skills

memory:
  enabled: true

cron:
  enabled: true

# Messaging gateway platforms (Telegram/Discord/etc.) + file delivery rules.
gateway:
  platforms:
    telegram:
      enabled: $TelegramEnabled
  # Folders the agent may pull files from to send as native attachments.
  # System paths (~/.ssh, ~/.aws, C:\Windows, etc.) stay blocked regardless.
  # Add more drives/dirs here (e.g. "D:\\", "E:\\Projects") as you need.
  media_delivery_allow_dirs:
$(((Get-PSDrive -PSProvider FileSystem).Root | ForEach-Object { "    - `"$($_ -replace '\\','/')`"" }) -join "`n")
  # Trust files created in the last 5 minutes (screenshots, exports, downloads)
  # so the agent can send freshly-produced files without listing every dir.
  trust_recent_files: true
  trust_recent_files_seconds: 300

# Embedded MCP servers (desktop/device automation).
# windows MCP provides the Screenshot tool used for screen capture/streaming.
mcp_servers:
  windows:
    name: "windows"
    enabled: true
    command: "python"
    args: ["-m", "windows_mcp", "serve"]
    transport: "stdio"

portable:
  enabled: true
"@
Set-Content -Path $ConfigFile -Value $ConfigYaml -Encoding UTF8
Write-Success "Created config.yaml at $ConfigFile"

# =========================================================================
# Cleanup: Stop 9router (will be restarted by START.bat)
# =========================================================================
Write-Host ""
Write-Info "Stopping 9router (will restart via START.bat)..."
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Success "9router stopped for now"

# =========================================================================
# Summary
# =========================================================================
Write-Host ""
Write-Host "Setup Complete!" -ForegroundColor $ColorSuccess
Write-Header
Write-Host ""
Write-Host "Summary:" -ForegroundColor $ColorInfo
Write-Host "  Bundle root:    $BundleRoot"
Write-Host "  Data directory: $DataDir"
Write-Host "  Hermes config:  $ConfigFile"
Write-Host "  Hermes env:     $EnvFile"
Write-Host "  9router env:    $Router9EnvFile"
Write-Host ""
if (![string]::IsNullOrEmpty($TelegramToken)) {
    Write-Host "  Telegram:       Enabled" -ForegroundColor $ColorSuccess
} else {
    Write-Host "  Telegram:       Disabled" -ForegroundColor $ColorWarn
}
Write-Host ""
Write-Host "NEXT STEP: Run START.bat to launch Hermes + 9router" -ForegroundColor $ColorSuccess
Write-Host ""

if ($Mode -eq 'Interactive') { Read-Host "Press Enter to exit" }
