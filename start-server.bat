@echo off
title VUO CSC HELP Server (Port 3000)
cd /d "%~dp0"
echo ============================================================
echo Starting VUO CSC HELP Server at http://localhost:3000
echo ============================================================
start "" "http://localhost:3000/#admin"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
pause
