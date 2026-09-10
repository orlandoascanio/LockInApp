#!/usr/bin/env bash
# Build the app and put it in /Applications, replacing whatever is there.
#
# Kept separate from build_app.sh on purpose: building is harmless and can run
# any time, while installing quits the copy you are using. Nothing should
# replace a running app behind your back mid-session.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LockIn"
SOURCE_APP="$ROOT_DIR/build/$APP_NAME.app"
DESTINATION="/Applications/$APP_NAME.app"

"$ROOT_DIR/Scripts/build_app.sh"

WAS_RUNNING=false
if pgrep -f "$DESTINATION/Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
    WAS_RUNNING=true
    echo "Quitting the running $APP_NAME…"
    osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
        pgrep -f "$DESTINATION/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 || break
        sleep 0.25
    done
    # A focus session that will not close should not be killed silently.
    if pgrep -f "$DESTINATION/Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
        echo "$APP_NAME is still running — quit it and run this again." >&2
        exit 1
    fi
fi

rm -rf "$DESTINATION"
cp -R "$SOURCE_APP" "$DESTINATION"

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$DESTINATION/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$DESTINATION/Contents/Info.plist")"
COMMIT="$(/usr/libexec/PlistBuddy -c "Print LockInSourceCommit" "$DESTINATION/Contents/Info.plist" 2>/dev/null || echo unknown)"
echo "Installed $DESTINATION ($VERSION build $BUILD, $COMMIT)"

if [[ "$WAS_RUNNING" == true ]]; then
    open "$DESTINATION"
    echo "Relaunched."
fi
