@echo off
chcp 65001 >nul
title SAHA 3D - local server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"
if errorlevel 1 pause
