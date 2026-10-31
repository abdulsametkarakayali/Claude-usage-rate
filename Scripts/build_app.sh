#!/bin/bash
# Build ClaudeTokens.app bundle and (optionally) install to /Applications.
# Usage: ./Scripts/build_app.sh [install]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClaudeTokens"
APP="$ROOT/build/$APP_NAME.app"

echo "[1/4] swift build (release)"
cd "$ROOT"
swift build -c release

echo "[2/4] assemble bundle at $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ClaudeTokens</string>
    <key>CFBundleDisplayName</key><string>ClaudeTokens</string>
    <key>CFBundleIdentifier</key><string>com.claudetokens.widget</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>ClaudeTokens</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "[3/4] ad-hoc codesign"
codesign --force --deep -s - "$APP"

if [[ "${1:-}" == "install" ]]; then
    echo "[4/4] install to /Applications"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/$APP_NAME.app"
    touch "/Applications/$APP_NAME.app"
    killall Finder Dock 2>/dev/null || true
    echo "Installed. Open: open /Applications/$APP_NAME.app"
else
    echo "[4/4] built at $APP (pass 'install' to copy to /Applications)"
fi
