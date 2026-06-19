@echo off
REM ===========================================================
REM  Hermes Portable - Interactive Config Tool
REM  Manage: Telegram, WhatsApp, Discord, Slack, Providers
REM ===========================================================
setlocal
set SCRIPT_DIR=%~dp0

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%portable-config\config-setup.ps1"

if errorlevel 1 (
    echo.
    echo  [X] Config setup failed.
    echo.
    pause
    exit /b 1
)

echo.
echo  [OK] Config updated. Changes saved to data\.env
echo.
pause
endlocal
