@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0send.ps1"
timeout /t 2
