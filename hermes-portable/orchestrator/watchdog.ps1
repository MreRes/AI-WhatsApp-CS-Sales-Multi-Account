#Requires -Version 5.1
<#
.SYNOPSIS
    Hermes Portable watchdog - keeps services alive + writes health for observability.

.DESCRIPTION
    Every interval it health-checks each service and RESTARTS any that died:
      - 9router  : HTTP probe http://localhost:20128         -> relaunch cli.js
      - Hermes   : HTTP probe http://127.0.0.1:9119/api/status -> relaunch dashboard
      - gateway  : process-alive (PID)                        -> relaunch gateway run
    cloudflared tunnels self-retry, so the watchdog only records their state.

    It also writes data/health.json every cycle (consumed by STATUS.bat and the
    dashboard) and appends events to data/logs/watchdog.log. Restarts are rate-
    limited (max N per service per window) so a hard-crashing service doesn't
    spin forever.

    Launched by START (tracked in pids.txt); stopped by STOP. Self-contained:
    it knows how to relaunch each service without re-running the full orchestrator.
#>

param(
    [int]$IntervalSeconds = 15
)

$ErrorActionPreference = "Continue"

$OrchestratorDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot   = Split-Path -Parent $OrchestratorDir
$RuntimeDir   = Join-Path $BundleRoot "runtime"
$NodeExe      = Join-Path $RuntimeDir "node\node.exe"
$Router9Cli   = Join-Path $RuntimeDir "9router-app\node_modules\9router\cli.js"
$ServicesDir  = Join-Path $BundleRoot "services"
$HermesDir    = Join-Path $ServicesDir "hermes"
$DataDir      = Join-Path $BundleRoot "data"
$VenvDir      = Join-Path $DataDir ".venv"
$HermesExe    = Join-Path $VenvDir "Scripts\hermes.exe"
if (-not (Test-Path $HermesExe)) { $HermesExe = Join-Path $VenvDir "Scripts\hermes-agent.exe" }
$LogsDir      = Join-Path $DataDir "logs"
$PidsFile     = Join-Path $DataDir "pids.txt"
$HealthFile   = Join-Path $DataDir "health.json"
$WatchLog     = Join-Path $LogsDir "watchdog.log"

$Router9Port = 20128
$HermesPort  = 9119

# Restart rate-limit: max restarts per service within the window.
$MaxRestarts = 5
$RestartWindowSec = 300
$restartHistory = @{}   # name -> [datetime,...]

function Log-Watch { param($msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Add-Content -Path $WatchLog -Value $line -ErrorAction SilentlyContinue
}

function Test-Http { param([string]$Url)
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500)
    } catch { return $false }
}

function Test-PidAlive { param([int]$ProcId)
    if (-not $ProcId) { return $false }
    return [bool](Get-Process -Id $ProcId -ErrorAction SilentlyContinue)
}

function Get-Pids {
    $h = @{}
    if (Test-Path $PidsFile) {
        Get-Content $PidsFile -ErrorAction SilentlyContinue | ForEach-Object {
            $p = $_ -split '=', 2
            if ($p.Count -eq 2) { $h[$p[0]] = [int]$p[1] }
        }
    }
    return $h
}

function Set-Pid { param($name, $procId)
    $h = Get-Pids
    $h[$name] = $procId
    ($h.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) | Set-Content $PidsFile -Encoding ascii
}

function Can-Restart { param($name)
    $now = Get-Date
    if (-not $restartHistory.ContainsKey($name)) { $restartHistory[$name] = @() }
    $restartHistory[$name] = @($restartHistory[$name] | Where-Object { ($now - $_).TotalSeconds -lt $RestartWindowSec })
    if ($restartHistory[$name].Count -ge $MaxRestarts) { return $false }
    $restartHistory[$name] += $now
    return $true
}

function Restart-Router9 {
    if (-not (Can-Restart "9router")) { Log-Watch "[skip] 9router restart rate-limited"; return }
    Log-Watch "[restart] 9router (port $Router9Port down)"
    # Ensure sql.js wasm present (auto-update may have wiped it)
    $wasm = Join-Path $RuntimeDir "9router-app\node_modules\9router\app\node_modules\sql.js\dist\sql-wasm.wasm"
    $cached = Join-Path $DataDir "sql-wasm.wasm"
    if ((Test-Path (Split-Path $wasm)) -and -not (Test-Path $wasm) -and (Test-Path $cached)) {
        Copy-Item $cached $wasm -Force -ErrorAction SilentlyContinue
    }
    $env:NODE_ENV = "production"; $env:PORT = "$Router9Port"
    $env:DATA_DIR = Join-Path $DataDir "9router"   # portable DB (matches start_all.ps1)
    $log = Join-Path $LogsDir "9router.log"; $err = Join-Path $LogsDir "9router.err.log"
    $p = Start-Process -FilePath $NodeExe -ArgumentList $Router9Cli, "-n", "-l", "-p", "$Router9Port" `
        -WorkingDirectory (Join-Path $RuntimeDir "9router-app") -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $log -RedirectStandardError $err
    Set-Pid "9router" $p.Id
}

function Restart-Hermes {
    if (-not (Can-Restart "hermes")) { Log-Watch "[skip] hermes restart rate-limited"; return }
    Log-Watch "[restart] Hermes dashboard (port $HermesPort down)"
    $env:HERMES_HOME = $DataDir; $env:HERMES_PORTABLE = "true"
    $env:PYTHONPATH = Join-Path $BundleRoot "embedded-mcps"   # drive-independent MCP import path
    $log = Join-Path $LogsDir "hermes.log"; $err = Join-Path $LogsDir "hermes.err.log"
    $p = Start-Process -FilePath $HermesExe `
        -ArgumentList "dashboard", "--port", "$HermesPort", "--host", "127.0.0.1", "--no-open", "--skip-build" `
        -WorkingDirectory $HermesDir -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $log -RedirectStandardError $err
    Set-Pid "hermes" $p.Id
}

function Restart-Gateway {
    if (-not (Can-Restart "hermes-gateway")) { Log-Watch "[skip] gateway restart rate-limited"; return }
    Log-Watch "[restart] Hermes gateway (process down)"
    $env:HERMES_HOME = $DataDir; $env:HERMES_PORTABLE = "true"
    $env:PYTHONPATH = Join-Path $BundleRoot "embedded-mcps"   # drive-independent MCP import path
    $log = Join-Path $LogsDir "gateway.log"; $err = Join-Path $LogsDir "gateway.err.log"
    $p = Start-Process -FilePath $HermesExe -ArgumentList "gateway", "run", "--accept-hooks", "--replace" `
        -WorkingDirectory $HermesDir -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $log -RedirectStandardError $err
    Set-Pid "hermes-gateway" $p.Id
}

Log-Watch "=== watchdog started (interval ${IntervalSeconds}s) ==="

while ($true) {
    $pids = Get-Pids
    $health = [ordered]@{ checked_at = (Get-Date -Format "o") }

    # 9router
    if (Test-Http "http://localhost:$Router9Port") {
        $health["9router"] = "up"
    } else {
        $health["9router"] = "down -> restarting"
        Restart-Router9
    }

    # Hermes dashboard
    if (Test-Http "http://127.0.0.1:$HermesPort/api/status") {
        $health["hermes"] = "up"
    } else {
        $health["hermes"] = "down -> restarting"
        Restart-Hermes
    }

    # Gateway (PID-based - no HTTP endpoint)
    $gwPid = $pids["hermes-gateway"]
    if (Test-PidAlive $gwPid) {
        $health["gateway"] = "up (pid $gwPid)"
    } else {
        $health["gateway"] = "down -> restarting"
        Restart-Gateway
    }

    # Tunnels (record only; cloudflared self-retries)
    $health["cloudflared_9router"] = if (Test-PidAlive $pids["cloudflared-9router"]) { "up" } else { "down" }
    $health["cloudflared_hermes"]  = if (Test-PidAlive $pids["cloudflared-hermes"]) { "up" } else { "down" }

    # Write health.json (observability)
    try { ($health | ConvertTo-Json -Compress) | Set-Content $HealthFile -Encoding utf8 -ErrorAction SilentlyContinue } catch {}

    Start-Sleep -Seconds $IntervalSeconds
}
