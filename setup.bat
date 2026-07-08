@echo off
:: R6 + Overwolf Launcher — Setup (eseguire una volta sola / run once)
:: Puoi aprire questo file per verificare: fa solo questo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
if %errorlevel% neq 0 pause
