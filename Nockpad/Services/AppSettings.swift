import Foundation
import Observation

@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults
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
        didSet { defaults.set(autoStartNext, forKey: "autoStartNext") }
    }
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }
    var tickingEnabled: Bool {
        didSet { defaults.set(tickingEnabled, forKey: "tickingEnabled") }
    }
    var ambientOnStop: Bool {
        didSet { defaults.set(ambientOnStop, forKey: "ambientOnStop") }
    }
    var bringForwardOnStop: Bool {
        didSet { defaults.set(bringForwardOnStop, forKey: "bringForwardOnStop") }
    }
    var notifyOnComplete: Bool {
        didSet { defaults.set(notifyOnComplete, forKey: "notifyOnComplete") }
    }

    init(defaults: UserDefaults = .standard, edition: NockpadEdition = .current) {
        self.defaults = defaults
        focusMinutes = Self.clampedMinutes(defaults.object(forKey: "focusMinutes") as? Int ?? 25)
        shortBreakMinutes = Self.clampedMinutes(defaults.object(forKey: "shortBreakMinutes") as? Int ?? 5)
        longBreakMinutes = Self.clampedMinutes(defaults.object(forKey: "longBreakMinutes") as? Int ?? 15)
        focusesUntilLongBreak = min(12, max(2, defaults.object(forKey: "focusesUntilLongBreak") as? Int ?? 4))
        autoStartNext = defaults.object(forKey: "autoStartNext") as? Bool ?? false
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? (edition != .quiet)
        tickingEnabled = defaults.object(forKey: "tickingEnabled") as? Bool ?? (edition != .quiet)
        ambientOnStop = defaults.object(forKey: "ambientOnStop") as? Bool ?? (edition != .quiet)
        bringForwardOnStop = defaults.object(forKey: "bringForwardOnStop") as? Bool ?? (edition != .quiet)
        notifyOnComplete = defaults.object(forKey: "notifyOnComplete") as? Bool ?? (edition != .quiet)
    }

    func seconds(for phase: TimerPhase) -> Int {
        switch phase {
        case .focus: focusMinutes * 60
        case .shortBreak: shortBreakMinutes * 60
        case .longBreak: longBreakMinutes * 60
        }
    }

    private func persist(_ key: String, _ value: Int) {
        defaults.set(value, forKey: key)
    }

    static func clampedMinutes(_ value: Int) -> Int {
        min(90, max(1, value))
    }
}
