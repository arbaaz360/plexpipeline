@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-samurai.ps1"
set "SETUP_EXIT=%ERRORLEVEL%"

echo.
if not "%SETUP_EXIT%"=="0" (
  echo Setup stopped with exit code %SETUP_EXIT%.
  echo Read the message above, then run Setup-Samurai.cmd again.
) else (
  echo Samurai setup completed.
)
pause
exit /b %SETUP_EXIT%
