#Requires -Version 5.1
<#
.SYNOPSIS
    Interactive config setup for Hermes Portable messaging platforms.

.DESCRIPTION
    Menu-driven tool to add/edit credentials for:
    - Telegram (bot token + chat ID)
    - WhatsApp (Twilio account)
    - Discord (bot token)
    - Slack (bot token + signing secret)
    - 9router provider (OpenRouter API key)

    Updates: data/.env (MASTER CREDENTIALS FILE)

.PARAMETER EnvPath
    Path to .env file (default: ../data/.env from script location)
#>

param(
    [string]$EnvPath
)

$ErrorActionPreference = "Stop"

# Detect paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrEmpty($EnvPath)) {
    $EnvPath = Join-Path (Split-Path -Parent $ScriptDir) "data\.env"
}

if (-not (Test-Path $EnvPath)) {
    Write-Host "[X] .env file not found at: $EnvPath" -ForegroundColor Red
    Write-Host "    Run INSTALL.bat first to create .env" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Colors
$ColorTitle = "Cyan"
$ColorMenu = "Green"
$ColorInput = "Yellow"
$ColorOK = "Green"
$ColorWarn = "Yellow"

function Show-Menu {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $ColorTitle
    Write-Host " Hermes Portable - Config Setup Tool" -ForegroundColor $ColorTitle
    Write-Host "========================================" -ForegroundColor $ColorTitle
    Write-Host ""
    Write-Host "Manage credentials & API keys" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [1] Telegram (bot token + chat ID)" -ForegroundColor $ColorMenu
    Write-Host "  [2] WhatsApp (Twilio account)" -ForegroundColor $ColorMenu
    Write-Host "  [3] Discord (bot token)" -ForegroundColor $ColorMenu
    Write-Host "  [4] Slack (bot token + signing secret)" -ForegroundColor $ColorMenu
    Write-Host "  [5] 9router Provider (OpenRouter API key)" -ForegroundColor $ColorMenu
    Write-Host "  [6] View current config" -ForegroundColor $ColorMenu
    Write-Host "  [7] Reset credential (remove from .env)" -ForegroundColor $ColorMenu
    Write-Host "  [0] Exit" -ForegroundColor $ColorMenu
    Write-Host ""
}

function Read-EnvValue {
    param([string]$Key)
    $content = Get-Content $EnvPath -Raw
    if ($content -match "^$Key=(.+)$") {
        return ($Matches[1].Trim() -split "`n")[0]
    }
    return ""
}

function Set-EnvValue {
    param([string]$Key, [string]$Value)
    $content = Get-Content $EnvPath -Raw
    if ($content -match "^$Key=") {
        $content = $content -replace "^$Key=.+$", "$Key=$Value"
    } else {
        $content += "`n$Key=$Value"
    }
    Set-Content $EnvPath -Value $content -Encoding UTF8
    Write-Host "[OK] Saved $Key" -ForegroundColor $ColorOK
}

function Setup-Telegram {
    Write-Host ""
    Write-Host "─── Telegram Setup ───" -ForegroundColor $ColorTitle
    Write-Host "Get bot token: https://t.me/BotFather → /newbot" -ForegroundColor Gray
    Write-Host "Get chat ID: https://t.me/userinfobot" -ForegroundColor Gray
    Write-Host ""

    $current = Read-EnvValue "HERMES_TELEGRAM_TOKEN"
    if ($current) { Write-Host "Current token: $($current.Substring(0, 10))..." -ForegroundColor Gray }

    $token = Read-Host "Enter bot token (or press Enter to skip)"
    if ($token) {
        Set-EnvValue "HERMES_TELEGRAM_TOKEN" $token

        $chatId = Read-Host "Enter chat ID"
        if ($chatId) {
            Set-EnvValue "HERMES_TELEGRAM_CHAT_ID" $chatId
            Write-Host "[OK] Telegram configured!" -ForegroundColor $ColorOK
        } else {
            Write-Host "[!] Chat ID required for Telegram" -ForegroundColor $ColorWarn
        }
    } else {
        Write-Host "[!] Telegram skipped" -ForegroundColor $ColorWarn
    }
}

function Setup-WhatsApp {
    Write-Host ""
    Write-Host "─── WhatsApp Setup (Twilio) ───" -ForegroundColor $ColorTitle
    Write-Host "Get credentials: https://console.twilio.com" -ForegroundColor Gray
    Write-Host ""

    $accountSid = Read-Host "Twilio Account SID (or press Enter to skip)"
    if ($accountSid) {
        Set-EnvValue "HERMES_WHATSAPP_ACCOUNT_SID" $accountSid

        $authToken = Read-Host "Twilio Auth Token"
        Set-EnvValue "HERMES_WHATSAPP_AUTH_TOKEN" $authToken

        $phoneId = Read-Host "Twilio Phone Number ID"
        Set-EnvValue "HERMES_WHATSAPP_PHONE_ID" $phoneId

        $allowedNums = Read-Host "Allowed WhatsApp numbers (comma-separated, optional)"
        if ($allowedNums) { Set-EnvValue "HERMES_WHATSAPP_ALLOWED_NUMBERS" $allowedNums }

        Write-Host "[OK] WhatsApp configured!" -ForegroundColor $ColorOK
    } else {
        Write-Host "[!] WhatsApp skipped" -ForegroundColor $ColorWarn
    }
}

function Setup-Discord {
    Write-Host ""
    Write-Host "─── Discord Setup ───" -ForegroundColor $ColorTitle
    Write-Host "Get token: https://discord.com/developers/applications → Bot → Token" -ForegroundColor Gray
    Write-Host ""

    $token = Read-Host "Discord bot token (or press Enter to skip)"
    if ($token) {
        Set-EnvValue "HERMES_DISCORD_TOKEN" $token

        $userIds = Read-Host "Allowed user IDs (comma-separated, optional)"
        if ($userIds) { Set-EnvValue "HERMES_DISCORD_ALLOWED_USER_IDS" $userIds }

        Write-Host "[OK] Discord configured!" -ForegroundColor $ColorOK
    } else {
        Write-Host "[!] Discord skipped" -ForegroundColor $ColorWarn
    }
}

function Setup-Slack {
    Write-Host ""
    Write-Host "─── Slack Setup ───" -ForegroundColor $ColorTitle
    Write-Host "Get token: https://api.slack.com/apps → OAuth Tokens" -ForegroundColor Gray
    Write-Host ""

    $token = Read-Host "Slack bot token (or press Enter to skip)"
    if ($token) {
        Set-EnvValue "HERMES_SLACK_TOKEN" $token

        $signingSecret = Read-Host "Slack Signing Secret"
        Set-EnvValue "HERMES_SLACK_SIGNING_SECRET" $signingSecret

        $userIds = Read-Host "Allowed user IDs (comma-separated, optional)"
        if ($userIds) { Set-EnvValue "HERMES_SLACK_ALLOWED_USER_IDS" $userIds }

        Write-Host "[OK] Slack configured!" -ForegroundColor $ColorOK
    } else {
        Write-Host "[!] Slack skipped" -ForegroundColor $ColorWarn
    }
}

function Setup-Provider {
    Write-Host ""
    Write-Host "─── 9router Provider Setup ───" -ForegroundColor $ColorTitle
    Write-Host "Configure providers in 9router dashboard:" -ForegroundColor Gray
    Write-Host "  → http://localhost:20128" -ForegroundColor Gray
    Write-Host "  → Menu: Providers" -ForegroundColor Gray
    Write-Host "  → Add: OpenRouter / Anthropic / Google / etc" -ForegroundColor Gray
    Write-Host ""

    Write-Host "For reference, enter primary provider here:" -ForegroundColor Gray
    $provider = Read-Host "Provider name (openrouter/anthropic/google, optional)"
    if ($provider) {
        Set-EnvValue "9ROUTER_PRIMARY_PROVIDER" $provider
    }
}

function Show-Config {
    Write-Host ""
    Write-Host "─── Current Configuration ───" -ForegroundColor $ColorTitle
    $content = Get-Content $EnvPath -Raw
    $essential = @("HERMES_API_KEY", "HERMES_TELEGRAM_TOKEN", "HERMES_WHATSAPP_ACCOUNT_SID", "HERMES_DISCORD_TOKEN", "HERMES_SLACK_TOKEN", "9ROUTER_PRIMARY_PROVIDER")

    foreach ($key in $essential) {
        $value = Read-EnvValue $key
        if ($value) {
            $masked = if ($value.Length -gt 10) { "$($value.Substring(0, 10))..." } else { $value }
            Write-Host "  $key = $masked" -ForegroundColor $ColorOK
        } else {
            Write-Host "  $key = (not set)" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

function Reset-Credential {
    Write-Host ""
    Write-Host "─── Reset Credential ───" -ForegroundColor $ColorTitle
    $key = Read-Host "Enter key name to remove (e.g., HERMES_TELEGRAM_TOKEN)"

    $content = Get-Content $EnvPath -Raw
    $content = $content -replace "^$key=.+`n", ""
    Set-Content $EnvPath -Value $content -Encoding UTF8
    Write-Host "[OK] Removed $key" -ForegroundColor $ColorOK
}

# Main loop
while ($true) {
    Show-Menu
    $choice = Read-Host "Select option"

    switch ($choice) {
        "1" { Setup-Telegram }
        "2" { Setup-WhatsApp }
        "3" { Setup-Discord }
        "4" { Setup-Slack }
        "5" { Setup-Provider }
        "6" { Show-Config }
        "7" { Reset-Credential }
        "0" {
            Write-Host ""
            Write-Host "Exiting. Changes saved to: $EnvPath" -ForegroundColor $ColorOK
            exit 0
        }
        default { Write-Host "[!] Invalid option" -ForegroundColor $ColorWarn }
    }
}
