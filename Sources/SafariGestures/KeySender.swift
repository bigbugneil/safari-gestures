import CoreGraphics
import OSLog

@MainActor
enum KeySender {
  private static let logger = Logger(
    subsystem: "com.bigbug.safarigestures",
    category: "KeySender"
  )

  static func send(_ action: GestureAction) {
    guard
      let source = CGEventSource(stateID: .combinedSessionState),
      let keyDown = CGEvent(
        keyboardEventSource: source,
        virtualKey: action.keyCode,
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: source,
        virtualKey: action.keyCode,
        keyDown: false
      )
    else {
      logger.error("无法为动作“\(action.name, privacy: .public)”创建键盘事件。")
      return
    }

    keyDown.flags = action.modifiers
    keyUp.flags = action.modifiers
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
  }
}
