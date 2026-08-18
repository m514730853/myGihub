# GetWiFi - iOS WiFi 名称获取插件

一个用于获取iOS设备当前连接WiFi信息的越狱插件。

## 功能特性

- 获取当前连接的WiFi SSID（名称）
- 获取BSSID（MAC地址）
- 查看信号强度（dBm）
- 查看安全类型（WPA2、WPA3等）
- 支持命令行工具和SpringBoard插件两种使用方式
- 支持JSON格式输出

## 目录结构

```
debStudy/
├── src/
│   ├── getwifi.m          # 命令行工具（使用私有API）
│   ├── getwifi_public.m   # 命令行工具（使用公共API，需要位置权限）
│   ├── GetWiFi.mm        # SpringBoard插件（基础版）
│   └── WiFiStatus.mm     # SpringBoard插件（状态栏显示版）
├── Makefile               # Theos构建文件
├── build.sh               # macOS/Linux编译脚本
├── build.bat              # Windows编译脚本
├── pack_deb.sh            # DEB打包脚本
└── GetWiFi.plist          # 应用配置
```

## 编译方法

### 方法一：使用 Theos（推荐）

Theos是iOS越狱开发的标准工具链。

```bash
# 安装 Theos
brew install theos
# 或访问 https://theos.dev

# 编译
make clean
make

# 打包
make package
```

### 方法二：手动编译（macOS）

```bash
# 编译命令行工具
clang -arch arm64 \
    -isysroot $(xcrun --show-sdk-path --sdk iphoneos) \
    -fobjc-arc \
    -framework Foundation \
    -o getwifi \
    src/getwifi.m \
    -lMobileWiFi

# 编译SpringBoard插件
clang -arch arm64 \
    -isysroot $(xcrun --show-sdk-path --sdk iphoneos) \
    -fobjc-arc -fPIC -shared \
    -framework UIKit -framework Foundation \
    -o GetWiFi.dylib \
    src/GetWiFi.mm \
    -lMobileWiFi
```

### 方法三：使用脚本

```bash
# macOS/Linux
chmod +x build.sh
./build.sh

# Windows
build.bat
```

## 打包DEB

```bash
chmod +x pack_deb.sh
./pack_deb.sh
```

生成的deb文件在 `output/` 目录下。

## 安装方法

### 方法一：SSH安装

```bash
# 传输文件到设备
scp com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb root@<设备IP>:/tmp/

# SSH登录设备
ssh root@<设备IP>

# 安装
dpkg -i /tmp/com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb

# 修复依赖（如需要）
apt-get install -f
```

### 方法二：Cydia/Sileo

1. 将deb上传到你的仓库
2. 添加源到Cydia/Sileo
3. 搜索并安装 GetWiFi

## 使用方法

### 命令行工具

```bash
# 基本用法
getwifi

# 输出:
# SSID: MyWiFi
# BSSID: AA:BB:CC:DD:EE:FF
# 信号强度: -45 dBm
# 安全类型: WPA2

# JSON格式输出
getwifi --json

# 输出:
# {
#   "SSID": "MyWiFi",
#   "BSSID": "AA:BB:CC:DD:EE:FF",
#   "signalStrength": -45,
#   "securityType": "WPA2",
#   "connected": true
# }
```

### SpringBoard插件

安装后插件自动加载：
- 基础版 (`GetWiFi.dylib`): 在日志中输出WiFi信息
- 状态栏版 (`WiFiStatus.dylib`): 在状态栏显示当前WiFi名称

点击状态栏图标可以查看详细WiFi信息。

## 系统要求

- iOS 11.0 或更高版本
- 越狱设备（支持 checkra1n, unc0ver, Taurine, palera1n 等）
- Substitute 或 Substrate（用于dylib注入）

## 技术说明

### 私有API版本 (getwifi.m)

使用 `MobileWiFi` 私有框架，直接获取WiFi信息，无需用户授权。

### 公共API版本 (getwifi_public.m)

使用 `CoreLocation` 和 `SystemConfiguration` 公共API：
- iOS 13+ 需要位置服务权限
- 通过 `CNCopyCurrentNetworkInfo` 获取SSID
- 需要在 Info.plist 中添加 `NSLocationWhenInUseUsageDescription`

## 常见问题

**Q: 编译时找不到 MobileWiFi 头文件？**
A: 需要使用越狱设备的SDK或dump头文件。可以从越狱设备中导出：
```bash
scp root@<设备IP>:/usr/include/MobileWiFi/ .
```

**Q: 安装后没有反应？**
A: 请检查：
1. 设备是否已越狱
2. 是否安装了 Substrate/Substitute
3. 查看 `syslog` 或使用 `log show` 查看日志

**Q: getwifi 命令找不到？**
A: 确认路径：
```bash
ls -la /usr/local/bin/getwifi
```

## 许可证

MIT License
