#!/usr/bin/env bash
# One-time: create the EdDSA key Sparkle signs updates with, and put its public
# half into project.yml so every build can verify what it downloads.
#
# The private key goes into your login keychain (item "Private key for signing
# Sparkle updates"). Back it up — lose it and existing installs can never
# accept another update. Never commit it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DERIVED="$ROOT_DIR/build/DerivedData"
cd "$ROOT_DIR"

SPARKLE_BIN="$(find "$DERIVED/SourcePackages/artifacts" -type d -path '*Sparkle/bin' 2>/dev/null | head -1 || true)"
if [[ -z "$SPARKLE_BIN" ]]; then
    echo "Sparkle's tools aren't downloaded yet — building once to fetch them…"
    "$ROOT_DIR/Scripts/build_app.sh" >/dev/null
    SPARKLE_BIN="$(find "$DERIVED/SourcePackages/artifacts" -type d -path '*Sparkle/bin' | head -1)"
fi

# Prints the existing key if there is one; otherwise creates it.
PUBLIC_KEY="$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null || true)"
if [[ -z "$PUBLIC_KEY" ]]; then
    "$SPARKLE_BIN/generate_keys" >/dev/null
    PUBLIC_KEY="$("$SPARKLE_BIN/generate_keys" -p)"
fi

sed -i '' "s|SPARKLE_PUBLIC_KEY: \".*\"|SPARKLE_PUBLIC_KEY: \"$PUBLIC_KEY\"|" project.yml
echo "Sparkle public key: $PUBLIC_KEY"
echo "Written to project.yml. Commit that change; builds from now on will check for updates."
