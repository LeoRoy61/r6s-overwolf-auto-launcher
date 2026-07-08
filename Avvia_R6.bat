@echo off
:: R6 + Overwolf Launcher — avvia Avvia_R6.ps1
:: Puoi aprire questo file per verificare: fa solo questo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Avvia_R6.ps1"
if %errorlevel% neq 0 pause
