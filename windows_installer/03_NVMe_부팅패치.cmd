@echo off
setlocal
if not exist "%~dp0support\patch_nvme_live.ps1" (
  echo Please extract all files before running.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0support\patch_nvme_live.ps1"
set "RESULT=%ERRORLEVEL%"
if %RESULT% neq 0 (
  echo.
  pause
)
exit /b %RESULT%
