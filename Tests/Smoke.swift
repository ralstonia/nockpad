import AppKit
import Foundation

// Keep notifications out of the standalone check; timer and audio code are real.
enum NotificationService {
    static func schedulePhaseEnd(at: Date, phase: TimerPhase) {}
    static func cancelPending() {}
    static func playCompletionSound() {}
    static func notifyNow(phase: TimerPhase) {}
}

@main struct Smoke {
    @MainActor static func main() async throws {
        let settings = AppSettings()
        settings.autoStartNext = false
        settings.notifyOnComplete = false
        settings.soundEnabled = false
        settings.tickingEnabled = true
        settings.ambientOnStop = true
        settings.bringForwardOnStop = true
        var transitions = 0
        let engine = TimerEngine(settings: settings, onFocusStop: { transitions += 1 })
        engine.start()
        engine.pause()
        precondition(transitions == 1)
        precondition(engine.ambientIsPlaying, "Ambient sound should play on focus pause")
        engine.start()
        precondition(!engine.ambientIsPlaying, "Focus resumption must stop ambient audio")
        engine.pause()
        engine.stopAmbient()
        precondition(!engine.ambientIsPlaying)
        engine.start()
        engine.pause()
        settings.ambientOnStop = false
        engine.refreshAudio()
        precondition(!engine.ambientIsPlaying)
        settings.ambientOnStop = true
        engine.refreshAudio()
        precondition(engine.ambientIsPlaying)
        engine.stopAmbient()
        engine.remaining = 0.1
        engine.start()
        try await Task.sleep(for: .milliseconds(450))
        precondition(engine.phase == .shortBreak && !engine.isRunning)
        precondition(engine.lastCompletion?.completed == true && engine.ambientIsPlaying)
        engine.start()
        let beforeBreakPause = transitions
        engine.pause()
        precondition(transitions == beforeBreakPause, "Pausing a break must not signal focus stop")
        let remaining = engine.remaining
        try await Task.sleep(for: .milliseconds(300))
        precondition(engine.remaining == remaining)
        engine.stopAmbient()
        engine.skip()
        settings.autoStartNext = true
        engine.remaining = 0.1
        engine.start()
        try await Task.sleep(for: .milliseconds(450))
        precondition(engine.phase == .shortBreak && engine.isRunning && engine.ambientIsPlaying)
        engine.skip()
        precondition(engine.phase == .focus && engine.isRunning && !engine.ambientIsPlaying)
        engine.reset()
        engine.stopAmbient()
        precondition(!engine.isRunning && engine.remaining == Double(settings.seconds(for: .focus)))
        print("PASS: focus pause/resume, completion, break pause, auto-start, mute, live settings, reset")

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NockpadTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Jotpad.json")
        let store = JotStore(fileURL: url)
        store.add()
        let id = store.selectedID!
        store.update(id, title: "A thought", body: "First line\n日本語 — second line")
        let reloaded = JotStore(fileURL: url)
        precondition(reloaded.notes.count == 1)
        precondition(reloaded.notes[0].id == id && reloaded.notes[0].body == store.notes[0].body)
        reloaded.add()
        precondition(JotStore(fileURL: url).notes.count == 2)
        try Data("invalid JSON".utf8).write(to: url)
        let broken = JotStore(fileURL: url)
        precondition(broken.error != nil)
        broken.add()
        let preserved = try String(contentsOf: url, encoding: .utf8)
        precondition(preserved == "invalid JSON")
        let unwritable = JotStore(fileURL: url.appendingPathComponent("child.json"))
        unwritable.add()
        precondition(unwritable.error != nil)
        print("PASS: multiple notes, atomic save/reload, Unicode, corrupt-file protection, save failure reporting")
    }
}
