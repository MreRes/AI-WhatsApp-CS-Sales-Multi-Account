@echo off
REM ===========================================================
REM  Hermes Portable - START all services (ONE start)
REM  Starts: 9router + Hermes + Cloudflare tunnels
REM ===========================================================
setlocal
set SCRIPT_DIR=%~dp0

REM Auto-install if not yet installed
if not exist "%SCRIPT_DIR%data\.installed" (
    echo.
    echo  [*] Not installed yet - running installer first...
    echo.
    call "%SCRIPT_DIR%INSTALL.bat"
    if errorlevel 1 exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%orchestrator\start_all.ps1" %*

if errorlevel 1 (
    echo.
    echo  [X] Startup failed. Check data\logs\ for details.
    echo.
    pause
    exit /b 1
)

echo.
echo  Services are running in the background.
echo  Public URLs shown above (also saved to data\tunnel_urls.txt).
echo.
pause
endlocal
