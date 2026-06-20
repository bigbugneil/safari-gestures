import CoreGraphics

/// 一次右键手势的纯状态：负责轨迹采样与容量上限，不接触 Event Tap 或系统输入。
public struct GestureSession: Sendable {
  public struct RightClickContext: Equatable, Sendable {
    public let location: CGPoint
    public let flagsRawValue: UInt64
    public let clickState: Int64

    public init(location: CGPoint, flagsRawValue: UInt64, clickState: Int64) {
      self.location = location
      self.flagsRawValue = flagsRawValue
      self.clickState = clickState
    }
  }

  public enum Completion: Equatable, Sendable {
    case replayRightClick(RightClickContext)
    case gesture(String)
  }

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
  private var rightClickContext: RightClickContext?

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

  /// 开始可延迟决策的右键会话，并保存普通点击补发所需的最小元数据。
  @discardableResult
  public mutating func begin(rightClick context: RightClickContext) -> Bool {
    let replacedExistingSession = begin(at: context.location)
    rightClickContext = context
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

  /// 正常 mouse-up 才允许完成会话。异常路径必须调用 reset，返回值因而永远为 nil。
  public mutating func finish() -> Completion? {
    guard isTracking, let rightClickContext else {
      reset()
      return nil
    }

    let directions = GestureRecognizer.directions(from: points)
    let completion: Completion = directions.isEmpty
      ? .replayRightClick(rightClickContext)
      : .gesture(directions)
    reset()
    return completion
  }

  /// 结束或异常取消都回到 idle；返回本次是否确实取消了活动会话。
  @discardableResult
  public mutating func reset() -> Bool {
    let wasTracking = isTracking
    state = .idle
    points.removeAll(keepingCapacity: false)
    pathLength = 0
    rightClickContext = nil
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
