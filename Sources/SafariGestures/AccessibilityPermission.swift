import AppKit
import ApplicationServices

@MainActor
enum AccessibilityPermission {
  /// 静默读取当前授权状态，启动时不让系统额外弹出权限提示。
  static var isTrusted: Bool {
    AXIsProcessTrustedWithOptions(options(prompt: false))
  }

  static func openSystemSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      )
    else {
      return
    }

    NSWorkspace.shared.open(url)
  }

  private static func options(prompt: Bool) -> CFDictionary {
    // Swift 6 会把 SDK 中的 kAXTrustedCheckOptionPrompt 视为并发不安全的可变 C 全局量。
    // 使用该公开常量的稳定字符串值，可以保持同一 API 语义并通过严格并发检查。
    [
      "AXTrustedCheckOptionPrompt": prompt
    ] as CFDictionary
  }
}
