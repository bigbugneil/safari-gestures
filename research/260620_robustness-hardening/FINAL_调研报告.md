# SafariGestures 第 6 步健壮性调研报告

> 研究日期：2026-06-20 | 对象：macOS 15+ 本机自用 Safari 右键手势 App

## 摘要

一句话结论：第 6 步应围绕“可测试的右键会话状态机 + 生命周期重建 + 有上限的轨迹层”展开；后台事件线程、进程保活和整 App watchdog 对当前项目属于过度工程，不应照搬。

## 1. 必须纳入

### 1.1 纯右键会话状态机

把 down、drag、up、普通点击补发、手势命中和异常 cancel 收到同一个纯逻辑对象中。tap disabled、Safari 失焦、停用、退出、睡眠、用户切换、屏幕变化、watchdog 超时都必须进入同一个 cancel 入口，异常 cancel 不补发点击。

依据：[LinearMouse 手势 fallback 协调器](https://github.com/linearmouse/linearmouse/pull/1246)、[手势按钮未释放 #1138](https://github.com/linearmouse/linearmouse/issues/1138)、[MacGesture 遗留 down 处理](https://github.com/MacGesture/MacGesture/blob/50c794c5a156e6ed0ceac8406f0f8dcbca196c44/MacGesture/AppDelegate.m#L342-L356)。

### 1.2 睡眠、用户会话与 tap 健康恢复

sleep / session inactive 前完整停止 tap，wake / active 后完整重建；tap timeout 可以先 enable，失败后销毁 tap 与 run-loop source 再重建。增加约 10 秒的低频健康检查，同时检查 `CFMachPortIsValid` 和 `CGEvent.tapIsEnabled`。

依据：[Apple NSWorkspace 通知](https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification)、[LinearMouse 当前生命周期实现](https://github.com/linearmouse/linearmouse/blob/ef541a5cf5b89e17167b773a545010a454632c08/LinearMouse/AppDelegate.swift#L80-L137)、[Event Tap 健康检查修复](https://github.com/linearmouse/linearmouse/commit/9cf8a899e16407704b367bfc208dd3b784ec2b77)。

### 1.3 轨迹限流与多屏覆盖层

路径长度改为增量计算；按距离降采样；设置点数上限；5 秒没有 mouse-up 自动取消。覆盖窗口按手势起点选择屏幕，监听屏幕参数变化并取消当前会话。窗口继续复用一个实例，level 从 shielding 降为 statusBar。

依据：[MacGesture 多屏错位 #90](https://github.com/MacGesture/MacGesture/issues/90)、[Mission Control 残影 #139](https://github.com/MacGesture/MacGesture/issues/139)、[Hammerspoon 多屏垂直偏移 #3263](https://github.com/Hammerspoon/hammerspoon/issues/3263)。

### 1.4 真实状态、右键元数据与安全测试

菜单状态必须来自 tap 真实状态，启动失败不能静默；普通右键补发保留 flags 与 clickState。`swift test` 只能测试纯逻辑，禁止默认向系统发送真实 down/up；真实事件测试必须显式启用并保证清理。

依据：[Hammerspoon tap 状态与完整销毁](https://github.com/Hammerspoon/hammerspoon/blob/08e93f679bb5d9b88d2e8bd493d964a133c89960/extensions/eventtap/libeventtap.m#L196-L258)、[LinearMouse 测试卡住 WindowServer 的修复](https://github.com/linearmouse/linearmouse/commit/2f90965c62405dd88d8a49263f3db82fd0a60889)。

### 1.5 签名私钥安全

正式安装前移除 `security import -A`，限制私钥只供 codesign 使用，并处理已经以宽 ACL 导入的旧私钥。这会单独执行，可能需要最后一次辅助功能重新授权。

## 2. 只验证、不预先修改

- KeySender 修饰键释放：外部项目有残留案例，但当前本机多次真实手势后 modifier flags 为 0。先增加专项验收，只有复现才改成显式 flagsChanged。
- 内存泄漏：当前约 35 分钟运行、18.3MB footprint、leaks=0。重点验证无上限轨迹与窗口生命周期，不做无证据的所有权重构。

## 3. 明确不纳入

- 专用 Event Tap 后台线程：当前输入量低，迁线程会引入 AppKit 边界和竞态。
- 每 10 秒创建 test tap 并失败后重启整个 App：对只拦右键的轻量 App 过重。
- LaunchAgent / 无条件 KeepAlive：当前无崩溃记录；`SMAppService.mainApp` 已满足登录启动。若未来确认崩溃，再单独评估只针对异常退出的保活。
- 自动更新、联网崩溃上报、遥测、Developer ID、公证。

## 4. 实施顺序

1. 标准纯测试 + `GestureSession`
2. 异常 cancel 与 deferred click
3. sleep/session stop-rebuild + tap health check
4. 轨迹限流 + 多屏 + statusBar overlay
5. 真实状态 + click metadata
6. 签名 ACL、CI、原子打包
7. 真机异常矩阵 + 24 小时观察

## 5. 完成判断

完成不等于“代码编译”。必须同时满足：标准测试全绿、8 手势和普通右键回归通过、睡眠/用户切换/多屏恢复、无输入状态残留、24 小时 CPU/内存稳定、签名 ACL 已收紧。之后才能合并 `main`、发布 `v0.3.0` 并安装到 `~/Applications/`。
