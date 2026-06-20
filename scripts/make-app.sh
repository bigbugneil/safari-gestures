#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/SafariGestures.app"
STAGING_ROOT="$(mktemp -d "$PROJECT_DIR/.safari-gestures-package.XXXXXX")"
STAGED_APP="$STAGING_ROOT/SafariGestures.app"
SCRATCH_DIR="$STAGING_ROOT/build"

trap 'rm -rf "$STAGING_ROOT"' EXIT

cd "$PROJECT_DIR"
swift build -c release --scratch-path "$SCRATCH_DIR"

BIN_DIR="$(swift build -c release --scratch-path "$SCRATCH_DIR" --show-bin-path)"
BINARY="$BIN_DIR/SafariGestures"

if [[ ! -x "$BINARY" ]]; then
    echo "找不到 release 可执行文件：$BINARY" >&2
    exit 1
fi

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
install -m 755 "$BINARY" "$STAGED_APP/Contents/MacOS/SafariGestures"
cp "$PROJECT_DIR/AppIcon.icns" "$STAGED_APP/Contents/Resources/AppIcon.icns"

cat > "$STAGED_APP/Contents/Info.plist" <<'PLIST'
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
    <string>0.3.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>SafariGestures 需要辅助功能权限，以识别 Safari 中的右键手势并触发对应操作。</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$STAGED_APP/Contents/Info.plist"

# 优先用本机自签名证书签名：designated requirement 绑定到证书而非 cdhash，
# 这样每次重编重签后 macOS 仍认作同一 App，辅助功能授权不失效。
# 没有该证书的机器（如他人 clone）自动回退 ad-hoc 签名。
SIGN_ID="SafariGestures Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    echo "用自签名证书签名：$SIGN_ID"
    codesign --force --deep --sign "$SIGN_ID" --identifier com.bigbug.safarigestures "$STAGED_APP"
else
    echo "（未找到自签名证书，回退 ad-hoc；如需稳定授权请先跑 scripts/setup-signing-cert.sh）"
    codesign --force --deep --sign - --identifier com.bigbug.safarigestures "$STAGED_APP"
fi
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
swift "$SCRIPT_DIR/replace-app.swift" "$STAGED_APP" "$APP_DIR"
echo "已生成：$APP_DIR"
