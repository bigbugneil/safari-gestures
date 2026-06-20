# SafariGestures 发布检查表

## 自动检查

- [ ] `swift build -c release`
- [ ] `swift run -c release safari-gestures-selftest`
- [ ] `bash scripts/make-app.sh`
- [ ] `codesign --verify --deep --strict --verbose=2 SafariGestures.app`
- [ ] GitHub Actions 全绿
- [ ] `git diff --check`

## 真机功能与异常

- [ ] 8 个手势、普通右键、无映射手势、非 Safari 右键全部通过
- [ ] 手势中途 Cmd-Tab、停用监听和丢失 mouse-up 后没有卡右键或幽灵菜单
- [ ] 睡眠唤醒、用户会话切换后监听恢复
- [ ] 主屏、外接屏、屏幕拔插、排列变化和分辨率变化通过
- [ ] Mission Control、全屏 Safari、空间切换无覆盖层残影
- [ ] 连续 Cmd / Cmd+Shift 手势后 modifier flags 为 0

## 资源与安全

- [ ] 静置 CPU 接近 0，24 小时内内存无单调增长
- [ ] `leaks` 无确定泄漏，无 SafariGestures crash report
- [ ] 日志中没有连续 tap disabled / 重建循环
- [ ] 执行 `bash scripts/setup-signing-cert.sh --rotate-insecure-existing`
- [ ] 新私钥 ACL 仅允许 `/usr/bin/codesign`，且不可导出
- [ ] 新证书连续两次打包后的 Designated Requirement 一致

## 发布与安装

- [ ] `CHANGELOG.md` 从 `Unreleased` 归档为 `0.3.0`
- [ ] `Info.plist` 版本更新为 `0.3.0` / build `3`
- [ ] 合并 `codex/robustness-hardening` 到 `main`
- [ ] 创建并推送 `v0.3.0` tag
- [ ] 将最终 `SafariGestures.app` 安装到 `~/Applications/`
- [ ] 重新授予一次辅助功能权限并验证登录启动
