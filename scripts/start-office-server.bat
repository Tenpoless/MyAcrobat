@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-office-server.ps1" %*
endlocal
