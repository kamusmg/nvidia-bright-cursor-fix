@echo off
REM Double-click this to collect every relevant measurement.
REM Read-only - this changes nothing on your system.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnose.ps1"
echo.
pause
