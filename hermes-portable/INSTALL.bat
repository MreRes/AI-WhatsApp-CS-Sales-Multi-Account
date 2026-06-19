@echo off
REM ===========================================================
REM  Hermes Portable - ONE-TIME INSTALLER
REM  Double-click this once to install everything.
REM ===========================================================

setlocal
set SCRIPT_DIR=%~dp0

echo.
echo  ===========================================================
echo   Hermes Portable Installer
echo   This will download and set up:
echo     - Portable Node.js (for 9router)
echo     - Python environment (for Hermes)
echo     - cloudflared (for internet tunneling)
echo     - Build 9router + install Hermes
echo  ===========================================================
echo.
echo  This runs ONCE. After this, just use START.bat.
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%installer\install.ps1" %*

if errorlevel 1 (
    echo.
    echo  [X] Installation failed. See messages above.
    echo.
    pause
    exit /b 1
)

echo.
echo  [OK] Installation complete!
echo  Next: double-click START.bat to launch.
echo.
pause
endlocal
