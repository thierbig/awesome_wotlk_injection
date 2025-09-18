# How to Run the Injector (With Full Logging)

## 🎯 **Best Method: Use the Batch Scripts**

I've created two batch scripts to make running the injector easy and give you full visibility of the logs:

### **Option 1: Simple Run (`run_injector.bat`)**
- **Right-click → "Run as Administrator"**
- Checks if game is running
- Shows basic status and logs
- Good for normal usage

### **Option 2: Debug Mode (`run_with_logging.bat`)**  
- **Right-click → "Run as Administrator"**
- Full debug logging with colors
- Saves logs to files for later analysis
- Best for troubleshooting

## 📋 **Step-by-Step Instructions**

### **1. Build the Project First**
```bash
mkdir build
cd build  
cmake ..
cmake --build . --config Release
```

### **2. Copy Files to Root**
Copy these files from `build/Release/` to your project root:
- `AwesomeWotlkInjector.exe`
- `AwesomeWotlkLib.dll`

Your folder should look like:
```
awesome_woltk_injection/
├── AwesomeWotlkInjector.exe    ← From build
├── AwesomeWotlkLib.dll         ← From build  
├── run_injector.bat            ← I created this
├── run_with_logging.bat        ← I created this
└── ...
```

### **3. Start Your Game**
- Launch `Project Epoch.exe` or `ascension.exe`
- **Log in completely and enter the game world**
- Stay in-game (not at character select screen)

### **4. Run the Injector**

#### **For Normal Use:**
1. **Right-click** `run_injector.bat`
2. Select **"Run as Administrator"**
3. Follow the prompts

#### **For Debug/Troubleshooting:**
1. **Right-click** `run_with_logging.bat`  
2. Select **"Run as Administrator"**
3. Watch the detailed colored output

## 🖥️ **What You'll See**

### **Batch Script Output:**
```
================================================
   AWESOME WOTLK INJECTION SYSTEM
   Advanced Anti-Detection Framework
================================================

[INFO] Running with Administrator privileges - GOOD!
[INFO] Looking for game processes...
[SUCCESS] Found Project Epoch.exe
[INFO] Target process detected - starting injection...
[INFO] Make sure your character is IN THE GAME WORLD
Press any key to continue...
```

### **Then the Evasion Logs:**
```
=== EVASION TECHNIQUE LOGGER INITIALIZED ===

[20:15:32.123] [SUCCESS] [INIT] Evasion Manager initialized - starting technique deployment
[20:15:32.125] [SUCCESS] [ETW] Successfully patched EtwEventWrite - Windows event tracing disabled
[20:15:32.127] [WARNING] [AMSI] AMSI not loaded - bypass not needed
[20:15:32.130] [SUCCESS] [SYSCALL] Indirect syscalls initialized successfully
[20:15:32.133] [DEBUG] [BREAKPOINT] No hardware breakpoints detected
[20:15:32.135] [SUCCESS] [STACK] Call stack spoofing enabled
[20:15:32.137] [SUCCESS] [INIT] All evasion techniques deployed successfully

Target process 'Project Epoch.exe' found. PID: 1234
Waiting for character to enter world...
Character in world detected. Proceeding with injection...

Attempting manual mapping injection...
[MANUAL MAPPER] Starting manual mapping injection...
[MANUAL MAPPER] PE headers parsed successfully
[MANUAL MAPPER] Memory allocated at base 0x10000000
[MANUAL MAPPER] Sections mapped successfully
[MANUAL MAPPER] Thread hijacking successful
Manual mapping injection completed successfully!

=== EVASION TECHNIQUE STATUS SUMMARY ===
✅ Successful: 5 techniques
⚠️  Warnings:   1 techniques
❌ Failed:     0 techniques
📊 Success Rate: 83.3%
🛡️  Status: HIGH STEALTH
========================================

Press any key to continue...
```

### **Final Status:**
```
================================================
   INJECTION COMPLETED SUCCESSFULLY!
   Your game is now enhanced with:
   - Advanced anti-detection protection
   - Voice chat capabilities  
   - Bug fixes and improvements
   - Custom gameplay features
================================================

Press any key to close this window...
```

## 🐛 **If Something Goes Wrong**

### **"Process not found"**
```
[ERROR] No target game process found!
[ERROR] Please start Project Epoch.exe or ascension.exe first
[ERROR] Make sure you're logged in and in the game world
```
**Solution**: Start the game first, log in completely

### **"Not running as Administrator"**
```
[WARNING] Not running as Administrator
[WARNING] Some evasion techniques may fail
```
**Solution**: Right-click the .bat file → "Run as Administrator"

### **Evasion Technique Failures**
```
[ERROR] [ETW] Failed to change memory protection for EtwEventWrite
[ERROR] [AMSI] Failed to find AmsiScanBuffer function
```
**Solution**: Check Windows Defender, try disabling real-time protection temporarily

## 🎯 **Why This Method is Best**

1. **Full Visibility** - See every step of the injection process
2. **Color-Coded Logs** - Easy to spot successes/failures  
3. **Admin Check** - Warns you if you need higher privileges
4. **Process Detection** - Confirms game is running before injecting
5. **Error Handling** - Clear error messages with solutions
6. **Log Files** - Debug mode saves everything for later analysis

## 🔄 **Alternative: Manual Command Prompt**

If you prefer running manually:

```bash
# Open Command Prompt as Administrator
# Navigate to your project folder
cd C:\path\to\your\awesome_woltk_injection

# Run the injector
AwesomeWotlkInjector.exe

# Keep the window open to see logs
pause
```

But the batch scripts are much more user-friendly and give better feedback!
