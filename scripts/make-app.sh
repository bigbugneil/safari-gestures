#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/SafariGestures.app"

"$SCRIPT_DIR/build.sh"

BIN_DIR="$(cd "$PROJECT_DIR" && swift build -c release --show-bin-path)"
BINARY="$BIN_DIR/SafariGestures"

if [[ ! -x "$BINARY" ]]; then
    echo "找不到 release 可执行文件：$BINARY" >&2
    exit 1
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
install -m 755 "$BINARY" "$APP_DIR/Contents/MacOS/SafariGestures"
cp "$PROJECT_DIR/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>SafariGestures</string>
    <key>CFBundleExecutable</key>
    <string>SafariGestures</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.bigbug.safarigestures</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SafariGestures</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>SafariGestures 需要辅助功能权限，以便在后续版本中读取鼠标手势并触发 Safari 操作。</string>
    <key>NSInputMonitoringUsageDescription</key>
    <string>SafariGestures 需要输入监控权限，以只读方式观察 Safari 中的右键鼠标轨迹。</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - --identifier com.bigbug.safarigestures "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "已生成：$APP_DIR"
