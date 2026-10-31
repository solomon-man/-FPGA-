@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build.ps1"
if errorlevel 1 (
  echo Build failed. Read the log printed above.
  pause
  exit /b 1
)
echo Build passed. Download build\demo.bit.
pause
