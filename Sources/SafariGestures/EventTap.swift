import AppKit
import CoreGraphics
import OSLog
import SafariGesturesCore

/// 给「补发的右键」打的标记，写在事件的 eventSourceUserData 字段里。
/// 真实硬件事件该字段为 0，我们的合成事件设成这个非零值，回调里据此跳过，避免无限回环。
/// 放在文件作用域是因为 CGEventTapCallBack 是 @convention(c) 回调，引用全局常量安全、不构成捕获。
private let kSyntheticEventMarker: Int64 = 0x5347_5F52  // "SG_R"

@MainActor
final class EventTap {
  private static let logger = Logger(
    subsystem: "com.bigbug.safarigestures",
    category: "EventTap"
  )

  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var points: [CGPoint] = []
  private var isTracking = false
  private let overlay = GestureOverlay()

  var isRunning: Bool {
    tap != nil
  }

  @discardableResult
  func start() -> Bool {
    guard tap == nil else {
      return true
    }

    guard CGPreflightListenEventAccess() else {
      log(
        level: .error,
        "缺少“输入监控”权限：请在“系统设置 → 隐私与安全性 → 输入监控”中启用 SafariGestures，然后重新启动 App。"
      )
      _ = CGRequestListenEventAccess()
      return false
    }

    let eventMask =
      (CGEventMask(1) << CGEventType.rightMouseDown.rawValue)
      | (CGEventMask(1) << CGEventType.rightMouseDragged.rawValue)
      | (CGEventMask(1) << CGEventType.rightMouseUp.rawValue)

    // .defaultTap：可主动拦截/吞掉事件（需要“辅助功能”权限，tapCreate 失败即代表未授权）。
    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard let userInfo else {
        return Unmanaged.passUnretained(event)
      }

      // 跳过自己补发的合成右键，避免回调再次处理形成死循环。
      if event.getIntegerValueField(.eventSourceUserData) == kSyntheticEventMarker {
        return Unmanaged.passUnretained(event)
      }

      let owner = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
      let swallow = MainActor.assumeIsolated {
        owner.handle(type: type, event: event)
      }

      // swallow=true：返回 nil 吞掉事件（菜单不弹）；false：原样放行。
      return swallow ? nil : Unmanaged.passUnretained(event)
    }

    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: callback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else {
      log(
        level: .error,
        "Event Tap 创建失败：请检查“系统设置 → 隐私与安全性 → 辅助功能”中的 SafariGestures 权限；重编后可能需要删除旧条目并重新添加当前 App。"
      )
      return false
    }

    guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
      CFMachPortInvalidate(tap)
      log(level: .error, "Event Tap 已创建，但无法建立 RunLoop source。")
      return false
    }

    self.tap = tap
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    log(level: .info, "手势监听已启用：Safari 内按住右键划动触发动作，单击照常弹菜单。")
    return true
  }

  func stop() {
    guard let tap else {
      resetTracking()
      return
    }

    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
      CFRunLoopSourceInvalidate(runLoopSource)
    }
    CGEvent.tapEnable(tap: tap, enable: false)
    CFMachPortInvalidate(tap)

    self.tap = nil
    runLoopSource = nil
    resetTracking()
    log(level: .info, "手势监听已停用。")
  }

  /// 返回值：true=吞掉该事件，false=原样放行。
  private func handle(type: CGEventType, event: CGEvent) -> Bool {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap {
        CGEvent.tapEnable(tap: tap, enable: true)
        log(level: .fault, "系统临时停用了 Event Tap，现已自动重新启用。")
      }
      return false
    }

    switch type {
    case .rightMouseDown:
      // 非 Safari 前台：完全不干预，右键照常。
      guard isSafariFrontmost else {
        resetTracking()
        return false
      }
      // Safari 前台：先扣住右键（菜单暂不弹），开始记录轨迹，松手时再决定。
      isTracking = true
      points = [event.location]
      overlay.begin()
      overlay.addPoint(event.location)
      return true

    case .rightMouseDragged:
      guard isTracking else {
        return false
      }
      guard isSafariFrontmost else {
        resetTracking()
        return false
      }
      points.append(event.location)
      overlay.addPoint(event.location)
      return true

    case .rightMouseUp:
      guard isTracking else {
        return false
      }
      guard isSafariFrontmost else {
        resetTracking()
        return false
      }
      points.append(event.location)
      let swallow = resolveGesture()
      resetTracking()
      return swallow

    default:
      return false
    }
  }

  private var isSafariFrontmost: Bool {
    NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.Safari"
  }

  /// 松开右键时的分流决策；返回 true 表示吞掉原始 up 事件。
  private func resolveGesture() -> Bool {
    let directions = GestureRecognizer.directions(from: points)

    // 空序列 = 几乎没移动 = 普通右键单击 → 补发一次真右键，让原生菜单正常弹出。
    if directions.isEmpty {
      let location = points.first ?? points.last ?? CGPoint.zero
      log(level: .default, "普通右键单击（点数=\(points.count)）→ 补发原生右键菜单")
      replayRightClick(at: location)
      return true
    }

    // 有方向但没映射到动作：是个手势动作意图，吞掉、不执行、也不弹菜单（避免意外菜单）。
    guard let action = GestureMap.action(for: directions) else {
      log(level: .default, "方向序列=\(directions) 未映射任何动作，已忽略")
      return true
    }

    // 命中手势 → 发送对应快捷键，并吞掉右键（菜单不弹）。
    log(level: .default, "手势=\(directions) → \(action.name)，发送快捷键")
    KeySender.send(action)
    return true
  }

  /// 补发一次右键 down+up，触发 Safari 原生右键菜单；事件打合成标记以便回调跳过。
  private func replayRightClick(at location: CGPoint) {
    let source = CGEventSource(stateID: .combinedSessionState)
    guard
      let down = CGEvent(
        mouseEventSource: source,
        mouseType: .rightMouseDown,
        mouseCursorPosition: location,
        mouseButton: .right
      ),
      let up = CGEvent(
        mouseEventSource: source,
        mouseType: .rightMouseUp,
        mouseCursorPosition: location,
        mouseButton: .right
      )
    else {
      log(level: .error, "补发右键失败：无法创建鼠标事件。")
      return
    }

    down.setIntegerValueField(.eventSourceUserData, value: kSyntheticEventMarker)
    up.setIntegerValueField(.eventSourceUserData, value: kSyntheticEventMarker)
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }

  private func resetTracking() {
    points.removeAll(keepingCapacity: true)
    isTracking = false
    overlay.end()
  }

  private func log(level: OSLogType, _ message: String) {
    Self.logger.log(level: level, "\(message, privacy: .public)")
    print("[SafariGestures] \(message)")
  }
}
