import Foundation
import os
import MashCore

let appName = "Mash"
let bundleID = Bundle.main.bundleIdentifier ?? "io.github.xinding33.mash"
let appVersion = Version(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
    ?? Version("0.0.0")!
/// Read it with: /usr/bin/log stream --predicate 'subsystem == "io.github.xinding33.mash"' --level info
/// (zsh has its own `log` builtin, hence the full path.)
let log = Logger(subsystem: bundleID, category: "app")
let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent(appName, isDirectory: true)
