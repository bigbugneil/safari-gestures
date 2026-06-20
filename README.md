# SafariGestures

SafariGestures 是一个只显示在 macOS 菜单栏的 Safari 鼠标手势工具。本目录当前完成实施计划的第 4 步：菜单栏应用、双权限引导、手势识别、发送快捷键，以及右键拦截/补发——**Safari 内按住右键划动触发对应动作；普通右键单击照常弹出原生菜单**。

当前版本使用 `.defaultTap` Event Tap：识别出手势时发送快捷键并吞掉右键菜单；几乎没移动（普通单击）时补发一次真实右键，让原生菜单正常弹出（补发事件带标记，回调跳过以防回环）。开机自启与单元测试（第 5 步）尚未实现。

## 环境

- macOS 15，Apple Silicon
- Swift 6.1.2 / Command Line Tools
- 不需要 Xcode 或 Apple 开发者账号；打包脚本使用固定 bundle identifier 做 ad-hoc 签名

## 编译

```bash
cd /Users/bigbug/Documents/1_AIWorkSpace/pj_safari_gestures
bash scripts/build.sh
```

Release 可执行文件由 Swift Package Manager 输出到 `.build/`。

## 打包

```bash
bash scripts/make-app.sh
```

脚本会先执行 release 编译，再在项目根目录生成：

```text
SafariGestures.app
```

## 运行

```bash
open SafariGestures.app
```

应用没有 Dock 图标和主窗口。首次运行需要在“系统设置 → 隐私与安全性”中授予两项权限：

1. **辅助功能**：供后续步骤执行 Safari 操作；当前也用它做统一启动门槛。
2. **输入监控**：`.listenOnly` Event Tap 读取全局右键事件所必需。

App 会先引导辅助功能权限；辅助功能通过后，如果输入监控尚未授权，系统会再给出输入监控提示。菜单栏中的“启用/停用”会实际启动或停止观察监听。

## 查看识别日志

先运行 App，再在另一个终端执行：

```bash
/usr/bin/log stream --style compact --level info \
  --predicate 'subsystem == "com.bigbug.safarigestures"'
```

在 Safari 中按住右键划动后，日志会显示原始点数、方向序列和对应动作名。有效手势会发送一次对应快捷键；空序列和未映射序列不会执行任何动作。非 Safari 程序中的右键轨迹不会记录。

## 第 3 步已知现象

本步还没有实现第 4 步的右键菜单拦截，Event Tap 仍是 `.listenOnly`。因此做手势时 Safari 右键菜单可能照常弹出，然后快捷键再被发送，可能出现菜单闪一下或快捷键偶尔被菜单吃掉。

这是第 3 步的预期中间状态，不是当前 Bug。第 4 步会专门处理“右键单击照常显示菜单，右键划动才触发手势并隐藏菜单”。

也可以直接从终端运行 bundle 内的可执行文件，通过标准输出看日志：

```bash
./SafariGestures.app/Contents/MacOS/SafariGestures
```

## 重编后的隐私权限

`make-app.sh` 会执行固定 identifier 的 ad-hoc 签名。相同二进制重复打包时签名稳定，但源码变化会改变 CDHash，macOS 仍可能让旧的辅助功能授权失效。

如果日志提示权限缺失、Event Tap 创建失败，或 Safari 中划动完全没有日志：

1. 退出 SafariGestures。
2. 分别打开“系统设置 → 隐私与安全性 → 辅助功能”和“输入监控”。
3. 删除两个列表中旧的 SafariGestures 条目。
4. 在两个列表中重新添加项目根目录中的 `SafariGestures.app` 并启用。
5. 完全退出旧进程，再运行 `open SafariGestures.app`。

退出应用可点击菜单栏图标后选择“退出”，也可执行：

```bash
pkill -x SafariGestures
```
