@echo off
REM Hermes Portable - enable/disable auto-start at logon.
REM   AUTOSTART.bat            -> enable
REM   AUTOSTART.bat -Disable   -> disable
REM   AUTOSTART.bat -Status    -> check
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\autostart-setup.ps1" %*
pause
