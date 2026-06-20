import AppKit
import CoreGraphics
import OSLog
import SafariGesturesCore

/// 给「补发的右键」打的标记，写在事件的 eventSourceUserData 字段里。
/// 真实硬件事件该字段为 0，我们的合成事件设成这个非零值，回调里据此跳过，避免无限回环。
/// 放在文件作用域是因为 CGEventTapCallBack 是 @convention(c) 回调，引用全局常量安全、不构成捕获。
private let kSyntheticEventMarker: Int64 = 0x5347_5F52  // "SG_R"

@MainActor
final class EventTap: NSObject {
  enum Status: Equatable {
    case stopped
    case running
    case recovering
    case failed
  }

  private static let logger = Logger(
    subsystem: "com.bigbug.safarigestures",
    category: "EventTap"
  )

  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var healthCheckTimer: Timer?
  private var rebuildScheduled = false
  private var shouldRun = false
  private var session = GestureSession()
  private var trackingWatchdog: Timer?
  private let overlay = GestureOverlay()

  private(set) var status: Status = .stopped
  var onStatusChange: ((Status) -> Void)? {
    didSet { onStatusChange?(status) }
  }

  var isRunning: Bool {
    guard let tap else { return false }
    return CFMachPortIsValid(tap) && CGEvent.tapIsEnabled(tap: tap)
  }

  @discardableResult
  func start() -> Bool {
    shouldRun = true
    guard !isRunning else {
      transition(to: .running)
      return true
    }
    transition(to: .recovering)
    if tap != nil {
      destroyTap(logStop: false)
    }

    // 注意：.defaultTap（可拦截/补发事件）只需要“辅助功能”权限，不需要“输入监控”。
    // 早期 .listenOnly 版本曾在此处预检 CGPreflightListenEventAccess，切到 .defaultTap 后该检查多余且会误拦，已移除。
    // 权限是否到位交给下面的 tapCreate 判定：返回 nil 即代表缺辅助功能权限。

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
      transition(to: .failed)
      return false
    }

    guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
      CFMachPortInvalidate(tap)
      log(level: .error, "Event Tap 已创建，但无法建立 RunLoop source。")
      transition(to: .failed)
      return false
    }

    self.tap = tap
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    startHealthCheck()
    transition(to: .running)
    log(level: .info, "手势监听已启用：Safari 内按住右键划动触发动作，单击照常弹菜单。")
    return true
  }

  func stop() {
    shouldRun = false
    destroyTap(logStop: true)
    transition(to: .stopped)
  }

  private func destroyTap(logStop: Bool) {
    healthCheckTimer?.invalidate()
    healthCheckTimer = nil
    cancelTracking(reason: "事件监听已停止")

    guard let tap else { return }

    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
      CFRunLoopSourceInvalidate(runLoopSource)
    }
    CGEvent.tapEnable(tap: tap, enable: false)
    CFMachPortInvalidate(tap)

    self.tap = nil
    runLoopSource = nil
    if logStop {
      log(level: .info, "手势监听已停用。")
    }
  }

  /// 返回值：true=吞掉该事件，false=原样放行。
  private func handle(type: CGEventType, event: CGEvent) -> Bool {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      cancelTracking(reason: "系统临时停用了 Event Tap")
      transition(to: .recovering)
      if let tap {
        CGEvent.tapEnable(tap: tap, enable: true)
        if CFMachPortIsValid(tap), CGEvent.tapIsEnabled(tap: tap) {
          transition(to: .running)
          log(level: .fault, "系统临时停用了 Event Tap，重新启用成功。")
        } else {
          log(level: .fault, "Event Tap 重新启用失败，将销毁后重建。")
          scheduleRebuild(reason: "tap disabled 后重新启用失败")
        }
      }
      return false
    }

    switch type {
    case .rightMouseDown:
      // 非 Safari 前台：完全不干预，右键照常。
      guard isSafariFrontmost else {
        cancelTracking(reason: "Safari 不在前台")
        return false
      }
      // Safari 前台：先扣住右键（菜单暂不弹），开始记录轨迹，松手时再决定。
      if session.isTracking {
        cancelTracking(reason: "收到新的右键按下，替换未结束的手势")
      }
      session.begin(
        rightClick: .init(
          location: event.location,
          flagsRawValue: event.flags.rawValue,
          clickState: event.getIntegerValueField(.mouseEventClickState)
        )
      )
      overlay.begin(at: event.location)
      startTrackingWatchdog()
      return true

    case .rightMouseDragged:
      guard session.isTracking else {
        return false
      }
      guard isSafariFrontmost else {
        cancelTracking(reason: "手势期间 Safari 失去前台")
        return true
      }
      if session.append(event.location) {
        overlay.addPoint(event.location)
      }
      return true

    case .rightMouseUp:
      guard session.isTracking else {
        return false
      }
      guard isSafariFrontmost else {
        cancelTracking(reason: "手势期间 Safari 失去前台")
        return true
      }
      _ = session.append(event.location)
      let swallow = resolveGesture()
      clearTracking()
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
    let pointCount = session.points.count
    guard let completion = session.finish() else {
      log(level: .fault, "右键会话没有可完成的结果，已安全取消。")
      return true
    }

    switch completion {
    case .replayRightClick(let context):
      log(level: .default, "普通右键单击（点数=\(pointCount)）→ 补发原生右键菜单")
      replayRightClick(context)
      return true

    case .gesture(let directions):
      // 有方向但没映射到动作：吞掉、不执行、也不弹菜单。
      guard let action = GestureMap.action(for: directions) else {
        log(level: .default, "方向序列=\(directions) 未映射任何动作，已忽略")
        return true
      }

      log(level: .default, "手势=\(directions) → \(action.name)，发送快捷键")
      KeySender.send(action)
      return true
    }
  }

  /// 补发一次右键 down+up，触发 Safari 原生右键菜单；事件打合成标记以便回调跳过。
  private func replayRightClick(_ context: GestureSession.RightClickContext) {
    let source = CGEventSource(stateID: .combinedSessionState)
    guard
      let down = CGEvent(
        mouseEventSource: source,
        mouseType: .rightMouseDown,
        mouseCursorPosition: context.location,
        mouseButton: .right
      ),
      let up = CGEvent(
        mouseEventSource: source,
        mouseType: .rightMouseUp,
        mouseCursorPosition: context.location,
        mouseButton: .right
      )
    else {
      log(level: .error, "补发右键失败：无法创建鼠标事件。")
      return
    }

    down.flags = CGEventFlags(rawValue: context.flagsRawValue)
    up.flags = CGEventFlags(rawValue: context.flagsRawValue)
    down.setIntegerValueField(.mouseEventClickState, value: context.clickState)
    up.setIntegerValueField(.mouseEventClickState, value: context.clickState)
    down.setIntegerValueField(.eventSourceUserData, value: kSyntheticEventMarker)
    up.setIntegerValueField(.eventSourceUserData, value: kSyntheticEventMarker)
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }

  private func startTrackingWatchdog() {
    trackingWatchdog?.invalidate()
    let timer = Timer(
      timeInterval: 5,
      target: self,
      selector: #selector(trackingTimedOut),
      userInfo: nil,
      repeats: false
    )
    trackingWatchdog = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func startHealthCheck() {
    healthCheckTimer?.invalidate()
    let timer = Timer(
      timeInterval: 10,
      target: self,
      selector: #selector(checkHealth),
      userInfo: nil,
      repeats: true
    )
    healthCheckTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  @objc private func checkHealth() {
    guard shouldRun, !isRunning else { return }
    log(level: .fault, "Event Tap 健康检查失败，将销毁后重建。")
    scheduleRebuild(reason: "低频健康检查失败")
  }

  private func scheduleRebuild(reason: String) {
    guard shouldRun, !rebuildScheduled else { return }
    rebuildScheduled = true
    transition(to: .recovering)

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.rebuildScheduled = false
      guard self.shouldRun else { return }

      self.destroyTap(logStop: false)
      if self.start() {
        self.log(level: .info, "Event Tap 销毁后重建成功：\(reason)")
      } else {
        self.log(level: .error, "Event Tap 销毁后重建失败：\(reason)")
      }
    }
  }

  @objc private func trackingTimedOut() {
    cancelTracking(reason: "等待右键抬起超时")
  }

  private func cancelTracking(reason: String) {
    if session.isTracking {
      log(level: .fault, "取消未完成手势：\(reason)")
    }
    clearTracking()
  }

  private func clearTracking() {
    trackingWatchdog?.invalidate()
    trackingWatchdog = nil
    session.reset()
    overlay.end()
  }

  func screenConfigurationDidChange() {
    cancelTracking(reason: "屏幕参数发生变化")
    overlay.invalidateScreenConfiguration()
  }

  private func log(level: OSLogType, _ message: String) {
    Self.logger.log(level: level, "\(message, privacy: .public)")
    print("[SafariGestures] \(message)")
  }

  private func transition(to newStatus: Status) {
    guard status != newStatus else { return }
    status = newStatus
    onStatusChange?(newStatus)
  }
}
