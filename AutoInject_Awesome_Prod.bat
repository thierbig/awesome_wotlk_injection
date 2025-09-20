@echo off
REM Production mode injector - minimal verbose output
REM Set environment variable to disable verbose logging
set AWESOME_VERBOSE=0

echo Starting injection in production mode (minimal logging)...
echo.

REM Run the injector with Ascension.exe as target
"%~dp0build\Release\AwesomeWotlkInjector.exe" "Ascension.exe"

echo.
echo Injection process completed.

REM Clean up environment variable
set AWESOME_VERBOSE=

REM Pause to see results
pause
