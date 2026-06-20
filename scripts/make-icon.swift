import AppKit

let S: CGFloat = 1024
let canvas = NSImage(size: CGSize(width: S, height: S))
canvas.lockFocus()

// 1) 圆角方底 + 蓝色渐变
let rect = NSRect(x: 0, y: 0, width: S, height: S)
let bg = NSBezierPath(roundedRect: rect, xRadius: 230, yRadius: 230)
bg.addClip()
let grad = NSGradient(colors: [
  NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.98, alpha: 1),
  NSColor(calibratedRed: 0.06, green: 0.32, blue: 0.82, alpha: 1)
])!
grad.draw(in: rect, angle: -90)

// 2) 白色符号(先在独立透明画布染白，再居中贴上)
let cfg = NSImage.SymbolConfiguration(pointSize: 560, weight: .regular)
if let base = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
  let sz = base.size
  let sym = NSImage(size: sz)
  sym.lockFocus()
  base.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
  NSColor.white.set()
  NSRect(origin: .zero, size: sz).fill(using: .sourceAtop)
  sym.unlockFocus()
  let dx = (S - sz.width) / 2, dy = (S - sz.height) / 2
  sym.draw(at: NSPoint(x: dx, y: dy), from: .zero, operation: .sourceOver, fraction: 1)
}
canvas.unlockFocus()

if let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
  try! png.write(to: URL(fileURLWithPath: "/tmp/appicon_1024.png"))
  print("wrote /tmp/appicon_1024.png")
}
