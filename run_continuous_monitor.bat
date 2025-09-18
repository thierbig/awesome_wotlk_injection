@echo off
title Awesome WotLK Injector - Continuous Monitor
color 0B

echo.
echo ================================================
echo    AWESOME WOTLK INJECTOR - CONTINUOUS MONITOR
echo    Waiting for game launch...
echo ================================================
echo.

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
echo [INFO] Continuous monitoring mode enabled
echo [INFO] This window will stay open and monitor for game launches
echo [INFO] You can start the game at any time - injection will happen automatically
echo.
echo [INFO] Monitoring for processes: Project Epoch.exe, ascension.exe
echo [INFO] Press Ctrl+C at any time to stop monitoring
echo.

:monitor_loop
echo [%TIME%] Scanning for target processes...

:: Check for Project Epoch
tasklist /FI "IMAGENAME eq Project Epoch.exe" 2>NUL | find /I /N "Project Epoch.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo.
    echo [SUCCESS] Found Project Epoch.exe at %TIME%
    set "target_process=Project Epoch.exe"
    goto :found_process
)

:: Check for Ascension  
tasklist /FI "IMAGENAME eq ascension.exe" 2>NUL | find /I /N "ascension.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo.
    echo [SUCCESS] Found ascension.exe at %TIME%
    set "target_process=ascension.exe"
    goto :found_process
)

:: Wait 10 seconds before next check
timeout /t 10 /nobreak >nul
goto :monitor_loop

:found_process
echo [INFO] Target process: %target_process%
echo [INFO] Waiting 30 seconds for game to fully load...
timeout /t 30 /nobreak

echo.
echo ================================================
echo    GAME DETECTED - STARTING INJECTION
echo ================================================
echo.

:: Create timestamped log file
if not exist "logs" mkdir logs
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "timestamp=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

echo [INFO] Full debug logging enabled
echo [INFO] Log file: logs\injection_log_%timestamp%.txt
echo.

:: Run the injector with logging
echo [INFO] Launching injector with full evasion logging...
echo [INFO] Make sure your character is IN THE GAME WORLD for automatic injection
echo.

AwesomeWotlkInjector.exe 2>&1 | tee logs\injection_log_%timestamp%.txt

:: Check injection result
if %errorLevel% == 0 (
    echo.
    echo ================================================
    echo    INJECTION COMPLETED SUCCESSFULLY!
    echo    Your game is now enhanced with all features
    echo    Log saved: logs\injection_log_%timestamp%.txt
    echo ================================================
    echo.
    echo [INFO] Resuming continuous monitoring...
    echo [INFO] If you restart the game, injection will happen automatically
    echo.
    goto :monitor_loop
) else (
    echo.
    echo ================================================
    echo    INJECTION FAILED!
    echo    Error Code: %errorLevel%
    echo    Log saved: logs\injection_log_%timestamp%.txt
    echo ================================================
    echo.
    echo [INFO] Resuming monitoring in 60 seconds...
    echo [INFO] You can restart the game or try again
    timeout /t 60 /nobreak
    goto :monitor_loop
)

:end
echo [INFO] Monitor stopped
pause
