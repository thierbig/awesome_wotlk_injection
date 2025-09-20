@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: ========================
:: USER SETTINGS (edit me)
:: ========================
:: Leave GAME_EXE empty to auto-detect in Program Files paths,
:: or set it to either the folder OR the full path to Ascension.exe.
set "GAME_EXE=E:\Games\epoch_live_bon"

:: The line the injector prints when things worked
set "SUCCESS_LINE=Injection successful! Monitoring target process..."

:: Timing knobs (tweak if desired)
set "WAIT_FOR_GAME_SECS=2"            :: poll cadence while waiting for the game
set "WAIT_FOR_GAME_TIMEOUT_SECS=30"   :: max seconds to wait after starting game
set "DELAY_BEFORE_FIRST_INJECT=5"     :: wait this many seconds before first injection
set "POLL_SLEEP_SECS=3"               :: wait between each success-check poll
set "POLLS_PER_ATTEMPT=3"             :: after this many polls w/o success, relaunch injector
set "MAX_INJECT_ATTEMPTS=10"          :: total injector relaunches allowed before giving up

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

:: Start log entry
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

:: ========================
:: RESOLVE GAME PATH
:: ========================
if not defined GAME_EXE (
  set "PF1=%ProgramFiles%\Ascension Launcher\resources\epoch_live\%TARGET_EXE_NAME%"
  set "PF2=%ProgramFiles(x86)%\Ascension Launcher\resources\epoch_live\%TARGET_EXE_NAME%"
  if exist "%PF1%" (
    set "GAME_EXE=%PF1%"
    call :log OK "Found in Program Files: %PF1%"
  ) else if exist "%PF2%" (
    set "GAME_EXE=%PF2%"
    call :log OK "Found in Program Files (x86): %PF2%"
  ) else (
    call :log ERROR "Ascension.exe not found in:"
    call :log ERROR "  %ProgramFiles%\Ascension Launcher\resources\epoch_live"
    call :log ERROR "  %ProgramFiles(x86)%\Ascension Launcher\resources\epoch_live"
    call :die "Cannot continue without explicit GAME_EXE."
    goto :end
  )
)

:: If GAME_EXE is a directory, append the exe name
if exist "%GAME_EXE%\" (
  if exist "%GAME_EXE%\%TARGET_EXE_NAME%" (
    set "GAME_EXE=%GAME_EXE%\%TARGET_EXE_NAME%"
  ) else (
    call :log ERROR "Folder provided but %TARGET_EXE_NAME% not found in: %GAME_EXE%"
    call :die "Ensure %TARGET_EXE_NAME% is inside that folder or set GAME_EXE to full path."
    goto :end
  )
) else (
  :: If not ending in .exe, but is a folder path without trailing slash, try to fix
  if /I not "%GAME_EXE:~-4%"==".exe" (
    if exist "%GAME_EXE%\%TARGET_EXE_NAME%" (
      set "GAME_EXE=%GAME_EXE%\%TARGET_EXE_NAME%"
    )
  )
)

:: Validate final
if not exist "%GAME_EXE%" (
  call :log ERROR "GAME_EXE points to a non-existent file: %GAME_EXE%"
  call :die "Fix GAME_EXE at the top of the script."
  goto :end
)

for %%I in ("%GAME_EXE%") do set "GAME_DIR=%%~dpI"
set "GAME_DIR=%GAME_DIR:~0,-1%"
call :log OK "Using ascension.exe: %GAME_EXE%"

:: ========================
:: START GAME ONCE (poll, no errorlevel check)
:: ========================
call :ensure_game_running
if errorlevel 1 goto :end

:: Grace period before first injection
call :log INFO "Waiting %DELAY_BEFORE_FIRST_INJECT% seconds before injection..."
timeout /t %DELAY_BEFORE_FIRST_INJECT% /nobreak >nul

:: ========================
:: INJECTION LOOP
:: ========================
set /a ATTEMPT=0

:inject_cycle
if %ATTEMPT% GEQ %MAX_INJECT_ATTEMPTS% (
  call :log ERROR "Giving up after %MAX_INJECT_ATTEMPTS% injector attempts."
  call :die "Injection did not report success. Check injector and permissions."
  goto :end
)

set /a ATTEMPT+=1
call :log INFO "Launching injector attempt %ATTEMPT%: %INJECTOR_EXE% %TARGET_EXE_NAME%"

:: Clean old injector log so we don't match stale lines
if exist "%INJECTOR_LOG%" del /f /q "%INJECTOR_LOG%" >nul 2>&1

:: Launch the injector and capture its output to log file
:: Use cmd /c so redirection works; start the injector and don't block this script
start "" cmd /c ""%INJECTOR_EXE%" "%TARGET_EXE_NAME%" > "%INJECTOR_LOG%" 2>&1"

:: Poll for success, POLLS_PER_ATTEMPT polls per attempt
set /a POLLCOUNT=0

:poll_loop
set /a POLLCOUNT+=1

:: If the game was closed by user, wait for it to reappear (do NOT auto-start again)
tasklist /FI "IMAGENAME eq %TARGET_EXE_NAME%" 2>NUL | find /I "%TARGET_EXE_NAME%" >NUL
if errorlevel 1 (
  call :log WARN "Game not detected; waiting for it to appear again (not starting it)."
  call :wait_for_game
  timeout /t %POLL_SLEEP_SECS% /nobreak >nul
)

:: Wait for injector log to show up first
if not exist "%INJECTOR_LOG%" (
  call :log INFO "^(try !POLLCOUNT!^) Waiting for injector log to be created..."
  timeout /t %POLL_SLEEP_SECS% /nobreak >nul
  if !POLLCOUNT! GEQ %POLLS_PER_ATTEMPT% goto :retry_injector
  goto :poll_loop
)

:: Search for success line
findstr /I /C:"%SUCCESS_LINE%" "%INJECTOR_LOG%" >nul 2>&1
if not errorlevel 1 (
  call :log OK "Injection success line found."
  goto :success
)

call :log INFO "^(try !POLLCOUNT!^) Success line not found yet; rechecking"
timeout /t %POLL_SLEEP_SECS% /nobreak >nul

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
  tasklist /FI "IMAGENAME eq %TARGET_EXE_NAME%" 2>NUL | find /I "%TARGET_EXE_NAME%" >NUL
  if errorlevel 1 (
    call :log INFO "Starting game"
    start "" "%GAME_EXE%"
    :: Don’t trust errorlevel from START; we poll for the process instead.
    call :wait_for_game %WAIT_FOR_GAME_TIMEOUT_SECS%
    if errorlevel 1 (
      call :die "Game did not appear within %WAIT_FOR_GAME_TIMEOUT_SECS% seconds after start. Check path/permissions."
      exit /b 1
    )
  ) else (
    call :log INFO "Game already running"
  )
  exit /b 0

:wait_for_game
  :: %1 (optional): max seconds to wait; if empty, wait indefinitely
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
  timeout /t %WAIT_FOR_GAME_SECS% /nobreak >nul
  set /a WG_WAITED+=%WAIT_FOR_GAME_SECS%
  goto :wg_loop

:log
  :: Writes only to the log file (no console output).
  set "LEVEL=%~1"
  set "MSG=%~2"
  :: Escape any problematic characters for safety:
  set "SAFE_MSG=!MSG:^>=^>!"
  set "SAFE_MSG=!SAFE_MSG:^|=^|!"
  set "SAFE_MSG=!SAFE_MSG:&=^&!"
  set "SAFE_MSG=!SAFE_MSG:(=^(!"
  set "SAFE_MSG=!SAFE_MSG:)=^)!"
  echo [!LEVEL!] !SAFE_MSG!>>"%SCRIPT_LOG%"
  exit /b

:die
  set "ERR=%~1"
  set "SAFE_ERR=!ERR:^>=^>!"
  set "SAFE_ERR=!SAFE_ERR:^|=^|!"
  set "SAFE_ERR=!SAFE_ERR:&=^&!"
  set "SAFE_ERR=!SAFE_ERR:(=^(!"
  set "SAFE_ERR=!SAFE_ERR:)=^)!"
  echo [ERROR] !SAFE_ERR!>>"%SCRIPT_LOG%"
  :: exit with non-zero code so callers can detect failure
  endlocal & exit /b 1

:end
endlocal
exit /b 0
