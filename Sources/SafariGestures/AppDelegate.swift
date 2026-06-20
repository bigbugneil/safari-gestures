import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var toggleMenuItem: NSMenuItem!
  private let eventTap = EventTap()
  private var isEnabled = true

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureStatusItem()

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
    if isEnabled, AccessibilityPermission.isTrusted {
      startEventTapIfPossible()
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
    guard isEnabled, !eventTap.isRunning else {
      return
    }
    _ = eventTap.start()
  }

  @objc
  private func showAbout() {
    let alert = NSAlert()
    alert.messageText = "SafariGestures"
    alert.informativeText = "一个轻量的 Safari 鼠标手势菜单栏工具。\n\n第 3 步会把已识别手势发送为 Safari 快捷键，但仍不拦截右键菜单。"
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
