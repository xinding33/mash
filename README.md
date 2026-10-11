# Mash

A small, free native macOS menu bar app that presses one key over and over while a chosen app is in front. It was built to skip through dialogue in games streamed with NVIDIA GeForce NOW, which is the default app, but the key, the app and the shortcut are all yours to choose.

## Install

Requires macOS 13 or newer. Releases are signed with a Developer ID and notarized by Apple.

```sh
brew install --cask xinding33/tap/mash
```

Or download `Mash-x.y.z.zip` from the [latest release](https://github.com/xinding33/mash/releases/latest), unzip it, and move `Mash.app` to Applications.

To uninstall, quit Mash from its menu, then run `brew uninstall --cask mash` (or delete `Mash.app`).

To build it yourself instead, see [Build](#build).

### Updating

Mash updates itself: once a day it checks for a new [release](https://github.com/xinding33/mash/releases), checks that it is signed by the same developer, replaces itself and restarts. It never does this while it is switched on. To turn that off, uncheck **Install updates automatically** in Settings, and use **Check for Updates…** in the menu instead. Because Mash updates itself, `brew upgrade` skips it.

## Use

Open Mash. It lives in the menu bar as an **M** icon. With the chosen app in front, press the toggle shortcut (the backtick key, `` ` ``, by default) to start pressing F eight times a second, and press it again to stop. A banner at the top of the screen confirms each change.

The first time you turn it on, macOS asks you to allow Mash under **System Settings → Privacy & Security → Accessibility**. Mash needs that to send key presses.

Mash only presses the key, and only listens for the shortcut, while the chosen app is in front. Switch to another app and it pauses; switch back and it carries on. It also turns itself off after ten minutes, so it can't be left running by accident.

**Settings…** in the menu changes:

- the key to press
- the app it works in
- the toggle shortcut: a single key, a key combination, or an extra mouse button
- presses per second, from 1 to 20
- whether and when it turns itself off
- whether it installs updates automatically

Some games and apps don't allow automated input. Check the rules of whatever you use Mash with.

## Build

Requires Xcode. Mash uses no packages. Its only network access is the update check against GitHub.

```sh
swift test
bash scripts/build.sh
open dist/Mash.app
```

The build is universal and signed with an Apple Development certificate if your keychain has one, so the Accessibility permission survives rebuilds. Otherwise it is ad-hoc signed and macOS asks for the permission again after each build. `MASH_ARCHS=native` builds for your Mac only, which the Swift command-line tools can do without Xcode.

Builds you make yourself cannot install releases from the menu, since they are not signed by the same developer; pull and build again to update.

### Release

Pushing a `v*` tag runs `.github/workflows/release.yml`, which tests, signs with the hardened runtime, notarizes and staples the app, publishes `Mash-x.y.z.zip` to a GitHub Release, and updates the cask in [xinding33/homebrew-tap](https://github.com/xinding33/homebrew-tap). It needs these secrets in a `release` environment restricted to `v*` tags: `DEVELOPER_ID_P12` and `DEVELOPER_ID_P12_PASSWORD` (the base64-encoded Developer ID Application certificate and its password), `NOTARY_KEY`, `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID` (a base64-encoded App Store Connect API key), and `TAP_DEPLOY_KEY` (a deploy key with write access to the tap).

To produce the same notarized ZIP locally, save notary credentials once with `xcrun notarytool store-credentials wink-notary`, then run `bash scripts/release.sh`.

## Development

Mash's implementation and documentation were developed with AI assistance.

## License

Copyright 2026 Xin Ding. Licensed under the [Apache License, Version 2.0](LICENSE).
