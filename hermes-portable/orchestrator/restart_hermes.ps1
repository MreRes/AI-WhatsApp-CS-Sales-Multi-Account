$HermesExe = "D:\hermes-agent-main\hermes-portable\data\.venv\Scripts\hermes.exe"
$HermesDir = "D:\hermes-agent-main\hermes-portable\services\hermes"
$DataDir = "D:\hermes-agent-main\hermes-portable\data"
$LogsDir = "D:\hermes-agent-main\hermes-portable\data\logs"
$HermesPort = 9119
$BundleRoot = "D:\hermes-agent-main\hermes-portable"

$env:HERMES_HOME = $DataDir
$env:HERMES_PORTABLE = "true"
$EmbeddedMcps = Join-Path $BundleRoot "embedded-mcps"
$env:PYTHONPATH = "$EmbeddedMcps;$env:PYTHONPATH"

$HermesLog = Join-Path $LogsDir "hermes.log"
$HermesErr = Join-Path $LogsDir "hermes.err.log"

$p = Start-Process -FilePath $HermesExe `
    -ArgumentList "dashboard", "--port", "$HermesPort", "--host", "127.0.0.1", "--no-open", "--skip-build" `
    -WorkingDirectory $HermesDir -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $HermesLog -RedirectStandardError $HermesErr
Write-Host "Dashboard PID: $($p.Id)"

$GatewayLog = Join-Path $LogsDir "gateway.log"
$GatewayErr = Join-Path $LogsDir "gateway.err.log"
$g = Start-Process -FilePath $HermesExe `
    -ArgumentList "gateway", "run", "--accept-hooks" `
    -WorkingDirectory $HermesDir -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $GatewayLog -RedirectStandardError $GatewayErr
Write-Host "Gateway PID: $($g.Id)"
