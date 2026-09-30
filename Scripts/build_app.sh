#!/usr/bin/env bash
# Build LockIn.app (with its widget) into build/LockIn.app, signed with your
# development certificate. For a notarized DMG, use Scripts/release.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LockIn"
DERIVED="$ROOT_DIR/build/DerivedData"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONFIGURATION="${CONFIGURATION:-Release}"

cd "$ROOT_DIR"

# Derived from git so two builds are never confusable, and so the updater has
# a monotonically increasing build number to compare. CFBundleVersion must
# increase on every release; CFBundleShortVersionString is what people read.
SHORT_VERSION="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || echo "0.2.0")"
SHORT_VERSION="${SHORT_VERSION#v}"
BUILD_NUMBER="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo "1")"
COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null)" ]]; then
    COMMIT="$COMMIT-dirty"
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is needed to generate the Xcode project: brew install xcodegen" >&2
    exit 1
fi
xcodegen generate --quiet

xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED" \
    -destination 'platform=macOS' \
    MARKETING_VERSION="$SHORT_VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    LOCKIN_SOURCE_COMMIT="$COMMIT" \
    build \
    | grep -E "error:|warning: .*\.swift|BUILD (SUCCEEDED|FAILED)" || true

BUILT="$DERIVED/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$BUILT" ]]; then
    echo "Build failed — run xcodebuild without the filter above to see why." >&2
    exit 1
fi

rm -rf "$APP_DIR" "$ROOT_DIR/build/FocusLock.app"
cp -R "$BUILT" "$APP_DIR"

echo "Built $APP_DIR ($SHORT_VERSION build $BUILD_NUMBER, $COMMIT)"
echo "Run with: open \"$APP_DIR\""
