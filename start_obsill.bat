@echo off
setlocal
rem Starts Obsill with AutoHotkey v2 (not v1, even if both are installed).
rem Set the environment variable OBSILL_AHK to a full path to use a portable AutoHotkey v2.

set "SCRIPT=%~dp0src\Obsill.ahk"

set "AHK=%OBSILL_AHK%"
if defined AHK if exist "%AHK%" goto :found
set "AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
if exist "%AHK%" goto :found
set "AHK=%ProgramFiles%\AutoHotkey\v2\AutoHotkey32.exe"
if exist "%AHK%" goto :found
set "AHK=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if exist "%AHK%" goto :found
set "AHK=%LocalAppData%\Programs\AutoHotkey\v2\AutoHotkey32.exe"
if exist "%AHK%" goto :found

echo AutoHotkey v2 was not found.
echo Install it from https://www.autohotkey.com and try again.
echo.
pause
exit /b 1

:found
start "" "%AHK%" "%SCRIPT%"
exit /b 0
