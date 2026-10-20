#!/bin/bash
# Writes the mash cask for a release into a homebrew-tap checkout. The release workflow runs
# this, and it rewrites the whole file, so change the cask here rather than in the tap.
# Usage: scripts/update-cask.sh TAP_DIR VERSION SHA256
#
# Mash updates itself, so the cask says `auto_updates true` and `brew upgrade` leaves it alone.
# Keep it that way from the first release: adding it later strands installs that can't update.
set -euo pipefail
TAP="$1" VERSION="$2" SHA="$3"
mkdir -p "$TAP/Casks"
cat > "$TAP/Casks/mash.rb" <<CASK
cask "mash" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/xinding33/mash/releases/download/v#{version}/Mash-#{version}.zip"
  name "Mash"
  desc "Repeatedly presses a key while a chosen app is in front"
  homepage "https://github.com/xinding33/mash"

  auto_updates true
  depends_on macos: :sonoma

  app "Mash.app"

  uninstall launchctl: "io.github.xinding33.mash",
            quit:      "io.github.xinding33.mash"

  zap trash: [
    "~/Library/Application Support/Mash",
    "~/Library/LaunchAgents/io.github.xinding33.mash.plist",
    "~/Library/Logs/Mash",
    "~/Library/Preferences/io.github.xinding33.mash.plist",
  ]
end
CASK
