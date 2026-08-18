@echo off
chcp 65001 >nul
echo ============================================
echo   iOS WiFi 插件 - Windows 构建脚本
echo ============================================
echo.

set PROJECT_DIR=%~dp0
set BUILD_DIR=%PROJECT_DIR%build
set DEB_DIR=%PROJECT_DIR%package

if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%DEB_DIR%" rmdir /s /q "%DEB_DIR%"
mkdir "%BUILD_DIR%"
mkdir "%DEB_DIR%"

echo [1/4] 检查编译工具...
where clang >nul 2>&1
if errorlevel 1 (
    echo 错误: 未找到 clang 编译器
    echo 请安装 Xcode 或 iOS 交叉编译工具链
    pause
    exit /b 1
)

echo [2/4] 编译 getwifi 命令行工具...
clang -arch arm64 -fobjc-arc -framework Foundation -o "%BUILD_DIR%\getwifi" "%PROJECT_DIR%src\getwifi.m" -lMobileWiFi
if errorlevel 1 (
    echo 错误: 编译 getwifi 失败
    pause
    exit /b 1
)

echo [3/4] 编译 GetWiFi SpringBoard 插件...
clang -arch arm64 -fobjc-arc -fPIC -shared -framework UIKit -framework Foundation -o "%BUILD_DIR%\GetWiFi.dylib" "%PROJECT_DIR%src\GetWiFi.mm" -lMobileWiFi
if errorlevel 1 (
    echo 错误: 编译 GetWiFi.dylib 失败
    pause
    exit /b 1
)

echo [4/4] 创建 deb 包结构...
mkdir "%DEB_DIR%\DEBIAN"
mkdir "%DEB_DIR%\usr\local\bin"
mkdir "%DEB_DIR%\Library\Loader\SBPlugins"

copy "%BUILD_DIR%\getwifi" "%DEB_DIR%\usr\local/bin\" >nul
copy "%BUILD_DIR%\GetWiFi.dylib" "%DEB_DIR%\Library\Loader\SBPlugins\" >nul

(
echo Package: com.debstudy.getwifi
echo Version: 1.0.0
echo Section: Utilities
echo Priority: optional
echo Architecture: arm64
echo Maintainer: DebStudy ^<debstudy@example.com^>
echo Description: 获取iOS设备WiFi名称的插件
echo   提供命令行工具和SpringBoard插件
echo Depends: firmware ^(^>=11.0^), mobilesubstrate
) > "%DEB_DIR%\DEBIAN\control"

(
echo #!/bin/sh
echo chmod 755 /usr/local/bin/getwifi
echo chmod 755 /Library/Loader/SBPlugins/GetWiFi.dylib
echo killall -9 SpringBoard
) > "%DEB_DIR%\DEBIAN\postinst"

echo.
echo ============================================
echo   构建完成！
echo ============================================
echo.
echo 输出目录: %BUILD_DIR%
echo   - getwifi (命令行工具)
echo   - GetWiFi.dylib (SpringBoard插件)
echo.
echo 要创建 deb 包，请在 Linux/macOS 上执行:
echo   dpkg-deb -b package/ com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb
echo.
pause
