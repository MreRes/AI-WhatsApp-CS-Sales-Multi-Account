@echo off
REM ===========================================================
REM  Hermes Portable - STOP all services
REM ===========================================================
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%orchestrator\stop_all.ps1"
endlocal
