@echo off
title Awesome WotLK Injector - Debug Mode
color 0A

echo.
echo ================================================
echo    AWESOME WOTLK INJECTOR - DEBUG MODE
echo    Full Logging + File Output Enabled
echo ================================================
echo.

:: Create logs directory if it doesn't exist
if not exist "logs" mkdir logs

:: Generate timestamp for log file
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "timestamp=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

echo [INFO] Debug mode enabled - all output will be saved to:
echo [INFO] logs\injection_log_%timestamp%.txt
echo.

echo [INFO] You can start this BEFORE the game if you want
echo [INFO] The injector will wait for the game to start and for you to enter world
echo.

:check_process
echo [INFO] Checking for target processes...

:: Check if target processes are running
tasklist /FI "IMAGENAME eq Project Epoch.exe" 2>NUL | find /I /N "Project Epoch.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [SUCCESS] Found Project Epoch.exe
    goto :inject
)

tasklist /FI "IMAGENAME eq ascension.exe" 2>NUL | find /I /N "ascension.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [SUCCESS] Found ascension.exe
    goto :inject
)

echo [WARNING] No target game process found yet
echo [INFO] Start Project Epoch.exe or ascension.exe when ready
echo.
set /p choice="Wait for game to start? (Y/n): "
if /i "%choice%"=="n" exit /b 1

echo [INFO] Waiting for game process to start...
timeout /t 10 /nobreak >nul
goto :check_process

:inject

:: Check admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [SUCCESS] Running with Administrator privileges
) else (
    echo [ERROR] Not running as Administrator!
    echo [ERROR] Many evasion techniques will fail without admin rights
    echo [ERROR] Right-click this file and select "Run as Administrator"
    echo.
    set /p choice="Continue anyway? (y/N): "
    if /i not "%choice%"=="y" exit /b 1
)

echo.
echo [INFO] Starting injection with full debug logging...
echo [INFO] Watch the colored output below for real-time status
echo.

:: Run injector with output redirection (both to console and file)
AwesomeWotlkInjector.exe 2>&1 | tee logs\injection_log_%timestamp%.txt

echo.
if %errorLevel% == 0 (
    echo [SUCCESS] Injection completed! Log saved to logs\injection_log_%timestamp%.txt
) else (
    echo [ERROR] Injection failed! Check logs\injection_log_%timestamp%.txt for details
)

echo.
echo Press any key to exit...
pause >nul
