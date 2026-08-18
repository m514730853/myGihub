#!/bin/bash

IOS_ARM_SDK=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
IOS_ARM64_SDK=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
CLANG=clang

PROJECT_DIR=$(cd "$(dirname "$0")" && pwd)
BUILD_DIR="$PROJECT_DIR/build"
DEB_DIR="$PROJECT_DIR/package"

rm -rf "$BUILD_DIR" "$DEB_DIR"
mkdir -p "$BUILD_DIR" "$DEB_DIR"

echo "=== 编译 getwifi 命令行工具 (arm64) ==="

$CLANG -arch arm64 \
    -isysroot "$IOS_ARM64_SDK" \
    -fobjc-arc \
    -framework Foundation \
    -o "$BUILD_DIR/getwifi" \
    "$PROJECT_DIR/src/getwifi.m" \
    -lMobileWiFi \
    -L/usr/lib \
    -I"$IOS_ARM64_SDK"/usr/include \
    -Wl,-rpath,/usr/lib

if [ $? -ne 0 ]; then
    echo "错误: 编译 getwifi 失败"
    exit 1
fi

echo "=== 编译 GetWiFi SpringBoard 插件 (arm64) ==="

$CLANG -arch arm64 \
    -isysroot "$IOS_ARM64_SDK" \
    -fobjc-arc \
    -fPIC \
    -shared \
    -framework UIKit \
    -framework Foundation \
    -o "$BUILD_DIR/GetWiFi.dylib" \
    "$PROJECT_DIR/src/GetWiFi.mm" \
    -lMobileWiFi \
    -L/usr/lib \
    -I"$IOS_ARM64_SDK"/usr/include \
    -Wl,-rpath,/usr/lib

if [ $? -ne 0 ]; then
    echo "错误: 编译 GetWiFi.dylib 失败"
    exit 1
fi

echo "=== 创建 deb 包结构 ==="

mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/local/bin"
mkdir -p "$DEB_DIR/Library/Loader/SBPlugins"
mkdir -p "$DEB_DIR/Library/LaunchDaemons"
mkdir -p "$DEB_DIR/Library/PreferenceBundles"

cp "$BUILD_DIR/getwifi" "$DEB_DIR/usr/local/bin/"
chmod 755 "$DEB_DIR/usr/local/bin/getwifi"

cp "$BUILD_DIR/GetWiFi.dylib" "$DEB_DIR/Library/Loader/SBPlugins/"

cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: com.debstudy.getwifi
Version: 1.0.0
Section: Utilities
Priority: optional
Architecture: arm64
Maintainer: DebStudy <debstudy@example.com>
Description: 获取iOS设备WiFi名称的插件
  提供命令行工具和SpringBoard插件，用于获取当前连接的WiFi信息
  包括SSID、BSSID、信号强度等
Depends: firmware (>=11.0), mobilesubstrate
EOF

cat > "$DEB_DIR/DEBIAN/postinst" << 'POSTINST'
#!/bin/sh
chmod 755 /usr/local/bin/getwifi
chmod 755 /Library/Loader/SBPlugins/GetWiFi.dylib
killall -9 SpringBoard
POSTINST
chmod 755 "$DEB_DIR/DEBIAN/postinst"

cat > "$DEB_DIR/DEBIAN/postrm" << 'POSTRM'
#!/bin/sh
if [ -d /Library/Loader/SBPlugins ]; then
    killall -9 SpringBoard
fi
POSTRM
chmod 755 "$DEB_DIR/DEBIAN/postrm"

echo "=== 打包 deb 文件 ==="

DEB_NAME="com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb"
dpkg-deb -b "$DEB_DIR" "$PROJECT_DIR/$DEB_NAME"

if [ $? -ne 0 ]; then
    echo "错误: 打包 deb 失败"
    exit 1
fi

echo ""
echo "=== 构建完成 ==="
echo "deb 文件: $PROJECT_DIR/$DEB_NAME"
echo ""
echo "安装方法:"
echo "  1. 将 deb 文件复制到越狱设备"
echo "  2. 使用 dpkg -i $DEB_NAME 安装"
echo "  3. 或者在 Cydia/Sileo 中安装"
echo ""
echo "使用方法:"
echo "  命令行: getwifi          - 显示当前WiFi信息"
echo "  命令行: getwifi --json   - 以JSON格式输出"
echo "  SpringBoard插件: 安装后自动加载"
