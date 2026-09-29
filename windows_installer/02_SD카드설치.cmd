@echo off
setlocal
if not exist "%~dp0support\launcher.ps1" (
  echo Please extract all files before running.
  echo 먼저 모든 파일의 압축을 푼 뒤 실행해 주세요.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0support\launcher.ps1" -Stage Install
set "RESULT=%ERRORLEVEL%"
if %RESULT% neq 0 (
  echo.
  pause
)
exit /b %RESULT%
