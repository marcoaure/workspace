@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0split-screen.ps1"
timeout /t 2
