@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: ========================
:: USER SETTINGS (edit me)
:: ========================
:: Leave GAME_EXE empty to auto-detect in Program Files and common paths,
:: or set it to either the folder OR the full path to Ascension.exe.
set "GAME_EXE="
:: The line the injector prints when things worked
set "SUCCESS_LINE=Injection successful! Monitoring target process..."
:: Timing knobs (tweak if desired)
set "WAIT_FOR_GAME_SECS=2" :: poll cadence while waiting for the game
set "WAIT_FOR_GAME_TIMEOUT_SECS=30" :: max seconds to wait after starting game
set "DELAY_BEFORE_FIRST_INJECT=5" :: wait this many seconds before first injection
set "POLL_SLEEP_SECS=3" :: wait between each success-check poll
set "POLLS_PER_ATTEMPT=10" :: after this many polls w/o success, relaunch injector
set "MAX_INJECT_ATTEMPTS=3" :: total injector relaunches allowed before giving up
set "POST_INJECTOR_LAUNCH_DELAY=5" :: delay after launching injector to allow log write
:: ========================
:: CONSTANTS/DERIVED
:: ========================
set "BASE_DIR=%~dp0"
set "TARGET_EXE_NAME=Ascension.exe"
set "INJECTOR_EXE=%BASE_DIR%AwesomeWotlkInjector.exe"
set "INJECTOR_LOG=%BASE_DIR%injector_output.log"
set "SCRIPT_LOG=%BASE_DIR%AutoInject_Awesome.log"
:: Support subfolder .\AwesomeWotlkInjector\AwesomeWotlkInjector.exe
if not exist "%INJECTOR_EXE%" (
  if exist "%BASE_DIR%AwesomeWotlkInjector\AwesomeWotlkInjector.exe" (
    set "INJECTOR_EXE=%BASE_DIR%AwesomeWotlkInjector\AwesomeWotlkInjector.exe"
    set "INJECTOR_LOG=%BASE_DIR%AwesomeWotlkInjector\injector_output.log"
  )
)
:: ========================
:: LOG RESET
:: ========================
2>nul del /f /q "%SCRIPT_LOG%" || (
  echo [ERROR] Failed to delete %SCRIPT_LOG%. Check permissions.>>con
  exit /b 1
)
2>nul del /f /q "%INJECTOR_LOG%" || (
  echo [ERROR] Failed to delete %INJECTOR_LOG%. Check permissions.>>con
)
2>nul del /f /q "%BASE_DIR%injector_output.txt"
2>nul del /f /q "%BASE_DIR%AwesomeWotlkInjector\injector_output.txt"
type nul > "%SCRIPT_LOG%" 2>nul || (
  echo [ERROR] Failed to create %SCRIPT_LOG%. Check permissions.>>con
  exit /b 1
)
>>"%SCRIPT_LOG%" echo(
>>"%SCRIPT_LOG%" echo ==== %date% %time% : Script start ====
call :log INFO "BASE_DIR=%BASE_DIR%"
call :log INFO "INJECTOR_EXE=%INJECTOR_EXE%"
call :log INFO "INJECTOR_LOG=%INJECTOR_LOG%"
call :log INFO "SCRIPT_LOG=%SCRIPT_LOG%"
if not exist "%INJECTOR_EXE%" (
  call :log ERROR "Injector not found: %INJECTOR_EXE%"
  call :die "Place AwesomeWotlkInjector.exe next to this script (or in .\AwesomeWotlkInjector\)."
  goto :end
)
:: Debug environment variables
call :log INFO "ProgramFiles=%ProgramFiles%"
call :log INFO "ProgramFiles(x86)=%ProgramFiles(x86)%"
call :log INFO "ProgramW6432=%ProgramW6432%"
:: ========================
:: RESOLVE GAME PATH
:: ========================
if not defined GAME_EXE (
  set "PF64=%ProgramW6432%"
  if not defined PF64 set "PF64=%ProgramFiles%"
  set "PF86=%ProgramFiles(x86)%"
  :: Define candidate paths
  set "CAND1=%PF64%\Ascension Launcher\resources\epoch_live\%TARGET_EXE_NAME%"
  set "CAND2=%PF64%\Ascension Launcher\resources\ascension_live\%TARGET_EXE_NAME%"
  set "CAND3=%PF64%\Ascension Launcher\resources\epoch_ptr\%TARGET_EXE_NAME%"
  set "CAND4=%ProgramFiles%\Ascension Launcher\resources\epoch_live\%TARGET_EXE_NAME%"
  set "CAND5=%ProgramFiles%\Ascension Launcher\resources\ascension_live\%TARGET_EXE_NAME%"
  set "CAND6=%ProgramFiles%\Ascension Launcher\resources\epoch_ptr\%TARGET_EXE_NAME%"
  set "CAND7=%PF86%\Ascension Launcher\resources\epoch_live\%TARGET_EXE_NAME%"
  set "CAND8=%PF86%\Ascension Launcher\resources\ascension_live\%TARGET_EXE_NAME%"
  set "CAND9=%PF86%\Ascension Launcher\resources\epoch_ptr\%TARGET_EXE_NAME%"
  set "CAND10=C:\Games\Ascension Launcher\resources\epoch_live\%TARGET_EXE_NAME%"
  set "CAND11=C:\Games\Ascension Launcher\resources\ascension_live\%TARGET_EXE_NAME%"
  set "CAND12=C:\Games\Ascension Launcher\resources\epoch_ptr\%TARGET_EXE_NAME%"
  set "CAND13=D:\Games\Ascension Launcher\resources\epoch_live\%TARGET_EXE_NAME%"
  set "CAND14=D:\Games\Ascension Launcher\resources\ascension_live\%TARGET_EXE_NAME%"
  set "CAND15=D:\Games\Ascension Launcher\resources\epoch_ptr\%TARGET_EXE_NAME%"
  call :log INFO "Probing for game exe in:"
  for /L %%N in (1,1,15) do (
    set "CURRENT_CAND=!CAND%%N!"
    call :log INFO " !CURRENT_CAND!"
    if exist "!CURRENT_CAND!" (
      set "GAME_EXE=!CURRENT_CAND!"
      call :log OK "Found: !CURRENT_CAND!"
      goto :game_exe_found
    )
  )
  call :log ERROR "%TARGET_EXE_NAME% not found in any known paths."
  call :log ERROR "Checked:"
  for /L %%N in (1,1,15) do (
    set "CURRENT_CAND=!CAND%%N!"
    call :log ERROR " !CURRENT_CAND!"
  )
  call :log INFO "If the launcher is installed elsewhere, set GAME_EXE explicitly to the full path or folder."
  call :die "Cannot continue without GAME_EXE."
  goto :end
)
:game_exe_found
:: Validate GAME_EXE
call :log INFO "Validating GAME_EXE: %GAME_EXE%"
if exist "%GAME_EXE%\" (
  call :log INFO "GAME_EXE is a directory, checking for %TARGET_EXE_NAME%..."
  if exist "%GAME_EXE%\%TARGET_EXE_NAME%" (
    set "GAME_EXE=%GAME_EXE%\%TARGET_EXE_NAME%"
    call :log INFO "GAME_EXE updated to: %GAME_EXE%"
  ) else (
    call :log ERROR "Folder provided but %TARGET_EXE_NAME% not found in: %GAME_EXE%"
    call :die "Ensure %TARGET_EXE_NAME% is inside that folder or set GAME_EXE to full path."
    goto :end
  )
) else (
  call :log INFO "GAME_EXE is not a directory, checking if it's a valid file..."
  echo %GAME_EXE% | findstr /I /C:".exe" >nul
  if errorlevel 1 (
    call :log INFO "GAME_EXE does not end in .exe, checking folder..."
    if exist "%GAME_EXE%\%TARGET_EXE_NAME%" (
      set "GAME_EXE=%GAME_EXE%\%TARGET_EXE_NAME%"
      call :log INFO "GAME_EXE updated to: %GAME_EXE%"
    ) else (
      call :log ERROR "GAME_EXE does not end in .exe and %TARGET_EXE_NAME% not found in: %GAME_EXE%"
      call :die "Fix GAME_EXE to point to a valid file or folder."
      goto :end
    )
  )
)
:: Final validation
if not exist "%GAME_EXE%" (
  call :log ERROR "GAME_EXE points to a non-existent file: %GAME_EXE%"
  call :die "Fix GAME_EXE at the top of the script."
  goto :end
)
call :log INFO "Extracting GAME_DIR from %GAME_EXE%..."
for %%I in ("%GAME_EXE%") do (
  set "GAME_DIR=%%~dpI"
  call :log INFO "GAME_DIR set to: !GAME_DIR!"
)
if not defined GAME_DIR (
  call :log ERROR "Failed to extract GAME_DIR from %GAME_EXE%."
  call :die "Invalid GAME_EXE path."
  goto :end
)
set "GAME_DIR=%GAME_DIR:~0,-1%"
call :log OK "Using %TARGET_EXE_NAME%: %GAME_EXE%"
:: ========================
:: START GAME ONCE
:: ========================
call :log INFO "Attempting to ensure game is running..."
call :ensure_game_running
if errorlevel 1 (
  call :log ERROR "Failed to ensure game is running."
  goto :end
)
:: Grace period before first injection
call :log INFO "Waiting %DELAY_BEFORE_FIRST_INJECT% seconds before injection..."
timeout /t %DELAY_BEFORE_FIRST_INJECT% /nobreak >nul 2>nul || (
  call :log ERROR "Failed to execute timeout command."
  call :die "Script encountered an error during delay."
  goto :end
)
:: ========================
:: INJECTION LOOP
:: ========================
set /a ATTEMPT=0
:inject_cycle
if %ATTEMPT% GEQ %MAX_INJECT_ATTEMPTS% (
  call :log ERROR "Giving up after %MAX_INJECT_ATTEMPTS% injector attempts."
  call :log ERROR "Contents of %INJECTOR_LOG% (if exists):"
  if exist "%INJECTOR_LOG%" (
    type "%INJECTOR_LOG%" >> "%SCRIPT_LOG%" 2>nul || call :log ERROR "Failed to read %INJECTOR_LOG%."
  ) else (
    call :log ERROR "Injector log not found: %INJECTOR_LOG%"
  )
  call :die "Injection did not report success. Check injector and permissions."
  goto :end
)
set /a ATTEMPT+=1
call :log INFO "Launching injector attempt %ATTEMPT%: %INJECTOR_EXE% %TARGET_EXE_NAME%"
:: Clean old injector log
if exist "%INJECTOR_LOG%" (
  del /f /q "%INJECTOR_LOG%" >nul 2>&1 || (
    call :log ERROR "Failed to delete %INJECTOR_LOG%. Check permissions."
    call :die "Cannot clean injector log."
    goto :end
  )
)
:: Verify injector executable exists
if not exist "%INJECTOR_EXE%" (
  call :log ERROR "Injector executable missing: %INJECTOR_EXE%"
  call :die "Ensure AwesomeWotlkInjector.exe is in the correct directory."
  goto :end
)
:: Terminate any existing injector processes
taskkill /IM "AwesomeWotlkInjector.exe" /F >nul 2>&1 || call :log INFO "No existing injector processes found."
:: Launch the injector asynchronously
call :log INFO "Starting injector..."
call :log INFO "Executing: %INJECTOR_EXE% %TARGET_EXE_NAME%"
start "" /B cmd /c ""%INJECTOR_EXE%" "%TARGET_EXE_NAME%" > "%INJECTOR_LOG%" 2>&1"
call :log INFO "Injector launched, waiting %POST_INJECTOR_LAUNCH_DELAY% seconds for log write..."
timeout /t %POST_INJECTOR_LAUNCH_DELAY% /nobreak >nul 2>nul || (
  call :log ERROR "Failed to execute timeout command after injector launch."
)
:: Poll for success
set /a POLLCOUNT=0
:poll_loop
set /a POLLCOUNT+=1
:: Check if game is running
tasklist /FI "IMAGENAME eq %TARGET_EXE_NAME%" 2>NUL | find /I "%TARGET_EXE_NAME%" >NUL
if errorlevel 1 (
  call :log WARN "Game not detected; waiting for it to appear again (not starting it)."
  call :wait_for_game
  timeout /t %POLL_SLEEP_SECS% /nobreak >nul 2>nul || (
    call :log ERROR "Failed to execute timeout command in poll loop."
  )
)
:: Check if injector process is running
tasklist /FI "IMAGENAME eq AwesomeWotlkInjector.exe" 2>NUL | find /I "AwesomeWotlkInjector.exe" >NUL
if not errorlevel 1 (
  call :log INFO "^(try !POLLCOUNT!^) Injector process still running."
) else (
  call :log INFO "^(try !POLLCOUNT!^) Injector process not running."
)
:: Check if injector log exists
if not exist "%INJECTOR_LOG%" (
  call :log INFO "^(try !POLLCOUNT!^) Waiting for injector log to be created..."
  timeout /t %POLL_SLEEP_SECS% /nobreak >nul 2>nul || (
    call :log ERROR "Failed to execute timeout command in poll loop."
  )
  if !POLLCOUNT! GEQ %POLLS_PER_ATTEMPT% goto :retry_injector
  goto :poll_loop
)
:: Search for success line
findstr /I /C:"%SUCCESS_LINE%" "%INJECTOR_LOG%" >nul 2>&1
if not errorlevel 1 (
  call :log OK "Injection success line found."
  goto :success
)
:: Fallback: Check for partial success
findstr /I /C:"Traditional injection completed successfully" "%INJECTOR_LOG%" >nul 2>&1
if not errorlevel 1 (
  call :log OK "Partial injection success line found."
  goto :success
)
call :log INFO "^(try !POLLCOUNT!^) Success line not found yet; rechecking"
call :log INFO "Current contents of %INJECTOR_LOG%:"
type "%INJECTOR_LOG%" >> "%SCRIPT_LOG%" 2>nul || call :log ERROR "Failed to read %INJECTOR_LOG%."
timeout /t %POLL_SLEEP_SECS% /nobreak >nul 2>nul || (
  call :log ERROR "Failed to execute timeout command in poll loop."
)
if !POLLCOUNT! GEQ %POLLS_PER_ATTEMPT% goto :retry_injector
goto :poll_loop
:retry_injector
call :log INFO "No success after %POLLS_PER_ATTEMPT% polls; relaunching injector..."
goto :inject_cycle
:success
call :log OK "Injection reported success. Exiting."
goto :end
:: ========================
:: HELPERS
:: ========================
:ensure_game_running
  call :log INFO "Checking if %TARGET_EXE_NAME% is running..."
  tasklist /FI "IMAGENAME eq %TARGET_EXE_NAME%" 2>NUL | find /I "%TARGET_EXE_NAME%" >NUL
  if errorlevel 1 (
    call :log INFO "Starting game: %GAME_EXE%"
    start "" "%GAME_EXE%" || (
      call :log ERROR "Failed to start %GAME_EXE%. Check path and permissions."
      exit /b 1
    )
    call :wait_for_game %WAIT_FOR_GAME_TIMEOUT_SECS%
    if errorlevel 1 (
      call :log ERROR "Game did not appear within %WAIT_FOR_GAME_TIMEOUT_SECS% seconds after start."
      exit /b 1
    )
  ) else (
    call :log INFO "Game already running"
  )
  exit /b 0
:wait_for_game
  set "WG_TIMEOUT=%~1"
  set /a WG_WAITED=0
  :wg_loop
  tasklist /FI "IMAGENAME eq %TARGET_EXE_NAME%" 2>NUL | find /I "%TARGET_EXE_NAME%" >NUL
  if not errorlevel 1 (
    call :log OK "Game detected"
    exit /b 0
  )
  if defined WG_TIMEOUT (
    if %WG_WAITED% GEQ %WG_TIMEOUT% (
      call :log ERROR "Timed out waiting for %TARGET_EXE_NAME% (waited %WG_WAITED%s)."
      exit /b 1
    )
  )
  call :log INFO "Waiting for %TARGET_EXE_NAME%..."
  timeout /t %WAIT_FOR_GAME_SECS% /nobreak >nul 2>nul || (
    call :log ERROR "Failed to execute timeout command in wait_for_game."
  )
  set /a WG_WAITED+=%WAIT_FOR_GAME_SECS%
  goto :wg_loop
:log
  set "LEVEL=%~1"
  set "MSG=%~2"
  set "SAFE_MSG=!MSG:^>=^>!"
  set "SAFE_MSG=!SAFE_MSG:^|=^|!"
  set "SAFE_MSG=!SAFE_MSG:&=^&!"
  set "SAFE_MSG=!SAFE_MSG:(=^(!"
  set "SAFE_MSG=!SAFE_MSG:)=^)!"
  echo [!LEVEL!] !SAFE_MSG!>>"%SCRIPT_LOG%" 2>nul || echo [!LEVEL!] !SAFE_MSG!
  exit /b
:die
  set "ERR=%~1"
  set "SAFE_ERR=!ERR:^>=^>!"
  set "SAFE_ERR=!SAFE_ERR:^|=^|!"
  set "SAFE_ERR=!SAFE_ERR:&=^&!"
  set "SAFE_ERR=!SAFE_ERR:(=^(!"
  set "SAFE_ERR=!SAFE_ERR:)=^)!"
  echo [ERROR] !SAFE_ERR!>>"%SCRIPT_LOG%" 2>nul || echo [ERROR] !SAFE_ERR!
  endlocal & exit /b 1
:end
endlocal
exit /b 0