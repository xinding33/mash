# Mash

Scars and invariants only. Anything a grep or `--help` can tell you doesn't go here.

## Invariants

- `swift test` and `bash scripts/build.sh` must pass. Logic that can be tested without the
  hardware lives in `MashCore`, with tests. AppKit and system calls stay in `Mash`.
- No third-party dependencies.
- Only Xin tags. Pushing a `v*` tag publishes a release, updates the Homebrew cask, and every
  installed copy installs it within a day.
- The bundle identifier `io.github.xinding33.mash` never changes. Privacy grants, settings,
  the login item and the cask all hang off it.
- Only `scripts/release.sh` stamps `MashBuild` = `release`. Local builds are signed with the
  same Developer ID, so that key is what stops a release overwriting one.
- The repo is public. Keep account emails, tokens, machine names and personal config out of
  commits, logs pasted into docs, and PR text.

## Hazards

<!-- Add each one the first time it costs a session: what happened, and what to do instead. -->

- Before v0.1.0 the bundle identifier was `com.xinding.mash`. It was never released, so there is
  no migration: local copies lost their settings and Accessibility grant once.
- The HUD panel sits one level above `CGShieldingWindowLevel()`, because SDL raises a focused
  full-screen game window to the shielding level and covers anything lower.
- Key triggers are registered only while the target app is frontmost, so Mash never takes the
  key from other apps. Keep it that way.
