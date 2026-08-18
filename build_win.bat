@echo off
chcp 65001 >nul
echo ============================================
echo   GetWiFi Windows 编译脚本
echo ============================================
echo.

setlocal enabledelayedexpansion

set PROJECT_DIR=%~dp0
set BUILD_DIR=%PROJECT_DIR%build

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

set COMPILER=
set COMPILE_CMD=

where cl >nul 2>&1
if %errorlevel%==0 (
    set COMPILER=MSVC
    set COMPILE_CMD=cl /Fe:"%BUILD_DIR%\getwifi.exe" "%PROJECT_DIR%src\getwifi_cross.c" /link wlanapi.lib
    goto :found_compiler
)

where gcc >nul 2>&1
if %errorlevel%==0 (
    set COMPILER=GCC
    set COMPILE_CMD=gcc -o "%BUILD_DIR%\getwifi.exe" "%PROJECT_DIR%src\getwifi_cross.c" -lws2_32
    goto :found_compiler
)

where clang >nul 2>&1
if %errorlevel%==0 (
    set COMPILER=Clang
    set COMPILE_CMD=clang -o "%BUILD_DIR%\getwifi.exe" "%PROJECT_DIR%src\getwifi_cross.c" -lws2_32
    goto :found_compiler
)

echo [错误] 未找到任何C编译器！
echo.
echo 请安装以下任一编译器:
echo   1. Visual Studio (MSVC) - https://visualstudio.microsoft.com
echo   2. MinGW-w64 (GCC)     - https://www.mingw-w64.org
echo   3. LLVM (Clang)        - https://llvm.org
echo.
echo 或者使用以下方式快速开始:
echo   - winget install Microsoft.VisualStudio.2022.BuildTools
echo   - winget install LLVM.LLVM
echo.
pause
exit /b 1

:found_compiler
echo 检测到编译器: %COMPILER%
echo.
echo [1/3] 编译中...
echo.

%COMPILE_CMD%

if %errorlevel% neq 0 (
    echo.
    echo [错误] 编译失败！
    echo.
    echo 可能的原因:
    echo   1. 缺少Windows SDK头文件
    echo   2. 编译器版本过低
    echo   3. 代码语法错误
    echo.
    echo 解决方案:
    echo   - 确保安装了Windows SDK 10.0+
    echo   - Visual Studio用户请在Developer Command Prompt中运行此脚本
    pause
    exit /b 1
)

echo.
echo [2/3] 编译成功！
echo.
echo [3/3] 运行测试...
echo.

"%BUILD_DIR%\getwifi.exe"
echo.

echo ============================================
echo   编译完成
echo ============================================
echo.
echo 输出文件: %BUILD_DIR%\getwifi.exe
echo.
echo 该版本可在Windows上测试WiFi信息获取逻辑
echo 要编译iOS版本（arm64），需要:
echo   1. macOS + Xcode (推荐)
echo   2. WSL2 + Theos + iOS SDK
echo   3. 云Mac服务 (如 MacStadium)
echo.
pause
