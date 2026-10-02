@echo off
cd /d "%~dp0"
powershell -STA -ExecutionPolicy Bypass -File "Main.ps1"
pause