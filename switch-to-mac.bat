@echo off
REM switch-to-mac.bat — Launcher para trocar estacao pro Mac
REM Pode ser criado atalho na taskbar ou executado via Win+R
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0switch-to-mac.ps1"
timeout /t 3
