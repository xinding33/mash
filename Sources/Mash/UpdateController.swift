import AppKit
import MashCore
import os

private let logger = Logger(subsystem: "com.xinding.mash", category: "update")

/// Checks GitHub for newer releases of Mash, installs them and restarts into them.
final class UpdateController {
    /// Only release builds can install releases, since an update must be signed the same way.
    static let canInstall = Updater.isDeveloperIDSigned(Bundle.main.bundleURL)
    static let currentVersion =
        Version(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") ?? Version("0.0.0")!
    static let versionText = currentVersion.description

    private enum Key {
        static let lastCheck = "lastUpdateCheck"
    }

    private struct RestartError: LocalizedError {
        let reason: String
        var errorDescription: String? {
            "Mash was updated but could not restart (\(reason)). Quit and open it again to finish."
        }
    }

    /// What the updater is doing, or nil when it is idle.
    private(set) var status: String?
    /// Automatic updates wait while this returns true, since installing one restarts Mash.
    var isBusy: () -> Bool = { false }
    /// Called just before Mash restarts into an update.
    var willRestart: () -> Void = {}

    private let settings = Settings.shared
    private let defaults = UserDefaults.standard
    private var timer: Timer?

    func start() {
        checkAutomatically()
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.checkAutomatically()
        }
    }

    /// When automatic updates are on, checks GitHub at most once a day and installs any newer release.
    func checkAutomatically() {
        let lastCheck = defaults.object(forKey: Key.lastCheck) as? Date ?? .distantPast
        guard settings.autoUpdate, Self.canInstall, status == nil, !isBusy(),
              Date().timeIntervalSince(lastCheck) > 24 * 60 * 60 else { return }
        status = "Checking for Updates…"
        Task { @MainActor in
            defer { status = nil }
            // A failed check is retried within the hour; a failed install at the next daily check.
            do {
                let release = try await Updater.latestRelease()
                // Mash was switched on during the check, so leave the update for the next hourly attempt.
                if release.version > Self.currentVersion, isBusy() { return }
                defaults.set(Date(), forKey: Key.lastCheck)
                if release.version > Self.currentVersion { try await install(release) }
            } catch {
                logger.error("Automatic update failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func checkNow() {
        status = "Checking for Updates…"
        Task { @MainActor in
            defer { status = nil }
            do {
                let release = try await Updater.latestRelease()
                defaults.set(Date(), forKey: Key.lastCheck)
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                guard release.version > Self.currentVersion else {
                    alert.messageText = "Mash is up to date"
                    alert.informativeText = "Version \(Self.versionText) is the latest."
                    alert.runModal()
                    return
                }
                alert.messageText = "Mash \(release.version) is available"
                alert.informativeText = Self.canInstall
                    ? "You have version \(Self.versionText). Mash restarts to install the update."
                    : "You have version \(Self.versionText). This copy was built from source, so it cannot update itself."
                if Self.canInstall { alert.addButton(withTitle: "Install and Restart") }
                alert.addButton(withTitle: "Release Notes")
                alert.addButton(withTitle: "Later")
                switch (alert.runModal(), Self.canInstall) {
                case (.alertFirstButtonReturn, true): try await install(release)
                case (.alertFirstButtonReturn, false), (.alertSecondButtonReturn, true): NSWorkspace.shared.open(release.page)
                default: break
                }
            } catch {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "Could not update Mash"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    /// Replaces this copy with `release` and restarts into it.
    @MainActor private func install(_ release: Release) async throws {
        status = "Installing Mash \(release.version)…"
        try await Updater.install(release, replacing: Bundle.main.bundleURL)
        willRestart()
        var arguments = CommandLine.arguments.map { strdup($0) } + [nil]
        execv(Bundle.main.executablePath!, &arguments)
        // Only reached if execv failed. Keep running the old code until the next launch.
        throw RestartError(reason: String(cString: strerror(errno)))
    }
}
