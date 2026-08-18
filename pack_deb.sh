#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  iOS WiFi 插件 - DEB 打包脚本${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="1.0.0"
PACKAGE_NAME="com.debstudy.getwifi"
ARCH="iphoneos-arm64"
DEB_NAME="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

WORK_DIR="$PROJECT_DIR/deb_build"
OUTPUT_DIR="$PROJECT_DIR/output"

rm -rf "$WORK_DIR" "$OUTPUT_DIR"
mkdir -p "$WORK_DIR/DEBIAN"
mkdir -p "$WORK_DIR/usr/local/bin"
mkdir -p "$WORK_DIR/Library/Loader/SBPlugins"
mkdir -p "$WORK_DIR/Library/Application Support/GetWiFi"
mkdir -p "$OUTPUT_DIR"

echo -e "${YELLOW}[1/5]${NC} 准备文件..."

if [ ! -f "$PROJECT_DIR/build/getwifi" ]; then
    echo -e "${RED}错误: 未找到编译好的 getwifi 二进制文件${NC}"
    echo "请先运行编译脚本 (build.sh 或 build.bat)"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/build/GetWiFi.dylib" ]; then
    echo -e "${RED}错误: 未找到编译好的 GetWiFi.dylib${NC}"
    exit 1
fi

cp "$PROJECT_DIR/build/getwifi" "$WORK_DIR/usr/local/bin/"
cp "$PROJECT_DIR/build/GetWiFi.dylib" "$WORK_DIR/Library/Loader/SBPlugins/"

chmod 755 "$WORK_DIR/usr/local/bin/getwifi"
chmod 755 "$WORK_DIR/Library/Loader/SBPlugins/GetWiFi.dylib"

echo -e "${YELLOW}[2/5]${NC} 创建控制文件..."

cat > "$WORK_DIR/DEBIAN/control" << EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: Utilities
Priority: optional
Architecture: arm64
Maintainer: DebStudy Team <debstudy@example.com>
Installed-Size: $(du -sk "$WORK_DIR" | cut -f1)
Description: 获取iOS设备WiFi信息的越狱插件
  提供命令行工具和SpringBoard插件两种方式获取WiFi信息
  功能包括:
  - 获取当前连接的WiFi SSID (名称)
  - 获取BSSID (MAC地址)
  - 查看信号强度
  - 查看安全类型
  支持 iOS 11+ 越狱设备
Depends: firmware (>=11.0), mobilesubstrate
Name: GetWiFi
Author: DebStudy Team
Homepage: https://github.com/debstudy/getwifi
EOF

echo -e "${YELLOW}[3/5]${NC} 创建安装脚本..."

cat > "$WORK_DIR/DEBIAN/preinst" << 'EOF'
#!/bin/sh
if [ -d /Library/Loader/SBPlugins/GetWiFi.dylib ]; then
    killall -9 SpringBoard 2>/dev/null
fi
EOF
chmod 755 "$WORK_DIR/DEBIAN/preinst"

cat > "$WORK_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/sh
set -e

chmod 755 /usr/local/bin/getwifi
chmod 755 /Library/Loader/SBPlugins/GetWiFi.dylib

if [ -d /Library/Loader/SBPlugins ]; then
    killall -9 SpringBoard 2>/dev/null || true
fi

echo "GetWiFi 插件安装成功！"
echo "使用 'getwifi' 命令查看当前WiFi信息"
EOF
chmod 755 "$WORK_DIR/DEBIAN/postinst"

cat > "$WORK_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/sh
if [ -f /Library/Loader/SBPlugins/GetWiFi.dylib ]; then
    killall -9 SpringBoard 2>/dev/null || true
fi
EOF
chmod 755 "$WORK_DIR/DEBIAN/prerm"

cat > "$WORK_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/sh
if [ -d /Library/Loader/SBPlugins ] || [ -f /usr/local/bin/getwifi ]; then
    killall -9 SpringBoard 2>/dev/null || true
fi
EOF
chmod 755 "$WORK_DIR/DEBIAN/postrm"

echo -e "${YELLOW}[4/5]${NC} 打包 DEB 文件..."

if command -v dpkg-deb >/dev/null 2>&1; then
    dpkg-deb -b "$WORK_DIR" "$OUTPUT_DIR/$DEB_NAME"
elif command -v fakeroot >/dev/null 2>&1; then
    fakeroot dpkg-deb -b "$WORK_DIR" "$OUTPUT_DIR/$DEB_NAME"
else
    echo -e "${YELLOW}警告: 未找到 dpkg-deb，使用 tar 方式打包${NC}"
    cd "$WORK_DIR"
    tar cf "$OUTPUT_DIR/${DEB_NAME}.tar" .
    mv "$OUTPUT_DIR/${DEB_NAME}.tar" "$OUTPUT_DIR/$DEB_NAME"
    echo -e "${YELLOW}注意: 这不是标准的 deb 格式，仅用于测试${NC}"
    cd "$PROJECT_DIR"
fi

echo -e "${YELLOW}[5/5]${NC} 验证包..."

if [ -f "$OUTPUT_DIR/$DEB_NAME" ]; then
    PACKAGE_SIZE=$(du -h "$OUTPUT_DIR/$DEB_NAME" | cut -f1)
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  打包完成！${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "文件: ${OUTPUT_DIR}/${DEB_NAME}"
    echo -e "大小: ${PACKAGE_SIZE}"
    echo ""
    echo -e "${YELLOW}安装方法:${NC}"
    echo "  1. 使用 SCP 传输到设备:"
    echo "     scp ${DEB_NAME} root@<设备IP>:/tmp/"
    echo ""
    echo "  2. 在设备上安装:"
    echo "     ssh root@<设备IP>"
    echo "     dpkg -i /tmp/${DEB_NAME}"
    echo ""
    echo "  3. 或者通过 Cydia/Sileo 安装"
    echo ""
    echo -e "${YELLOW}使用方法:${NC}"
    echo "  getwifi              - 显示WiFi信息"
    echo "  getwifi --json       - JSON格式输出"
    echo "  getwifi -h           - 显示帮助"
else
    echo -e "${RED}错误: 打包失败${NC}"
    exit 1
fi

rm -rf "$WORK_DIR"
