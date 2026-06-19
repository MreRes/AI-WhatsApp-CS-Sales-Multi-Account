#Requires -Version 5.1
<#
.SYNOPSIS
    Download portable runtimes for hermes-portable bundle.

.DESCRIPTION
    Downloads and extracts:
    - Portable Node.js (win-x64) -> runtime/node/
    - cloudflared.exe -> runtime/bin/

    Idempotent: skips already-downloaded runtimes unless -Force.

.PARAMETER Force
    Re-download even if runtime already present.

.PARAMETER NodeVersion
    Node.js version to download (default: 22.11.0 LTS).
#>

param(
    [switch]$Force,
    [string]$NodeVersion = "22.11.0",
    [switch]$WithAdb = $true
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Resolve paths relative to bundle root (parent of installer/)
$InstallerDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot = Split-Path -Parent $InstallerDir
$RuntimeDir = Join-Path $BundleRoot "runtime"
$NodeDir = Join-Path $RuntimeDir "node"
$BinDir = Join-Path $RuntimeDir "bin"

function Write-Step { Write-Host "==> $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[!] $args" -ForegroundColor Yellow }

# Ensure runtime dirs exist
foreach ($d in @($RuntimeDir, $NodeDir, $BinDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

# ---------------------------------------------------------------------------
# 1. Portable Node.js
# ---------------------------------------------------------------------------
$NodeExe = Join-Path $NodeDir "node.exe"
if ((Test-Path $NodeExe) -and -not $Force) {
    Write-OK "Node.js already present: $(& $NodeExe --version)"
} else {
    Write-Step "Downloading portable Node.js v$NodeVersion (win-x64)..."
    $NodeZipName = "node-v$NodeVersion-win-x64"
    $NodeUrl = "https://nodejs.org/dist/v$NodeVersion/$NodeZipName.zip"
    $TmpZip = Join-Path $env:TEMP "node-$NodeVersion-$(Get-Random).zip"
    $TmpExtract = Join-Path $env:TEMP "node-extract-$(Get-Random)"

    try {
        Invoke-WebRequest -Uri $NodeUrl -OutFile $TmpZip -UseBasicParsing
        Write-Step "Extracting Node.js..."
        Expand-Archive -Path $TmpZip -DestinationPath $TmpExtract -Force

        # Move contents of node-vX-win-x64/ into runtime/node/
        $Inner = Join-Path $TmpExtract $NodeZipName
        Get-ChildItem -Path $Inner -Force | ForEach-Object {
            $dest = Join-Path $NodeDir $_.Name
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Move-Item -Path $_.FullName -Destination $NodeDir -Force
        }
        Write-OK "Node.js installed: $(& $NodeExe --version)"
    } catch {
        Write-Warn "Failed to download Node.js: $_"
        throw
    } finally {
        if (Test-Path $TmpZip)     { Remove-Item $TmpZip -Force -ErrorAction SilentlyContinue }
        if (Test-Path $TmpExtract) { Remove-Item $TmpExtract -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
# 2. cloudflared.exe
# ---------------------------------------------------------------------------
$CloudflaredExe = Join-Path $BinDir "cloudflared.exe"
if ((Test-Path $CloudflaredExe) -and -not $Force) {
    Write-OK "cloudflared already present"
} else {
    Write-Step "Downloading cloudflared (win-amd64)..."
    $CfUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
    try {
        Invoke-WebRequest -Uri $CfUrl -OutFile $CloudflaredExe -UseBasicParsing
        Write-OK "cloudflared installed: $CloudflaredExe"
    } catch {
        Write-Warn "Failed to download cloudflared: $_"
        throw
    }
}

# ---------------------------------------------------------------------------
# 3. ADB (Android platform-tools) - for Android-MCP
# ---------------------------------------------------------------------------
$AdbDir = Join-Path $BinDir "platform-tools"
$AdbExe = Join-Path $AdbDir "adb.exe"
if ($WithAdb) {
    if ((Test-Path $AdbExe) -and -not $Force) {
        Write-OK "ADB already present"
    } else {
        Write-Step "Downloading ADB platform-tools (Android)..."
        $AdbUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
        $TmpAdb = Join-Path $env:TEMP "adb-$(Get-Random).zip"
        try {
            Invoke-WebRequest -Uri $AdbUrl -OutFile $TmpAdb -UseBasicParsing
            # Zip contains a top-level platform-tools/ folder -> extract into bin/
            Expand-Archive -Path $TmpAdb -DestinationPath $BinDir -Force
            Write-OK "ADB installed: $AdbExe"
        } catch {
            Write-Warn "Failed to download ADB (Android-MCP optional): $_"
        } finally {
            if (Test-Path $TmpAdb) { Remove-Item $TmpAdb -Force -ErrorAction SilentlyContinue }
        }
    }
}

Write-Host ""
Write-OK "All runtimes ready:"
Write-Host "    Node.js:     $NodeDir"
Write-Host "    cloudflared: $CloudflaredExe"
if ($WithAdb -and (Test-Path $AdbExe)) { Write-Host "    ADB:         $AdbExe" }
