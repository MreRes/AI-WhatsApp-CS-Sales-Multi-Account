#Requires -Version 5.1
<#
.SYNOPSIS
    Master installer for hermes-portable bundle (run ONCE).

.DESCRIPTION
    One-time setup that provisions everything needed for plug-and-play:
      1. Download portable Node.js + cloudflared (download_runtimes.ps1)
      2. Install uv + provision Python 3.13 venv
      3. Build 9router (npm install + npm run build)
      4. Install Hermes (uv pip install .[portable-windows])
      5. Run setup wizard (generate .env + config.yaml)
      6. Write data/.installed flag

    Idempotent: re-running verifies/repairs without redoing finished steps.

.PARAMETER Force
    Force re-run of all steps even if already installed.

.PARAMETER SkipWizard
    Skip interactive setup wizard (use -Auto config defaults).
#>

param(
    [switch]$Force,
    [switch]$SkipWizard
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$InstallerDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot   = Split-Path -Parent $InstallerDir
$RuntimeDir   = Join-Path $BundleRoot "runtime"
$NodeDir      = Join-Path $RuntimeDir "node"
$BinDir       = Join-Path $RuntimeDir "bin"
$ServicesDir  = Join-Path $BundleRoot "services"
$Router9Dir   = Join-Path $ServicesDir "9router"
$HermesDir    = Join-Path $ServicesDir "hermes"
$DataDir      = Join-Path $BundleRoot "data"
$VenvDir      = Join-Path $DataDir ".venv"
$ConfigDir    = Join-Path $BundleRoot "portable-config"
$InstalledFlag = Join-Path $DataDir ".installed"

$NodeExe = Join-Path $NodeDir "node.exe"
$NpmCmd  = Join-Path $NodeDir "npm.cmd"

function Write-Header { param($t) Write-Host ""; Write-Host "=============================================" -ForegroundColor Cyan; Write-Host " $t" -ForegroundColor Cyan; Write-Host "=============================================" -ForegroundColor Cyan }
function Write-Step { Write-Host "==> $args" -ForegroundColor Cyan }
function Write-OK   { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[!] $args" -ForegroundColor Yellow }
function Write-Err  { Write-Host "[X] $args" -ForegroundColor Red }

Write-Header "Hermes Portable Installer"

# Already installed?
if ((Test-Path $InstalledFlag) -and -not $Force) {
    Write-OK "Bundle already installed (found data/.installed)."
    Write-Host "    Run START.bat to launch, or pass -Force to reinstall."
    exit 0
}

# Ensure data dir
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Force -Path $DataDir | Out-Null }
foreach ($d in @((Join-Path $DataDir "logs"), (Join-Path $DataDir "9router"))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

# ---------------------------------------------------------------------------
# Step 1: Download runtimes (Node + cloudflared)
# ---------------------------------------------------------------------------
Write-Header "Step 1/6: Provision runtimes"
$DownloadScript = Join-Path $InstallerDir "download_runtimes.ps1"
if ($Force) {
    & $DownloadScript -Force
} else {
    & $DownloadScript
}
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { Write-Err "Runtime download failed"; exit 1 }

# ---------------------------------------------------------------------------
# Step 2: Install uv + Python venv
# ---------------------------------------------------------------------------
Write-Header "Step 2/6: Python environment (uv)"
$UvExe = Join-Path $BinDir "uv.exe"
if (-not (Test-Path $UvExe)) {
    Write-Step "Installing uv..."
    $UvZip = "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip"
    $TmpUv = Join-Path $env:TEMP "uv-$(Get-Random).zip"
    Invoke-WebRequest -Uri $UvZip -OutFile $TmpUv -UseBasicParsing
    Expand-Archive -Path $TmpUv -DestinationPath $BinDir -Force
    Remove-Item $TmpUv -Force -ErrorAction SilentlyContinue
}
Write-OK "uv ready: $(& $UvExe --version)"

# Isolate uv/python under data
$env:UV_CACHE_DIR = Join-Path $DataDir ".uv_cache"
$env:UV_PYTHON_INSTALL_DIR = Join-Path $DataDir ".python"
$env:UV_PROJECT_ENVIRONMENT = $VenvDir
$env:UV_PYTHON = "3.13"

Write-Step "Installing bundle-internal Python 3.13 (portable)..."
# Install Python INSIDE the bundle (UV_PYTHON_INSTALL_DIR = data/.python) so the
# whole hermes-portable folder is self-contained and movable. Without this the
# venv links to a system/parent Python and breaks when the bundle is relocated.
& $UvExe python install 3.13
# --relocatable makes the venv's console scripts (hermes.exe etc.) resolve their
# Python relative to the venv, so moving the bundle to another drive/path works.
Write-Step "Creating portable Python venv (--relocatable)..."
& $UvExe venv $VenvDir --python 3.13 --relocatable
Write-OK "Python venv ready (portable, bundle-internal): $VenvDir"

# ---------------------------------------------------------------------------
# Step 3: Install 9router (official npm package - prebuilt + self-updating)
# ---------------------------------------------------------------------------
# We use the published `9router` npm package rather than building from source.
# Why: it ships prebuilt (installs in ~15s vs a multi-minute Next.js/turbopack
# build that broke on tailwind/postcss + Windows file-tracing EPERM), and it
# auto-updates to the latest version on its own. START.bat also refreshes it
# to @latest on each boot, so the user always runs the newest 9router.
Write-Header "Step 3/6: Install 9router (npm package, auto-updating)"
$Router9AppDir = Join-Path $RuntimeDir "9router-app"
$Router9Cli    = Join-Path $Router9AppDir "node_modules\9router\cli.js"
if (-not (Test-Path $Router9AppDir)) { New-Item -ItemType Directory -Force -Path $Router9AppDir | Out-Null }

$env:npm_config_cache = Join-Path $DataDir ".npm"
Remove-Item Env:\NODE_ENV -ErrorAction SilentlyContinue
Write-Step "Installing 9router@latest (prebuilt, no build step)..."
& $NpmCmd install 9router@latest --prefix $Router9AppDir --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { Write-Err "9router install failed (exit $LASTEXITCODE)"; exit 1 }
if (-not (Test-Path $Router9Cli)) { Write-Err "9router cli.js missing after install"; exit 1 }
$Router9Ver = (Get-Content (Join-Path $Router9AppDir "node_modules\9router\package.json") -Raw | ConvertFrom-Json).version
Write-OK "9router $Router9Ver installed (auto-updates on each START)"

# --- SQLite driver fix (critical) -------------------------------------------
# 9router's native better-sqlite3 is built for a newer Node ABI (MODULE_VERSION
# 137 / Node 23+) than our portable Node 22 (127), so it fails to load. node:sqlite
# doesn't exist in Node 22 either. The pure-WASM sql.js fallback works on ANY
# Node version - but the npm package ships WITHOUT the sql-wasm.wasm binary, so
# 9router crashes with "No SQLite driver available" (HTTP 500 on every request).
# Fix: drop the wasm into 9router's bundled sql.js so the WASM fallback works.
$SqlJsDist = Join-Path $Router9AppDir "node_modules\9router\app\node_modules\sql.js\dist"
$WasmDst   = Join-Path $SqlJsDist "sql-wasm.wasm"
if ((Test-Path $SqlJsDist) -and -not (Test-Path $WasmDst)) {
    Write-Step "Providing sql.js WASM (9router SQLite fallback)..."
    $SqlTmp = Join-Path $DataDir ".sqljs_tmp"
    if (-not (Test-Path $SqlTmp)) { New-Item -ItemType Directory -Force -Path $SqlTmp | Out-Null }
    & $NpmCmd install sql.js@1.14.1 --prefix $SqlTmp --no-audit --no-fund --silent 2>$null
    $WasmSrc = Join-Path $SqlTmp "node_modules\sql.js\dist\sql-wasm.wasm"
    if (Test-Path $WasmSrc) {
        Copy-Item $WasmSrc $WasmDst -Force
        Write-OK "sql.js WASM installed -> 9router SQLite works on Node $((& $NodeExe -v))"
    } else {
        Write-Warn "Could not fetch sql.js WASM - 9router DB may fail. Re-run with internet."
    }
    Remove-Item $SqlTmp -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Step 4: Install Hermes (Python service) + embedded MCP deps (OS-aware)
# ---------------------------------------------------------------------------
Write-Header "Step 4/6: Install Hermes + MCPs"
if (-not (Test-Path $HermesDir)) {
    Write-Warn "Hermes source not found at $HermesDir"
    Write-Warn "Copy hermes core into services/hermes/ before installing."
} else {
    # Always include Windows-MCP + Android-MCP extras on a Windows host.
    # macOS-MCP extra is platform-guarded in pyproject (pyobjc; sys_platform=='darwin'),
    # so requesting it on Windows is a safe no-op rather than a build failure.
    Write-Step "Installing Hermes with [portable-windows] + [portable-android] extras..."
    Push-Location $HermesDir
    try {
        # Editable install keeps hermes_agent pointed at the source tree, so ALL runtime
        # data ships intact (web_dist, locales, skills, plugin manifests). A NON-editable
        # install would copy only files declared in pyproject's packages.find/package-data
        # — and `locales/` is NOT declared, so it would silently drop i18n and reintroduce
        # the raw-key bug. We get drive-independence a different, safe way: see the
        # relative-path .pth rewrite below (post-install).
        & $UvExe pip install --python $VenvDir -e ".[portable-windows]" -e ".[portable-android]"
        # Extra deps not always pulled by the extras but required at runtime:
        #   posthog     -> windows_mcp analytics import (else MCP crashes on load)
        #   edge-tts    -> tts toolset voice output
        #   firecrawl-py-> web/search backend
        & $UvExe pip install --python $VenvDir "posthog" "edge-tts==7.2.7" "firecrawl-py==4.17.0" "discord.py[voice]==2.7.1"
        Write-OK "Hermes + Windows-MCP + Android-MCP deps installed"
    } catch {
        Write-Err "Hermes install failed: $_"
        Pop-Location
        exit 1
    }
    Pop-Location

    # --- Make the editable install DRIVE-INDEPENDENT -----------------------------------
    # uv's editable install writes __editable__.hermes_agent-<ver>.pth + a *_finder.py whose
    # MAPPING hardcodes the absolute path to services\hermes (bakes D:\). We replace that with
    # a self-locating loader that resolves paths RELATIVE to its own file location, so the
    # bundle imports correctly on any drive letter / folder. The dist-info (and thus the
    # hermes.exe entry point) is left untouched. The same loader also wires embedded-mcps,
    # so `python -m windows_mcp` works even without the orchestrator's PYTHONPATH.
    try {
        $siteDir = Join-Path $VenvDir "Lib\site-packages"
        Get-ChildItem $siteDir -Filter "__editable__*hermes_agent*" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        $staleEmbed = Join-Path $siteDir "hermes-embedded-mcps.pth"
        if (Test-Path $staleEmbed) { Remove-Item $staleEmbed -Force -ErrorAction SilentlyContinue }

        $loaderPy = @'
# _hermes_portable_paths.py - drive/location-independent sys.path wiring (portable bundle).
# Resolves services/hermes + embedded-mcps RELATIVE to THIS file, which lives in
# <bundle>/data/.venv/Lib/site-packages. No absolute drive path is stored anywhere, so the
# bundle works from any drive letter or folder as long as its internal layout is intact.
import os, sys
_here = os.path.dirname(os.path.abspath(__file__))
# site-packages -> Lib -> .venv -> data -> <bundle>
_bundle = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(_here))))
for _p in (os.path.join(_bundle, "services", "hermes"),
           os.path.join(_bundle, "embedded-mcps")):
    if os.path.isdir(_p) and _p not in sys.path:
        sys.path.insert(0, _p)
'@
        Set-Content -Path (Join-Path $siteDir "_hermes_portable_paths.py") -Value $loaderPy -Encoding ascii
        # .pth lines starting with "import" are executed at interpreter startup.
        Set-Content -Path (Join-Path $siteDir "_hermes_portable.pth") -Value "import _hermes_portable_paths" -Encoding ascii
        Write-OK "Editable install made drive-independent (relative path loader)"
    } catch { Write-Warn "Could not write portable path loader: $_" }

    # Verify embedded MCP source trees are present (copied during bundling).
    $EmbeddedDir = Join-Path $BundleRoot "embedded-mcps"
    foreach ($mcp in @("windows_mcp", "android_mcp", "macos_mcp")) {
        $mcpPath = Join-Path $EmbeddedDir $mcp
        if (Test-Path $mcpPath) {
            Write-OK "Embedded MCP present: $mcp"
        } else {
            Write-Warn "Embedded MCP source missing: $mcp (copy before bundling)"
        }
    }
    Write-Host "    Note: macOS-MCP only activates when this bundle runs on macOS." -ForegroundColor Gray
    Write-Host "    Note: Android-MCP activates when an Android device is connected (adb)." -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
# Step 5: Setup wizard (9router + API key collection + Hermes config)
# ---------------------------------------------------------------------------
Write-Header "Step 5/6: Interactive Setup (9router + Credentials)"
$WizardScript = Join-Path $BundleRoot "setup-portable.ps1"
if (Test-Path $WizardScript) {
    Write-Step "Launching setup wizard..."
    Write-Warn "This will:"
    Write-Warn "  1. Start 9router (may take 30-60 seconds)"
    Write-Warn "  2. Prompt you to configure provider in 9router dashboard"
    Write-Warn "  3. Collect API key from 9router"
    Write-Warn "  4. Generate Hermes config"
    Write-Host ""

    if ($SkipWizard) {
        Write-Step "Running auto setup (demo mode)..."
        & $WizardScript -Mode Auto
    } else {
        & $WizardScript -Mode Interactive
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Setup wizard failed. Check error messages above."
        exit 1
    }
    Write-OK "Setup wizard completed"
} else {
    Write-Err "Setup wizard not found at $WizardScript"
    exit 1
}

# ---------------------------------------------------------------------------
# Step 6: Mark installed
# ---------------------------------------------------------------------------
Write-Header "Step 6/6: Finalize"
$InstallInfo = @{
    installed_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    node_version = (& $NodeExe --version)
    bundle_root  = $BundleRoot
} | ConvertTo-Json
Set-Content -Path $InstalledFlag -Value $InstallInfo -Encoding UTF8
Write-OK "Installation complete!"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " Ready! Run START.bat to launch everything." -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Services that will start:"
Write-Host "    - 9router   (LLM gateway)  -> http://localhost:20128"
Write-Host "    - Hermes    (AI agent)     -> http://localhost:9119"
Write-Host "    - Cloudflare tunnels       -> public URLs printed at startup"
Write-Host ""
