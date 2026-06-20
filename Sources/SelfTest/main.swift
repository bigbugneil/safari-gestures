import CoreGraphics
import SafariGesturesCore

// 不依赖 Xcode/XCTest 的自检小程序：跑 GestureRecognizer 的关键用例。
// 用法：swift run safari-gestures-selftest（全过退出码 0，有失败退出码 1）。
// 坐标按 CGEvent 真实坐标系：左上角原点、y 向下增大（y 减小=上 U，y 增大=下 D）。

func check(_ name: String, _ raw: [(CGFloat, CGFloat)], _ expected: String) -> Bool {
  let pts = raw.map { CGPoint(x: $0.0, y: $0.1) }
  let got = GestureRecognizer.directions(from: pts)
  if got == expected {
    print("  ✅ \(name): \"\(got)\"")
    return true
  }
  print("  ❌ \(name): 期望 \"\(expected)\"，实际 \"\(got)\"")
  return false
}

func verify(_ name: String, _ condition: @autoclosure () -> Bool) -> Bool {
  if condition() {
    print("  ✅ \(name)")
    return true
  }
  print("  ❌ \(name)")
  return false
}

print("GestureRecognizer 自检：")
let results: [Bool] = [
  check("左划→L", [(100, 100), (60, 100), (20, 100)], "L"),
  check("右划→R", [(20, 100), (60, 100), (100, 100)], "R"),
  check("上划→U", [(100, 180), (100, 120), (100, 60)], "U"),
  check("下划→D", [(100, 60), (100, 120), (100, 180)], "D"),
  check("先下再右→DR", [(100, 100), (100, 140), (100, 180), (140, 180), (180, 180)], "DR"),
  check("先右再上→RU", [(100, 180), (140, 180), (180, 180), (180, 140), (180, 100)], "RU"),
  check("先右再下→RD", [(100, 100), (140, 100), (180, 100), (180, 140), (180, 180)], "RD"),
  check("先上再左→UL", [(180, 180), (180, 120), (180, 60), (120, 60), (60, 60)], "UL"),
  check("先上再右→UR", [(60, 180), (60, 120), (60, 60), (120, 60), (180, 60)], "UR"),
  check("先左再上→LU", [(180, 180), (120, 180), (60, 180), (60, 120), (60, 60)], "LU"),
  check("微动当单击→空", [(100, 100), (105, 103)], ""),
  check("单点→空", [(100, 100)], ""),
  check("抖动合并同向→R", [(20, 100), (60, 102), (100, 98), (140, 101)], "R"),
]

print("GestureSession 自检：")
var session = GestureSession(
  configuration: .init(minimumSampleDistance: 2, maximumPointCount: 32)
)
var sessionResults: [Bool] = []
sessionResults.append(verify("首次 begin 不替换旧会话", !session.begin(at: .zero)))
sessionResults.append(verify("不足采样距离的点被忽略", !session.append(CGPoint(x: 1, y: 0))))
sessionResults.append(verify("达到采样距离的点被记录", session.append(CGPoint(x: 2, y: 0))))
sessionResults.append(verify("pathLength 增量累计", session.pathLength == 2))
sessionResults.append(
  verify("新 begin 会替换未结束会话", session.begin(at: CGPoint(x: 100, y: 100)))
)
sessionResults.append(
  verify("替换后只保留新起点", session.points == [CGPoint(x: 100, y: 100)])
)

for index in 1...10_000 {
  session.append(CGPoint(x: 100 + index * 2, y: 100))
}
sessionResults.append(verify("超长轨迹点数有上限", session.points.count <= 32))
sessionResults.append(
  verify("超长轨迹保留最新点", session.points.last == CGPoint(x: 20_100, y: 100))
)
sessionResults.append(verify("reset 能结束活动会话", session.reset()))
sessionResults.append(verify("reset 后回到 idle", session.state == .idle))
sessionResults.append(verify("reset 后清空轨迹", session.points.isEmpty && session.pathLength == 0))

let failures = (results + sessionResults).filter { !$0 }.count
if failures == 0 {
  print("全部通过 ✅（\(results.count + sessionResults.count) 项）")
} else {
  print("有 \(failures) 个失败 ❌")
  exit(1)
}
