import Foundation
import Observation

@Observable
final class AppSettings {
    var focusMinutes: Int {
        didSet { persist("focusMinutes", focusMinutes) }
    }
    var shortBreakMinutes: Int {
        didSet { persist("shortBreakMinutes", shortBreakMinutes) }
    }
    var longBreakMinutes: Int {
        didSet { persist("longBreakMinutes", longBreakMinutes) }
    }
    var focusesUntilLongBreak: Int {
        didSet { persist("focusesUntilLongBreak", focusesUntilLongBreak) }
    }
    var autoStartNext: Bool {
        didSet { UserDefaults.standard.set(autoStartNext, forKey: "autoStartNext") }
    }
    var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }
    var tickingEnabled: Bool {
        didSet { UserDefaults.standard.set(tickingEnabled, forKey: "tickingEnabled") }
    }
    var ambientOnStop: Bool {
        didSet { UserDefaults.standard.set(ambientOnStop, forKey: "ambientOnStop") }
    }
    var bringForwardOnStop: Bool {
        didSet { UserDefaults.standard.set(bringForwardOnStop, forKey: "bringForwardOnStop") }
    }
    var notifyOnComplete: Bool {
        didSet { UserDefaults.standard.set(notifyOnComplete, forKey: "notifyOnComplete") }
    }

    init() {
        let defaults = UserDefaults.standard
        focusMinutes = Self.clampedMinutes(defaults.object(forKey: "focusMinutes") as? Int ?? 25)
        shortBreakMinutes = Self.clampedMinutes(defaults.object(forKey: "shortBreakMinutes") as? Int ?? 5)
        longBreakMinutes = Self.clampedMinutes(defaults.object(forKey: "longBreakMinutes") as? Int ?? 15)
        focusesUntilLongBreak = min(12, max(2, defaults.object(forKey: "focusesUntilLongBreak") as? Int ?? 4))
        autoStartNext = defaults.object(forKey: "autoStartNext") as? Bool ?? false
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        tickingEnabled = defaults.object(forKey: "tickingEnabled") as? Bool ?? true
        ambientOnStop = defaults.object(forKey: "ambientOnStop") as? Bool ?? true
        bringForwardOnStop = defaults.object(forKey: "bringForwardOnStop") as? Bool ?? true
        notifyOnComplete = defaults.object(forKey: "notifyOnComplete") as? Bool ?? true
    }

    func seconds(for phase: TimerPhase) -> Int {
        switch phase {
        case .focus: focusMinutes * 60
        case .shortBreak: shortBreakMinutes * 60
        case .longBreak: longBreakMinutes * 60
        }
    }

    private func persist(_ key: String, _ value: Int) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func clampedMinutes(_ value: Int) -> Int {
        min(90, max(1, value))
    }
}
