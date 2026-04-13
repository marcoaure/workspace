@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0switch-peripherals.ps1" -Target windows
timeout /t 2
