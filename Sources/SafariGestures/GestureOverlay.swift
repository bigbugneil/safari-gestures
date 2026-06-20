import AppKit
import CoreGraphics

/// 手势轨迹悬浮层：一个透明、点击穿透、置顶的全屏窗口，按住右键划动时跟手画线。
/// 不参与事件处理（ignoresMouseEvents=true），只做视觉提示，划完即清空。
@MainActor
final class GestureOverlay {
  private var window: NSWindow?
  private var trailView: TrailView?
  private var shown = false

  private func ensureWindow() {
    guard window == nil, let screen = NSScreen.screens.first else { return }

    let w = NSWindow(
      contentRect: screen.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    w.isOpaque = false
    w.backgroundColor = .clear
    w.hasShadow = false
    w.ignoresMouseEvents = true  // 点击穿透，绝不抢事件
    w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
    w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

    let view = TrailView(frame: screen.frame)
    w.contentView = view
    window = w
    trailView = view
  }

  /// 右键按下：准备一条新轨迹（先不显示，等真的移动了再显示，避免单击闪线）。
  func begin() {
    ensureWindow()
    trailView?.reset()
    shown = false
  }

  /// 追加一个轨迹点（传入的是 CGEvent 全局坐标，左上角原点、y 向下）。
  func addPoint(_ cgPoint: CGPoint) {
    guard let screen = NSScreen.screens.first, let view = trailView else { return }

    // 转成主屏 Cocoa 坐标（左下角原点、y 向上），再落到覆盖主屏的视图坐标。
    let viewPoint = CGPoint(
      x: cgPoint.x - screen.frame.minX,
      y: screen.frame.height - (cgPoint.y - screen.frame.minY)
    )
    view.append(viewPoint)

    // 移动超过阈值才真正显示，纯单击不画。
    if !shown, view.pathLength > 8 {
      window?.orderFrontRegardless()
      shown = true
    }
    if shown {
      view.needsDisplay = true
    }
  }

  /// 右键抬起或中断：清空并隐藏。
  func end() {
    trailView?.reset()
    if shown {
      trailView?.needsDisplay = true
      window?.orderOut(nil)
      shown = false
    }
  }
}

private final class TrailView: NSView {
  private static let maximumPointCount = 512
  private var points: [CGPoint] = []
  private(set) var pathLength: CGFloat = 0

  override var isFlipped: Bool { false }
  override var isOpaque: Bool { false }

  func append(_ point: CGPoint) {
    if let previous = points.last {
      pathLength += hypot(point.x - previous.x, point.y - previous.y)
    }
    makeRoomIfNeeded()
    points.append(point)
  }

  func reset() {
    points.removeAll(keepingCapacity: false)
    pathLength = 0
  }

  private func makeRoomIfNeeded() {
    guard points.count >= Self.maximumPointCount else { return }

    let finalPoint = points.last
    points = points.enumerated().compactMap { index, point in
      index.isMultiple(of: 2) ? point : nil
    }
    if let finalPoint, points.last != finalPoint {
      points.append(finalPoint)
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    guard points.count >= 2 else { return }

    let path = NSBezierPath()
    path.lineWidth = 4
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: points[0])
    for point in points.dropFirst() {
      path.line(to: point)
    }

    NSColor.systemBlue.withAlphaComponent(0.85).setStroke()
    path.stroke()
  }
}
