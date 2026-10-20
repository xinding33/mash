import AppKit
import Combine
import SwiftUI
import os
import MashCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let presser = AutoPresser()
    private let triggerMonitor = TriggerMonitor()
    private let hud = HUD()
    private let updates = Updates()

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
        // A second copy would fight the first over the trigger and the key presses.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != getpid() }
        if !others.isEmpty {
            others.first?.activate()
            Relaunch.terminate()
            return
        }

        installMainMenu()
        LoginItem.refresh()
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
            .sink { [weak self] in self?.apply() }
            .store(in: &cancellables)

        apply()
        updates.isBusy = { [weak self] in self?.isEnabled ?? false }
        updates.start()
        log.info("\(appName, privacy: .public) \(appVersion.description, privacy: .public) started")
    }

    /// Releases a key that's down, so quitting or relaunching mid-press doesn't leave it held in the game.
    func applicationWillTerminate(_ notification: Notification) {
        presser.stop()
    }

    /// Opening Mash again while it runs shows Settings, which is also where Open at Login and updates are.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
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
        log.info("Auto-pressing \(enabled ? "enabled" : "disabled", privacy: .public)")
        apply()
        if !enabled { updates.becameIdle() }
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
                MainActor.assumeIsolated {
                    self?.setEnabled(false)
                    self?.hud.show("Mash Off (timer)")
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            autoOffTimer = timer
        }

        let symbol = isEnabled ? "m.square.fill" : "m.square"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Mash")
        statusItem.button?.appearsDisabled = isEnabled && !targetIsFrontmost
    }

    // MARK: - Accessibility

    private func requestAccessibility() -> Bool {
        // The value of kAXTrustedCheckOptionPrompt, which Swift 6 won't read because it's a global var.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
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
        menu.addItem(item("Quit Mash", action: #selector(quit), key: "q"))
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
        // macOS 27 adds symbols to items like Quit. The setting is in the macOS 27 SDK (Swift 6.4),
        // and CI's Xcode may be older than this Mac's.
        #if compiler(>=6.4)
        if #available(macOS 27, *) { item.preferredImageVisibility = .hidden }
        #endif
        return item
    }

    @objc private func quit() { Relaunch.terminate() }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Settings window

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings, updates: updates)))
            window.title = "Mash Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Menu bar apps have no visible main menu, but the Settings window still needs one for ⌘C, ⌘V and ⌘W.
    private func installMainMenu() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }
}
