@echo off
setlocal
echo Phi Chat setup
echo.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" %*
set "PhiChatSetupExit=%errorlevel%"
if "%~1"=="" (
    echo.
    if "%PhiChatSetupExit%"=="0" (
        echo Setup completed. You can also open Phi Chat from its desktop shortcut.
    ) else (
        echo Setup stopped. Review the message above for details.
    )
    echo Press any key to close setup.
    pause >nul
)
exit /b %PhiChatSetupExit%
