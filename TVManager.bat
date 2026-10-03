@echo off
cd /d "%~dp0"
start "" powershell -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "Main.ps1"
exit