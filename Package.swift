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
    .executableTarget(
      name: "SafariGestures",
      path: "Sources/SafariGestures"
    )
  ]
)
