#Requires -Version 5.1
<#
.SYNOPSIS
    Health-check helper: poll a URL until it responds (or timeout).

.PARAMETER Url
    URL to poll.

.PARAMETER TimeoutSec
    Max seconds to wait (default 60).

.PARAMETER Name
    Friendly service name for logging.

.OUTPUTS
    Exit code 0 if healthy within timeout, 1 if timed out.
#>

param(
    [Parameter(Mandatory = $true)][string]$Url,
    [int]$TimeoutSec = 60,
    [string]$Name = "service"
)

$Elapsed = 0
Write-Host "    Waiting for $Name at $Url ..." -ForegroundColor Gray

while ($Elapsed -lt $TimeoutSec) {
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
            Write-Host "    [OK] $Name is up (HTTP $($resp.StatusCode))" -ForegroundColor Green
            exit 0
        }
    } catch {
        Start-Sleep -Seconds 2
        $Elapsed += 2
    }
}

Write-Host "    [X] $Name did not become healthy within ${TimeoutSec}s" -ForegroundColor Red
exit 1
