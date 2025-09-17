#include "BugFixes.h"
#include "CommandLine.h"
#include "NamePlates.h"
#include "Misc.h"
#include "Hooks.h"
#include "Inventory.h"
#include "Item.h"
#include "Spell.h"
#include "UnitAPI.h"
#include <Windows.h>
#include <Detours/detours.h>
#include <Psapi.h>
#include "VoiceChat.h"
#include <thread>
#include <chrono>
#include <random>
#include <vector>

static int lua_debugbreak(lua_State* L)
{
    if (IsDebuggerPresent())
        DebugBreak();
    return 0;
}

static int lua_openawesomewotlk(lua_State* L)
{
    lua_pushnumber(L, 1.f);
    lua_setglobal(L, "AwesomeWotlk");
#ifdef _DEBUG
    lua_pushcfunction(L, lua_debugbreak);
    lua_setglobal(L, "debugbreak");
#endif
    return 0;
}

// Hook common anti-cheat detection APIs to hide our presence
static HMODULE (WINAPI* OriginalGetModuleHandleA)(LPCSTR lpModuleName) = GetModuleHandleA;
static HMODULE (WINAPI* OriginalGetModuleHandleW)(LPCWSTR lpModuleName) = GetModuleHandleW;
static BOOL (WINAPI* OriginalEnumProcessModules)(HANDLE hProcess, HMODULE* lphModule, DWORD cb, LPDWORD lpcbNeeded) = EnumProcessModules;

// Our DLL name for hiding
static const char* OUR_DLL_NAME = "AwesomeWotlkLib.dll";
static HMODULE g_ourModule = nullptr;

HMODULE WINAPI HookedGetModuleHandleA(LPCSTR lpModuleName) {
    if (lpModuleName && _stricmp(lpModuleName, OUR_DLL_NAME) == 0) {
        return nullptr; // Hide our DLL from GetModuleHandle calls
    }
    return OriginalGetModuleHandleA(lpModuleName);
}

HMODULE WINAPI HookedGetModuleHandleW(LPCWSTR lpModuleName) {
    if (lpModuleName) {
        char narrowName[MAX_PATH];
        WideCharToMultiByte(CP_ACP, 0, lpModuleName, -1, narrowName, MAX_PATH, NULL, NULL);
        if (_stricmp(narrowName, OUR_DLL_NAME) == 0) {
            return nullptr; // Hide our DLL from GetModuleHandle calls
        }
    }
    return OriginalGetModuleHandleW(lpModuleName);
}

BOOL WINAPI HookedEnumProcessModules(HANDLE hProcess, HMODULE* lphModule, DWORD cb, LPDWORD lpcbNeeded) {
    BOOL result = OriginalEnumProcessModules(hProcess, lphModule, cb, lpcbNeeded);
    
    if (result && lphModule && lpcbNeeded) {
        DWORD moduleCount = *lpcbNeeded / sizeof(HMODULE);
        
        // Remove our module from the enumeration
        for (DWORD i = 0; i < moduleCount; i++) {
            if (lphModule[i] == g_ourModule) {
                // Shift remaining modules down
                for (DWORD j = i; j < moduleCount - 1; j++) {
                    lphModule[j] = lphModule[j + 1];
                }
                *lpcbNeeded -= sizeof(HMODULE);
                break;
            }
        }
    }
    
    return result;
}

// Additional stealth APIs
static BOOL (WINAPI* OriginalGetModuleInformation)(HANDLE hProcess, HMODULE hModule, LPMODULEINFO lpmodinfo, DWORD cb) = GetModuleInformation;
static DWORD (WINAPI* OriginalGetModuleFileNameA)(HMODULE hModule, LPSTR lpFilename, DWORD nSize) = GetModuleFileNameA;
static DWORD (WINAPI* OriginalGetModuleFileNameW)(HMODULE hModule, LPWSTR lpFilename, DWORD nSize) = GetModuleFileNameW;

// Hook GetModuleInformation to hide our module info
BOOL WINAPI HookedGetModuleInformation(HANDLE hProcess, HMODULE hModule, LPMODULEINFO lpmodinfo, DWORD cb) {
    if (hModule == g_ourModule) {
        SetLastError(ERROR_INVALID_HANDLE);
        return FALSE; // Hide our module information
    }
    return OriginalGetModuleInformation(hProcess, hModule, lpmodinfo, cb);
}

// Hook GetModuleFileName to hide our DLL path
DWORD WINAPI HookedGetModuleFileNameA(HMODULE hModule, LPSTR lpFilename, DWORD nSize) {
    if (hModule == g_ourModule) {
        SetLastError(ERROR_INVALID_HANDLE);
        return 0; // Hide our filename
    }
    return OriginalGetModuleFileNameA(hModule, lpFilename, nSize);
}

DWORD WINAPI HookedGetModuleFileNameW(HMODULE hModule, LPWSTR lpFilename, DWORD nSize) {
    if (hModule == g_ourModule) {
        SetLastError(ERROR_INVALID_HANDLE);
        return 0; // Hide our filename
    }
    return OriginalGetModuleFileNameW(hModule, lpFilename, nSize);
}

// Memory pattern obfuscation - XOR our PE header
static void ObfuscatePEHeader() {
    MEMORY_BASIC_INFORMATION mbi;
    if (VirtualQuery(g_ourModule, &mbi, sizeof(mbi))) {
        DWORD oldProtect;
        if (VirtualProtect(mbi.BaseAddress, 0x1000, PAGE_EXECUTE_READWRITE, &oldProtect)) {
            // XOR the PE header to break signature detection
            BYTE* header = (BYTE*)mbi.BaseAddress;
            for (int i = 0; i < 0x400; i++) {
                header[i] ^= 0x42;
            }
            VirtualProtect(mbi.BaseAddress, 0x1000, oldProtect, &oldProtect);
        }
    }
}

// Install comprehensive API hooks to hide from ClientExtensions.dll
static void InstallAntiCheatEvasion() {
    DetourTransactionBegin();
    DetourUpdateThread(GetCurrentThread());
    
    // Hook module enumeration APIs to hide our presence
    DetourAttach(&(PVOID&)OriginalGetModuleHandleA, HookedGetModuleHandleA);
    DetourAttach(&(PVOID&)OriginalGetModuleHandleW, HookedGetModuleHandleW);
    DetourAttach(&(PVOID&)OriginalEnumProcessModules, HookedEnumProcessModules);
    DetourAttach(&(PVOID&)OriginalGetModuleInformation, HookedGetModuleInformation);
    DetourAttach(&(PVOID&)OriginalGetModuleFileNameA, HookedGetModuleFileNameA);
    DetourAttach(&(PVOID&)OriginalGetModuleFileNameW, HookedGetModuleFileNameW);
    
    DetourTransactionCommit();
    
    // Obfuscate our PE header after hooking
    ObfuscatePEHeader();
}

// Anti-debugging and stealth measures
static bool IsEnvironmentSafe() {
    // Check for debugger
    if (IsDebuggerPresent()) {
        return false;
    }
    
    // Check if ClientExtensions.dll is loaded (anti-cheat system)
    HMODULE clientExt = GetModuleHandleA("ClientExtensions.dll");
    if (clientExt != nullptr) {
        // Install enhanced anti-cheat evasion hooks
        InstallAntiCheatEvasion();
    }
    
    // Check for common analysis tools in memory
    HMODULE modules[] = {
        GetModuleHandleA("dbghelp.dll"),
        GetModuleHandleA("ntdll.dll")
    };
    
    // Basic heuristic checks (expand as needed)
    return true;
}

// Hide our threads from thread enumeration
static HANDLE (WINAPI* OriginalCreateToolhelp32Snapshot)(DWORD dwFlags, DWORD th32ProcessID) = CreateToolhelp32Snapshot;
static std::vector<DWORD> g_ourThreadIds;

HANDLE WINAPI HookedCreateToolhelp32Snapshot(DWORD dwFlags, DWORD th32ProcessID) {
    HANDLE result = OriginalCreateToolhelp32Snapshot(dwFlags, th32ProcessID);
    
    if (dwFlags & TH32CS_SNAPTHREAD) {
        // If they're enumerating threads, we need to hide our threads
        // This is a simplified approach - in practice you'd need more sophisticated filtering
    }
    
    return result;
}

// Install additional thread/memory hiding hooks
static void InstallAdvancedEvasion() {
    DetourTransactionBegin();
    DetourUpdateThread(GetCurrentThread());
    
    DetourAttach(&(PVOID&)OriginalCreateToolhelp32Snapshot, HookedCreateToolhelp32Snapshot);
    
    DetourTransactionCommit();
}

// Delayed initialization function
static void DelayedInitialization() {
    // Store our thread ID for hiding
    g_ourThreadIds.push_back(GetCurrentThreadId());
    
    // Wait until we're definitely in world
    int attempts = 0;
    const int maxAttempts = 60; // 5 minutes max wait
    
    while (attempts < maxAttempts) {
        if (Hooks::IsInWorld()) {
            break; // Proceed immediately once in world
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(5000)); // Check every5 seconds
        attempts++;
    }
    
    if (attempts >= maxAttempts) {
        return; // Failed to detect world entry, abort initialization
    }
    
    // Install additional evasion measures
    InstallAdvancedEvasion();
    
    // Proceed with actual module initialization immediately after world entry
    OnRealAttach();
}

static void OnRealAttach()
{
    // Environment safety check
    if (!IsEnvironmentSafe()) {
        return;
    }

    *(DWORD*)0x00B6AF54 = 1; // TOSAccepted = 1
    *(DWORD*)0x00B6AF5C = 1; // EULAAccepted = 1

    // Initialize modules
    DetourTransactionBegin();
    DetourUpdateThread(GetCurrentThread());
    Hooks::initialize();
    BugFixes::initialize();
    CommandLine::initialize();
    Inventory::initialize();
    Item::initialize();
    NamePlates::initialize();
    Misc::initialize();
    UnitAPI::initialize();
    Spell::initialize();
    VoiceChat::initialize();
    DetourTransactionCommit();

    // Register base
    Hooks::FrameXML::registerLuaLib(lua_openawesomewotlk);
}

static void OnAttach()
{
    // Just set up basic hooks and world state monitoring
    // Actual initialization happens later
    DetourTransactionBegin();
    DetourUpdateThread(GetCurrentThread());
    Hooks::initialize(); // This sets up world state detection
    DetourTransactionCommit();
}

static DWORD WINAPI AttachThread(LPVOID) {
    g_ourThreadIds.push_back(GetCurrentThreadId());
    OnAttach();
    return 0;
}

static DWORD WINAPI DelayedInitThread(LPVOID) {
    g_ourThreadIds.push_back(GetCurrentThreadId());
    DelayedInitialization();
    return 0;
}

int __stdcall DllMain(HMODULE hModule, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(hModule);
        
        // Store our module handle for hiding
        g_ourModule = hModule;
        
        // Basic attachment for world state monitoring
        HANDLE h1 = CreateThread(nullptr, 0, AttachThread, nullptr, 0, nullptr);
        if (h1) CloseHandle(h1);
        
        // Delayed initialization thread
        HANDLE h2 = CreateThread(nullptr, 0, DelayedInitThread, nullptr, 0, nullptr);
        if (h2) CloseHandle(h2);
    }
    return 1;
}