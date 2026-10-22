@echo off
setlocal
title Obsill setup

set "ROOT=%~dp0"
set "PS1=%ROOT%src\Setup-Obsill.ps1"

if not exist "%PS1%" (
    echo [ERROR] Could not find "%PS1%".
    echo Keep setup_obsill.bat in the Obsill folder, next to the "src" folder.
    echo.
    pause
    exit /b 1
)

echo Starting Obsill setup...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%PS1%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo Done. The setup log is in the "logs" folder: setup.log
) else (
    echo Setup did not complete ^(exit code %RC%^). Details: logs\setup.log
)
echo.
pause
endlocal & exit /b %RC%
