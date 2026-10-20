import AppKit
import Carbon.HIToolbox
import MashCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var updates: Updates
    @State private var opensAtLogin = LoginItem.isEnabled
    @State private var loginNeedsApproval = LoginItem.needsApproval
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Key to press") {
                    ShortcutRecorder(title: keyName(for: settings.pressedKeyCode), keysOnly: true) { candidate in
                        guard case let .key(keyCode, _) = candidate else { return nil }
                        if settings.trigger.conflicts(withPressedKey: keyCode) {
                            return "That key is the toggle shortcut, so it can't also be the key to press."
                        }
                        settings.pressedKeyCode = keyCode
                        return nil
                    }
                }
                LabeledContent("In app") {
                    TargetAppPicker(target: $settings.target)
                }
            } footer: {
                Text("Mash only presses the key, and only listens for the shortcut, while this app is in front.")
            }

            Section {
                LabeledContent("Toggle shortcut") {
                    ShortcutRecorder(title: settings.trigger.displayName) { candidate in
                        if candidate.conflicts(withPressedKey: settings.pressedKeyCode) {
                            return "That's the key being pressed, so it can't also be the shortcut on its own."
                        }
                        settings.trigger = candidate
                        return nil
                    }
                }
            } footer: {
                Text("Click a button above, then press a key. The shortcut can also be a key combination or an extra mouse button. Esc cancels.")
            }

            Section {
                Stepper(
                    "Presses per second: \(settings.pressesPerSecond)",
                    value: $settings.pressesPerSecond,
                    in: Settings.pressesPerSecondRange
                )
            }

            Section {
                Toggle("Turn off automatically", isOn: $settings.autoOffEnabled)
                LabeledContent("After") {
                    HStack(spacing: 6) {
                        TextField("", value: $settings.autoOffMinutes, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                        Stepper("", value: $settings.autoOffMinutes, in: Settings.autoOffMinutesRange)
                            .labelsHidden()
                        Text("minutes")
                    }
                }
                .disabled(!settings.autoOffEnabled)
            }

            Section {
                Toggle("Open at Login", isOn: Binding(get: { opensAtLogin }, set: { enabled in
                    do {
                        try LoginItem.setEnabled(enabled)
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                    }
                    refreshLoginItem()
                }))
                .disabled(LoginItem.problem != nil)
                if let problem = LoginItem.problem {
                    Text(problem).font(.caption).foregroundStyle(.secondary)
                } else if loginNeedsApproval {
                    LabeledContent("Switched off in System Settings") {
                        Button("Open Login Items…") { NSWorkspace.shared.open(LoginItem.settingsURL) }
                    }
                }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            }

            Section {
                Toggle("Install Updates Automatically", isOn: $updates.automatic)
                    .disabled(!updates.canInstall)
                LabeledContent("Version \(appVersion.description)") {
                    if let status = updates.status {
                        Text(status).foregroundStyle(.secondary)
                    } else {
                        Button("Check for Updates…") { updates.checkNow() }
                    }
                }
            } header: {
                Text("Updates")
            } footer: {
                Text(updates.canInstall
                     ? "Mash checks GitHub once a day and installs new releases signed by its developer."
                     : "This copy was built from source, so it can't install releases. Pull and build again to update.")
            }
        }
        .formStyle(.grouped)
        // Login Items can be switched on or off in System Settings while this window is open.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            refreshLoginItem()
        }
        .frame(width: 440)
        .fixedSize()
    }

    private func refreshLoginItem() {
        opensAtLogin = LoginItem.isEnabled
        loginNeedsApproval = LoginItem.needsApproval
    }
}

private struct TargetAppPicker: View {
    @Binding var target: TargetApp

    var body: some View {
        HStack(spacing: 10) {
            Text(target.name)
            Button("Choose…", action: chooseApplication)
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let app = TargetApp(bundleURL: url) else { return }
        target = app
    }
}

private struct ShortcutRecorder: View {
    let title: String
    /// Limits recording to a single key, ignoring modifiers and mouse buttons.
    var keysOnly = false
    /// Stores the candidate, or returns why it can't be used.
    let record: (Trigger) -> String?

    @State private var monitor: Any?
    @State private var rejection: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                if monitor == nil { startRecording() } else { stopRecording() }
            } label: {
                Text(monitor == nil ? title : keysOnly ? "Press key…" : "Press shortcut…")
                    .frame(minWidth: 80)
            }
            if let rejection {
                Text(rejection)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        rejection = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: keysOnly ? .keyDown : [.keyDown, .otherMouseDown]) { event in
            if event.type == .otherMouseDown {
                finish(.mouse(button: event.buttonNumber))
            } else if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
            } else {
                let modifiers = keysOnly ? [] : event.modifierFlags.intersection(Trigger.supportedModifiers)
                finish(.key(keyCode: event.keyCode, modifiers: modifiers.rawValue))
            }
            return nil
        }
    }

    private func finish(_ candidate: Trigger) {
        rejection = record(candidate)
        if rejection == nil { stopRecording() }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
