# SafariGestures

[English](README.md) | **简体中文**

[![CI](https://github.com/bigbugneil/safari-gestures/actions/workflows/ci.yml/badge.svg)](https://github.com/bigbugneil/safari-gestures/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

SafariGestures 是一个轻量的 macOS 菜单栏应用，为 Safari 增加右键鼠标手势。按住鼠标右键并划出手势，即可后退、切换标签页、刷新页面等。

它专注于 Safari，可替代功能较重的系统级手势工具：

- **只作用于 Safari：** 其他应用中的鼠标事件完全不受影响。
- **保留原生右键：** 普通右键单击仍会打开 Safari 原生上下文菜单。
- **可视化反馈：** 划动手势时，蓝色轨迹线会跟随鼠标指针。
- **隐私优先：** 不联网、不收集遥测、不读取键盘内容，也不写入用户数据文件。
- **工具链精简：** 使用 Swift Package Manager 构建，不需要完整 Xcode 或 Apple 开发者账号。

## 手势一览

按住鼠标右键，依次划出以下方向，然后松开：

| 手势 | 动作 | Safari 快捷键 |
|---|---|---|
| `左` | 后退 | `Command + [` |
| `右` | 前进 | `Command + ]` |
| `下、右` | 关闭当前标签页 | `Command + W` |
| `左、上` | 重新打开上次关闭的标签页 | `Command + Shift + T` |
| `右、上` | 新建标签页 | `Command + T` |
| `右、下` | 刷新页面 | `Command + R` |
| `上、左` | 切换到左侧标签页 | `Command + Shift + [` |
| `上、右` | 切换到右侧标签页 | `Command + Shift + ]` |

手势映射位于 [`Sources/SafariGestures/GestureMap.swift`](Sources/SafariGestures/GestureMap.swift)，方向识别位于 [`Sources/SafariGesturesCore/GestureRecognizer.swift`](Sources/SafariGesturesCore/GestureRecognizer.swift)。

## 工作原理

SafariGestures 使用会话级 `CGEventTap` 监听右键事件，并且只在 Safari 位于最前台时介入：

1. 按下右键时暂时扣住事件，不立即打开上下文菜单。
2. 记录鼠标移动，并显示手势轨迹。
3. 松开右键时，如果识别到已映射手势，就发送对应的 Safari 键盘快捷键。
4. 如果鼠标几乎没有移动，则补发一个带标记的右键事件，让原生上下文菜单正常打开。

事件回调会忽略带标记的补发事件，避免形成事件循环。监听器还会从 Event Tap 中断中自动恢复，并在系统睡眠、唤醒、用户会话或显示器发生变化后重新建立监听。

## 环境要求

- macOS 15 或更高版本
- Apple Silicon
- Swift 6.1 或更高版本，以及 Command Line Tools
- 为 SafariGestures 授予辅助功能权限

不需要输入监控权限。

当前菜单栏界面使用中文标签，手势行为不受界面语言影响。

## 构建与运行

克隆仓库后执行：

```bash
git clone https://github.com/bigbugneil/safari-gestures.git
cd safari-gestures

# 可选但推荐：首次使用时创建本机签名身份。
bash scripts/setup-signing-cert.sh

# 构建并打包 SafariGestures.app。
bash scripts/make-app.sh

# 从项目目录启动应用。
open SafariGestures.app
```

首次启动后，在 **系统设置 > 隐私与安全性 > 辅助功能** 中授权 SafariGestures。随后切换到 Safari，按住右键划出手势并松开即可。

菜单栏入口可查看监听状态、启用或停用手势、重新启动监听、设置开机启动、查看应用信息和退出应用。

如需作为日常应用使用，可将 `SafariGestures.app` 复制到 `~/Applications/`，并在菜单栏入口中启用开机启动。

## 稳定的本机签名

macOS 会根据应用的代码签名身份记忆辅助功能权限。使用 ad-hoc 签名时，每次重新构建都会改变身份，系统可能因此要求重新授权。

[`scripts/setup-signing-cert.sh`](scripts/setup-signing-cert.sh) 会在登录钥匙串中创建一个免费的自签名代码签名身份。[`scripts/make-app.sh`](scripts/make-app.sh) 会自动使用该身份，使应用的 designated requirement 在本机重新构建后保持稳定。私钥不可导出，并且只允许 `/usr/bin/codesign` 使用。

如果签名身份由旧版脚本创建，请在最终安装前轮换：

```bash
bash scripts/setup-signing-cert.sh --rotate-insecure-existing
```

轮换会改变签名身份，因此之后需要最后一次重新授予辅助功能权限。macOS 不将这个自签名证书标记为受信任是正常现象，不影响本机代码签名或稳定识别权限。

如果本机没有签名身份，打包脚本会自动回退到 ad-hoc 签名。

## 开发自检

项目包含一个零依赖的自检程序，用来测试手势识别和右键会话逻辑，不会生成真实的鼠标或键盘输入事件。

```bash
swift build -c release
swift run -c release safari-gestures-selftest
```

CI 会执行以上命令，并验证应用包能够正常打包和签名。

## 项目结构

| 路径 | 用途 |
|---|---|
| `Sources/SafariGestures/` | 菜单栏应用、Event Tap、手势映射、轨迹层和快捷键发送 |
| `Sources/SafariGesturesCore/` | 手势识别和右键会话状态机 |
| `Sources/SelfTest/` | 零依赖逻辑自检 |
| `scripts/` | 构建、打包、图标和本机签名脚本 |

## 许可证

SafariGestures 基于 [MIT License](LICENSE) 开源，可在许可证条款下使用、复制、修改和分发。
