@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\backup-samurai.ps1"
set "BACKUP_EXIT=%ERRORLEVEL%"

echo.
if not "%BACKUP_EXIT%"=="0" (
  echo Backup stopped with exit code %BACKUP_EXIT%.
) else (
  echo Samurai private recovery backup completed.
)
pause
exit /b %BACKUP_EXIT%
