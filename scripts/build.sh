#!/bin/bash
# Builds dist/Mash.app and dist/Mash.zip: universal (Apple silicon and Intel) unless
# MASH_ARCHS=native. Signs with SIGN_IDENTITY, or else an Apple Development certificate if the
# keychain has one, or else ad-hoc. scripts/release.sh makes the notarized releases.
set -euo pipefail
cd "$(dirname "$0")/.."
# Releases pass MASH_VERSION from the tag; other builds use the latest tag.
VERSION="${MASH_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.0.0}"
# A stable signing identity keeps the Accessibility grant across rebuilds; ad-hoc signing ("-") does not.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}' || true)}"
IDENTITY="${IDENTITY:--}"
ARCHS=(--arch arm64 --arch x86_64)
if [ "${MASH_ARCHS:-universal}" = native ]; then ARCHS=(); fi
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} 2>&1 | tail -1
BIN_DIR="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)"

rm -rf dist
APP="$PWD/dist/Mash.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Mash" "$APP/Contents/MacOS/Mash"
cp scripts/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"

if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
elif [ "${MASH_BUILD:-development}" = release ]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
else
  # Only notarization needs Apple's timestamp, and a local build should not need the internet.
  codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$PWD/dist/Mash.zip"
printf 'Built: %s (%s)\n' "$APP" "$VERSION"
