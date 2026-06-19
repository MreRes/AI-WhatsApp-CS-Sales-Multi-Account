#Requires -Version 5.1
<#
.SYNOPSIS
    Stop all hermes-portable services (9router, hermes, cloudflared).

.DESCRIPTION
    Reads data/pids.txt and terminates each recorded process.
    Also cleans up tunnel_urls.txt.
#>

$OrchestratorDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot = Split-Path -Parent $OrchestratorDir
$DataDir = Join-Path $BundleRoot "data"
$PidsFile = Join-Path $DataDir "pids.txt"
$TunnelFile = Join-Path $DataDir "tunnel_urls.txt"

function Write-OK   { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[!] $args" -ForegroundColor Yellow }

Write-Host ""
Write-Host "Stopping Hermes Portable services..." -ForegroundColor Cyan

if (-not (Test-Path $PidsFile)) {
    Write-Warn "No pids.txt found - nothing to stop (or already stopped)."
    exit 0
}

$stopped = 0

# CRITICAL: kill the watchdog FIRST. Otherwise it sees the other services dying
# and restarts them mid-shutdown, fighting STOP.
$pidMap = @{}
Get-Content $PidsFile -ErrorAction SilentlyContinue | ForEach-Object {
    $pp = $_.Trim() -split '=', 2
    if ($pp.Count -eq 2) { $pidMap[$pp[0]] = $pp[1] }
}
if ($pidMap.ContainsKey("watchdog")) {
    try { Stop-Process -Id ([int]$pidMap["watchdog"]) -Force -ErrorAction SilentlyContinue; Write-OK "Stopped watchdog first (PID $($pidMap['watchdog']))"; $stopped++ } catch {}
}
# Also sweep any orphan watchdog by command line, before touching services.
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
    if ((($_.CommandLine | Out-String).ToLower()) -match "watchdog") {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Milliseconds 500

Get-Content $PidsFile -ErrorAction SilentlyContinue | ForEach-Object {
    $line = $_.Trim()
    if (-not $line) { return }

    # Format: "name=PID"
    $parts = $line -split '=', 2
    $svcName = if ($parts.Count -eq 2) { $parts[0] } else { "process" }
    $procId  = if ($parts.Count -eq 2) { $parts[1] } else { $parts[0] }

    try {
        $p = Get-Process -Id ([int]$procId) -ErrorAction SilentlyContinue
        if ($p) {
            Stop-Process -Id ([int]$procId) -Force -ErrorAction SilentlyContinue
            Write-OK "Stopped $svcName (PID $procId)"
            $stopped++
        }
    } catch {
        Write-Warn "Could not stop $svcName (PID $procId): stale entry"
    }
}

Remove-Item $PidsFile -Force -ErrorAction SilentlyContinue
Remove-Item $TunnelFile -Force -ErrorAction SilentlyContinue

# Orphan sweep: if START was run multiple times without STOP, earlier
# cloudflared/node processes won't be in pids.txt and keep stale tunnels alive
# (the classic "old trycloudflare URL is dead but a new one exists" confusion).
# Kill any cloudflared whose command line targets OUR bundle ports (20128/9119),
# and any node running THIS bundle's 9router cli - targeted so we don't touch
# unrelated cloudflared/node the user may run elsewhere.
Write-Host ""
Write-Host "Sweeping orphaned tunnels/processes..." -ForegroundColor Cyan
try {
    $bundleMarker = $BundleRoot.ToLower()
    Get-CimInstance Win32_Process -Filter "Name='cloudflared.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        $cl = ($_.CommandLine | Out-String).ToLower()
        if ($cl -match "localhost:20128" -or $cl -match "localhost:9119" -or ($cl -match "cloudflared\\config.yml" -or ($cl -match "config.yml" -and $cl -match $bundleMarker))) {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            Write-OK "Swept orphan cloudflared (PID $($_.ProcessId))"
            $stopped++
        }
    }
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        $cl = ($_.CommandLine | Out-String).ToLower()
        if ($cl -match "9router-app" -and $cl -match $bundleMarker) {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            Write-OK "Swept orphan 9router node (PID $($_.ProcessId))"
            $stopped++
        }
    }
    # Orphan keep_awake.ps1 (wake lock) - a powershell.exe still holding the
    # no-sleep lock from a previous run. Releasing it lets the laptop sleep
    # normally again once Hermes is down.
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        $cl = ($_.CommandLine | Out-String).ToLower()
        if ($cl -match "keep_awake" -or $cl -match "watchdog") {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            Write-OK "Swept orphan helper (PID $($_.ProcessId))"
            $stopped++
        }
    }
    # Orphan hermes.exe (gateway/dashboard) from earlier runs - these hold a
    # STALE environment (e.g. an old API key or base_url) and keep answering
    # Telegram with the wrong routing. Kill any hermes.exe under this bundle.
    foreach ($pname in @('hermes.exe')) {
        Get-CimInstance Win32_Process -Filter "Name='$pname'" -ErrorAction SilentlyContinue | ForEach-Object {
            $cl = ($_.CommandLine | Out-String).ToLower()
            $exe = ($_.ExecutablePath | Out-String).ToLower()
            if ($exe -match $bundleMarker -or $cl -match $bundleMarker -or $cl -match "gateway" -or $cl -match "dashboard") {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                Write-OK "Swept orphan hermes (PID $($_.ProcessId))"
                $stopped++
            }
        }
    }
} catch {
    Write-Warn "Orphan sweep skipped: $_"
}

Write-Host ""
Write-OK "Stopped $stopped service(s). Hermes Portable is down."
