#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LockIn"
BUNDLE_IDENTIFIER="com.lockin.app"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
ICON_PATH="$ROOT_DIR/FocusLock/Resources/AppIcon.icns"

cd "$ROOT_DIR"

# Derived from git so two builds are never confusable, and so an updater has
# a monotonically increasing build number to compare. CFBundleVersion must
# increase on every release; CFBundleShortVersionString is what people read.
SHORT_VERSION="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || echo "0.1.0")"
SHORT_VERSION="${SHORT_VERSION#v}"
BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo "1")"
COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null)" ]]; then
    COMMIT="$COMMIT-dirty"
fi

BUILD_OUTPUT_DIR="$(swift build -c release --show-bin-path)"
BINARY_PATH="$BUILD_OUTPUT_DIR/$APP_NAME"

swift build -c release --product "$APP_NAME"

rm -rf "$APP_DIR"
rm -rf "$ROOT_DIR/build/FocusLock.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ -f "$ICON_PATH" ]]; then
    cp "$ICON_PATH" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

find "$BUILD_OUTPUT_DIR" -maxdepth 1 -name "${APP_NAME}_*.bundle" -type d -exec cp -R {} "$APP_DIR/Contents/Resources/" \;

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LockInSourceCommit</key>
    <string>$COMMIT</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "Built $APP_DIR ($SHORT_VERSION build $BUILD_NUMBER, $COMMIT)"
echo "Run with: open \"$APP_DIR\""
