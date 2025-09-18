@echo off
title Awesome WotLK Injector
color 0F

echo.
echo ================================================
echo    AWESOME WOTLK INJECTION SYSTEM
echo    Advanced Anti-Detection Framework
echo ================================================
echo.

:: Check if running as admin
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [INFO] Running with Administrator privileges - GOOD!
) else (
    echo [WARNING] Not running as Administrator
    echo [WARNING] Some evasion techniques may fail
    echo [WARNING] Right-click and "Run as Administrator" for best results
)

echo.
echo [INFO] Looking for game processes...

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

echo [ERROR] No target game process found!
echo [ERROR] Please start Project Epoch.exe or ascension.exe first
echo [ERROR] Make sure you're logged in and in the game world
echo.
pause
exit /b 1

:inject
echo.
echo [INFO] Target process detected - starting injection...
echo [INFO] Make sure your character is IN THE GAME WORLD (not at character select)
echo [INFO] The injector will wait up to 5 minutes for world entry detection
echo.
pause

:: Run the injector
echo [INFO] Launching injector with full logging...
echo.
AwesomeWotlkInjector.exe

:: Check if injection was successful
if %errorLevel% == 0 (
    echo.
    echo ================================================
    echo    INJECTION COMPLETED SUCCESSFULLY!
    echo    Your game is now enhanced with:
    echo    - Advanced anti-detection protection
    echo    - Voice chat capabilities  
    echo    - Bug fixes and improvements
    echo    - Custom gameplay features
    echo ================================================
) else (
    echo.
    echo ================================================
    echo    INJECTION FAILED!
    echo    Error Code: %errorLevel%
    echo    Check the logs above for details
    echo ================================================
)

echo.
echo Press any key to close this window...
pause >nul
