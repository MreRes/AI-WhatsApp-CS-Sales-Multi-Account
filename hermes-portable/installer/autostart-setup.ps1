#Requires -Version 5.1
<#
.SYNOPSIS
    Enable/disable auto-start of Hermes Portable at Windows logon.

.DESCRIPTION
    Uses the per-user STARTUP FOLDER (the most reliable, zero-permission method):
    drops a launcher .bat into
        %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
    so Windows runs it automatically every logon - no admin, no Task Scheduler
    rights required. The launcher waits for the network, then runs the
    orchestrator hidden (9router + dashboard + gateway + tunnel + watchdog +
    keep-awake).

    Why logon (not pre-login boot): Windows-MCP drives the interactive desktop,
    so it needs your logged-in session.

.PARAMETER Disable
    Remove the auto-start launcher.
.PARAMETER Status
    Show whether auto-start is enabled.
#>

param(
    [switch]$Disable,
    [switch]$Status
)

$ErrorActionPreference = "Stop"

$InstallerDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot   = Split-Path -Parent $InstallerDir
$LaunchBat    = Join-Path $BundleRoot "orchestrator\autostart_launch.bat"

$StartupDir = [Environment]::GetFolderPath('Startup')   # %APPDATA%\...\Startup
$Stub       = Join-Path $StartupDir "HermesPortable-AutoStart.bat"

if ($Status) {
    if (Test-Path $Stub) { Write-Host "[ON]  Auto-start ENABLED -> $Stub" -ForegroundColor Green }
    else { Write-Host "[OFF] Auto-start NOT enabled." -ForegroundColor Yellow }
    exit 0
}

if ($Disable) {
    Remove-Item $Stub -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Auto-start disabled (removed startup launcher)." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $LaunchBat)) { Write-Host "[X] autostart_launch.bat not found at $LaunchBat" -ForegroundColor Red; exit 1 }

# Write a tiny stub in Startup that calls the bundle's launcher by absolute path.
# (A stub rather than copying the launcher keeps it pointing at the live bundle.)
$stubContent = "@echo off`r`ncall `"$LaunchBat`"`r`n"
Set-Content -Path $Stub -Value $stubContent -Encoding ascii

Write-Host ""
Write-Host "[OK] Auto-start ENABLED (Startup folder method)." -ForegroundColor Green
Write-Host "     Hermes Portable launches automatically ~20s after you log in."
Write-Host "     Launcher: $Stub"
Write-Host ""
Write-Host "  Manage:" -ForegroundColor Gray
Write-Host "    Check  : AUTOSTART.bat -Status"
Write-Host "    Disable: AUTOSTART.bat -Disable"
Write-Host ""
Write-Host "  NOTE: if you MOVE the bundle to another folder/drive, re-run this" -ForegroundColor Yellow
Write-Host "        to update the path." -ForegroundColor Yellow
