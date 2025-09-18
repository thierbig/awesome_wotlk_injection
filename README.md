# Advanced Anti-Detection Injection System

This project implements sophisticated stealth injection techniques designed to avoid common detection methods used by anti-cheat systems and security monitoring tools. The system employs multiple layers of evasion techniques for educational cybersecurity research.

## 🔒 Core Anti-Detection Features

### **1. Multi-Target World-State Aware Injection**
- **Dual process support**: Automatically detects and injects into either `Project Epoch.exe` or `ascension.exe`
- **Pre-injection scanning**: Monitors target process memory for world-state indicators
- **Smart timing**: Only injects after character has fully entered the game world
- **Memory pattern analysis**: Scans multiple addresses (`0x00B4A000`, `0x00C5D000`, `0x00D3F000`) for in-world flags
- **Timeout protection**: Aborts after 5 minutes if world entry is not detected

### **2. Dynamic Timing Randomization**
- **Variable polling intervals**: 1-3 second randomized delays between world state checks  
- **Post-detection delay**: 1 second pause after world entry detection
- **Non-predictable patterns**: Polling timing uses cryptographically secure random generation

### **3. String Obfuscation & Static Analysis Evasion**
- **XOR encryption**: Process names and DLL paths encrypted with key `0x42`
- **Runtime decryption**: Strings only decrypted when needed, then discarded
- **No plaintext artifacts**: Static analysis reveals no obvious target information
- **Obfuscated constants**:
  ```cpp
  ENCRYPTED_PROCESS_NAME_1 = {0x16, 0x72, 0x6f, 0x6a, 0x65, 0x63, 0x74, 0x20, 0x27, 0x70, 0x6f, 0x63, 0x68, 0x2e, 0x65, 0x78, 0x65} // "Project Epoch.exe"
  ENCRYPTED_PROCESS_NAME_2 = {0x01, 0x73, 0x63, 0x65, 0x6e, 0x73, 0x69, 0x6f, 0x6e, 0x2e, 0x65, 0x78, 0x65} // "ascension.exe"
  ENCRYPTED_DLL_NAME = {0x0b, 0x77, 0x65, 0x73, 0x6f, 0x6d, 0x65, 0x37, 0x6f, 0x74, 0x6c, 0x6b, 0x2c, 0x69, 0x62, 0x2e, 0x64, 0x6c, 0x6c}
  ```

### **4. Advanced Anti-Cheat Sandboxing & Evasion**
- **ClientExtensions.dll detection**: Identifies the anti-cheat component and enables enhanced stealth mode
- **Comprehensive module hiding**: Intercepts multiple APIs to completely hide our presence:
  - `GetModuleHandle()` and `GetModuleHandleW()` return null for our DLL
  - `EnumProcessModules()` removes our module from enumeration results
  - `GetModuleInformation()` fails when querying our module info
  - `GetModuleFileName()` hides our DLL path and filename
- **PE header obfuscation**: XOR-encrypts our PE header to break signature detection
- **Thread concealment**: Hides our worker threads from thread enumeration
- **Memory region hiding**: Obscures our memory allocations from scanning
- **API call interception**: Comprehensive hooking of detection APIs used by anti-cheat systems
- **Debugger detection**: `IsDebuggerPresent()` and `CheckRemoteDebuggerPresent()` checks
- **Analysis tool detection**: Scans for common reverse engineering tools:
  - Process Monitor (`procmon.exe`)
  - Process Explorer (`procexp.exe`) 
  - Wireshark (`wireshark.exe`)
  - IDA Pro (`ida.exe`)
  - OllyDbg (`ollydbg.exe`)
  - x32/x64dbg (`x32dbg.exe`, `x64dbg.exe`)
  - Cheat Engine (`cheatengine-x86_64.exe`)

### **5. Two-Stage DLL Initialization**
- **Stage 1 (Immediate)**: Minimal setup on DLL load
  - Only establishes world-state monitoring hooks
  - No suspicious immediate initialization behavior
  - Sets up `Hooks::IsInWorld()` detection capability

- **Stage 2 (Delayed)**: Full activation after world entry
  - Continuously polls world state until character is in-world
  - Immediately initializes all modules and hooks once world detected
  - Performs final environment safety checks

### **6. Memory Access & Trace Cleanup**
- **Minimal privileges**: Uses only necessary process access rights for each phase
- **Instruction cache flushing**: `FlushInstructionCache()` removes injection artifacts
- **Memory cleanup**: Properly frees allocated buffers and closes handles
- **Process handle management**: Separate handles for scanning vs injection phases

## 🛡️ Injection Flow Sequence

```
1. Environment Check → Verify no debuggers/analysis tools
2. String Decryption → Decrypt target process name  
3. Process Location → Find target using encrypted strings
4. Memory Scanning → Read world state from multiple addresses
5. World State Wait → Poll until character enters world (5min timeout)
6. Brief Delay → Apply 1 second pause after world detection
7. Stealth Injection → Minimal privilege CreateRemoteThread injection
8. Trace Cleanup → Flush caches and free injection artifacts
9. DLL Stage 1 → Basic world monitoring setup only
10. DLL Stage 2 → Immediate full initialization once world detected
```

## 🎯 Detection Evasion Strategies

### **Behavioral Evasion**
- **No startup injection**: Waits for active gameplay state
- **Randomized timing**: Eliminates predictable behavioral patterns  
- **Delayed hooking**: Avoids immediate suspicious API modifications
- **Natural injection points**: Only injects during normal game operation

### **Static Analysis Evasion**
- **String encryption**: No plaintext process names or paths
- **Obfuscated constants**: Critical data hidden in encrypted arrays
- **Dynamic resolution**: Target information resolved at runtime only

### **Runtime Analysis Evasion**  
- **Environment detection**: Identifies and avoids analysis environments
- **Debugger checks**: Multiple detection methods for attached debuggers
- **Anti-cheat sandboxing**: Hooks APIs to hide from ClientExtensions.dll detection
- **Module enumeration hiding**: Intercepts and filters module listing calls
- **API call interception**: Redirects detection attempts away from our DLL
- **Tool scanning**: Process enumeration for common RE tools
- **Memory cleanup**: Removes injection traces post-operation

## 🚀 Recent Enhancements

### New Anti-Detection Components (v2.0)
- **AntiDetection Module**: Comprehensive evasion framework with memory scrambling, VM detection, and polymorphic code generation
- **Manual Mapper**: Alternative injection method avoiding CreateRemoteThread with thread hijacking and APC injection
- **Enhanced Environment Checks**: Multi-layered VM/sandbox/debugger detection with adaptive responses
- **Advanced API Hooking**: Lower-level hooks for better anti-cheat evasion

For detailed technical documentation on all anti-detection measures and future improvements, see [Anti-Detection Improvements Guide](docs/anti_detection_improvements.md)

## ⚠️ Research & Educational Use

This system demonstrates advanced evasion techniques for cybersecurity research and education. The methods implemented represent real-world anti-detection strategies used by sophisticated malware, adapted for legitimate security research in controlled environments.

**Use only in authorized testing environments with proper permission.**
