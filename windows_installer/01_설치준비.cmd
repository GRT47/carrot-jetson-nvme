@echo off
chcp 65001 >nul
if not exist "%~dp0support\launcher.ps1" (
  echo 먼저 모두 압축을 풀어 주세요.
  echo Extract all files before running.
  echo 아무 키나 누르면 닫습니다.
  echo Press any key to close.
  pause >nul
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0support\launcher.ps1" -Stage Prepare
set "RESULT=%ERRORLEVEL%"
echo 아무 키나 누르면 닫습니다.
echo Press any key to close.
pause >nul
exit /b %RESULT%
