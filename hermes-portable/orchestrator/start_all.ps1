#Requires -Version 5.1
<#
.SYNOPSIS
    Start all hermes-portable services (ONE start service).

.DESCRIPTION
    Boot sequence:
      1. Start 9router (Node, port 20128)
      2. Wait for 9router health
      3. Start Hermes gateway (Python, base_url -> 9router, frontend port 9119)
      4. Wait for Hermes health
      5. Start cloudflared tunnel -> 9router (:20128)
      6. Start cloudflared tunnel -> Hermes frontend (:9119)
      7. Capture public URLs, save to data/tunnel_urls.txt + pids.txt
      8. Print summary

.PARAMETER NoTunnel
    Skip cloudflare tunnels (local-only mode).
#>

param(
    [switch]$NoTunnel
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$OrchestratorDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot   = Split-Path -Parent $OrchestratorDir
$RuntimeDir   = Join-Path $BundleRoot "runtime"
$NodeDir      = Join-Path $RuntimeDir "node"
$BinDir       = Join-Path $RuntimeDir "bin"
$ServicesDir  = Join-Path $BundleRoot "services"
$Router9Dir   = Join-Path $ServicesDir "9router"
$HermesDir    = Join-Path $ServicesDir "hermes"
$DataDir      = Join-Path $BundleRoot "data"
$VenvDir      = Join-Path $DataDir ".venv"
$LogsDir      = Join-Path $DataDir "logs"
$InstalledFlag = Join-Path $DataDir ".installed"

$NodeExe   = Join-Path $NodeDir "node.exe"
$NpmCmd    = Join-Path $NodeDir "npm.cmd"
$PyExe     = Join-Path $VenvDir "Scripts\python.exe"
# Console script name varies by install: prefer hermes.exe, fall back to
# hermes-agent.exe (the package's canonical entry point).
$HermesExe = Join-Path $VenvDir "Scripts\hermes.exe"
if (-not (Test-Path $HermesExe)) { $HermesExe = Join-Path $VenvDir "Scripts\hermes-agent.exe" }

# --- Relocation guard: keep the venv portable across drive letters / folders -----------
# The venv was created with uv --relocatable (Scripts resolve the interpreter relatively),
# and site-packages now uses a relative path loader (no baked D:\). The one remaining
# absolute reference is pyvenv.cfg `home =`, which points at the bundled base Python. If
# the whole bundle was moved (e.g. D:\ -> E:\), rewrite `home` to the current location so
# the interpreter still finds its stdlib. Cheap text fix; no venv rebuild needed.
$PyVenvCfg = Join-Path $VenvDir "pyvenv.cfg"
$PyRoot    = Join-Path $RuntimeDir "python"
if ((Test-Path $PyVenvCfg) -and (Test-Path $PyRoot)) {
    try {
        $cfg = Get-Content $PyVenvCfg -ErrorAction Stop
        $cur = (($cfg | Where-Object { $_ -match '^\s*home\s*=' }) -replace '^\s*home\s*=\s*', '').Trim()
        if ($cur) {
            # PRESERVE the exact python folder name (e.g. cpython-3.13.13-...). runtime\python
            # can hold more than one cpython-* dir, so we must NOT guess/pick the first — that
            # could silently switch interpreter versions. We only relocate the PATH PREFIX to
            # this bundle's current location, keeping the same leaf folder.
            $leaf = Split-Path $cur -Leaf
            $expected = Join-Path $PyRoot $leaf
            # Fallback only if the preserved folder is genuinely absent at the new location.
            if (-not (Test-Path $expected)) {
                $cp = Get-ChildItem $PyRoot -Directory -Filter "cpython-*" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($cp) { $expected = $cp.FullName }
            }
            if ((Test-Path $expected) -and ($cur -ne $expected)) {
                ($cfg | ForEach-Object { if ($_ -match '^\s*home\s*=') { "home = $expected" } else { $_ } }) |
                    Set-Content $PyVenvCfg -Encoding ascii
                Write-Host "[OK] Relocation guard: pyvenv.cfg home -> $expected" -ForegroundColor Green
            }
        }
    } catch { Write-Host "[!] Relocation guard skipped: $_" -ForegroundColor Yellow }
}

# 9router is installed as the official npm package (prebuilt, auto-updating)
# under runtime/9router-app. cli.js is its launcher/server entry point.
$Router9AppDir = Join-Path $RuntimeDir "9router-app"
$Router9Cli    = Join-Path $Router9AppDir "node_modules\9router\cli.js"
$CloudflaredExe = Join-Path $BinDir "cloudflared.exe"
$HealthCheck = Join-Path $OrchestratorDir "healthcheck.ps1"

$PidsFile   = Join-Path $DataDir "pids.txt"
$TunnelFile = Join-Path $DataDir "tunnel_urls.txt"

# Ports
$Router9Port = 20128
$HermesPort  = 9119

function Write-Header { param($t) Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }
function Write-Step { Write-Host "==> $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[!] $args" -ForegroundColor Yellow }
function Write-Err  { Write-Host "[X] $args" -ForegroundColor Red }

# Ensure logs dir
if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Force -Path $LogsDir | Out-Null }

# Track PIDs (name=pid lines)
$PidLines = @()

# ---------------------------------------------------------------------------
# Pre-flight: installed?
# ---------------------------------------------------------------------------
if (-not (Test-Path $InstalledFlag)) {
    Write-Warn "Bundle not installed yet. Running installer first..."
    $InstallScript = Join-Path $BundleRoot "installer\install.ps1"
    & $InstallScript
    if (-not (Test-Path $InstalledFlag)) {
        Write-Err "Installation did not complete. Aborting."
        exit 1
    }
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " Starting Hermes Portable" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Prepend the venv Scripts (so MCP subprocesses spawned as "python" use the
# BUNDLE venv python, not a system Python on PATH) and portable ADB bin.
# Without this, `command: python` in mcp_servers resolves to e.g. C:\Python314
# which lacks windows_mcp/android_mcp deps -> MCP crashes ("Connection closed").
$env:PATH = (Join-Path $VenvDir "Scripts") + ";" + (Join-Path $RuntimeDir "bin") + ";" + $env:PATH

# ---------------------------------------------------------------------------
# Step 0: Keep the laptop awake for the whole session.
# Sleep drops the network and kills the tunnel - hold a wake lock (auto-released
# when STOP kills this process). Tracked in pids.txt like every other service.
# ---------------------------------------------------------------------------
$KeepAwakeScript = Join-Path $OrchestratorDir "keep_awake.ps1"
if (Test-Path $KeepAwakeScript) {
    $AwakeProc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", $KeepAwakeScript `
        -PassThru -WindowStyle Hidden
    $PidLines += "keep-awake=$($AwakeProc.Id)"
    Write-OK "Keep-awake lock active (laptop won't sleep while Hermes runs)"
}

# ---------------------------------------------------------------------------
# Step 1: Start 9router
# ---------------------------------------------------------------------------
Write-Header "1/4 Starting 9router (port $Router9Port)"
if (-not (Test-Path $Router9Cli)) {
    Write-Err "9router npm package not found at $Router9Cli"
    Write-Err "Run INSTALL.bat to provision it."
    exit 1
}

$Router9Log = Join-Path $LogsDir "9router.log"
$Router9Err = Join-Path $LogsDir "9router.err.log"

# Best-effort: keep 9router on the latest published version. Non-blocking and
# non-fatal - if offline or the registry is slow, we just run what's installed.
Write-Step "Checking for 9router updates (best-effort)..."
$env:npm_config_cache = Join-Path $DataDir ".npm"
try {
    & $NpmCmd install 9router@latest --prefix $Router9AppDir --no-audit --no-fund --silent 2>$null
    Write-OK "9router is up to date"
} catch {
    Write-Warn "Update check skipped (offline?). Using installed version."
}

# Ensure 9router's sql.js WASM is present (the npm package ships without it, and
# an auto-update above may have reinstalled the incomplete sql.js). Without this
# 9router has no working SQLite driver on Node 22 and returns HTTP 500 on every
# request. Copy from a cached wasm if missing.
$SqlJsWasm = Join-Path $Router9AppDir "node_modules\9router\app\node_modules\sql.js\dist\sql-wasm.wasm"
if ((Test-Path (Split-Path $SqlJsWasm)) -and -not (Test-Path $SqlJsWasm)) {
    $CachedWasm = Join-Path $DataDir "sql-wasm.wasm"
    if (-not (Test-Path $CachedWasm)) {
        # First time: fetch once and cache under data/ for future boots.
        $SqlTmp = Join-Path $DataDir ".sqljs_tmp"
        New-Item -ItemType Directory -Force -Path $SqlTmp | Out-Null
        & $NpmCmd install sql.js@1.14.1 --prefix $SqlTmp --no-audit --no-fund --silent 2>$null
        $src = Join-Path $SqlTmp "node_modules\sql.js\dist\sql-wasm.wasm"
        if (Test-Path $src) { Copy-Item $src $CachedWasm -Force }
        Remove-Item $SqlTmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $CachedWasm) {
        Copy-Item $CachedWasm $SqlJsWasm -Force
        Write-OK "9router SQLite (sql.js WASM) ready"
    }
}

# Launch the official 9router CLI (prebuilt server).
#   -n  no-browser (headless), -l  show logs, -p  port.
# We deliberately DO NOT pass --skip-update so 9router keeps itself current.
$env:NODE_ENV = "production"
$env:PORT = "$Router9Port"
# Portable DB: 9router honors DATA_DIR for its sqlite + secrets (client.js/sqliteRuntime.js/
# updater.js). Point it inside the bundle so provider credentials + the sk- API key persist
# across auto-updates and travel with the USB (instead of %APPDATA%\9router).
$env:DATA_DIR = Join-Path $DataDir "9router"
$Router9Proc = Start-Process -FilePath $NodeExe `
    -ArgumentList $Router9Cli, "-n", "-l", "-p", "$Router9Port" `
    -WorkingDirectory $Router9AppDir -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $Router9Log -RedirectStandardError $Router9Err
$PidLines += "9router=$($Router9Proc.Id)"
Write-OK "9router started (PID $($Router9Proc.Id))"

# Step 2: Wait for 9router health
& $HealthCheck -Url "http://localhost:$Router9Port" -TimeoutSec 90 -Name "9router"
if ($LASTEXITCODE -ne 0) {
    Write-Err "9router failed to start. Check $Router9Err"
    $PidLines | Set-Content $PidsFile
    exit 1
}

# ---------------------------------------------------------------------------
# Step 3: Start Hermes
# ---------------------------------------------------------------------------
Write-Header "2/4 Starting Hermes (port $HermesPort)"
if (-not (Test-Path $HermesDir)) {
    Write-Err "Hermes not found at $HermesDir"
    & (Join-Path $OrchestratorDir "stop_all.ps1")
    exit 1
}

$HermesLog = Join-Path $LogsDir "hermes.log"
$HermesErr = Join-Path $LogsDir "hermes.err.log"

# Hermes env: data home + portable mode. base_url is in config.yaml -> 9router.
$env:HERMES_HOME = $DataDir
$env:HERMES_PORTABLE = "true"
# Embedded-MCPs import path, computed dynamically from THIS bundle's location (drive-
# independent — replaces the old absolute site-packages .pth). Both the dashboard and
# the gateway inherit this, and the MCP subprocesses they spawn inherit it in turn, so
# `python -m windows_mcp` / `android_mcp` resolve no matter what drive the bundle is on.
$EmbeddedMcps = Join-Path $BundleRoot "embedded-mcps"
if ($env:PYTHONPATH) { $env:PYTHONPATH = "$EmbeddedMcps;$($env:PYTHONPATH)" } else { $env:PYTHONPATH = $EmbeddedMcps }

# Launch the Hermes web dashboard (frontend + API) on port 9119.
# --skip-build serves the prebuilt web_dist (no Node build at runtime),
# --no-open keeps it headless, --host 127.0.0.1 keeps it loopback-only.
# NOTE: this Hermes build's `dashboard` has no --trust-proxy flag (it errors
# "unrecognized arguments"). Dashboard-over-tunnel may hit a Host-header 400;
# the Telegram gateway is unaffected. Do NOT add --trust-proxy here.
$HermesProc = Start-Process -FilePath $HermesExe `
        -ArgumentList "dashboard", "--port", "$HermesPort", "--host", "127.0.0.1", "--no-open", "--skip-build" `
    -WorkingDirectory $HermesDir -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $HermesLog -RedirectStandardError $HermesErr
$PidLines += "hermes=$($HermesProc.Id)"
Write-OK "Hermes dashboard started (PID $($HermesProc.Id))"

# Wait for Hermes health (frontend/dashboard)
& $HealthCheck -Url "http://127.0.0.1:$HermesPort/api/status" -TimeoutSec 90 -Name "Hermes"
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Hermes health endpoint not responding yet (may still be booting)."
}

# ---------------------------------------------------------------------------
# Step 3b: Always start the Hermes messaging gateway (Telegram/Discord/etc.)
# Runs in the foreground mode (`gateway run`) as a separate tracked process,
# so the bot is live whenever the bundle is up. It reads the same .env /
# config.yaml (HERMES_HOME) for platform tokens. If no platform is configured
# it simply idles - harmless. This satisfies "always run the messenger gateway".
# ---------------------------------------------------------------------------
Write-Header "Starting Hermes messaging gateway"
$GatewayLog = Join-Path $LogsDir "gateway.log"
$GatewayErr = Join-Path $LogsDir "gateway.err.log"
$GatewayProc = Start-Process -FilePath $HermesExe `
    -ArgumentList "gateway", "run", "--accept-hooks" `
    -WorkingDirectory $HermesDir -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $GatewayLog -RedirectStandardError $GatewayErr
$PidLines += "hermes-gateway=$($GatewayProc.Id)"
Write-OK "Hermes gateway started (PID $($GatewayProc.Id))"

# ---------------------------------------------------------------------------
# Step 4: Cloudflare tunnels (both services)
# ---------------------------------------------------------------------------
$Router9PublicUrl = $null
$HermesPublicUrl = $null

$NamedTunnelConfig = Join-Path $DataDir "cloudflared\config.yml"

if (-not $NoTunnel -and (Test-Path $CloudflaredExe) -and (Test-Path $NamedTunnelConfig)) {
    # Named tunnel (stable URLs, set up via tunnel/named-tunnel-setup.ps1)
    Write-Header "3/4 Starting NAMED Cloudflare tunnel (stable URLs)"

    # --- Portability guard: relocate credentials-file to THIS bundle --------------------
    # named-tunnel-setup writes credentials-file as an absolute path. If the bundle moved
    # (drive/folder), rewrite it to this bundle's data\cloudflared\<UUID>.json so
    # `cloudflared tunnel run` still finds the creds. The tunnel UUID + DNS routes live in
    # Cloudflare's cloud (account-bound), so the SAME stable URL works from any location.
    try {
        $CfCredDir = Join-Path $DataDir "cloudflared"
        $cfgRaw = Get-Content $NamedTunnelConfig
        $uuidLine = ($cfgRaw | Where-Object { $_ -match '^\s*tunnel:\s*(\S+)' })
        if ($uuidLine -match '^\s*tunnel:\s*(\S+)') {
            $uuid = $Matches[1]
            $expectedCred = Join-Path $CfCredDir "$uuid.json"
            if (Test-Path $expectedCred) {
                $curCred = (($cfgRaw | Where-Object { $_ -match '^\s*credentials-file:\s*' }) -replace '^\s*credentials-file:\s*', '').Trim()
                if ($curCred -ne $expectedCred) {
                    ($cfgRaw | ForEach-Object { if ($_ -match '^\s*credentials-file:\s*') { "credentials-file: $expectedCred" } else { $_ } }) |
                        Set-Content $NamedTunnelConfig -Encoding UTF8
                    Write-OK "Named tunnel: credentials path relocated -> $expectedCred"
                }
            } else {
                Write-Warn "Named tunnel creds $uuid.json missing in data\cloudflared - re-run named-tunnel-setup"
            }
        }
    } catch { Write-Warn "Named tunnel config guard skipped: $_" }

    $cfLog = Join-Path $LogsDir "cloudflared-named.log"
    $cfErr = Join-Path $LogsDir "cloudflared-named.err.log"
    $proc = Start-Process -FilePath $CloudflaredExe `
        -ArgumentList "tunnel", "--no-autoupdate", "--protocol", "http2", "--config", $NamedTunnelConfig, "run" `
        -PassThru -WindowStyle Hidden -RedirectStandardOutput $cfLog -RedirectStandardError $cfErr
    if ($proc) { $PidLines += "cloudflared-named=$($proc.Id)" }
    # Derive public URLs from the config: line after a "service: <port>" wins.
    $cfgLines = Get-Content $NamedTunnelConfig
    $lastHost = ""
    foreach ($ln in $cfgLines) {
        if ($ln -match "hostname:\s*(\S+)") { $lastHost = $Matches[1] }
        elseif ($ln -match "service:\s*http://localhost:9119" -and $lastHost) { $HermesPublicUrl = "https://$lastHost" }
        elseif ($ln -match "service:\s*http://localhost:20128" -and $lastHost) { $Router9PublicUrl = "https://$lastHost" }
    }
    Write-OK "Named tunnel up. Hermes: $HermesPublicUrl  9router: $Router9PublicUrl"
} elseif (-not $NoTunnel -and (Test-Path $CloudflaredExe)) {
    Write-Header "3/4 Starting Cloudflare tunnels (quick / ephemeral)"

    # Helper: start a quick tunnel and scrape the public URL from its log.
    # Returns $null Url if the tunnel failed to connect or DNS didn't resolve.
    function Start-Tunnel {
        param([int]$Port, [string]$Tag, [string]$HostHeader)
        $cfLog = Join-Path $LogsDir "cloudflared-$Tag.log"
        $cfErr = Join-Path $LogsDir "cloudflared-$Tag.err.log"
        # Base args. For the Hermes dashboard we MUST rewrite the Host header to the
        # hostname the server bound to (127.0.0.1:9119); otherwise the dashboard rejects
        # tunnel requests with "Invalid Host header" (this build has no --trust-proxy).
        $cfArgs = @("tunnel", "--no-autoupdate", "--protocol", "http2", "--retries", "10")
        if ($HostHeader) { $cfArgs += @("--http-host-header", $HostHeader) }
        $cfArgs += @("--url", "http://localhost:$Port")
        $proc = Start-Process -FilePath $CloudflaredExe `
            -ArgumentList $cfArgs `
            -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $cfLog -RedirectStandardError $cfErr

        # Poll logs for the trycloudflare URL
        $url = $null
        $waited = 0
        while ($waited -lt 40 -and -not $url) {
            Start-Sleep -Seconds 1
            $waited++
            foreach ($logPath in @($cfLog, $cfErr)) {
                if (-not (Test-Path $logPath)) { continue }
                $content = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
                # Null-safe extraction: [regex]::Match never throws on no-match
                # (the old `$content -match`/`$Matches[0]` pattern crashed with
                # "Cannot index into a null array" when $content was array-typed
                # or the match populated $Matches inconsistently).
                if ($content) {
                    $m = [regex]::Match([string]$content, "https://[a-zA-Z0-9-]+\.trycloudflare\.com")
                    if ($m.Success) { $url = $m.Value; break }
                }
            }
        }
        return @{ Proc = $proc; Url = $url }
    }

    # Verify that a trycloudflare URL actually resolves in DNS. Cloudflare needs
    # ~10-15s to PROPAGATE the quick-tunnel subdomain after the URL is printed, so a
    # single immediate check yields a FALSE NXDOMAIN and triggers needless retries
    # (each retry burns a fresh URL that ALSO gets checked too early -> cascade).
    # Fix: POLL up to $TimeoutSec, preferring a reliable public resolver (1.1.1.1)
    # where the record lands first; the local/system resolver can lag or cache the
    # negative answer. Returns true as soon as the name resolves anywhere.
    function Test-TunnelDns {
        param([string]$Url, [int]$TimeoutSec = 45)
        if (-not $Url) { return $false }
        $hostname = ($Url -replace '^https://', '').TrimEnd('/')
        $waited = 0
        while ($waited -lt $TimeoutSec) {
            try {
                $r = Resolve-DnsName -Name $hostname -Server '1.1.1.1' -Type A -ErrorAction Stop
                if ($r | Where-Object { $_.IPAddress }) { return $true }
            } catch {}
            try {
                $e = [System.Net.Dns]::GetHostEntry($hostname)
                if ($e.AddressList.Count -gt 0) { return $true }
            } catch {}
            Start-Sleep -Seconds 5
            $waited += 5
        }
        return $false
    }

    # Tunnels are best-effort: a capture hiccup must never abort the whole
    # startup (services are already up). Each call is isolated in try/catch.

    # Helper: tries a tunnel + DNS validation, with up to $MaxRetries retries.
    # NOTE on retries: account-less quick tunnels are RATE-LIMITED by Cloudflare —
    # creating many in a short window makes Cloudflare stop provisioning DNS for new
    # ones (NXDOMAIN even though the tunnel "registers"). So aggressive retry is
    # COUNTERPRODUCTIVE (each retry = another tunnel = more throttle). We keep it low
    # (1 retry) and rely on a patient DNS wait instead. For RELIABLE public access,
    # use a NAMED tunnel (tunnel\named-tunnel-setup.ps1) — it is not rate-limited.
    function Start-TunnelWithRetry {
        param([int]$Port, [string]$Tag, [string]$HostHeader, [int]$MaxRetries = 2)
        $attempt = 0
        $tunnel = $null
        while ($attempt -lt $MaxRetries) {
            $attempt++
            if ($attempt -gt 1) { Write-Step "Retry $attempt/$MaxRetries for $Tag tunnel..." }
            try {
                $tunnel = Start-Tunnel -Port $Port -Tag "$Tag-attempt$attempt" -HostHeader $HostHeader
                if (-not $tunnel.Proc) {
                    Write-Warn "$Tag tunnel process did not start"
                    continue
                }
                if (-not $tunnel.Url) {
                    Write-Warn "$Tag tunnel URL not captured from logs"
                    # Kill the hung tunnel before retry
                    Stop-Process -Id $tunnel.Proc.Id -Force -ErrorAction SilentlyContinue
                    continue
                }
                # Verify DNS resolution (trycloudflare occasionally drops records)
                if (Test-TunnelDns $tunnel.Url) {
                    return $tunnel
                } else {
                    Write-Warn "$Tag tunnel URL $($tunnel.Url) failed DNS resolution - retrying"
                    Stop-Process -Id $tunnel.Proc.Id -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Warn "$Tag tunnel error (attempt $attempt): $_"
                if ($tunnel -and $tunnel.Proc) { Stop-Process -Id $tunnel.Proc.Id -Force -ErrorAction SilentlyContinue }
            }
        }
        return $null
    }

    try {
        Write-Step "Tunnel -> 9router (:$Router9Port)..."
        $t1 = Start-TunnelWithRetry -Port $Router9Port -Tag "9router"
        if ($t1 -and $t1.Proc) { $PidLines += "cloudflared-9router=$($t1.Proc.Id)" }
        $Router9PublicUrl = $t1.Url
        if ($Router9PublicUrl) { Write-OK "9router public: $Router9PublicUrl" } else { Write-Warn "9router tunnel not available (all retries exhausted)" }
    } catch { Write-Warn "9router tunnel error (continuing): $_" }

    try {
        Write-Step "Tunnel -> Hermes (:$HermesPort)..."
        $t2 = Start-TunnelWithRetry -Port $HermesPort -Tag "hermes" -HostHeader "127.0.0.1:$HermesPort"
        if ($t2 -and $t2.Proc) { $PidLines += "cloudflared-hermes=$($t2.Proc.Id)" }
        $HermesPublicUrl = $t2.Url
        if ($HermesPublicUrl) { Write-OK "Hermes public: $HermesPublicUrl" } else { Write-Warn "Hermes tunnel not available (all retries exhausted)" }
    } catch { Write-Warn "Hermes tunnel error (continuing): $_" }
} else {
    Write-Header "3/4 Tunnels skipped (local-only mode)"
}

# ---------------------------------------------------------------------------
# Step 3c: Watchdog - keep services alive + write health.json (observability).
# Launched LAST so it doesn't fight the initial boot; it monitors from here on
# and auto-restarts 9router/Hermes/gateway if they die.
# ---------------------------------------------------------------------------
$WatchdogScript = Join-Path $OrchestratorDir "watchdog.ps1"
if (Test-Path $WatchdogScript) {
    $WatchProc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", $WatchdogScript `
        -PassThru -WindowStyle Hidden
    $PidLines += "watchdog=$($WatchProc.Id)"
    Write-OK "Watchdog started (auto-restart + health monitoring)"
}

# ---------------------------------------------------------------------------
# Persist state + summary
# ---------------------------------------------------------------------------
Write-Header "4/4 Ready"
$PidLines | Set-Content $PidsFile -Encoding ascii

$TunnelInfo = @"
9router_local=http://localhost:$Router9Port
9router_public=$Router9PublicUrl
hermes_local=http://localhost:$HermesPort
hermes_public=$HermesPublicUrl
"@
Set-Content -Path $TunnelFile -Value $TunnelInfo -Encoding UTF8

# Send Telegram notification (if configured)
Write-Host ""
Write-Host "Checking Telegram configuration..." -ForegroundColor Gray
$EnvFile = Join-Path $DataDir ".env"
if (Test-Path $EnvFile) {
    $EnvContent = Get-Content $EnvFile -Raw
    $TgToken = if ($EnvContent -match 'HERMES_TELEGRAM_TOKEN=(.+)') { ($Matches[1].Trim() -split "`n")[0] } else { "" }
    $TgChat = if ($EnvContent -match 'HERMES_TELEGRAM_CHAT_ID=(.+)') { ($Matches[1].Trim() -split "`n")[0] } else { "" }

    if (![string]::IsNullOrWhiteSpace($TgToken) -and ![string]::IsNullOrWhiteSpace($TgChat)) {
        Write-Host "  Sending Telegram notification..." -ForegroundColor Cyan
        $TgMessage = @"
<b>Hermes Portable is ONLINE!</b>

<b>9router (LLM gateway):</b>
  Local:  http://localhost:$Router9Port
  Public: $Router9PublicUrl

<b>Hermes (AI Agent):</b>
  Local:  http://localhost:$HermesPort
  Public: $HermesPublicUrl

Ready for commands!
"@
        & (Join-Path $OrchestratorDir "send_telegram.ps1") `
            -Message $TgMessage `
            -TelegramToken $TgToken `
            -ChatId $TgChat
    } else {
        Write-Host "  Telegram not configured (optional)" -ForegroundColor Gray
    }
} else {
    Write-Host "  .env not found (Telegram skipped)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " Hermes Portable is RUNNING" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  9router (LLM gateway):" -ForegroundColor Cyan
Write-Host "    Local:  http://localhost:$Router9Port"
if ($Router9PublicUrl) { Write-Host "    Public: $Router9PublicUrl" -ForegroundColor Yellow }
Write-Host ""
Write-Host "  Hermes (AI agent):" -ForegroundColor Cyan
Write-Host "    Local:  http://localhost:$HermesPort"
if ($HermesPublicUrl) { Write-Host "    Public: $HermesPublicUrl" -ForegroundColor Yellow }
Write-Host ""
Write-Host "  Logs:  $LogsDir"
Write-Host "  Stop:  run STOP.bat"
Write-Host ""
Write-Host "  Keep this window open, or close it - services run in background." -ForegroundColor Gray
Write-Host ""
