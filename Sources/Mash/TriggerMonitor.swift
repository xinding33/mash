import AppKit
import Carbon.HIToolbox
import os

private let logger = Logger(subsystem: bundleID, category: "trigger")

/// Listens for the toggle trigger. Key triggers use a Carbon hot key; mouse triggers use an event tap,
/// which needs Accessibility access. Both swallow the trigger so the game never sees it.
@MainActor
final class TriggerMonitor {
    var onTrigger: (() -> Void)?

    private var installed: Trigger?
    private var hotKeyRef: EventHotKeyRef?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var mouseButton: Int64 = -1

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            Unmanaged<TriggerMonitor>.fromOpaque(userData).takeUnretainedValue().onTrigger?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    /// Installs `trigger` while `active`, and removes it otherwise. A failed install is retried on the next call.
    func update(trigger: Trigger, active: Bool) {
        let wanted = active ? trigger : nil
        guard wanted != installed else { return }

        uninstall()
        guard let wanted else { return }

        let succeeded: Bool
        switch wanted {
        case let .key(keyCode, modifiers):
            succeeded = installHotKey(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiers))
        case let .mouse(button):
            succeeded = installMouseTap(button: button)
        }
        if succeeded {
            installed = wanted
            logger.info("Installed trigger \(wanted.displayName, privacy: .public)")
        } else {
            logger.error("Failed to install trigger \(wanted.displayName, privacy: .public)")
        }
    }

    private func installHotKey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let id = EventHotKeyID(signature: OSType(0x4D41_5348) /* 'MASH' */, id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode), carbonModifiers(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        return status == noErr
    }

    private func installMouseTap(button: Int) -> Bool {
        let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue | 1 << CGEventType.otherMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<TriggerMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return monitor.handleMouseEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        mouseButton = Int64(button)
        eventTap = tap
        eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handleMouseEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.mouseEventButtonNumber) == mouseButton else {
            return Unmanaged.passUnretained(event)
        }
        if type == .otherMouseDown { onTrigger?() }
        return nil
    }

    private func uninstall() {
        installed = nil
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
            eventTapSource = nil
        }
    }
}
