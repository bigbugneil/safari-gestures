#!/usr/bin/env swift

import Foundation

guard CommandLine.arguments.count == 3 else {
  fputs("用法：replace-app.swift <暂存 App> <目标 App>\n", stderr)
  exit(64)
}

let fileManager = FileManager.default
let stagedURL = URL(fileURLWithPath: CommandLine.arguments[1])
let destinationURL = URL(fileURLWithPath: CommandLine.arguments[2])

do {
  if fileManager.fileExists(atPath: destinationURL.path) {
    _ = try fileManager.replaceItemAt(
      destinationURL,
      withItemAt: stagedURL,
      backupItemName: nil,
      options: []
    )
  } else {
    try fileManager.moveItem(at: stagedURL, to: destinationURL)
  }
} catch {
  fputs("替换 App 失败：\(error.localizedDescription)\n", stderr)
  exit(1)
}
