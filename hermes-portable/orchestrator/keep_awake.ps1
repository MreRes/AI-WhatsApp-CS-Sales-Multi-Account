#Requires -Version 5.1
<#
.SYNOPSIS
    Keep the machine (and display) awake while Hermes Portable is running.

.DESCRIPTION
    Holds a Windows "wake lock" via SetThreadExecutionState so the laptop won't
    sleep, hibernate, or turn off the screen - which is what drops the network
    and kills the Cloudflare tunnel. This is the same mechanism media players use.

    It is TEMPORARY and self-reverting: the lock lives only as long as THIS
    process. When START's orchestrator launches it and STOP (or a crash) kills
    it, Windows automatically clears the request and normal sleep behaviour
    returns. No persistent power-plan changes are made.

.PARAMETER KeepDisplayOn
    Also keep the display awake (default true). Set -KeepDisplayOn:$false to let
    the screen turn off while keeping the SYSTEM awake (tunnel stays up, screen
    sleeps). For GUI automation you usually want the display on.
#>

param(
    [bool]$KeepDisplayOn = $true
)

$ErrorActionPreference = "Stop"

# P/Invoke SetThreadExecutionState
$signature = @'
using System;
using System.Runtime.InteropServices;
public static class Awake {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
    public const uint ES_CONTINUOUS        = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED   = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED  = 0x00000002;
}
'@
Add-Type -TypeDefinition $signature -ErrorAction SilentlyContinue

$flags = [Awake]::ES_CONTINUOUS -bor [Awake]::ES_SYSTEM_REQUIRED
if ($KeepDisplayOn) { $flags = $flags -bor [Awake]::ES_DISPLAY_REQUIRED }

# Apply the lock. ES_CONTINUOUS makes it persist for this thread until cleared
# (i.e. until this process exits), so the system stays awake the whole time.
[Awake]::SetThreadExecutionState($flags) | Out-Null
Write-Host "[keep-awake] Wake lock active (system$(if($KeepDisplayOn){' + display'})). Laptop will not sleep while Hermes runs."

# Re-assert periodically as a belt-and-braces guard (some group policies reset
# idle timers); ES_CONTINUOUS alone is enough, but re-applying is harmless.
try {
    while ($true) {
        [Awake]::SetThreadExecutionState($flags) | Out-Null
        Start-Sleep -Seconds 50
    }
} finally {
    # On exit, clear the lock so normal sleep behaviour returns immediately.
    [Awake]::SetThreadExecutionState([Awake]::ES_CONTINUOUS) | Out-Null
}
