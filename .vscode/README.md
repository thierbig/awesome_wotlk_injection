# VS Code Local Development Setup

This `.vscode` folder replicates the GitHub Actions workflow locally so you can build and test without relying on GitHub Actions.

## 🚀 Quick Start

Press `F5` or `Ctrl+F5` and select one of these launch configurations:

### **Launch Configurations Available:**

1. **🔨 Build and Run Injector**
   - Builds the project and runs the injector directly
   - Best for: Quick testing of injector functionality

2. **📡 Run Continuous Monitor** 
   - Builds the project, copies files, and runs the continuous monitor
   - Best for: Full automated injection workflow

3. **🧹 Clean Build and Run Monitor**
   - Clean build + continuous monitor
   - Best for: When you need a fresh build

4. **🐛 Debug Injector**
   - Builds and runs injector with debugger attached
   - Best for: Debugging injection issues

5. **🔧 Build Only**
   - Just builds the project without running anything
   - Best for: When you only want to compile

## 🛠️ Build Tasks Available

You can also run individual tasks via `Ctrl+Shift+P` → "Tasks: Run Task":

- **Fix Detours Interlocked Functions** - Applies the Detours fix
- **Configure CMake** - Sets up the build system  
- **Build DLL and Injector** - Compiles the project
- **Clean Build** - Removes build artifacts
- **Full Build (Clean + Build)** - Complete rebuild
- **Copy DLL to Root** - Copies built files to project root

## 📋 Requirements

- **Visual Studio 2022** (Community/Professional/Enterprise)
- **VS Code** with C/C++ extension
- **CMake** (usually comes with VS2022)

## ⚡ Keyboard Shortcuts

- `F5` - Run with debugging
- `Ctrl+F5` - Run without debugging  
- `Ctrl+Shift+P` → "Tasks: Run Build Task" - Quick build
- `Ctrl+Shift+B` - Default build task

## 🎯 Workflow Equivalent

This setup replicates the exact same steps as `build-injector.yml`:

```yaml
# GitHub Actions          →  VS Code Task
Fix Detours               →  "Fix Detours Interlocked Functions"  
Configure CMake           →  "Configure CMake"
Build DLL and Injector    →  "Build DLL and Injector"
```

The launch configurations then run the built executables automatically!
