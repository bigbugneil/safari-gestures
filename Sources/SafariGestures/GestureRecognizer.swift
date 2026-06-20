import CoreGraphics

enum GestureRecognizer {
  /// 把鼠标轨迹压缩成 L/R/U/D 方向序列；不读取或修改任何外部状态。
  static func directions(from points: [CGPoint], minSegment: CGFloat = 25) -> String {
    guard points.count >= 2, minSegment > 0 else {
      return ""
    }

    let pathLength = zip(points, points.dropFirst()).reduce(CGFloat.zero) { length, pair in
      length + distance(from: pair.0, to: pair.1)
    }
    guard pathLength >= minSegment else {
      return ""
    }

    var anchor = points[0]
    var result: [Character] = []

    for point in points.dropFirst() {
      let dx = point.x - anchor.x
      let dy = point.y - anchor.y
      guard hypot(dx, dy) >= minSegment else {
        continue
      }

      let direction: Character
      if abs(dx) >= abs(dy) {
        direction = dx < 0 ? "L" : "R"
      } else {
        // CGEvent.location 为左上角原点、y 向下增大；y 减小=向上，y 增大=向下。
        direction = dy < 0 ? "U" : "D"
      }

      if result.last != direction {
        result.append(direction)
      }
      anchor = point
    }

    return String(result)
  }

  private static func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
    hypot(end.x - start.x, end.y - start.y)
  }
}
