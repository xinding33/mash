import AppKit
import Combine
import SwiftUI
import os

private let logger = Logger(subsystem: "com.xinding.mash", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let presser = AutoPresser()
    private let triggerMonitor = TriggerMonitor()
    private let hud = HUD()
    private let updates = UpdateController()

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var autoOffTimer: Timer?
    /// Non-nil while auto-pressing is switched on, whether or not the target app is currently in front.
    private var enabledAt: Date?

    private var isEnabled: Bool { enabledAt != nil }

    private var autoOffDate: Date? {
        guard let enabledAt, settings.autoOffEnabled else { return nil }
        return enabledAt.addingTimeInterval(TimeInterval(settings.autoOffMinutes) * 60)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        triggerMonitor.onTrigger = { [weak self] in self?.toggle() }

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(frontmostAppChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        // objectWillChange fires before the new value lands, so hop to the next main-queue turn.
        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.apply()
                self?.updates.checkAutomatically()
            }
            .store(in: &cancellables)

        apply()

        updates.isBusy = { [weak self] in self?.isEnabled == true }
        updates.willRestart = { [weak self] in self?.shutDown() }
        updates.start()
    }

    // MARK: - State

    @objc private func toggle() {
        if isEnabled {
            setEnabled(false)
            hud.show("Mash Off")
            return
        }
        guard requestAccessibility() else {
            hud.show("Mash needs Accessibility access")
            return
        }
        setEnabled(true)
        hud.show("Mash On")
    }

    private func setEnabled(_ enabled: Bool) {
        enabledAt = enabled ? Date() : nil
        logger.info("Auto-pressing \(enabled ? "enabled" : "disabled", privacy: .public)")
        apply()
    }

    @objc private func frontmostAppChanged() {
        apply()
    }

    /// Brings the presser, trigger, auto-off timer and status icon in line with the current state.
    private func apply() {
        let targetIsFrontmost = settings.target.isFrontmost
        triggerMonitor.update(trigger: settings.trigger, active: targetIsFrontmost)

        if isEnabled && targetIsFrontmost {
            presser.start(
                keyCode: settings.pressedKeyCode, pressesPerSecond: settings.pressesPerSecond, in: settings.target
            )
        } else {
            presser.stop()
        }

        autoOffTimer?.invalidate()
        autoOffTimer = nil
        if let autoOffDate {
            let timer = Timer(fire: autoOffDate, interval: 0, repeats: false) { [weak self] _ in
                self?.setEnabled(false)
                self?.hud.show("Mash Off (timer)")
            }
            RunLoop.main.add(timer, forMode: .common)
            autoOffTimer = timer
        }

        let symbol = isEnabled ? "m.square.fill" : "m.square"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Mash")
        statusItem.button?.appearsDisabled = isEnabled && !targetIsFrontmost
    }

    /// Releases the pressed key and the shortcut before Mash restarts into an update.
    private func shutDown() {
        enabledAt = nil
        presser.stop()
        triggerMonitor.update(trigger: settings.trigger, active: false)
    }

    // MARK: - Accessibility

    private func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @objc private func openAccessibilitySettings() {
        _ = requestAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(disabledItem(statusText))
        menu.addItem(disabledItem("Shortcut in \(settings.target.name): \(settings.trigger.displayName)"))
        menu.addItem(.separator())

        menu.addItem(item(isEnabled ? "Turn Off" : "Turn On", action: #selector(toggle)))
        if !AXIsProcessTrusted() {
            menu.addItem(item("Grant Accessibility Access…", action: #selector(openAccessibilitySettings)))
        }
        menu.addItem(item("Settings…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        let update = item(updates.status ?? "Check for Updates…", action: #selector(checkForUpdates))
        update.isEnabled = updates.status == nil
        menu.addItem(update)
        menu.addItem(NSMenuItem(title: "Quit Mash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private var statusText: String {
        guard isEnabled else { return "Off" }
        var text = settings.target.isFrontmost ? "Pressing \(keyName(for: settings.pressedKeyCode))" : "On, paused until \(settings.target.name) is in front"
        if let autoOffDate {
            let minutes = max(1, Int((autoOffDate.timeIntervalSinceNow / 60).rounded(.up)))
            text += " · turns off in \(minutes) min"
        }
        return text
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func checkForUpdates() {
        updates.checkNow()
    }

    // MARK: - Settings window

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            window.title = "Mash Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
