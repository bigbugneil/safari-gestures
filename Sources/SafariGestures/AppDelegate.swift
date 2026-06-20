import AppKit
import OSLog
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private static let logger = Logger(subsystem: "com.bigbug.safarigestures", category: "AppDelegate")
  private var statusItem: NSStatusItem!
  private var toggleMenuItem: NSMenuItem!
  private var loginItemMenuItem: NSMenuItem!
  private let eventTap = EventTap()
  private var isEnabled = true
  private var systemPauseReasons: Set<SystemPauseReason> = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureStatusItem()
    observeSystemLifecycle()

    if AccessibilityPermission.isTrusted {
      startEventTapIfPossible()
    } else {
      // 等菜单栏图标完成挂载后再展示权限说明，避免首次启动时界面无归属。
      DispatchQueue.main.async { [weak self] in
        self?.showAccessibilityGuideIfNeeded()
      }
    }
  }

  func applicationDidBecomeActive(_ notification: Notification) {
    // 用户从系统设置返回后自动复查权限，无需重启 App。
    if systemPauseReasons.isEmpty, isEnabled, AccessibilityPermission.isTrusted {
      startEventTapIfPossible()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    NotificationCenter.default.removeObserver(self)
    eventTap.stop()
  }

  private func observeSystemLifecycle() {
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(
      self,
      selector: #selector(workspaceWillSleep),
      name: NSWorkspace.willSleepNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenParametersDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(workspaceDidWake),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(sessionDidResignActive),
      name: NSWorkspace.sessionDidResignActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(sessionDidBecomeActive),
      name: NSWorkspace.sessionDidBecomeActiveNotification,
      object: nil
    )
  }

  @objc private func workspaceWillSleep(_ notification: Notification) {
    pauseForSystemTransition(.sleep, reason: "系统即将睡眠")
  }

  @objc private func workspaceDidWake(_ notification: Notification) {
    resumeAfterSystemTransition(.sleep, reason: "系统已唤醒")
  }

  @objc private func sessionDidResignActive(_ notification: Notification) {
    pauseForSystemTransition(.sessionInactive, reason: "用户会话已失活")
  }

  @objc private func sessionDidBecomeActive(_ notification: Notification) {
    resumeAfterSystemTransition(.sessionInactive, reason: "用户会话已恢复")
  }

  @objc private func screenParametersDidChange(_ notification: Notification) {
    Self.logger.info("屏幕参数发生变化，取消当前手势并重建覆盖窗口。")
    eventTap.screenConfigurationDidChange()
  }

  private func pauseForSystemTransition(_ reason: SystemPauseReason, reason message: String) {
    systemPauseReasons.insert(reason)
    Self.logger.info("\(message, privacy: .public)，停用 Event Tap。")
    eventTap.stop()
  }

  private func resumeAfterSystemTransition(_ reason: SystemPauseReason, reason message: String) {
    systemPauseReasons.remove(reason)
    guard systemPauseReasons.isEmpty else { return }

    Self.logger.info("\(message, privacy: .public)，准备重建 Event Tap。")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      guard let self, self.systemPauseReasons.isEmpty else { return }
      self.startEventTapIfPossible()
    }
  }

  private func configureStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "cursorarrow.motionlines",
        accessibilityDescription: "Safari 鼠标手势"
      )

      // 极少数系统无法提供该 SF Symbol 时仍保留可点击入口。
      if button.image == nil {
        button.title = "SG"
      }
    }

    let menu = NSMenu()

    toggleMenuItem = NSMenuItem(
      title: "启用/停用",
      action: #selector(toggleEnabled(_:)),
      keyEquivalent: ""
    )
    toggleMenuItem.target = self
    menu.addItem(toggleMenuItem)
    updateToggleMenuItem()

    loginItemMenuItem = NSMenuItem(
      title: "开机时启动",
      action: #selector(toggleLoginItem),
      keyEquivalent: ""
    )
    loginItemMenuItem.target = self
    menu.addItem(loginItemMenuItem)
    updateLoginItemState()

    menu.addItem(.separator())

    let aboutItem = NSMenuItem(
      title: "关于",
      action: #selector(showAbout),
      keyEquivalent: ""
    )
    aboutItem.target = self
    menu.addItem(aboutItem)

    let quitItem = NSMenuItem(
      title: "退出",
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem.menu = menu
  }

  @objc
  private func toggleEnabled(_ sender: NSMenuItem) {
    isEnabled.toggle()
    updateToggleMenuItem()

    if isEnabled {
      if AccessibilityPermission.isTrusted {
        startEventTapIfPossible()
      } else {
        showAccessibilityGuideIfNeeded()
      }
    } else {
      eventTap.stop()
    }
  }

  private func updateToggleMenuItem() {
    toggleMenuItem.state = isEnabled ? .on : .off
  }

  @objc
  private func toggleLoginItem() {
    do {
      if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      } else {
        try SMAppService.mainApp.register()
      }
    } catch {
      Self.logger.error("切换开机自启失败：\(error.localizedDescription, privacy: .public)")
    }
    updateLoginItemState()
  }

  private func updateLoginItemState() {
    loginItemMenuItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
  }

  private func showAccessibilityGuideIfNeeded() {
    guard !AccessibilityPermission.isTrusted else {
      return
    }

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "需要辅助功能权限"
    alert.informativeText =
      "请前往“系统设置 → 隐私与安全性 → 辅助功能”，为 SafariGestures 开启权限。重编后若监听失败，请删除旧条目并重新添加当前 App。"
    alert.addButton(withTitle: "打开辅助功能设置")
    alert.addButton(withTitle: "稍后")

    NSApp.activate()
    if alert.runModal() == .alertFirstButtonReturn {
      AccessibilityPermission.openSystemSettings()
    }
  }

  private func startEventTapIfPossible() {
    guard systemPauseReasons.isEmpty, isEnabled, !eventTap.isRunning else {
      return
    }
    _ = eventTap.start()
  }

  @objc
  private func showAbout() {
    let alert = NSAlert()
    alert.messageText = "SafariGestures"
    alert.informativeText = "一个轻量的 Safari 鼠标手势菜单栏工具。\n\nSafari 内按住右键划动触发动作（返回/前进/开关标签/切换标签等），划动时显示轨迹；普通右键单击照常弹出菜单。"
    alert.addButton(withTitle: "好")

    NSApp.activate()
    alert.runModal()
  }

  @objc
  private func quit() {
    eventTap.stop()
    NSApp.terminate(nil)
  }
}

private enum SystemPauseReason: Hashable {
  case sleep
  case sessionInactive
}
