# SafariGestures

**English** | [简体中文](README.zh-CN.md)

[![CI](https://github.com/bigbugneil/safari-gestures/actions/workflows/ci.yml/badge.svg)](https://github.com/bigbugneil/safari-gestures/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

SafariGestures is a lightweight macOS menu bar app that adds right-button mouse gestures to Safari. Hold the right mouse button and draw a gesture to go back, move between tabs, reload a page, and more.

It is designed as a focused alternative to system-wide gesture utilities:

- **Safari only:** other apps receive mouse events unchanged.
- **Native right-click behavior:** a normal right-click still opens Safari's context menu.
- **Visible feedback:** a blue trail follows the pointer while a gesture is being drawn.
- **Privacy first:** no network access, telemetry, keyboard-content reading, or user-data files.
- **Small toolchain:** build with Swift Package Manager; full Xcode and an Apple Developer account are not required.

## Gestures

Hold the right mouse button, draw one of these paths, and then release:

| Gesture | Action | Safari shortcut |
|---|---|---|
| `Left` | Go back | `Command + [` |
| `Right` | Go forward | `Command + ]` |
| `Down, Right` | Close the current tab | `Command + W` |
| `Left, Up` | Reopen the last closed tab | `Command + Shift + T` |
| `Right, Up` | Open a new tab | `Command + T` |
| `Right, Down` | Reload the page | `Command + R` |
| `Up, Left` | Select the tab to the left | `Command + Shift + [` |
| `Up, Right` | Select the tab to the right | `Command + Shift + ]` |

Gesture mappings live in [`Sources/SafariGestures/GestureMap.swift`](Sources/SafariGestures/GestureMap.swift). Direction recognition is implemented in [`Sources/SafariGesturesCore/GestureRecognizer.swift`](Sources/SafariGesturesCore/GestureRecognizer.swift).

## How It Works

SafariGestures uses a session-level `CGEventTap` to observe right-button events. It intervenes only while Safari is the frontmost app:

1. A right-button press is held temporarily instead of opening the context menu immediately.
2. Pointer movement is recorded and shown as a gesture trail.
3. On release, a recognized gesture sends the corresponding Safari keyboard shortcut.
4. If the pointer barely moved, SafariGestures replays a marked right-click so the native context menu opens normally.

Synthetic replay events are marked and ignored by the event callback to prevent event loops. The listener also recovers from Event Tap interruptions and rebuilds itself after sleep, wake, user-session, and display changes.

## Requirements

- macOS 15 or later
- Apple Silicon
- Swift 6.1 or later and the Command Line Tools
- Accessibility permission for SafariGestures

Input Monitoring permission is not required.

The current menu bar interface uses Chinese labels. Gesture behavior is independent of the interface language.

## Build and Run

Clone the repository and run:

```bash
git clone https://github.com/bigbugneil/safari-gestures.git
cd safari-gestures

# Optional but recommended: create a local signing identity once.
bash scripts/setup-signing-cert.sh

# Build and package SafariGestures.app.
bash scripts/make-app.sh

# Launch the app from the project directory.
open SafariGestures.app
```

On first launch, grant SafariGestures access in **System Settings > Privacy & Security > Accessibility**. Then switch to Safari, hold the right mouse button, draw a gesture, and release.

The menu bar item lets you check listener status, enable or disable gestures, restart the listener, launch the app at login, view app information, and quit.

To use it as a daily app, copy `SafariGestures.app` to `~/Applications/` and enable launch at login from the menu bar item.

## Stable Local Signing

macOS remembers Accessibility permission using an app's code-signing identity. With ad-hoc signing, that identity changes after each rebuild, so the system may ask for permission again.

[`scripts/setup-signing-cert.sh`](scripts/setup-signing-cert.sh) creates a free, self-signed code-signing identity in the login keychain. [`scripts/make-app.sh`](scripts/make-app.sh) uses it automatically, keeping the app's designated requirement stable across local rebuilds. The private key is non-exportable and restricted to `/usr/bin/codesign`.

If the identity was created by an older version of the script, rotate it before the final installation:

```bash
bash scripts/setup-signing-cert.sh --rotate-insecure-existing
```

Rotation changes the signing identity, so Accessibility permission must be granted one final time. It is normal for macOS not to mark this self-signed certificate as trusted; that does not prevent local code signing or stable permission recognition.

If no local identity exists, the packaging script falls back to ad-hoc signing.

## Development Checks

The project includes a zero-dependency self-test executable. It tests gesture recognition and right-click session logic without generating real mouse or keyboard input.

```bash
swift build -c release
swift run -c release safari-gestures-selftest
```

CI runs both commands and verifies that the app bundle can be packaged and code-signed.

## Project Layout

| Path | Purpose |
|---|---|
| `Sources/SafariGestures/` | Menu bar app, Event Tap, gesture mapping, overlay, and shortcut dispatch |
| `Sources/SafariGesturesCore/` | Gesture recognition and right-click session state machine |
| `Sources/SelfTest/` | Zero-dependency logic self-tests |
| `scripts/` | Build, packaging, icon, and local-signing utilities |

## License

SafariGestures is available under the [MIT License](LICENSE). You may use, copy, modify, and distribute it under the license terms.
