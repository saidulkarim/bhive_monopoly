@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-bHiVE-Monopoly.ps1" %*
if errorlevel 1 (
    echo.
    echo The launcher reported an error. See the messages above.
    pause
)
endlocal
