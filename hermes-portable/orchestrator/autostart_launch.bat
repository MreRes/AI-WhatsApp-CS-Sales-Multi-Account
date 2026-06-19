@echo off
REM Logon auto-start launcher (called by the scheduled task). Single quoted path
REM in the task action -> no schtasks quoting issues. Waits, then runs orchestrator.
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0autostart_launch.ps1" -DelaySeconds 20
