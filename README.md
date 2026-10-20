# Mash

Repeatedly presses a key while a chosen app is in front.

Mash lives in the menu bar. Press its shortcut in your chosen app and it starts pressing a key
for you, several times a second, until you press the shortcut again or its timer runs out. It
was built for skipping dialogue in games streamed through NVIDIA GeForce NOW, which is the app
it starts with.

## Install

```sh
brew install --cask xinding33/tap/mash
```

Or download `Mash-x.y.z.zip` from the [latest release](https://github.com/xinding33/mash/releases/latest),
unzip it and move `Mash.app` to Applications. It needs macOS 14 or later.

Mash needs **Accessibility** access to press keys, and to use a mouse button as its shortcut.
It asks the first time you turn it on. Without it, Mash shows "Mash needs Accessibility access"
and stays off.

### Updating

Mash checks for a new release once a day and installs it. Turn that off with
**Install Updates Automatically** in Settings, or use **Check for Updates…** there. `brew upgrade`
leaves it alone, because it updates itself.

## Use

- Press the toggle shortcut (`` ` `` to start with) while the chosen app is in front. A banner
  shows **Mash On** or **Mash Off**, since the menu bar is hidden while a game is full screen.
- While it's on, Mash presses its key (`F` to start with) only while the chosen app is in front.
  Switch away and it pauses; come back and it carries on.
- It turns itself off after 10 minutes unless you change that.
- **Settings…** in the menu bar menu chooses the app, the key, the shortcut (a key, a key
  combination or an extra mouse button), presses per second, the timer, Open at Login and updates.
  Opening Mash again while it's running also shows Settings.

## How it works

Key presses are `CGEvent`s posted to the HID event tap, sent only while the chosen app is
frontmost. A keyboard shortcut is a Carbon hot key, registered only while the chosen app is in
front so it never takes the key from other apps. A mouse-button shortcut is an event tap, which
is why it needs Accessibility. Both swallow the shortcut, so the app never sees it.

## Build

```sh
swift test
bash scripts/build.sh   # dist/Mash.app
dist/Mash.app/Contents/MacOS/Mash --diagnose
```

`build.sh` signs with this Mac's Developer ID certificate if it has one, so permissions you grant
survive rebuilds. Otherwise it signs ad hoc, and macOS asks again after each build. Builds from
source never update themselves.

### Release

Push a `v` tag, e.g. `git tag v0.1.0 && git push origin v0.1.0`. The release workflow tests, signs,
notarizes and publishes `Mash-0.1.0.zip`, then updates the cask in
[xinding33/homebrew-tap](https://github.com/xinding33/homebrew-tap). To make a release on this Mac
instead, run `scripts/release.sh`.

## Limitations

- Mash presses one key. It doesn't play back sequences or hold keys down.

## Development

Mash was developed with AI assistance.

## License

Copyright 2026 Xin Ding. Licensed under the [Apache License, Version 2.0](LICENSE).
