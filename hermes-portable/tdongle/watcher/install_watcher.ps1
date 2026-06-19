#Requires -Version 5.1
<#
.SYNOPSIS
    Register the T-Dongle watcher as a Scheduled Task that runs at user logon.

.DESCRIPTION
    Installs a hidden background task ("HermesTDongleWatcher") that starts the
    presence watcher every time you log in, so plugging the T-Dongle launches
    Hermes Portable automatically. Use -Uninstall to remove it.

.PARAMETER Uninstall
    Remove the scheduled task instead of installing it.
#>

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$TaskName = "HermesTDongleWatcher"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$WatcherPs1 = Join-Path $ScriptDir "tdongle_watcher.ps1"

if ($Uninstall) {
    schtasks /Delete /TN $TaskName /F 2>$null
    Write-Host "[OK] Removed scheduled task '$TaskName'." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $WatcherPs1)) {
    Write-Host "[X] tdongle_watcher.ps1 not found at $WatcherPs1" -ForegroundColor Red
    exit 1
}

# Build the action: powershell hidden, no profile, bypass, run the watcher.
$Action = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$WatcherPs1`""

# Create (or replace) a logon-triggered task for the current user.
schtasks /Create /TN $TaskName /SC ONLOGON /RL LIMITED /F /TR $Action | Out-Null

Write-Host "[OK] Installed scheduled task '$TaskName' (runs at logon)." -ForegroundColor Green
Write-Host "     Start it now without re-login:" -ForegroundColor Gray
Write-Host "       schtasks /Run /TN $TaskName" -ForegroundColor Gray
Write-Host "     Remove it later:" -ForegroundColor Gray
Write-Host "       powershell -File install_watcher.ps1 -Uninstall" -ForegroundColor Gray
