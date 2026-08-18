@echo off
chcp 65001 >nul
echo ============================================
echo   GetWiFi - Windows 一键编译方案
echo ============================================
echo.
echo [方案选择]
echo.
echo   1. 安装WSL2 + Theos (推荐，免费)
echo      在Windows内运行Linux环境编译iOS代码
echo.
echo   2. 安装MinGW/GCC (仅测试C代码)
echo      编译Windows版本测试核心逻辑
echo.
echo   3. 使用云Mac服务 (最方便)
echo      租一台远程Mac，SSH连接编译
echo.
echo   4. 手动安装编译器
echo      单独安装 MSVC / GCC / Clang
echo.
set /p choice="请选择方案 (1-4): "

if "%choice%"=="1" goto :wsl2
if "%choice%"=="2" goto :mingw
if "%choice%"=="3" goto :cloud
if "%choice%"=="4" goto :manual
goto :end

:wsl2
echo.
echo === 方案1: WSL2 + Theos ===
echo.
echo 步骤:
echo   1. 启用WSL2 (需要管理员权限):
echo      打开PowerShell (管理员)，执行:
echo      wsl --install
echo      wsl --set-default-version 2
echo.
echo   2. 安装Ubuntu (在Microsoft Store搜索)
echo      或执行: wsl --install -d Ubuntu
echo.
echo   3. 进入Ubuntu后，执行以下命令:
echo.
echo      # 安装依赖
echo      sudo apt update && sudo apt install -y build-essential git libusb-dev
echo.
echo      # 安装Theos
echo      git clone https://github.com/theos/theos.git ~/theos
echo      cd ~/theos && make
echo.
echo      # 安装iOS SDK
echo      # 方法A: 从越狱设备导出
echo      # scp root@设备IP:/usr/include ~/theos/
echo      # 方法B: 下载预编译SDK
echo      # git clone https://github.com/theos/sdks ~/theos/sdks
echo.
echo      # 编译项目
echo      cd /mnt/e/Program\ Files/Trae\ CN/workplace/debStudy
echo      export THEOS=~/theos
echo      make clean && make package
echo.
echo   4. 输出: deb文件在 packages/ 目录
echo.
pause
goto :end

:mingw
echo.
echo === 方案2: MinGW/GCC (Windows原生编译) ===
echo.
echo 此方案仅能编译Windows版本用于测试C代码逻辑
echo 不能生成iOS arm64二进制文件
echo.
echo 步骤:
echo   1. 下载 MinGW-w64:
echo      访问 https://www.mingw-w64.org 或使用 winlibs 版本
echo      推荐: https://github.com/brechtsanders/winlibs_mingw/releases
echo.
echo   2. 安装后添加到PATH:
echo      将安装目录的bin文件夹添加到系统环境变量PATH
echo.
echo   3. 验证安装:
echo      gcc --version
echo.
echo   4. 编译 (在本项目目录执行):
echo      gcc -o build\getwifi.exe src\getwifi_cross.c -lws2_32
echo.
echo   5. 运行测试:
echo      build\getwifi.exe
echo.
echo   注意: 此版本只能在Windows上获取WiFi信息
echo         要编译iOS版本仍需使用方案1或3
echo.
pause
goto :end

:cloud
echo.
echo === 方案3: 云Mac服务 ===
echo.
echo 推荐的云Mac服务:
echo.
echo   1. MacStadium (最专业)
echo      https://www.macstadium.com
echo      价格: 约 $0.08/小时起
echo.
echo   2. VirtualMac (快速启动)
echo      https://www.virtualmac.com
echo      价格: 约 $5/月
echo.
echo   3. MacinCloud (按月订阅)
echo      https://www.macincloud.com
echo.
echo   4. 阿里云/腾讯云 macOS实例 (国内)
echo.
echo 使用步骤:
echo   1. 注册并购买Mac实例 (macOS 13+)
echo   2. 安装Xcode (App Store免费)
echo   3. SSH连接: ssh user@cloud-mac-ip
echo   4. 上传项目: scp -r ./debStudy user@cloud-mac-ip:~/
echo   5. 编译:
echo      cd ~/debStudy
echo      xcodebuild (需要配置Xcode项目)
echo      或使用命令行clang编译
echo.
echo   注意: 需要自己配置Theos和iOS SDK
echo.
pause
goto :end

:manual
echo.
echo === 方案4: 手动安装编译器 ===
echo.
echo 可用的C编译器:
echo.
echo   MSVC (Visual Studio):
echo     下载: https://visualstudio.microsoft.com
echo     安装时勾选 "使用C++的桌面开发"
echo     编译: cl /Fe:getwifi.exe src\getwifi_cross.c /link wlanapi.lib
echo.
echo   Clang for Windows:
echo     下载: https://llvm.org/builds
echo     编译: clang -o getwifi.exe src\getwifi_cross.c -lws2_32
echo.
echo   MinGW-w64 GCC:
echo     下载: https://www.mingw-w64.org
echo     编译: gcc -o getwifi.exe src\getwifi_cross.c -lws2_32
echo.
echo   安装完成后，重新运行本脚本即可自动检测
echo.
pause
goto :end

:end
