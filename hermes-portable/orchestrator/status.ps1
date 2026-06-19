#Requires -Version 5.1
<#
.SYNOPSIS
    Show Hermes Portable health (observability) - reads data/health.json + live probes.
#>
$OrchestratorDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot = Split-Path -Parent $OrchestratorDir
$DataDir = Join-Path $BundleRoot "data"
$HealthFile = Join-Path $DataDir "health.json"
$TunnelFile = Join-Path $DataDir "tunnel_urls.txt"
$PidsFile = Join-Path $DataDir "pids.txt"

function C($t,$c){ Write-Host $t -ForegroundColor $c }

Write-Host ""
C "=============================================" Cyan
C " Hermes Portable - Health Status" Cyan
C "=============================================" Cyan
Write-Host ""

# Live probes (authoritative right now)
function Probe($url){ try { $r=Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 4 -ErrorAction SilentlyContinue; return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) } catch { return $false } }
$r9 = Probe "http://localhost:20128"
$rh = Probe "http://127.0.0.1:9119/api/status"
C ("  9router (20128) : " + $(if($r9){"UP"}else{"DOWN"})) $(if($r9){"Green"}else{"Red"})
C ("  Hermes  (9119)  : " + $(if($rh){"UP"}else{"DOWN"})) $(if($rh){"Green"}else{"Red"})

# Tracked processes
if (Test-Path $PidsFile) {
    Write-Host ""
    C "  Tracked processes:" Gray
    Get-Content $PidsFile | ForEach-Object {
        $p = $_ -split '=',2
        if ($p.Count -eq 2) {
            $alive = [bool](Get-Process -Id ([int]$p[1]) -ErrorAction SilentlyContinue)
            C ("    {0,-20} PID {1,-7} {2}" -f $p[0], $p[1], $(if($alive){"alive"}else{"DEAD"})) $(if($alive){"Green"}else{"Red"})
        }
    }
}

# Watchdog health snapshot
if (Test-Path $HealthFile) {
    Write-Host ""
    C "  Watchdog snapshot (data/health.json):" Gray
    try { (Get-Content $HealthFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { C ("    {0,-22}: {1}" -f $_.Name, $_.Value) Gray } } catch { C "    (unreadable)" Yellow }
}

# Public URLs
if (Test-Path $TunnelFile) {
    Write-Host ""
    C "  Public URLs (data/tunnel_urls.txt):" Gray
    Get-Content $TunnelFile | Where-Object { $_ -match "public=" -and $_ -notmatch "public=$" } | ForEach-Object { C ("    $_") Yellow }
}

Write-Host ""
