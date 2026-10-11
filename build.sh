#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/Mash.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Mash "$APP/Contents/MacOS/Mash"
cp Info.plist "$APP/Contents/Info.plist"

# A stable signing identity keeps the Accessibility grant across rebuilds; ad-hoc signing ("-") does not.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')}"
codesign --force --sign "${IDENTITY:--}" "$APP"

echo "Built $APP"
