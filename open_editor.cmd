@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\csharp\open_editor.ps1" %*
if errorlevel 1 (
    echo Editor startup failed. See the build errors above.
    pause
    exit /b 1
)
