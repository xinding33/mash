import AppKit

/// Repeatedly presses a key, but only while the target app is frontmost.
@MainActor
final class AutoPresser {
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private var timer: DispatchSourceTimer?
    private var keyCode: CGKeyCode = 0
    private var pressesPerSecond = 0
    private var target: TargetApp?
    /// The key-up for a press still being held, and the work that posts it.
    private var pendingUp: (event: CGEvent, work: DispatchWorkItem)?

    func start(keyCode: CGKeyCode, pressesPerSecond: Int, in target: TargetApp) {
        let unchanged = keyCode == self.keyCode && pressesPerSecond == self.pressesPerSecond && target == self.target
        guard timer == nil || !unchanged else { return }
        stop()
        self.keyCode = keyCode
        self.pressesPerSecond = pressesPerSecond
        self.target = target

        let interval = 1.0 / Double(pressesPerSecond)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in self?.press(holdFor: min(0.04, interval / 2)) }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
        releaseKey()
    }

    /// Posts the pending key-up now rather than when it's due.
    private func releaseKey() {
        guard let pendingUp else { return }
        pendingUp.work.cancel()
        pendingUp.event.post(tap: .cghidEventTap)
        self.pendingUp = nil
    }

    private func press(holdFor holdDuration: TimeInterval) {
        // The app-activation notification can lag a tick behind the actual switch.
        guard target?.isFrontmost == true,
              let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
        else { return }

        // Clear flags so modifiers physically held for the toggle shortcut don't turn this into a combo.
        down.flags = []
        up.flags = []
        releaseKey()
        down.post(tap: .cghidEventTap)
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.releaseKey() } }
        pendingUp = (up, work)
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: work)
    }
}
