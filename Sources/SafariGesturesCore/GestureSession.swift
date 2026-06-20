import CoreGraphics

/// 一次右键手势的纯状态：负责轨迹采样与容量上限，不接触 Event Tap 或系统输入。
public struct GestureSession: Sendable {
  public enum State: Equatable, Sendable {
    case idle
    case tracking
  }

  public struct Configuration: Sendable {
    public let minimumSampleDistance: CGFloat
    public let maximumPointCount: Int

    public init(minimumSampleDistance: CGFloat = 2, maximumPointCount: Int = 512) {
      self.minimumSampleDistance = max(0, minimumSampleDistance)
      self.maximumPointCount = max(16, maximumPointCount)
    }
  }

  public private(set) var state: State = .idle
  public private(set) var points: [CGPoint] = []
  public private(set) var pathLength: CGFloat = 0

  private let configuration: Configuration

  public init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
  }

  public var isTracking: Bool {
    state == .tracking
  }

  /// 开始新会话。返回 true 表示开始前存在未结束的旧会话。
  @discardableResult
  public mutating func begin(at point: CGPoint) -> Bool {
    let replacedExistingSession = isTracking
    reset()
    state = .tracking
    points.append(point)
    return replacedExistingSession
  }

  /// 按距离采样追加轨迹点。返回 true 表示该点被采纳。
  @discardableResult
  public mutating func append(_ point: CGPoint) -> Bool {
    guard isTracking, let previous = points.last else {
      return false
    }

    let distance = hypot(point.x - previous.x, point.y - previous.y)
    guard distance >= configuration.minimumSampleDistance else {
      return false
    }

    pathLength += distance
    makeRoomIfNeeded()
    points.append(point)
    return true
  }

  /// 结束或异常取消都回到 idle；返回本次是否确实取消了活动会话。
  @discardableResult
  public mutating func reset() -> Bool {
    let wasTracking = isTracking
    state = .idle
    points.removeAll(keepingCapacity: true)
    pathLength = 0
    return wasTracking
  }

  private mutating func makeRoomIfNeeded() {
    guard points.count >= configuration.maximumPointCount else {
      return
    }

    let finalPoint = points.last
    points = points.enumerated().compactMap { index, point in
      index.isMultiple(of: 2) ? point : nil
    }
    if let finalPoint, points.last != finalPoint {
      points.append(finalPoint)
    }
  }
}
