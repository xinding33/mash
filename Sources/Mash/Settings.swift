import Carbon.HIToolbox
import Combine
import Foundation

final class Settings: ObservableObject {
    static let shared = Settings()

    static let pressesPerSecondRange = 1...20
    static let autoOffMinutesRange = 1...720

    private enum Key {
        static let target = "target"
        static let pressedKeyCode = "pressedKeyCode"
        static let trigger = "trigger"
        static let pressesPerSecond = "pressesPerSecond"
        static let autoOffEnabled = "autoOffEnabled"
        static let autoOffMinutes = "autoOffMinutes"
    }

    private let defaults = UserDefaults.standard

    @Published var target: TargetApp {
        didSet { defaults.set(try? JSONEncoder().encode(target), forKey: Key.target) }
    }

    /// Virtual key code of the key Mash presses.
    @Published var pressedKeyCode: UInt16 {
        didSet { defaults.set(Int(pressedKeyCode), forKey: Key.pressedKeyCode) }
    }

    @Published var trigger: Trigger {
        didSet { defaults.set(try? JSONEncoder().encode(trigger), forKey: Key.trigger) }
    }

    @Published var pressesPerSecond: Int {
        didSet {
            let clamped = Self.clamp(pressesPerSecond, to: Self.pressesPerSecondRange)
            if clamped != pressesPerSecond { pressesPerSecond = clamped }
            defaults.set(pressesPerSecond, forKey: Key.pressesPerSecond)
        }
    }

    @Published var autoOffEnabled: Bool {
        didSet { defaults.set(autoOffEnabled, forKey: Key.autoOffEnabled) }
    }

    @Published var autoOffMinutes: Int {
        didSet {
            let clamped = Self.clamp(autoOffMinutes, to: Self.autoOffMinutesRange)
            if clamped != autoOffMinutes { autoOffMinutes = clamped }
            defaults.set(autoOffMinutes, forKey: Key.autoOffMinutes)
        }
    }

    private init() {
        defaults.register(defaults: [
            Key.pressedKeyCode: kVK_ANSI_F,
            Key.pressesPerSecond: 8,
            Key.autoOffEnabled: true,
            Key.autoOffMinutes: 10,
        ])
        target = defaults.data(forKey: Key.target)
            .flatMap { try? JSONDecoder().decode(TargetApp.self, from: $0) } ?? .geforceNow
        pressedKeyCode = UInt16(exactly: defaults.integer(forKey: Key.pressedKeyCode)) ?? UInt16(kVK_ANSI_F)
        trigger = defaults.data(forKey: Key.trigger)
            .flatMap { try? JSONDecoder().decode(Trigger.self, from: $0) } ?? .default
        pressesPerSecond = Self.clamp(defaults.integer(forKey: Key.pressesPerSecond), to: Self.pressesPerSecondRange)
        autoOffEnabled = defaults.bool(forKey: Key.autoOffEnabled)
        autoOffMinutes = Self.clamp(defaults.integer(forKey: Key.autoOffMinutes), to: Self.autoOffMinutesRange)
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
