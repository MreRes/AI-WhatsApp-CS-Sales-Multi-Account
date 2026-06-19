#Requires -Version 5.1
<#
.SYNOPSIS
    Auto-start launcher invoked by the logon Scheduled Task.
    Waits for the network to settle, then runs the orchestrator. Kept as a
    separate -File so the scheduled task command has no inline quoting/semicolons
    (which schtasks mis-parses).
#>
param([int]$DelaySeconds = 20)

# Let Wi-Fi / network come up so the tunnel connects cleanly on first try.
Start-Sleep -Seconds $DelaySeconds

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
& (Join-Path $ScriptDir "start_all.ps1")
