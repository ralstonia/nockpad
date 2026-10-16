import AppKit
import Foundation
import Observation

struct SessionCompletion: Equatable {
    let token: UUID
    let phase: TimerPhase
    let taskID: UUID?
    let durationSeconds: Int
    let completed: Bool
    let startedAt: Date
    let countsAsPomodoro: Bool
}

@Observable
@MainActor
final class TimerEngine {
    var phase: TimerPhase = .focus
    var remaining: TimeInterval = 25 * 60
    var isRunning = false
    var activeTaskID: UUID?
    var consecutiveFocusCount = 0
    var lastCompletion: SessionCompletion?
    var focusStopCount = 0
    private var plannedSessionSeconds: Int?
    private var pomodoroTargetSeconds = 25 * 60
    var totalSeconds: Int = 25 * 60

    private var endDate: Date?
    private var tickTask: Task<Void, Never>?
    private var sessionStartedAt: Date?
    private let settings: AppSettings
    private let tickSound = FocusTickSound.make()
    private let ambientSound = FocusTickSound.makeAmbient()
    var ambientIsPlaying = false
    private var ambientRequested = false
    private let onFocusStop: () -> Void
    private var nextSoundAt = Date.distantPast

    init(settings: AppSettings, onFocusStop: @escaping () -> Void = {}) {
        self.onFocusStop = onFocusStop
        self.settings = settings
        remaining = TimeInterval(settings.seconds(for: .focus))
        totalSeconds = settings.seconds(for: .focus)
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, remaining / Double(totalSeconds)))
    }

    var clockLabel: String {
        let seconds = max(0, Int(remaining.rounded(.down)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var menuBarLabel: String {
        let seconds = max(0, Int(remaining.rounded(.down)))
        let mark = isRunning ? (phase == .focus ? "●" : "○") : "■"
        return "\(mark) \(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    func toggle() {
        if isRunning { pause() } else { start() }
    }

    func start() {
        guard !isRunning else { return }
        if remaining <= 0 {
            remaining = TimeInterval(settings.seconds(for: phase))
            totalSeconds = settings.seconds(for: phase)
        }
        if sessionStartedAt == nil {
            sessionStartedAt = .now
            plannedSessionSeconds = totalSeconds
            pomodoroTargetSeconds = settings.seconds(for: .focus)
        }
        if phase == .focus { stopAmbient() }
        isRunning = true
        nextSoundAt = .now
        endDate = Date().addingTimeInterval(remaining)
        if settings.notifyOnComplete {
            NotificationService.schedulePhaseEnd(at: endDate ?? Date(), phase: phase)
        }
        startTicking()
    }

    func pause() {
        let stoppedFocus = isRunning && phase == .focus
        if isRunning, let endDate {
            remaining = max(0, endDate.timeIntervalSinceNow)
        }
        isRunning = false
        tickSound?.stop()
        endDate = nil
        tickTask?.cancel()
        tickTask = nil
        NotificationService.cancelPending()
        if stoppedFocus {
            focusStopCount += 1
            ambientRequested = true
            refreshAudio()
            if settings.bringForwardOnStop { onFocusStop() }
        }
    }

    func stopAmbient() {
        ambientRequested = false
        ambientSound?.stop()
        ambientIsPlaying = false
    }

    func refreshAudio() {
        if !settings.tickingEnabled { tickSound?.stop() }
        if ambientRequested && settings.ambientOnStop && !(isRunning && phase == .focus) {
            if !ambientIsPlaying { ambientIsPlaying = ambientSound?.play() ?? false }
        } else {
            ambientSound?.stop()
            ambientIsPlaying = false
        }
    }

    func beginFocus(minutes: Int) {
        guard !isRunning else { return }
        selectPhase(.focus)
        reset()
        totalSeconds = AppSettings.clampedMinutes(minutes) * 60
        remaining = TimeInterval(totalSeconds)
        start()
    }

    func reset() {
        pause()
        sessionStartedAt = nil
        plannedSessionSeconds = nil
        applyDuration(for: phase)
    }

    func skip() {
        finishCurrent(completed: false)
    }

    func selectPhase(_ newPhase: TimerPhase) {
        guard !isRunning else { return }
        phase = newPhase
        sessionStartedAt = nil
        plannedSessionSeconds = nil
        applyDuration(for: newPhase)
    }

    func refreshIdleDuration() {
        guard !isRunning else { return }
        applyDuration(for: phase)
    }

    func bindTask(_ id: UUID?) {
        activeTaskID = id
    }

    private func applyDuration(for phase: TimerPhase) {
        totalSeconds = settings.seconds(for: phase)
        remaining = TimeInterval(totalSeconds)
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                self?.tickFromEndDate()
            }
        }
    }

    private func tickFromEndDate() {
        guard isRunning, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            finishCurrent(completed: true)
            return
        }
        if phase == .focus, settings.tickingEnabled, Date() >= nextSoundAt {
            tickSound?.play()
            nextSoundAt = Date().addingTimeInterval(1)
        }
    }

    private func finishCurrent(completed: Bool) {
        let finishedPhase = phase
        let duration = plannedSessionSeconds ?? totalSeconds
        let started = sessionStartedAt ?? Date().addingTimeInterval(TimeInterval(-duration))
        let earnsPomodoro = completed && finishedPhase == .focus && duration >= pomodoroTargetSeconds
        pause()
        remaining = 0
        lastCompletion = SessionCompletion(
            token: UUID(),
            phase: finishedPhase,
            taskID: activeTaskID,
            durationSeconds: duration,
            completed: completed,
            startedAt: started,
            countsAsPomodoro: earnsPomodoro
        )
        sessionStartedAt = nil
        plannedSessionSeconds = nil

        if completed {
            if settings.soundEnabled {
                NotificationService.playCompletionSound()
            }
            if settings.notifyOnComplete {
                NotificationService.notifyNow(phase: finishedPhase)
            }
        }

        if earnsPomodoro {
            consecutiveFocusCount += 1
        }

        let next: TimerPhase
        if finishedPhase == .focus {
            let cycle = max(2, settings.focusesUntilLongBreak)
            next = earnsPomodoro && consecutiveFocusCount % cycle == 0 ? .longBreak : .shortBreak
        } else {
            next = .focus
        }
        phase = next
        applyDuration(for: next)

        if settings.autoStartNext {
            start()
        }
    }
}

/// A short, softly decaying wooden-clock click, generated locally without audio assets.
private enum FocusTickSound {
    static func make() -> NSSound? {
        let sampleRate = 44_100
        let sampleCount = 1_323 // 30 ms; silence between ticks keeps the sound unobtrusive.
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func uint16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func uint32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        text("RIFF"); uint32(UInt32(36 + sampleCount * 2)); text("WAVE")
        text("fmt "); uint32(16); uint16(1); uint16(1)
        uint32(UInt32(sampleRate)); uint32(UInt32(sampleRate * 2))
        uint16(2); uint16(16)
        text("data"); uint32(UInt32(sampleCount * 2))
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let attack = min(1, time / 0.001)
            let envelope = attack * exp(-time * 220)
            let tone = sin(2 * .pi * 1_100 * time) * 0.7
                + sin(2 * .pi * 1_750 * time) * 0.3
            let sample = Int16(tone * envelope * 8_000)
            uint16(UInt16(bitPattern: sample))
        }
        let sound = NSSound(data: data)
        sound?.volume = 0.18 * 1.42
        return sound
    }

    static func makeAmbient() -> NSSound? {
        // Filtered white noise: a softer, low-frequency wash, with a seamless loop.
        let count = 44_100 * 8
        var samples = [Int16]()
        samples.reserveCapacity(count)
        var filtered = 0.0
        for index in 0..<count {
            filtered = filtered * 0.96 + Double.random(in: -1...1) * 0.04
            let edge = min(1, Double(min(index, count - 1 - index)) / 441.0)
            samples.append(Int16(filtered * edge * 24_000))
        }
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8); append(UInt32(36 + count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1)); append(UInt32(44_100))
        append(UInt32(88_200)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8); append(UInt32(count * 2))
        for sample in samples { append(sample) }
        let sound = NSSound(data: data)
        sound?.loops = true
        sound?.volume = 0.3
        return sound
    }

}
