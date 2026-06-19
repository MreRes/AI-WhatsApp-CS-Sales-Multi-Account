#Requires -Version 5.1
<#
.SYNOPSIS
    Hermes Portable — T-Dongle presence watcher (safe trigger, no keystroke injection).

.DESCRIPTION
    Polls Windows for a USB device matching the T-Dongle-S3's VID/PID. When the
    dongle is plugged in, it launches the bundle's START.bat — then debounces so
    it fires only once per insertion (won't re-launch while it stays connected).

    This is the SAFER alternative to the HID-keyboard firmware mode: nothing is
    auto-typed, so a dongle plugged into the wrong machine does nothing unless
    that machine is explicitly running this watcher.

    Run it via install_watcher.ps1 (registers a Scheduled Task at logon), or
    standalone for testing:
        powershell -NoProfile -ExecutionPolicy Bypass -File tdongle_watcher.ps1

.PARAMETER Vid
    USB Vendor ID hex (default 303A = Espressif/ESP32-S3).
.PARAMETER Pid
    USB Product ID hex. Empty = match any PID under the VID (default).
.PARAMETER PollSeconds
    How often to poll for the device (default 3).
.PARAMETER StartBat
    Explicit path to START.bat. Empty = auto-discover next to this script
    (..\..\START.bat) or scan drives for hermes-portable\START.bat.
#>

param(
    [string]$Vid = "303A",
    [string]$Pid = "",
    [int]$PollSeconds = 3,
    [string]$StartBat = ""
)

$ErrorActionPreference = "Stop"

function Resolve-StartBat {
    param([string]$Explicit)
    if ($Explicit -and (Test-Path $Explicit)) { return (Resolve-Path $Explicit).Path }

    # 1) Next to the bundle: tdongle/watcher/ -> bundle root is two levels up.
    $here = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $candidate = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "START.bat"
    if (Test-Path $candidate) { return (Resolve-Path $candidate).Path }

    # 2) Scan all filesystem drives for hermes-portable\START.bat
    foreach ($d in (Get-PSDrive -PSProvider FileSystem)) {
        $p = Join-Path $d.Root "hermes-portable\START.bat"
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Test-DonglePresent {
    param([string]$Vid, [string]$Pid)
    $pattern = if ($Pid) { "VID_$Vid&PID_$Pid" } else { "VID_$Vid" }
    $hit = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
        Where-Object { $_.PNPDeviceID -and $_.PNPDeviceID.ToUpper().Contains($pattern.ToUpper()) }
    return [bool]$hit
}

# ── main ──
$Vid = $Vid.ToUpper().Replace("0X", "")
$Pid = $Pid.ToUpper().Replace("0X", "")

Write-Host "[T-Dongle watcher] Watching for USB VID_$Vid$(if($Pid){"&PID_$Pid"}) every ${PollSeconds}s..." -ForegroundColor Cyan

$wasPresent = $false
while ($true) {
    try {
        $present = Test-DonglePresent -Vid $Vid -Pid $Pid
        if ($present -and -not $wasPresent) {
            # Rising edge: dongle just inserted.
            $bat = Resolve-StartBat -Explicit $StartBat
            if ($bat) {
                Write-Host "[T-Dongle watcher] Dongle detected -> launching $bat" -ForegroundColor Green
                Start-Process -FilePath $bat -WorkingDirectory (Split-Path $bat)
            } else {
                Write-Host "[T-Dongle watcher] Dongle detected but START.bat not found." -ForegroundColor Yellow
            }
        }
        $wasPresent = $present
    } catch {
        Write-Host "[T-Dongle watcher] poll error: $_" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds $PollSeconds
}
