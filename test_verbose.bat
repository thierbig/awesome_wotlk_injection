@echo off
echo Testing verbosity control...
echo.

echo === Test 1: Verbose Mode (AWESOME_VERBOSE=1) ===
set AWESOME_VERBOSE=1
echo Environment variable set to: %AWESOME_VERBOSE%
echo Expected: Full verbose logging from both injector and DLL
echo.
pause

echo === Test 2: Production Mode (AWESOME_VERBOSE=0) ===
set AWESOME_VERBOSE=0
echo Environment variable set to: %AWESOME_VERBOSE%
echo Expected: Minimal logging from both injector and DLL
echo.
pause

echo === Test 3: Unset (default behavior) ===
set AWESOME_VERBOSE=
echo Environment variable unset
echo Expected: Default verbose logging (development mode)
echo.
pause

echo Tests completed. You can now run the injector to see the difference.
pause
