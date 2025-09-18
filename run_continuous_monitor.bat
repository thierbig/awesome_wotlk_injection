@echo off
title Awesome WotLK Injector - Continuous Monitor
color 0B

:: Setup cleanup on exit (Ctrl+C or window close)
set "CLEANUP_NEEDED=1"
if not defined CLEANUP_HANDLER (
    set "CLEANUP_HANDLER=1"
    call :setup_cleanup
)

echo:
echo ================================================
echo    AWESOME WOTLK INJECTOR - CONTINUOUS MONITOR
echo    Waiting for game launch...
echo ================================================
echo:

:: Check admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [SUCCESS] Running with Administrator privileges
) else (
    echo [ERROR] Not running as Administrator!
    echo [ERROR] Many evasion techniques will fail without admin rights
    echo [ERROR] Right-click this file and select "Run as Administrator"
    echo:
    set /p choice="Continue anyway? (y/N): "
    if /i not "%choice%"=="y" goto :end_with_pause
)

echo:
echo [INFO] Continuous monitoring mode enabled
echo [INFO] This window will stay open and monitor for game launches
echo [INFO] You can start the game at any time - injection will happen automatically
echo:
echo [INFO] Monitoring for processes: Project Epoch.exe, ascension.exe
echo [INFO] Press Ctrl+C at any time to stop monitoring
echo:

:monitor_loop
echo [%TIME%] Scanning for target processes...

:: Check for Project Epoch
tasklist /FI "IMAGENAME eq Project Epoch.exe" 2>NUL | find /I /N "Project Epoch.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo:
    echo [SUCCESS] Found Project Epoch.exe at %TIME%
    set "target_process=Project Epoch.exe"
    goto :found_process
)

:: Check for Ascension  
tasklist /FI "IMAGENAME eq ascension.exe" 2>NUL | find /I /N "ascension.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo:
    echo [SUCCESS] Found ascension.exe at %TIME%
    set "target_process=ascension.exe"
    goto :found_process
)

:: Wait 10 seconds before next check
timeout /t 10 /nobreak >nul
goto :monitor_loop

:found_process
echo [INFO] Target process: %target_process%
echo [INFO] Waiting 5 seconds for game to fully load...
timeout /t 5 /nobreak

echo:
echo ================================================
echo    GAME DETECTED - STARTING INJECTION
echo ================================================
echo:

:: Create timestamped log file
if not exist "logs" mkdir logs
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "timestamp=%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

echo [INFO] Full debug logging enabled
echo [INFO] Log file: logs\injection_log_%timestamp%.txt
echo:

:: Debug and run the injector
echo [DEBUG] Current directory: %CD%
echo [DEBUG] Script directory: %~dp0
echo [DEBUG] Looking for: %~dp0AwesomeWotlkInjector.exe
echo [DEBUG] Directory listing:
dir "%~dp0*.exe" /b
dir "%~dp0*.dll" /b
echo [DEBUG] Trying alternative check...
if exist "%~dp0AwesomeWotlkInjector.exe" (
    echo [SUCCESS] Found AwesomeWotlkInjector.exe
) else (
    echo [ERROR] AwesomeWotlkInjector.exe NOT FOUND by IF EXIST!
    echo [DEBUG] Trying direct execution anyway...
)

echo [INFO] Launching injector with full evasion logging...
echo [INFO] Target process: %target_process%
echo [WARNING] The injector will prompt 'Press any key when ready...'
echo [WARNING] You'll need to press a key in the injector window when you're in-game
echo:
"%~dp0AwesomeWotlkInjector.exe" "%target_process%"
set INJECT_RESULT=%errorLevel%

:: Check injection result
echo:
echo ================================================
if %INJECT_RESULT% == 0 (
    echo [SUCCESS] INJECTION COMPLETED SUCCESSFULLY!
    echo [SUCCESS] Your game is now enhanced with all features
) else (
    echo [ERROR] INJECTION FAILED!
    echo [ERROR] Error Code: %INJECT_RESULT%
    echo [ERROR] Common issues:
    echo [ERROR] - Missing Administrator privileges
    echo [ERROR] - Game process not found or inaccessible  
    echo [ERROR] - DLL file missing or corrupted
    echo [ERROR] - Anti-virus blocking the injection
    echo [ERROR] - AwesomeWotlkInjector.exe not found
    echo [ERROR] - AwesomeWotlkLib.dll not found
)
echo ================================================
echo:
echo [INFO] Resuming continuous monitoring in 30 seconds...
echo [INFO] If you restart the game, injection will happen automatically
timeout /t 30 /nobreak
goto :monitor_loop

:end
call :cleanup_processes
echo [INFO] Monitor stopped
pause

:end_with_pause
call :cleanup_processes
echo [INFO] Monitor stopped - window will stay open
echo [INFO] Press any key to close this window...
pause >nul
exit /b

:setup_cleanup
:: This creates a cleanup temp file that gets called on exit
echo @echo off > "%TEMP%\awesome_cleanup.bat"
echo tasklist /FI "IMAGENAME eq AwesomeWotlkInjector.exe" 2^>NUL ^| find /I /N "AwesomeWotlkInjector.exe"^>NUL >> "%TEMP%\awesome_cleanup.bat"
echo if "%%ERRORLEVEL%%"=="0" ( >> "%TEMP%\awesome_cleanup.bat"
echo     echo [CLEANUP] Stopping AwesomeWotlkInjector.exe... >> "%TEMP%\awesome_cleanup.bat"
echo     taskkill /F /IM "AwesomeWotlkInjector.exe" 2^>NUL >> "%TEMP%\awesome_cleanup.bat"
echo ) >> "%TEMP%\awesome_cleanup.bat"
echo del "%%~f0" 2^>NUL >> "%TEMP%\awesome_cleanup.bat"
goto :eof

:cleanup_processes
echo [CLEANUP] Checking for running AwesomeWotlkInjector.exe processes...
tasklist /FI "IMAGENAME eq AwesomeWotlkInjector.exe" 2>NUL | find /I /N "AwesomeWotlkInjector.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo [CLEANUP] Stopping AwesomeWotlkInjector.exe...
    taskkill /F /IM "AwesomeWotlkInjector.exe" 2>NUL
    echo [CLEANUP] Process stopped.
) else (
    echo [CLEANUP] No AwesomeWotlkInjector.exe processes found.
)
goto :eof
