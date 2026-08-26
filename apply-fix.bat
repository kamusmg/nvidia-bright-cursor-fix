@echo off
REM Double-click this to fix the washed-out / too bright mouse cursor.
REM No admin needed. Applies instantly - no reboot, no closing your game.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply-fix.ps1"
echo.
pause
