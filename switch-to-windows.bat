@echo off
REM switch-to-windows.bat — Emergencia: volta monitores pro Windows
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0switch-to-mac.ps1" -Reverse
timeout /t 3
