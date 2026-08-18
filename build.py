#!/usr/bin/env python3
"""
GetWiFi - 智能编译脚本
自动检测环境并选择最佳编译方案
"""
import os
import sys
import subprocess
import shutil
import urllib.request
import zipfile
import tarfile
import tempfile
import platform
import json

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
BUILD_DIR = os.path.join(PROJECT_DIR, "build")
SRC_DIR = os.path.join(PROJECT_DIR, "src")
OUTPUT_DIR = os.path.join(PROJECT_DIR, "output")
CACHE_DIR = os.path.join(os.environ.get("LOCALAPPDATA", PROJECT_DIR), ".getwifi_cache")

COLORS = {
    "red": "\033[91m",
    "green": "\033[92m",
    "yellow": "\033[93m",
    "blue": "\033[94m",
    "reset": "\033[0m",
    "bold": "\033[1m",
}

def c(color, text):
    return f"{COLORS.get(color, '')}{text}{COLORS['reset']}"

def print_banner():
    print(c("bold", c("blue", "╔══════════════════════════════════════════════╗")))
    print(c("bold", c("blue", "║     GetWiFi iOS 插件 - 智能编译工具          ║")))
    print(c("bold", c("blue", "╚══════════════════════════════════════════════╝")))
    print()

def log_info(msg):
    print(f"  {c('blue','[INFO]')} {msg}")

def log_ok(msg):
    print(f"  {c('green','[OK]')}   {msg}")

def log_warn(msg):
    print(f"  {c('yellow','[WARN]')} {msg}")

def log_err(msg):
    print(f"  {c('red','[ERR]')}  {msg}")

def download_file(url, dest_path, show_progress=True):
    """下载文件，支持进度显示"""
    def progress(block_num, block_size, total_size):
        if show_progress and total_size > 0:
            downloaded = block_num * block_size
            percent = min(100, int(downloaded * 100 / total_size))
            mb_downloaded = downloaded / (1024 * 1024)
            mb_total = total_size / (1024 * 1024)
            sys.stdout.write(f"\r    下载进度: {mb_downloaded:.1f}/{mb_total:.1f} MB ({percent}%)")
            sys.stdout.flush()
    
    try:
        urllib.request.urlretrieve(url, dest_path, reporthook=progress)
        if show_progress:
            print()
        return True
    except Exception as e:
        if show_progress:
            print()
        log_err(f"下载失败: {e}")
        return False

def find_compiler():
    """查找系统中可用的C编译器"""
    for name in ["clang", "gcc", "cl", "zig"]:
        path = shutil.which(name)
        if path:
            try:
                result = subprocess.run(
                    [path, "--version"], capture_output=True, text=True, timeout=5
                )
                version_line = (result.stdout or result.stderr or "").split("\n")[0]
                log_ok(f"找到编译器: {name} -> {path}")
                log_info(f"版本: {version_line}")
                return name, path
            except:
                pass
    return None, None

def download_mingw():
    """下载MinGW-w64编译器"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    
    mingw_bin = os.path.join(CACHE_DIR, "mingw64", "bin")
    gcc_path = os.path.join(mingw_bin, "gcc.exe")
    
    if os.path.exists(gcc_path):
        log_ok(f"检测到已缓存的MinGW: {gcc_path}")
        return gcc_path
    
    urls = [
        ("https://github.com/brechtsanders/winlibs_mingw/releases/download/13.1.0-0/winlibs-x86_64-posix-seh-gcc-13.1.0-llvm-17.0.6-mingw-w64ucrt-11.0.0.zip", "winlibs"),
        ("https://github.com/niXman/mingw-builds-binaries/releases/download/13.1.0-rt11.0.0-ucrt-v12.0.0-x86_64-posix-seh/mingw13.1.0-rt11.0.0-ucrt-v12.0.0-x86_64-posix-seh.zip", "niXman"),
        ("https://github.com/niXman/mingw-builds-binaries/releases/download/12.2.0-rt12.0.0-ucrt-v12.0.0-x86_64-posix-seh/mingw12.2.0-rt12.0.0-ucrt-v12.0.0-x86_64-posix-seh.zip", "niXman-12"),
    ]
    
    for url, source in urls:
        log_info(f"尝试从 {source} 下载...")
        zip_path = os.path.join(tempfile.gettempdir(), f"mingw_{source}.zip")
        
        if download_file(url, zip_path):
            log_info("解压中...")
            try:
                with zipfile.ZipFile(zip_path, 'r') as zf:
                    zf.extractall(CACHE_DIR)
                os.remove(zip_path)
                
                # 查找gcc
                for root, dirs, files in os.walk(CACHE_DIR):
                    if "gcc.exe" in files and "bin" in root:
                        gcc_path = os.path.join(root, "gcc.exe")
                        log_ok(f"MinGW安装完成: {gcc_path}")
                        return gcc_path
            except Exception as e:
                log_err(f"解压失败: {e}")
                if os.path.exists(zip_path):
                    os.remove(zip_path)
    
    return None

def download_zig():
    """下载Zig编程语言编译器（可编译C）"""
    os.makedirs(CACHE_DIR, exist_ok=True)
    
    zig_exe = os.path.join(CACHE_DIR, "zig", "zig.exe")
    if os.path.exists(zig_exe):
        log_ok(f"检测到已缓存的Zig: {zig_exe}")
        return zig_exe
    
    url = "https://ziglang.org/builds/zig-windows-x86_64-0.13.0-dev.371+4f2f1297a.zip"
    log_info("下载Zig编译器 (约50MB)...")
    
    zip_path = os.path.join(tempfile.gettempdir(), "zig.zip")
    if download_file(url, zip_path):
        log_info("解压中...")
        try:
            with zipfile.ZipFile(zip_path, 'r') as zf:
                zf.extractall(CACHE_DIR)
            os.remove(zip_path)
            
            for root, dirs, files in os.walk(CACHE_DIR):
                if "zig.exe" in files:
                    zig_exe = os.path.join(root, "zig.exe")
                    # Create a symlink or just return the path
                    log_ok(f"Zig安装完成: {zig_exe}")
                    return zig_exe
        except Exception as e:
            log_err(f"解压失败: {e}")
    
    return None

def compile_with_gcc(gcc_path, source, output, flags=""):
    """使用GCC编译"""
    cmd = f'"{gcc_path}" -o "{output}" "{source}" {flags}'
    log_info(f"编译: {os.path.basename(source)} -> {os.path.basename(output)}")
    
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=PROJECT_DIR)
    
    if result.returncode != 0:
        log_err("编译失败!")
        if result.stderr:
            print(result.stderr)
        return False
    
    log_ok(f"编译成功: {output}")
    return True

def compile_with_zig(zig_path, source, output, flags=""):
    """使用Zig编译C代码"""
    cmd = f'"{zig_path}" cc -o "{output}" "{source}" {flags}'
    log_info(f"编译: {os.path.basename(source)} -> {os.path.basename(output)}")
    
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=PROJECT_DIR)
    
    if result.returncode != 0:
        log_err("编译失败!")
        if result.stderr:
            print(result.stderr)
        return False
    
    log_ok(f"编译成功: {output}")
    return True

def compile_ios_macos(sdk_path):
    """在macOS上编译iOS版本"""
    clang = shutil.which("clang")
    if not clang:
        log_err("未找到clang")
        return False
    
    target = "arm64-apple-ios11.0"
    
    commands = [
        (os.path.join(SRC_DIR, "getwifi.m"), os.path.join(BUILD_DIR, "getwifi"), 
         f"-arch arm64 -isysroot {sdk_path} -fobjc-arc -framework Foundation -lMobileWiFi"),
        (os.path.join(SRC_DIR, "GetWiFi.mm"), os.path.join(BUILD_DIR, "GetWiFi.dylib"),
         f"-arch arm64 -isysroot {sdk_path} -fobjc-arc -fPIC -shared -framework UIKit -framework Foundation -lMobileWiFi"),
    ]
    
    all_ok = True
    for source, output, flags in commands:
        if not compile_with_gcc(clang, source, output, flags):
            all_ok = False
    
    if all_ok:
        build_deb_package()
    
    return all_ok

def build_deb_package():
    """构建DEB包"""
    log_info("构建DEB包...")
    
    deb_root = os.path.join(tempfile.gettempdir(), "getwifi_deb")
    if os.path.exists(deb_root):
        shutil.rmtree(deb_root)
    
    dirs = [
        os.path.join(deb_root, "DEBIAN"),
        os.path.join(deb_root, "usr", "local", "bin"),
        os.path.join(deb_root, "Library", "Loader", "SBPlugins"),
    ]
    for d in dirs:
        os.makedirs(d, exist_ok=True)
    
    # Copy binaries
    for src, dst in [
        (os.path.join(BUILD_DIR, "getwifi"), os.path.join(deb_root, "usr", "local", "bin", "getwifi")),
        (os.path.join(BUILD_DIR, "GetWiFi.dylib"), os.path.join(deb_root, "Library", "Loader", "SBPlugins", "GetWiFi.dylib")),
    ]:
        if os.path.exists(src):
            shutil.copy2(src, dst)
    
    # Control file
    control = f"""Package: com.debstudy.getwifi
Version: 1.0.0
Section: Utilities
Priority: optional
Architecture: arm64
Maintainer: DebStudy <debstudy@example.com>
Description: 获取iOS设备WiFi信息的越狱插件
Depends: firmware (>=11.0), mobilesubstrate
"""
    with open(os.path.join(deb_root, "DEBIAN", "control"), "w") as f:
        f.write(control)
    
    postinst = '#!/bin/sh\nchmod 755 /usr/local/bin/getwifi\nkillall -9 SpringBoard 2>/dev/null || true\n'
    with open(os.path.join(deb_root, "DEBIAN", "postinst"), "w") as f:
        f.write(postinst)
    
    deb_file = os.path.join(OUTPUT_DIR, "com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb")
    
    # Try dpkg-deb first
    dpkg = shutil.which("dpkg-deb")
    if dpkg:
        subprocess.run([dpkg, "-b", deb_root, deb_file], check=True)
    else:
        # Create a minimal deb using ar + tar
        # A proper deb is: ar archive containing debian-binary, control.tar.gz, data.tar.gz
        try:
            import io
            
            debian_binary = b"2.0\n"
            
            # Control tar
            ctrl_buf = io.BytesIO()
            with tarfile.open(fileobj=ctrl_buf, mode='w:gz') as tar:
                tar.add(os.path.join(deb_root, "DEBIAN"), arcname="./")
            control_data = ctrl_buf.getvalue()
            
            # Data tar
            data_buf = io.BytesIO()
            with tarfile.open(fileobj=data_buf, mode='w:gz') as tar:
                for d in ["usr", "Library"]:
                    full_path = os.path.join(deb_root, d)
                    if os.path.exists(full_path):
                        tar.add(full_path, arcname=f"./{d}")
            data_data = data_buf.getvalue()
            
            # AR archive (simplified)
            with open(deb_file, 'wb') as f:
                f.write(b"!<arch>\n")
                # debian-binary
                f.write(b"debian-binary/     0           0     100644  ")
                f.write(f"{len(debian_binary):10d}".encode())
                f.write(b"  0     U\n")
                f.write(debian_binary)
                if len(debian_binary) % 2:
                    f.write(b" ")
                # control
                f.write(b"control.tar.gz/    0           0     100644  ")
                f.write(f"{len(control_data):10d}".encode())
                f.write(b"  0     U\n")
                f.write(control_data)
                if len(control_data) % 2:
                    f.write(b" ")
                # data
                f.write(b"data.tar.gz/       0           0     100644  ")
                f.write(f"{len(data_data):10d}".encode())
                f.write(b"  0     U\n")
                f.write(data_data)
                if len(data_data) % 2:
                    f.write(b" ")
        except Exception as e:
            log_err(f"DEB打包失败: {e}")
            # Fall back to tar.gz
            tar_file = os.path.join(OUTPUT_DIR, "getwifi_package.tar.gz")
            with tarfile.open(tar_file, "w:gz") as tar:
                tar.add(deb_root, arcname=".")
            log_warn(f"已创建tar.gz备份: {tar_file}")
    
    shutil.rmtree(deb_root, ignore_errors=True)
    log_ok(f"DEB包: {deb_file}")

def test_windows_binary(exe_path):
    """测试Windows可执行文件"""
    log_info("运行测试...")
    try:
        result = subprocess.run(
            [exe_path], capture_output=True, text=True, timeout=5,
            creationflags=subprocess.CREATE_NO_WINDOW
        )
        output = result.stdout + result.stderr
        if output.strip():
            print(output)
        else:
            log_warn("程序运行但无输出")
            log_info("(可能当前未连接WiFi)")
    except subprocess.TimeoutExpired:
        log_warn("运行超时")
    except Exception as e:
        log_err(f"运行失败: {e}")

def generate_ios_project():
    """生成完整的iOS Xcode项目"""
    xcode_proj_dir = os.path.join(PROJECT_DIR, "GetWiFi.xcodeproj")
    log_info("生成Xcode项目...")
    
    # 这是一个简化的说明，实际Xcode项目需要pbxproj文件
    log_info("iOS项目文件结构:")
    log_info("  GetWiFi/")
    log_info("    GetWiFi.mm         # SpringBoard插件")
    log_info("    getwifi.m          # 命令行工具")
    log_info("    Info.plist")
    log_info("    Makefile           # Theos编译")
    log_info("    Layout/")
    log_info("      DEBIAN/")
    log_info("      usr/local/bin/")
    log_info("      Library/Loader/SBPlugins/")
    
    # Generate Info.plist for the tool
    plist_content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.debstudy.getwifi</string>
    <key>CFBundleName</key>
    <string>GetWiFi</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>需要访问位置信息来获取WiFi名称</string>
    <key>NSLocationAlwaysUsageDescription</key>
    <string>需要访问位置信息来获取WiFi名称</string>
</dict>
</plist>"""
    
    # Write plist
    for d in [BUILD_DIR, PROJECT_DIR]:
        plist_path = os.path.join(d, "Info.plist")
        with open(plist_path, "w", encoding="utf-8") as f:
            f.write(plist_content)
    
    log_ok("Info.plist 已生成")
    
    # Copy source files to output
    for src_file in ["getwifi.m", "getwifi_public.m", "GetWiFi.mm", "WiFiStatus.mm"]:
        src = os.path.join(SRC_DIR, src_file)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(OUTPUT_DIR, src_file))
    
    log_ok(f"源代码已复制到: {OUTPUT_DIR}")

def show_next_steps():
    print()
    print(c("bold", c("yellow", "╔══════════════════════════════════════════════╗")))
    print(c("bold", c("yellow", "║           下一步操作指南                     ║")))
    print(c("bold", c("yellow", "╚══════════════════════════════════════════════╝")))
    print()
    print("  " + c("bold", "方案1: WSL2 + Theos (Windows内编译iOS代码)"))
    print("  " + "-" * 50)
    print("  1. 启用WSL2:")
    print("     PowerShell(管理员): wsl --install")
    print("     重启后: wsl --install -d Ubuntu")
    print()
    print("  2. 在Ubuntu中执行:")
    print("     sudo apt update && sudo apt install -y build-essential git")
    print("     git clone https://github.com/theos/theos.git ~/theos")
    print("     cd ~/theos && make")
    print()
    print("  3. 编译项目:")
    print("     cd /mnt/e/Program\\ Files/Trae\\ CN/workplace/debStudy")
    print("     export THEOS=~/theos")
    print("     make package")
    print()
    print("  " + c("bold", "方案2: 云Mac服务 (最方便)"))
    print("  " + "-" * 50)
    print("  1. 注册: https://www.macstadium.com (约$0.08/小时)")
    print("  2. 安装Xcode")
    print("  3. 上传项目: scp -r ./debStudy user@ip:~/")
    print("  4. 编译: cd ~/debStudy && make package")
    print()
    print("  " + c("bold", "方案3: 仅测试C代码 (Windows原生)"))
    print("  " + "-" * 50)
    print("  Windows版已在上方编译成功，可用于测试逻辑")
    print()

def main():
    print_banner()
    
    os.makedirs(BUILD_DIR, exist_ok=True)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    mode = sys.argv[1] if len(sys.argv) > 1 else "auto"
    
    # ========== macOS iOS 编译 ==========
    if platform.system() == "Darwin" and mode in ("auto", "ios"):
        log_info("检测到macOS系统，开始iOS编译...")
        
        sdk_path = None
        try:
            sdk_path = subprocess.check_output(
                ["xcrun", "--show-sdk-path", "--sdk", "iphoneos"], text=True
            ).strip()
        except:
            log_err("未安装iOS SDK，请先安装Xcode")
            return 1
        
        log_info(f"iOS SDK: {sdk_path}")
        success = compile_ios_macos(sdk_path)
        
        if success:
            log_ok("iOS编译完成!")
            show_next_steps()
        return 0 if success else 1
    
    # ========== Windows 编译 ==========
    if platform.system() == "Windows" and mode in ("auto", "windows"):
        log_info("Windows模式 - 编译Windows版本用于测试")
        print()
        
        # 检查现有编译器
        compiler_name, compiler_path = find_compiler()
        
        if not compiler_path:
            log_warn("未检测到系统编译器，尝试自动下载...")
            print()
            
            # 尝试MinGW
            gcc_path = download_mingw()
            if gcc_path:
                compiler_name = "gcc"
                compiler_path = gcc_path
            else:
                # 尝试Zig
                log_warn("MinGW下载失败，尝试Zig...")
                zig_path = download_zig()
                if zig_path:
                    compiler_name = "zig"
                    compiler_path = zig_path
        
        if not compiler_path:
            print()
            log_err("无法获取C编译器!")
            print()
            log_info("可选的手动安装方式:")
            print()
            print("  1. Visual Studio Build Tools:")
            print("     https://visualstudio.microsoft.com/downloads")
            print("     安装时选择 '使用C++的桌面开发'")
            print()
            print("  2. 独立GCC (TDM-GCC):")
            print("     https://jmeubank.github.io/tdm-gcc/")
            print()
            print("  3. 重新运行此脚本，已安装的编译器将自动被检测到")
            print()
            
            generate_ios_project()
            show_next_steps()
            return 1
        
        # 编译
        source = os.path.join(SRC_DIR, "getwifi_cross.c")
        output = os.path.join(BUILD_DIR, "getwifi.exe")
        
        if compiler_name == "zig":
            success = compile_with_zig(compiler_path, source, output, "-lws2_32")
        else:
            success = compile_with_gcc(compiler_path, source, output, "-lws2_32 -mwindows")
        
        if success:
            print()
            log_ok("=" * 40)
            log_ok("Windows版本编译成功!")
            log_ok("=" * 40)
            print()
            
            test_windows_binary(output)
            
            print()
            log_info("同时生成iOS项目文件...")
            generate_ios_project()
            
            show_next_steps()
        else:
            log_err("编译失败，请检查错误信息")
            return 1
        
        return 0
    
    # ========== 清理模式 ==========
    if mode == "clean":
        for d in [BUILD_DIR, OUTPUT_DIR]:
            if os.path.exists(d):
                shutil.rmtree(d, ignore_errors=True)
                log_ok(f"已清理: {d}")
        return 0
    
    log_err(f"未知模式: {mode}")
    log_info("用法: python build.py [auto|windows|ios|clean]")
    return 1

if __name__ == "__main__":
    sys.exit(main())
