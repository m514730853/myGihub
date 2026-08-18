#!/bin/bash

echo "=== GetWiFi 测试脚本 ==="
echo ""

GETWIFI_PATH="/usr/local/bin/getwifi"
PLUGIN_PATH="/Library/Loader/SBPlugins/GetWiFi.dylib"

if [ -f "$GETWIFI_PATH" ]; then
    echo "[OK] 命令行工具已安装: $GETWIFI_PATH"
    echo ""
    echo "运行 getwifi:"
    "$GETWIFI_PATH"
    echo ""
else
    echo "[FAIL] 命令行工具未找到: $GETWIFI_PATH"
fi

echo ""

if [ -f "$PLUGIN_PATH" ]; then
    echo "[OK] SpringBoard插件已安装: $PLUGIN_PATH"
else
    echo "[FAIL] SpringBoard插件未找到: $PLUGIN_PATH"
fi

echo ""
echo "=== 其他WiFi信息获取方式 ==="
echo ""

echo "方法1: 使用 ipconfig"
if command -v ipconfig >/dev/null 2>&1; then
    en0_mac=$(ifconfig en0 2>/dev/null | grep ether | awk '{print $2}')
    echo "  en0 MAC: ${en0_mac:-N/A}"
fi

echo ""
echo "方法2: 从系统文件读取"
if [ -f "/System/Library/SystemConfiguration/WiFiManager.bundle/Plug-Ins/AirPortFamily.service" ]; then
    echo "  WiFi服务存在"
fi

echo ""
echo "方法3: 使用 networksetup (如果可用)"
if command -v networksetup >/dev/null 2>&1; then
    networksetup -getairportnetwork en0 2>/dev/null || echo "  不支持"
fi

echo ""
echo "=== 完成 ==="
