#Requires -Version 5.1
<#
.SYNOPSIS
    Send Telegram message with public tunnel URLs when Hermes boots.

.PARAMETER Message
    Message text to send.

.PARAMETER TelegramToken
    Telegram bot token (from setup wizard).

.PARAMETER ChatId
    Telegram chat ID (from setup wizard).

.OUTPUTS
    Returns $true if message sent, $false if credentials missing.
#>

param(
    [string]$Message,
    [string]$TelegramToken,
    [string]$ChatId
)

function Send-TelegramMessage {
    param(
        [string]$Text,
        [string]$BotToken,
        [string]$ChatId
    )

    if ([string]::IsNullOrWhiteSpace($BotToken) -or [string]::IsNullOrWhiteSpace($ChatId)) {
        Write-Host "[!] Telegram not configured (skipping notification)" -ForegroundColor Yellow
        return $false
    }

    $Uri = "https://api.telegram.org/bot$BotToken/sendMessage"
    $Body = @{
        chat_id = $ChatId
        text    = $Text
        parse_mode = "HTML"
    } | ConvertTo-Json

    try {
        $response = Invoke-WebRequest -Uri $Uri -Method Post -ContentType "application/json" -Body $Body -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "[OK] Telegram notification sent" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "[!] Failed to send Telegram message: $_" -ForegroundColor Yellow
        return $false
    }

    return $false
}

# Send the message if both credentials provided
Send-TelegramMessage -Text $Message -BotToken $TelegramToken -ChatId $ChatId
