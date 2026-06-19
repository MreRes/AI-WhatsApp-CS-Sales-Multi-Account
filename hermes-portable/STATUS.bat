@echo off
REM Hermes Portable - show health/status (observability)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0orchestrator\status.ps1"
pause
