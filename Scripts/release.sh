#!/usr/bin/env bash
# Build, sign with Developer ID, notarize, and package LockIn as a DMG, then
# sign it for Sparkle and write the appcast.
#
#   Scripts/release.sh            # version from the latest vX.Y.Z tag
#
# One-time setup (see Scripts/release/README.md):
#   1. A "Developer ID Application" certificate in your keychain.
#   2. xcrun notarytool store-credentials LockIn-Notary --apple-id <you> --team-id 5BVWR47BQX
#   3. Scripts/release/setup_sparkle.sh
#
# Output lands in build/release/: LockIn-<version>.dmg and appcast.xml. Upload
# both to a GitHub release; the app's feed points at the latest release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LockIn"
TEAM_ID="5BVWR47BQX"
NOTARY_PROFILE="${NOTARY_PROFILE:-LockIn-Notary}"
REPO="orlandoascanio/LockInApp"
OUT="$ROOT_DIR/build/release"
ARCHIVE="$OUT/$APP_NAME.xcarchive"
DERIVED="$ROOT_DIR/build/DerivedData"

cd "$ROOT_DIR"

fail() { echo "✗ $*" >&2; exit 1; }
step() { echo; echo "▸ $*"; }

# --- Preflight: fail before a long build, not after it ---------------------

[[ -z "$(git status --porcelain)" ]] || fail "Commit or stash your changes first — a release should match a commit."
TAG="$(git describe --tags --exact-match --match 'v[0-9]*' 2>/dev/null)" \
    || fail "HEAD has no vX.Y.Z tag. Tag it first: git tag v0.2.0"
VERSION="${TAG#v}"
BUILD_NUMBER="$(git rev-list --count HEAD)"
COMMIT="$(git rev-parse --short HEAD)"

IDENTITY="$(security find-identity -v -p codesigning | grep "Developer ID Application: .*($TEAM_ID)" | head -1 | awk '{print $2}')"
[[ -n "$IDENTITY" ]] \
    || fail "No 'Developer ID Application' certificate for team $TEAM_ID. Create one at developer.apple.com › Certificates."
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "No notarytool profile '$NOTARY_PROFILE'. Run: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <your Apple ID> --team-id $TEAM_ID"
grep -q 'SPARKLE_PUBLIC_KEY: ""' project.yml \
    && fail "Sparkle isn't set up, so this release could never update itself. Run Scripts/release/setup_sparkle.sh"

rm -rf "$OUT"
mkdir -p "$OUT"
xcodegen generate --quiet

# --- Archive and export -----------------------------------------------------

step "Archiving $APP_NAME $VERSION ($BUILD_NUMBER)"
xcodebuild archive \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    -archivePath "$ARCHIVE" \
    -destination 'generic/platform=macOS' \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    LOCKIN_SOURCE_COMMIT="$COMMIT" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
[[ -d "$ARCHIVE" ]] || fail "Archive failed."

step "Exporting with Developer ID"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportPath "$OUT/export" \
    -exportOptionsPlist "$ROOT_DIR/Scripts/release/ExportOptions.plist" \
    | grep -E "error:|EXPORT (SUCCEEDED|FAILED)" || true
APP="$OUT/export/$APP_NAME.app"
[[ -d "$APP" ]] || fail "Export failed."
codesign --verify --deep --strict --verbose=2 "$APP"

# --- DMG --------------------------------------------------------------------

step "Building the DMG"
DMG="$OUT/$APP_NAME-$VERSION.dmg"
STAGING="$OUT/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "$IDENTITY" --timestamp "$DMG"

# --- Notarize ---------------------------------------------------------------

step "Notarizing (usually a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

# --- Sparkle ----------------------------------------------------------------

step "Signing for Sparkle and writing the appcast"
SPARKLE_BIN="$(find "$DERIVED/SourcePackages/artifacts" -type d -path '*Sparkle/bin' | head -1)"
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || fail "Sparkle's tools weren't found in $DERIVED/SourcePackages."
"$SPARKLE_BIN/generate_appcast" \
    --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" \
    -o "$OUT/appcast.xml" \
    "$OUT"

rm -rf "$STAGING" "$OUT/export"
echo
echo "✓ $DMG"
echo "✓ $OUT/appcast.xml"
echo
echo "Next: create the GitHub release $TAG and attach both files, e.g."
echo "  gh release create $TAG \"$DMG\" \"$OUT/appcast.xml\" --title \"$APP_NAME $VERSION\""
