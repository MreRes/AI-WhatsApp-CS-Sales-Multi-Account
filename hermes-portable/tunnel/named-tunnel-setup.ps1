#Requires -Version 5.1
<#
.SYNOPSIS
    One-time setup for a STABLE named Cloudflare tunnel (fixed URL + uptime),
    replacing the random/ephemeral trycloudflare quick tunnels.

.DESCRIPTION
    Walks you through:
      1. cloudflared login   (browser auth to your free Cloudflare account)
      2. tunnel create        (creates a persistent tunnel + credentials)
      3. DNS route            (maps your hostnames to the tunnel)
      4. writes data/cloudflared/config.yml mapping:
            hermes.<domain>  -> http://localhost:9119   (Hermes dashboard/gateway)
            router.<domain>  -> http://localhost:20128  (9router)
    After this, START.bat auto-detects the named tunnel and uses it instead of
    quick tunnels - same URL every time, with Cloudflare uptime.

    Requires: a free Cloudflare account + a domain added to Cloudflare (the
    domain's nameservers must point to Cloudflare; adding a domain is free).

.PARAMETER Domain
    Your Cloudflare-managed domain, e.g. example.com
.PARAMETER TunnelName
    Name for the tunnel (default: hermes-portable)
.PARAMETER Subdomain
    Hostname prefix for Hermes (default: hermes -> hermes.<domain>); 9router gets router.<domain>
#>

param(
    [Parameter(Mandatory=$true)][string]$Domain,
    [string]$TunnelName = "hermes-portable",
    [string]$Subdomain = "hermes"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BundleRoot = Split-Path -Parent $ScriptDir
$CfExe = Join-Path $BundleRoot "runtime\bin\cloudflared.exe"
$CfDir = Join-Path $BundleRoot "data\cloudflared"
$ConfigYml = Join-Path $CfDir "config.yml"

function Step($t){ Write-Host "==> $t" -ForegroundColor Cyan }
function OK($t){ Write-Host "[OK] $t" -ForegroundColor Green }

if (-not (Test-Path $CfExe)) { Write-Host "[X] cloudflared not found. Run INSTALL.bat first." -ForegroundColor Red; exit 1 }
New-Item -ItemType Directory -Force -Path $CfDir | Out-Null

# cloudflared stores creds/cert under this dir when we point HOME there.
$env:CLOUDFLARED_HOME = $CfDir
$HermesHost = "$Subdomain.$Domain"
$RouterHost = "router.$Domain"

Step "1/4 Login to Cloudflare (a browser window will open - pick your domain)..."
& $CfExe tunnel --origincert (Join-Path $CfDir "cert.pem") login
if (-not (Test-Path (Join-Path $CfDir "cert.pem"))) {
    # cloudflared may save cert to default ~/.cloudflared - copy it over
    $defaultCert = Join-Path $env:USERPROFILE ".cloudflared\cert.pem"
    if (Test-Path $defaultCert) { Copy-Item $defaultCert (Join-Path $CfDir "cert.pem") -Force }
}
OK "Logged in"

Step "2/4 Creating tunnel '$TunnelName'..."
& $CfExe tunnel --origincert (Join-Path $CfDir "cert.pem") create $TunnelName
# Find the credentials json (UUID.json) cloudflared just wrote
$credJson = Get-ChildItem -Path $CfDir, (Join-Path $env:USERPROFILE ".cloudflared") -Filter "*.json" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $credJson) { Write-Host "[X] Tunnel credentials json not found." -ForegroundColor Red; exit 1 }
Copy-Item $credJson.FullName (Join-Path $CfDir $credJson.Name) -Force -ErrorAction SilentlyContinue
$tunnelId = [System.IO.Path]::GetFileNameWithoutExtension($credJson.Name)
OK "Tunnel created: $tunnelId"

Step "3/4 Routing DNS: $HermesHost + $RouterHost -> tunnel..."
& $CfExe tunnel --origincert (Join-Path $CfDir "cert.pem") route dns $TunnelName $HermesHost
& $CfExe tunnel --origincert (Join-Path $CfDir "cert.pem") route dns $TunnelName $RouterHost
OK "DNS routed"

Step "4/4 Writing $ConfigYml ..."
# NOTE: credentials-file is written absolute here, but start_all.ps1 REWRITES it to the
# current bundle location on every boot (portability guard) — so moving the bundle to
# another drive/PC still works. The Hermes ingress carries httpHostHeader so the dashboard
# (which validates Host against 127.0.0.1:9119, no --trust-proxy) accepts tunnel requests.
$cfgContent = @"
tunnel: $tunnelId
credentials-file: $(Join-Path $CfDir $credJson.Name)

ingress:
  - hostname: $HermesHost
    service: http://localhost:9119
    originRequest:
      httpHostHeader: 127.0.0.1:9119
  - hostname: $RouterHost
    service: http://localhost:20128
  - service: http_status:404
"@
Set-Content -Path $ConfigYml -Value $cfgContent -Encoding UTF8
OK "Config written"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " Named tunnel ready!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "  Hermes : https://$HermesHost"
Write-Host "  9router: https://$RouterHost"
Write-Host ""
Write-Host "  START.bat will now auto-use this stable tunnel (same URL every time)."
Write-Host "  These URLs are permanent and backed by Cloudflare uptime."
