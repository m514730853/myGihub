# iOS WiFi 插件 - Windows 编译完整指南

## 核心问题

**iOS开发必须在macOS上进行**，因为：
- Xcode（含iOS SDK）仅支持macOS
- 苹果的编译工具链（clang for arm64）仅在Xcode中提供
- 私有API头文件（如MobileWiFi.framework）来自iOS SDK

## Windows编译方案对比

| 方案 | 难度 | 成本 | 说明 |
|------|------|------|------|
| **WSL2 + Theos** | ★★★★ | 免费 | 最推荐，Windows内运行Linux编译 |
| **云Mac服务** | ★★ | 付费 | 最方便，远程Mac编译 |
| **Mac虚拟机** | ★★★★★ | 免费 | Hackintosh或VMware macOS |
| **Docker macOS** | ★★★★ | 免费 | 实验性方案 |

---

## 方案一：WSL2 + Theos（推荐 ⭐）

### 前提条件
- Windows 10 2004+ 或 Windows 11
- 在BIOS中启用虚拟化
- 管理员权限

### 步骤1：启用WSL2

```powershell
# 以管理员身份打开PowerShell，执行：
wsl --install
wsl --set-default-version 2

# 重启计算机
shutdown /r /t 0
```

### 步骤2：安装Ubuntu

```powershell
# 重启后打开PowerShell，执行：
wsl --install -d Ubuntu
```

按提示设置Ubuntu用户名和密码。

### 步骤3：安装Theos编译环境

```bash
# 在Ubuntu终端中执行：

# 1. 安装基础依赖
sudo apt update
sudo apt install -y build-essential git libusb-dev cmake python3

# 2. 克隆Theos
cd ~
git clone https://github.com/theos/theos.git
cd theos
make

# 3. 克隆iOS SDK（从GitHub）
cd ~
git clone https://github.com/theos/sdks.git

# 或者从越狱设备导出SDK：
# scp -r root@<设备IP>:/usr/include ~/theos/sdks/iphoneos/usr/include/
# scp root@<设备IP>:/usr/lib/libMobileWiFi.dylib ~/theos/sdks/iphoneos/usr/lib/

# 4. 安装ldid（签名工具）
sudo apt install ldid
```

### 步骤4：编译项目

```bash
cd /mnt/e/Program\ Files/Trae\ CN/workplace/debStudy

# 设置Theos路径
export THEOS=~/theos
export THEOS_PACKAGE_DIR_NAME=debs

# 编译
make clean
make package

# 输出文件在 debs/ 目录
ls -la debs/
```

### 步骤5：安装到设备

```bash
# 传输到设备
scp debs/com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb root@<设备IP>:/tmp/

# SSH登录设备安装
ssh root@<设备IP>
dpkg -i /tmp/com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb
```

---

## 方案二：云Mac服务

### 推荐服务商

| 服务商 | 价格 | 特点 |
|--------|------|------|
| [MacStadium](https://www.macstadium.com) | $0.08/小时起 | 最专业 |
| [VirtualMac](https://www.virtualmac.com) | $5/月起 | 快速启动 |
| [MacinCloud](https://www.macincloud.com) | $9.99/月起 | 稳定可靠 |
| 阿里云ECS macOS | 按量计费 | 国内访问快 |
| 腾讯云macOS实例 | 按量计费 | 国内访问快 |

### 使用步骤

```bash
# 1. 购买实例后，获取SSH信息
# 2. 连接
ssh user@cloud-mac-ip -p port

# 3. 安装Xcode（首次需要）
# 登录远程桌面，从App Store安装Xcode
xcode-select --install

# 4. 上传项目
scp -P port -r ./debStudy user@cloud-mac-ip:~/

# 5. 编译
cd ~/debStudy
xcrun clang -arch arm64 \
    -isysroot $(xcrun --show-sdk-path --sdk iphoneos) \
    -fobjc-arc -framework Foundation \
    -o build/getwifi src/getwifi.m -lMobileWiFi

# 6. 或使用Theos（如果已安装）
export THEOS=~/theos
make package
```

---

## 方案三：Windows原生编译（仅测试）

此方案只能编译Windows版本，用于测试C代码逻辑：

### 安装MinGW-w64

```powershell
# 方式1：winget
winget install MinGW-w64

# 方式2：手动下载
# 访问 https://github.com/brechtsanders/winlibs_mingw/releases
# 下载 winlibs-x86_64-posix-seh-gcc-XX.X.0-llvm-XX.X.0-mingw-w64ucrt-XX.X.zip
# 解压后添加bin目录到PATH
```

### 编译测试

```powershell
# 在项目目录执行
mkdir build
gcc -o build\getwifi.exe src\getwifi_cross.c -lws2_32

# 运行测试
.\build\getwifi.exe
```

**注意**：此版本使用Windows API获取WiFi信息，仅用于验证代码逻辑。

---

## 方案四：Hackintosh虚拟机

在Windows上安装macOS虚拟机：

### 推荐工具
- **VMware Workstation Pro** + macOS补丁
- **VirtualBox** + macOS镜像
- **OpenCore**（最复杂，需要硬件兼容）

### 步骤概要

```
1. 下载macOS镜像 (从Mac或使用recoveryOS)
2. 安装VMware Workstation Pro
3. 安装Unlocker补丁 (支持macOS)
4. 创建虚拟机，分配CPU/内存
5. 安装macOS
6. 安装Xcode和Theos
7. 编译项目
```

**注意**：此方案法律风险和技术难度较高，不推荐商业项目使用。

---

## 快速决策指南

```
你的情况是什么？
├── 有管理员权限 + 内存 >= 8GB → 方案一 (WSL2)
├── 不想折腾 + 有信用卡 → 方案二 (云Mac)  
├── 只是想测试C代码 → 方案三 (Windows原生)
└── 技术高手 + 有时间 → 方案四 (Hackintosh)
```

## 常见问题

**Q: WSL2编译出错找不到MobileWiFi.h？**
A: 需要从越狱设备导出SDK头文件：
```bash
# 在越狱设备上执行
dpkg -l | grep mobilewifi
# 找到包后导出
cd /usr/include
tar czf /tmp/MobileWiFi.tar.gz MobileWiFi/
```

**Q: 没有越狱设备怎么办？**
A: 可以使用公共API版本（getwifi_public.m）：
- iOS 13+ 需要位置权限
- 使用 CoreLocation + SystemConfiguration 框架

**Q: deb包无法安装？**
A: 检查以下几点：
- 架构是否为 arm64 (`file getwifi`)
- 依赖是否满足 (`dpkg -i` 查看错误)
- Substrate/Substitute 是否已安装

**Q: 编译速度慢？**
A: 使用预编译SDK和缓存：
```bash
make clean && make THEOS_IGNORE = 1
```
