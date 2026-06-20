// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "SafariGestures",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "SafariGestures", targets: ["SafariGestures"])
  ],
  targets: [
    // 纯逻辑库（可被 App 和自检程序共用）
    .target(
      name: "SafariGesturesCore",
      path: "Sources/SafariGesturesCore"
    ),
    // 菜单栏 App
    .executableTarget(
      name: "SafariGestures",
      dependencies: ["SafariGesturesCore"],
      path: "Sources/SafariGestures"
    ),
    // 不依赖 Xcode/XCTest 的自检程序：swift run safari-gestures-selftest
    .executableTarget(
      name: "safari-gestures-selftest",
      dependencies: ["SafariGesturesCore"],
      path: "Sources/SelfTest"
    )
  ]
)
