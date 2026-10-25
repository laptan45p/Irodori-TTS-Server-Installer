@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcher.ps1" -Mode SelectModel
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" echo Failed. See the error above and logs folder.
pause
exit /b %RESULT%
