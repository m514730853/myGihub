# GitHub Actions 自动编译指南

## 概述

利用 GitHub Actions 的 **macOS 运行器**，实现在云端自动编译 iOS 插件，无需本地 Mac 电脑。

## 工作流文件

| 文件 | 触发条件 | 说明 |
|------|----------|------|
| `.github/workflows/build.yml` | push / PR / 手动 | 日常编译，上传产物 |
| `.github/workflows/release.yml` | Release发布 | 自动打包DEB并附加到Release |
| `.github/workflows/ci.yml` | push / PR | 代码质量检查 |

## 快速开始

### 步骤1：创建 GitHub 仓库

```bash
# 如果还没有初始化 git
cd debStudy
git init
git add .
git commit -m "feat: 初始提交 GetWiFi iOS 插件"

# 在 GitHub 创建仓库后
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

### 步骤2：触发编译

**方式A：推送代码触发**
```bash
git add .
git commit -m "feat: 更新后触发编译"
git push
# 推送到 main/develop 分支会自动触发 build.yml
```

**方式B：手动触发**
1. 打开 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 选择 **Build GetWiFi iOS Plugin** 
4. 点击 **Run workflow** 按钮

**方式C：创建 Release**
```bash
# 创建 git tag 并推送
git tag -a v1.0.0 -m "v1.0.0 初始版本"
git push origin v1.0.0

# 在 GitHub 上创建 Release
# Release 页面会自动附加编译好的 .deb 文件
```

### 步骤3：下载产物

1. 打开仓库的 **Actions** 页面
2. 点击成功的工作流运行
3. 在 **Artifacts** 部分下载：
   - `ios-build-artifacts` — macOS 编译的 iOS 二进制文件和 .deb
   - `windows-build` — Windows 测试版本
   - `linux-build` — Linux 测试版本

## 查看编译状态

```
GitHub 仓库页面:
├── Code        # 查看代码
├── Issues      # 问题追踪
├── Pull requests
├── Actions     # ⭐ 查看编译状态
└── Releases    # 下载发布版本
```

在 **Actions** 页面可以看到：
- ✅ 成功（绿色）
- ❌ 失败（红色）
- ⏳ 进行中（黄色）

点击某次运行可以查看详细日志。

## 下载后使用

```bash
# 1. 将 .deb 文件传输到越狱设备
scp com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb root@<设备IP>:/tmp/

# 2. SSH 登录设备
ssh root@<设备IP>

# 3. 安装插件
dpkg -i /tmp/com.debstudy.getwifi_1.0.0_iphoneos-arm64.deb

# 4. 如果提示依赖缺失
apt-get install -f

# 5. 使用
getwifi
getwifi --json
```

## 常见问题

### Q: 编译失败提示找不到 MobileWiFi.h？

A: GitHub Actions 的 macOS 运行器使用 Theos 自带的 SDK。如果缺少头文件：
1. 在 Theos 中克隆 SDKS 仓库：
```bash
git clone https://github.com/theos/sdks ~/theos/sdks
```
2. 或者从越狱设备导出：
```bash
# 在越狱设备上
tar czf /tmp/MobileWiFi.tar.gz /usr/include/MobileWiFi/
# 传回本地后添加到仓库
```

### Q: 编译需要多长时间？

A: 
- macOS 运行器启动：~2 分钟
- Theos 安装：~3 分钟
- 编译：< 1 分钟
- **总计约 5-7 分钟**

### Q: 免费吗？

A: 
- 公共仓库：**完全免费**
- 私有仓库：每月 2000 分钟免费额度（macOS 计 2 倍，即 1000 分钟）

### Q: 能否一次编译多个 iOS 版本？

A: 可以。修改 `build.yml` 中的 SDK 路径：
```yaml
# 支持多版本测试
strategy:
  matrix:
    ios-version: ["14.0", "15.0", "16.0"]
```

### Q: 如何添加自定义 Logo 到 Release？

A: 在 Release 配置中添加图片 URL：
```yaml
with:
  body: |
    ## GetWiFi v1.0.0
    ![Logo](https://...)
    ...
```

## 工作原理

```
代码推送 → GitHub Actions 触发
    ↓
macOS 虚拟机启动
    ↓
安装 Theos + ldid + dpkg
    ↓
编译 getwifi (arm64)
    ↓
编译 GetWiFi.dylib (arm64)
    ↓
打包 .deb
    ↓
上传到 Artifacts / Release
```

## 注意事项

1. **首次运行会比较慢**：需要安装 Theos 等工具，后续会快一些
2. **私有仓库额度**：macOS 运行时间按 2 倍计算
3. **调试技巧**：在 Actions 中查看完整日志，找到错误定位问题
4. **代码签名**：如果需要在非越狱设备运行，需加入签名步骤
