#!/bin/bash
# Writes the mash cask for a release into a homebrew-tap checkout.
# Usage: scripts/update-cask.sh TAP_DIR VERSION SHA256
set -euo pipefail
TAP="$1" VERSION="$2" SHA="$3"
mkdir -p "$TAP/Casks"
cat > "$TAP/Casks/mash.rb" <<CASK
cask "mash" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/xinding33/mash/releases/download/v#{version}/Mash-#{version}.zip"
  name "Mash"
  desc "Menu bar app that repeatedly presses a key while a chosen app is in front"
  homepage "https://github.com/xinding33/mash"

  depends_on macos: :ventura

  app "Mash.app"

  uninstall quit: "com.xinding.mash"

  zap trash: "~/Library/Preferences/com.xinding.mash.plist"
end
CASK
