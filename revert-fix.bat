@echo off
REM Double-click this to undo the fix and restore the hardware cursor.
REM WARNING: if your driver still has the bug, the bright cursor comes back.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0revert-fix.ps1"
echo.
pause
