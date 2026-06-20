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

let failures = results.filter { !$0 }.count
if failures == 0 {
  print("全部通过 ✅（\(results.count) 项）")
} else {
  print("有 \(failures) 个失败 ❌")
  exit(1)
}
