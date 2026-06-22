# SafariGestures

一个轻量的 macOS 菜单栏小程序，给 Safari 加「按住右键划动」鼠标手势——类似 Edge 自带的鼠标手势。只管 Safari、常驻内存很小，用来替代偏重的系统级手势工具。

**核心特点**：右键单击照常弹出原生菜单，只有「按住右键划动」才触发手势；划动时显示跟手轨迹线。

## 手势一览（按住右键划）

| 手势 | 动作 | 快捷键 |
|---|---|---|
| ← 左 | 后退 | Cmd+[ |
| → 右 | 前进 | Cmd+] |
| ↓→ 先下再右 | 关闭标签页 | Cmd+W |
| ←↑ 先左再上 | 重开已关标签 | Cmd+Shift+T |
| →↑ 先右再上 | 新建标签页 | Cmd+T |
| →↓ 先右再下 | 刷新 | Cmd+R |
| ↑← 先上再左 | 切到左边标签 | Cmd+Shift+[ |
| ↑→ 先上再右 | 切到右边标签 | Cmd+Shift+] |

映射表在 `Sources/SafariGestures/GestureMap.swift`，方向识别在 `Sources/SafariGesturesCore/GestureRecognizer.swift`。

## 工作原理

系统级 `CGEventTap`（`.defaultTap`）监听右键。仅当 Safari 在最前台时介入：按下右键先扣住（菜单不立即弹），松手时判断——划动超过阈值且命中手势 → 发对应快捷键并吞掉菜单；几乎没动（普通单击）→ 补发一次原生右键让菜单照常弹出。补发事件带标记，回调跳过以防回环。

## 环境

- macOS 15+，Apple Silicon
- Swift 6 / Command Line Tools（**不需要完整 Xcode、不需要 Apple 开发者账号**）

## 权限

只需一项：**辅助功能**（系统设置 → 隐私与安全性 → 辅助功能）。`.defaultTap` 事件 tap 仅需此权限。

## 构建与运行

```bash
# （可选，推荐）首次创建本机自签名证书：让重编重签后辅助功能授权不失效
bash scripts/setup-signing-cert.sh

# 编译
bash scripts/build.sh

# 打包成 .app（自动用上面的证书签名；无证书则回退 ad-hoc）
bash scripts/make-app.sh

# 运行
open SafariGestures.app

# 跑自检（不依赖 Xcode）
swift run -c release safari-gestures-selftest
```

首次运行授予辅助功能权限后，在 Safari 里按住右键划动即可。菜单栏图标提供「启用/停用」「开机时启动」「关于」「退出」。

## 稳定签名（为什么不用一直重新授权）

macOS 的辅助功能授权按 App 的代码签名身份记忆。ad-hoc 签名每次重编 CDHash 都变 → 系统当成新 App → 要重新授权。`setup-signing-cert.sh` 创建一个**免费的自签名证书**，`make-app.sh` 用它签名后，App 的 designated requirement 绑定到证书而非 CDHash，**重编重签后仍是同一身份，授权不失效，只需首次授权一次**。自签名证书不被系统「信任」是正常的，不影响本机签名与授权稳定性。

新版脚本以不可导出方式保存私钥，且不再使用不安全的 `security import -A`。如果本机身份由旧版脚本创建，最终安装前运行 `bash scripts/setup-signing-cert.sh --rotate-insecure-existing`；证书轮换后需要最后一次重新授予辅助功能权限。

## 安装为日常版

把编译好的 `SafariGestures.app` 拷到 `~/Applications/`，菜单里打开「开机时启动」即可常驻。版本用 git tag 记（如 `v0.2.0`）。

## License

本项目基于 [MIT License](LICENSE) 开源，可自由使用、修改和再分发，仅需保留版权声明。

## 退出

菜单栏图标 →「退出」，或 `pkill -x SafariGestures`。
