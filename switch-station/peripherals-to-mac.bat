@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0switch-peripherals.ps1" -Target mac
timeout /t 2
