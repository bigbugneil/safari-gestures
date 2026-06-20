import Carbon.HIToolbox
import CoreGraphics

struct GestureAction: Sendable {
  let name: String
  let keyCode: CGKeyCode
  let modifiers: CGEventFlags
}

enum GestureMap {
  private static let commandAndShift = CGEventFlags.maskCommand.union(.maskShift)

  /// 键码来自 Carbon HIToolbox 的 kVK_ 常量，不依赖当前键盘字符布局。
  private static let actions: [String: GestureAction] = [
    "L": GestureAction(
      name: "返回",
      keyCode: CGKeyCode(kVK_ANSI_LeftBracket),  // 33
      modifiers: .maskCommand
    ),
    "R": GestureAction(
      name: "前进",
      keyCode: CGKeyCode(kVK_ANSI_RightBracket),  // 30
      modifiers: .maskCommand
    ),
    "DR": GestureAction(
      name: "关闭标签页",
      keyCode: CGKeyCode(kVK_ANSI_W),  // 13
      modifiers: .maskCommand
    ),
    "LU": GestureAction(
      name: "重开已关标签",
      keyCode: CGKeyCode(kVK_ANSI_T),  // 17
      modifiers: commandAndShift
    ),
    "RU": GestureAction(
      name: "新建标签页",
      keyCode: CGKeyCode(kVK_ANSI_T),  // 17
      modifiers: .maskCommand
    ),
    "RD": GestureAction(
      name: "刷新",
      keyCode: CGKeyCode(kVK_ANSI_R),  // 15
      modifiers: .maskCommand
    ),
    "UL": GestureAction(
      name: "切到左边标签",
      keyCode: CGKeyCode(kVK_ANSI_LeftBracket),  // 33
      modifiers: commandAndShift
    ),
    "UR": GestureAction(
      name: "切到右边标签",
      keyCode: CGKeyCode(kVK_ANSI_RightBracket),  // 30
      modifiers: commandAndShift
    ),
    // DL（停止加载）已按用户反馈移除：实际用不上，槽位先空着。
  ]

  static func action(for sequence: String) -> GestureAction? {
    actions[sequence]
  }
}
