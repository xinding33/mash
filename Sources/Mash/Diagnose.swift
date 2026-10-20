import ApplicationServices
import Foundation
import MashCore

/// `Mash --diagnose` prints what an agent or a bug report needs, then exits. It only reads:
/// it never prompts for permissions or changes settings.
@MainActor
enum Diagnose {
    static func run() -> Never {
        let app = Bundle.main.bundleURL
        let settings = Settings.shared
        let lines = [
            "\(appName) \(appVersion) at \(app.path)",
            "Bundle identifier: \(bundleID)",
            "Release build: \(Updater.isRelease(app) ? "yes" : "no")",
            "Developer ID signed: \(Updater.isDeveloperIDSigned(app) ? "yes" : "no")",
            "Installs updates: \(Updater.canInstallUpdates(into: app) ? "yes" : "no")",
            "Open at Login: \(LoginItem.needsApproval ? "switched off in System Settings" : LoginItem.isEnabled ? "on" : "off")"
                + (LoginItem.problem.map { " (\($0))" } ?? ""),
            // Needed to press keys and for mouse-button shortcuts. Run from a terminal, the app has
            // the terminal's grant, so this reports the terminal's.
            "Accessibility: \(AXIsProcessTrusted() ? "granted" : "not granted")",
            "Target app: \(settings.target.name) (\(settings.target.bundleID))",
            "Presses: \(keyName(for: settings.pressedKeyCode)), \(settings.pressesPerSecond) per second",
            "Toggle shortcut: \(settings.trigger.displayName)",
            "Turns off after: " + (settings.autoOffEnabled ? "\(settings.autoOffMinutes) min" : "never"),
        ]
        print(lines.joined(separator: "\n"))
        exit(0)
    }
}
