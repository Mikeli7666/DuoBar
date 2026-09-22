# DuoBar

[English](README.md) | [Русский](README.ru.md) | [简体中文](README.zh-CN.md)

把 iPhone Duo 风格的三合一状态指示器带到 Mac 菜单栏。

一个图标同时显示：

- 电池
- 网络
- 音量

[**下载 DuoBar 1.2.0**](https://github.com/Mikeli7666/DuoBar/releases/download/v1.2.0/DuoBar-1.2.0.dmg) · [查看所有版本](https://github.com/Mikeli7666/DuoBar/releases) · [English](README.md)

macOS 13 Ventura 或更高版本 · Apple Silicon 与 Intel Mac · Universal 2

## 📥 下载与安装教程

### 第一步：下载 DuoBar

点击页面上方的“下载 DuoBar 1.2.0”。浏览器会下载：

`DuoBar-1.2.0.dmg`

普通用户只需要这个 DMG 文件。不要下载：

- Source code (zip)
- Source code (tar.gz)

这两个文件是给开发者查看源代码用的，不是普通用户的安装包。

如果你是从 GitHub Releases 页面开始：

1. 找到最新版本 **DuoBar 1.2.0**。
2. 找到页面下方的 **Assets** 文件列表。
3. 点击 **DuoBar-1.2.0.dmg**。

### 第二步：安装

1. 双击 `DuoBar-1.2.0.dmg`。
2. Finder 会打开一个磁盘映像窗口。
3. 将 `DuoBar.app` 拖到 **Applications / 应用程序** 文件夹；窗口中提供了应用程序文件夹入口。
4. 等待复制完成。
5. 打开“应用程序”文件夹。
6. 双击 DuoBar。

### 第三步：第一次打开

DuoBar 1.2.0 已使用 Apple Developer ID 签名，并通过 Apple 公证（Notarization）。正常情况下可以直接打开。

DuoBar 是菜单栏应用，不会出现在 Dock 中。打开后，请查看屏幕最上方的 macOS 菜单栏，DuoBar 图标会在那里出现。

正常安装不需要关闭 Gatekeeper 或 SIP，也不需要使用 Terminal、`sudo` 或 `xattr` 命令。

## 为什么会请求“位置”权限？

macOS 可能要求应用获得“位置”权限，才能读取当前连接的 Wi-Fi 网络名称（SSID）。DuoBar 只通过系统公开 API 使用这项权限来获取 Wi-Fi 名称。

如果拒绝权限：

- DuoBar 仍然可以使用
- 电池功能不受影响
- 音量功能不受影响
- 基本网络状态仍然可以显示
- Wi-Fi 名称可能显示为“网络名称不可用”

## 🖱 怎么使用

DuoBar 常驻在菜单栏。图标中的三个部分分别表示：

- **外圈** → 电池 / Adaptive Ring
- **中间** → Wi-Fi、Ethernet 或其他网络状态
- **下方四个点** → 音量

点击 DuoBar 图标即可打开弹出面板。面板包含：

- 网络
- 音量
- 电池
- 音频输出
- 设置
- 退出

点击「网络」会打开 Wi-Fi 或网络设置，行内开关只负责打开或关闭 Wi-Fi。点击「电池」会打开电池设置。

设置中还可以选择开启 **Open on Hover（悬停打开）**。

## 功能

- Battery Ring：显示电池电量、充电状态、动态充电闪电和可选的电池颜色编码
- Adaptive Ring：在桌面 Mac 上显示亮度，并在需要时自动显示 CPU、内存或温度压力
- 圆润的 Wi-Fi 指示器和 refined Duo 视觉语言
- 显示当前 Wi-Fi 网络名称（SSID）
- 直接在 DuoBar 中打开或关闭 Wi-Fi
- Wi-Fi、Ethernet 和离线网络状态
- 音量状态、音量滑块、静音控制和切换输出设备（取决于音频设备是否支持）
- 在弹出菜单中选择 Audio Output
- AirPods / 耳机连接时的临时状态展示
- Open on Hover（悬停打开）
- 可调节菜单栏图标大小
- 改进的 Battery Ring、音量指示点和充电展示
- English、俄语、乌克兰语、简体中文、繁體中文

## 系统要求

- macOS 13 Ventura 或更高版本
- 支持 Apple Silicon
- 支持 Intel Mac
- Universal 2

## 安全与隐私

DuoBar 1.2.0 已使用 Apple Developer ID 签名，并通过 Apple 公证。DuoBar 不通过 Mac App Store 分发。

系统状态在本机处理：

- 无分析或追踪
- 无后端遥测
- 不上传系统状态
- 无无关网络请求

DuoBar 是独立项目，与 Apple Inc. 没有隶属、赞助或认可关系。

## 🐛 遇到问题？

请前往 [GitHub Issues](https://github.com/Mikeli7666/DuoBar/issues) 报告问题。

如果你不熟悉技术，也只需要提供：

- Mac 型号
- macOS 版本
- DuoBar 版本
- 问题描述
- 如果方便，附上一张截图

不需要提供技术日志。

## 下载完整性

官方 DuoBar 1.2.0 DMG 的 SHA-256：

`186f68d4af1eb8f096cc854b8dadb113875c01ebdebfeca44ca248c50d92ad37`

普通用户不需要验证这一项。它主要用于希望确认下载文件完整性的用户。

## 开源许可

DuoBar 使用 [MIT License](LICENSE) 开源。
