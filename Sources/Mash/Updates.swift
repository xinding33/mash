import AppKit
import Combine
import MashCore

/// Installs new releases from GitHub: at most one check a day, and only into a release build
/// signed with the same Developer ID.
@MainActor
final class Updates: ObservableObject {
    let canInstall = Updater.canInstallUpdates(into: Bundle.main.bundleURL)
    @Published var automatic: Bool {
        didSet { UserDefaults.standard.set(automatic, forKey: "autoUpdate"); checkAutomatically() }
    }
    /// Whether an automatic update must not restart Mash yet: while it's switched on, a restart
    /// would turn it off mid-game. The update is installed anyway and runs from the next restart.
    var isBusy: () -> Bool = { false }
    /// An automatic update is installed, and Mash restarts into it once it isn't busy.
    private var relaunchPending = false
    /// What the updater is doing, or nil when it is idle.
    @Published private(set) var status: String?

    private var lastCheck: Date {
        get { UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "lastUpdateCheck") }
    }
    private var timer: DispatchSourceTimer?

    init() {
        automatic = UserDefaults.standard.object(forKey: "autoUpdate") as? Bool ?? true
    }

    func start() {
        // A DispatchSourceTimer, because run-loop timers pause while a menu is open.
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 30, repeating: 60 * 60)
        timer.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.checkAutomatically() } }
        timer.resume()
        self.timer = timer
    }

    func checkAutomatically() {
        guard automatic, canInstall, status == nil, !relaunchPending,
              Date().timeIntervalSince(lastCheck) > 24 * 60 * 60 else { return }
        status = "Checking for updates…"
        Task {
            defer { status = nil }
            // A failed check is retried within the hour; a failed install at the next daily check.
            do { if let release = try await newerRelease() { try await install(release, waitingWhileBusy: true) } }
            catch { log.error("Automatic update failed: \(error.localizedDescription, privacy: .public)") }
        }
    }

    func checkNow() {
        guard status == nil else { return }
        status = "Checking for updates…"
        Task {
            defer { status = nil }
            do {
                let release = try await newerRelease()
                let alert = NSAlert()
                guard let release else {
                    alert.messageText = "\(appName) is up to date"
                    alert.informativeText = "Version \(appVersion) is the latest."
                    await show(alert)
                    return
                }
                alert.messageText = "\(appName) \(release.version) is available"
                alert.informativeText = canInstall
                    ? "You have version \(appVersion)."
                    : "You have version \(appVersion). This copy wasn't installed from a release, so it can't update itself."
                if canInstall { alert.addButton(withTitle: "Install and Restart") }
                alert.addButton(withTitle: "Release Notes")
                alert.addButton(withTitle: "Later")
                switch (await show(alert), canInstall) {
                case (.alertFirstButtonReturn, true): try await install(release)
                case (.alertFirstButtonReturn, false), (.alertSecondButtonReturn, true): NSWorkspace.shared.open(release.page)
                default: break
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Couldn't update \(appName)"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                await show(alert)
            }
        }
    }

    /// Runs `alert` from the run loop rather than inside this task. A modal run inside a main-actor
    /// task holds the actor, so the rest of the app's tasks would wait until it's dismissed.
    @discardableResult
    private func show(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            RunLoop.main.perform {
                MainActor.assumeIsolated {
                    NSApp.activate()
                    continuation.resume(returning: alert.runModal())
                }
            }
        }
    }

    private func newerRelease() async throws -> Release? {
        let release = try await Updater.latestRelease()
        lastCheck = Date()
        return release.version > appVersion ? release : nil
    }

    /// Restarts into an installed update that was waiting for Mash to be switched off.
    func becameIdle() {
        guard relaunchPending, !isBusy() else { return }
        log.info("Relaunching into the installed update")
        Relaunch.now()
    }

    private func install(_ release: Release, waitingWhileBusy: Bool = false) async throws {
        status = "Installing \(appName) \(release.version)…"
        try await Updater.install(release, replacing: Bundle.main.bundleURL)
        if waitingWhileBusy, isBusy() {
            log.info("Installed \(release.version.description, privacy: .public), relaunching when Mash is off")
            relaunchPending = true
            return
        }
        log.info("Installed \(release.version.description, privacy: .public), relaunching")
        Relaunch.now()
    }
}
