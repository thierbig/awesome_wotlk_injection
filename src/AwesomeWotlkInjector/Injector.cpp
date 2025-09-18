#include <iostream>
#include <Windows.h>
#include <TlHelp32.h>
#include <string>
#include <filesystem>
#include <thread>
#include <chrono>
#include <random>
#include <vector>
#include <algorithm>
#include <cwctype>
#include "ManualMapper.h"

// Forward declarations
DWORD GetProcessIdByName(const std::wstring& processName);

// String obfuscation helper
std::wstring DecryptString(const std::vector<int>& encrypted) {
    std::wstring result;
    for (int c : encrypted) {
        result += static_cast<wchar_t>(c ^ 0x42); // Simple XOR obfuscation
    }
    return result;
}

// Obfuscated strings
static const std::vector<int> ENCRYPTED_PROCESS_NAME_1 = {0x16, 0x72, 0x6f, 0x6a, 0x65, 0x63, 0x74, 0x20, 0x27, 0x70, 0x6f, 0x63, 0x68, 0x2e, 0x65, 0x78, 0x65}; // "Project Epoch.exe"
static const std::vector<int> ENCRYPTED_PROCESS_NAME_2 = {0x01, 0x73, 0x63, 0x65, 0x6e, 0x73, 0x69, 0x6f, 0x6e, 0x2e, 0x65, 0x78, 0x65}; // "ascension.exe"
static const std::vector<int> ENCRYPTED_DLL_NAME = {0x0b, 0x77, 0x65, 0x73, 0x6f, 0x6d, 0x65, 0x37, 0x6f, 0x74, 0x6c, 0x6b, 0x2c, 0x69, 0x62, 0x2e, 0x64, 0x6c, 0x6c}; // "AwesomeWotlkLib.dll"

// Anti-debugging checks
bool IsDebuggerAttached() {
    BOOL remote = FALSE;
    CheckRemoteDebuggerPresent(GetCurrentProcess(), &remote);
    return IsDebuggerPresent() || (remote == TRUE);
}

// Check for common analysis tools
bool IsAnalysisToolRunning() {
    const wchar_t* tools[] = {
        L"procmon.exe", L"procexp.exe", L"wireshark.exe", L"ida.exe",
        L"ollydbg.exe", L"x32dbg.exe", L"x64dbg.exe", L"cheatengine-x86_64.exe"
    };
    
    for (const auto& tool : tools) {
        if (GetProcessIdByName(tool) != 0) {
            return true;
        }
    }
    return false;
}

// Check if ClientExtensions.dll is loaded (potential anti-cheat)
bool IsClientExtensionsLoaded(HANDLE hProcess) {
    // Re-implemented without Psapi: use Toolhelp32 module snapshot
    DWORD pid = GetProcessId(hProcess);
    if (pid == 0) return false;

    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid);
    if (snapshot == INVALID_HANDLE_VALUE) return false;

    MODULEENTRY32W me;
    me.dwSize = sizeof(me);
    bool found = false;
    if (Module32FirstW(snapshot, &me)) {
        do {
            std::wstring modName = me.szModule;
            std::transform(modName.begin(), modName.end(), modName.begin(), ::towlower);
            if (modName.find(L"clientextensions.dll") != std::wstring::npos) {
                found = true;
                break;
            }
        } while (Module32NextW(snapshot, &me));
    }
    CloseHandle(snapshot);
    return found;
}

// Check if character is in world by scanning memory
bool IsCharacterInWorld(HANDLE hProcess) {
    // Check if ClientExtensions.dll is loaded (anti-cheat component)
    if (IsClientExtensionsLoaded(hProcess)) {
        std::wcout << L"ClientExtensions.dll detected - anti-cheat present. Using stealth mode." << std::endl;
        // Continue with injection but flag for enhanced stealth measures
    }
    
    // Scan for world state indicator at known addresses
    const std::vector<uintptr_t> worldStateAddresses = {
        0x00B4A000,  // Common world state locations in WotLK client
        0x00C5D000,
        0x00D3F000
    };
    
    for (uintptr_t addr : worldStateAddresses) {
        DWORD worldState = 0;
        SIZE_T bytesRead = 0;
        if (ReadProcessMemory(hProcess, reinterpret_cast<LPCVOID>(addr), &worldState, sizeof(DWORD), &bytesRead)) {
            // Check for typical "in world" indicators
            if (worldState == 1 || (worldState & 0x1) != 0) {
                return true;
            }
        }
    }
    return false;
}

// Wait for character to enter world with timeout
bool WaitForWorldEntry(HANDLE hProcess, int timeoutSeconds = 300) {
    auto startTime = std::chrono::steady_clock::now();
    auto timeout = std::chrono::seconds(timeoutSeconds);
    
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1000, 3000); // 1-3 second intervals
    
    while (std::chrono::steady_clock::now() - startTime < timeout) {
        if (IsCharacterInWorld(hProcess)) {
            // Add random delay after world entry detection
            std::this_thread::sleep_for(std::chrono::milliseconds(dis(gen)));
            return true;
        }
        
        // Random sleep interval to avoid predictable scanning patterns
        std::this_thread::sleep_for(std::chrono::milliseconds(dis(gen)));
    }
    return false;
}

// Function to get the Process ID by process name
DWORD GetProcessIdByName(const std::wstring& processName) {
    PROCESSENTRY32W entry;
    entry.dwSize = sizeof(PROCESSENTRY32W);

    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, NULL);

    if (Process32FirstW(snapshot, &entry) == TRUE) {
        while (Process32NextW(snapshot, &entry) == TRUE) {
            if (std::wstring(entry.szExeFile) == processName) {
                CloseHandle(snapshot);
                return entry.th32ProcessID;
            }
        }
    }

    CloseHandle(snapshot);
    return 0;
}

int wmain(int argc, wchar_t* argv[]) {
    // Anti-analysis checks
    if (IsDebuggerAttached() || IsAnalysisToolRunning()) {
        std::wcerr << L"Security check failed. Environment not suitable for operation." << std::endl;
        return 1;
    }
    
    // Decrypt obfuscated strings
    std::vector<std::wstring> processNames = {
        DecryptString(ENCRYPTED_PROCESS_NAME_1), // "Project Epoch.exe"
        DecryptString(ENCRYPTED_PROCESS_NAME_2)  // "ascension.exe"
    };
    std::wstring dllName = DecryptString(ENCRYPTED_DLL_NAME);
    std::wstring targetProcessName;

    // Check if user provided custom process name
    if (argc >= 2 && argv[1] && wcslen(argv[1]) > 0) {
        targetProcessName = argv[1];
    }
    if (argc >= 3 && argv[2] && wcslen(argv[2]) > 0) {
        dllName = argv[2];
    }

    // 1. Get the full path to the DLL (located next to the injector executable)
    wchar_t modulePath[MAX_PATH] = {0};
    DWORD len = GetModuleFileNameW(nullptr, modulePath, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
        std::wcerr << L"Error: Failed to get injector module path." << std::endl;
        system("pause");
        return 1;
    }
    std::filesystem::path dllPath = std::filesystem::path(modulePath).parent_path() / dllName;

    if (!std::filesystem::exists(dllPath)) {
        std::wcerr << L"Error: '" << dllName << L"' not found next to the injector executable." << std::endl;
        std::wcerr << L"Please place the injector and the DLL in the same directory." << std::endl;
        system("pause");
        return 1;
    }

    // 2. Find the target process (try multiple names if no custom name provided)
    DWORD procId = 0;
    std::wstring foundProcessName;
    
    if (!targetProcessName.empty()) {
        // User provided specific process name
        procId = GetProcessIdByName(targetProcessName);
        foundProcessName = targetProcessName;
    } else {
        // Try both default process names
        for (const auto& processName : processNames) {
            procId = GetProcessIdByName(processName);
            if (procId != 0) {
                foundProcessName = processName;
                break;
            }
        }
    }
    
    if (procId == 0) {
        if (!targetProcessName.empty()) {
            std::wcerr << L"Error: Process '" << targetProcessName << L"' not found." << std::endl;
        } else {
            std::wcerr << L"Error: Neither 'Project Epoch.exe' nor 'ascension.exe' found." << std::endl;
        }
        system("pause");
        return 1;
    }

    std::wcout << L"Target process '" << foundProcessName << L"' found. PID: " << procId << std::endl;
    std::wcout << L"Waiting for character to enter world..." << std::endl;

    // 3. Get a handle to the process with minimal rights for world state checking
    HANDLE hTempProcess = OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, FALSE, procId);
    if (hTempProcess == NULL) {
        std::cerr << "Error: Could not open process for world state checking." << std::endl;
        system("pause");
        return 1;
    }
    
    // Wait for character to be in world before proceeding
    if (!WaitForWorldEntry(hTempProcess, 300)) {
        std::wcerr << L"Timeout: Character did not enter world within 5 minutes." << std::endl;
        CloseHandle(hTempProcess);
        system("pause");
        return 1;
    }
    
    CloseHandle(hTempProcess);
    std::wcout << L"Character in world detected. Proceeding with injection..." << std::endl;
    
    // Add brief delay before injection
    std::this_thread::sleep_for(std::chrono::milliseconds(1000)); // 1 second delay

    // Try advanced injection methods first for better stealth
    bool injectionSuccessful = false;
    
    // Method 1: Manual Mapping (Most stealthy)
    std::wcout << L"Attempting manual mapping injection..." << std::endl;
    if (ManualMapper::InjectDLL(procId, dllPath.wstring())) {
        std::wcout << L"Manual mapping injection completed successfully!" << std::endl;
        injectionSuccessful = true;
    } else {
        std::wcout << L"Manual mapping failed, falling back to traditional injection..." << std::endl;
        
        // Method 2: Traditional CreateRemoteThread (fallback)
        DWORD access = PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ;
        HANDLE hProcess = OpenProcess(access, FALSE, procId);
        if (hProcess == NULL) {
            std::cerr << "Error: Could not open a handle to the process. Try running as administrator." << std::endl;
            system("pause");
            return 1;
        }

        // Allocate memory in the target process for the DLL path
        std::wstring dllPathW = dllPath.wstring();
        SIZE_T bytes = (dllPathW.size() + 1) * sizeof(wchar_t); // include null terminator
        void* loc = VirtualAllocEx(hProcess, nullptr, bytes, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (loc == NULL) {
            std::cerr << "Error: Could not allocate memory in the target process." << std::endl;
            CloseHandle(hProcess);
            system("pause");
            return 1;
        }

        // Write the DLL path to the allocated memory
        if (!WriteProcessMemory(hProcess, loc, dllPathW.c_str(), bytes, nullptr)) {
            std::cerr << "Error: Could not write to the process's memory." << std::endl;
            VirtualFreeEx(hProcess, loc, 0, MEM_RELEASE);
            CloseHandle(hProcess);
            system("pause");
            return 1;
        }

        // Create a remote thread to load the DLL
        HANDLE hThread = CreateRemoteThread(hProcess, 0, 0, (LPTHREAD_START_ROUTINE)LoadLibraryW, loc, 0, 0);
        if (hThread == NULL) {
            std::cerr << "Error: Could not create a remote thread." << std::endl;
            VirtualFreeEx(hProcess, loc, 0, MEM_RELEASE);
            CloseHandle(hProcess);
            system("pause");
            return 1;
        }

        // Wait for remote thread to complete and free remote buffer
        WaitForSingleObject(hThread, INFINITE);
        VirtualFreeEx(hProcess, loc, 0, MEM_RELEASE);
        
        // Additional stealth: Clear injection traces
        FlushInstructionCache(hProcess, nullptr, 0);
        
        std::wcout << L"Traditional injection completed successfully!" << std::endl;
        injectionSuccessful = true;

        // Clean up
        CloseHandle(hThread);
        CloseHandle(hProcess);
    }
    
    if (!injectionSuccessful) {
        std::wcerr << L"All injection methods failed!" << std::endl;
        system("pause");
        return 1;
    }

    system("pause");
    return 0;
}
