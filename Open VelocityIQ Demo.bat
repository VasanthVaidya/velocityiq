@echo off
REM ============================================================
REM  VelocityIQ - The Used Car Profit Engine
REM  One-click demo launcher (Windows)
REM ============================================================
title VelocityIQ - Used Car Profit Engine
cd /d "%~dp0"

if not exist "velocityiq.html" (
  echo.
  echo   Could not find velocityiq.html next to this launcher.
  echo   Please keep "Open VelocityIQ Demo.bat" and "velocityiq.html"
  echo   together in the same folder.
  echo.
  pause
  exit /b 1
)

echo.
echo   Launching the VelocityIQ demo in your default browser...
echo.
start "" "%~dp0velocityiq.html"
exit /b 0

