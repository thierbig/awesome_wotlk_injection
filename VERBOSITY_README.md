# Verbosity Control System

The injector now supports configurable verbosity levels for development and production use.

## How It Works

The verbosity is controlled by the `AWESOME_VERBOSE` environment variable:
- `AWESOME_VERBOSE=1` or `AWESOME_VERBOSE=true` → **Verbose mode** (shows all debug info)
- `AWESOME_VERBOSE=0` or unset → **Production mode** (minimal output)

## Usage Options

### 1. Using Batch Files

**Development (Verbose):**
```batch
AutoInject_Awesome.bat
```
- Shows all debug information
- Detailed manual mapping logs
- Step-by-step injection process

**Production (Quiet):**
```batch
AutoInject_Awesome_Prod.bat
```
- Minimal output
- Only shows essential messages (success/error)
- Clean for end users

### 2. Manual Environment Variable

```batch
REM Enable verbose mode
set AWESOME_VERBOSE=1
AwesomeWotlkInjector.exe

REM Disable verbose mode
set AWESOME_VERBOSE=0
AwesomeWotlkInjector.exe
```

### 3. Command Line Options

```batch
REM Force manual mapping (verbose if AWESOME_VERBOSE=1)
AwesomeWotlkInjector.exe --manual

REM Custom process name
AwesomeWotlkInjector.exe "CustomProcess.exe"
```

## What Gets Hidden in Production Mode

When `AWESOME_VERBOSE=0`:

**Injector (AwesomeWotlkInjector.exe):**
- Manual mapping step-by-step details
- Memory allocation information
- Thread hijacking details
- PE parsing information
- Detailed error diagnostics

**DLL (AwesomeWotlkLib.dll):**
- Evasion technique logger initialization
- All EVASION_LOG_SUCCESS messages
- Detailed module initialization steps
- Hook attachment details
- CVar registration details
- Thread creation notifications
- Environment safety checks
- Advanced evasion technique deployment

**What's always shown:**
- Process found/not found messages
- Final injection success/failure
- Critical errors that prevent operation
- Essential status messages

## For Developers

To switch between modes during development, simply change this line in `Injector.cpp`:
```cpp
// Default to true (dev mode) if no environment variable
return true;  // Change to false for production builds
```

Or use the environment variable approach for runtime control.
