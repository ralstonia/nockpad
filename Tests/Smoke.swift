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
        let suite = "NockpadSmoke-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let quiet = AppSettings(defaults: defaults, edition: .quiet)
        precondition(!quiet.tickingEnabled && !quiet.ambientOnStop && !quiet.bringForwardOnStop && !quiet.notifyOnComplete && !quiet.soundEnabled)
        let settings = AppSettings(defaults: defaults, edition: .original)
        precondition(settings.tickingEnabled && settings.ambientOnStop && settings.bringForwardOnStop)
        precondition(Set(NockpadEdition.allCases.map(\.bundleID)).count == 5)
        print("PASS: Quiet's silent defaults, Original defaults, five distinct edition identities")
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
        settings.autoStartNext = false
        engine.consecutiveFocusCount = 4
        engine.beginFocus(minutes: 5)
        precondition(engine.totalSeconds == 300 && engine.isRunning)
        engine.pause()
        engine.remaining = 0.1
        engine.start()
        try await Task.sleep(for: .milliseconds(450))
        precondition(engine.lastCompletion?.durationSeconds == 300)
        precondition(engine.lastCompletion?.countsAsPomodoro == false)
        precondition(engine.phase == .shortBreak && engine.focusStopCount > 0)
        engine.stopAmbient()
        print("PASS: short-focus duration survives pause/resume and does not earn a full pomodoro")
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
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        reloaded.openDaily(day)
        let dailyID = reloaded.selectedID!
        reloaded.update(dailyID, body: "Keep my words")
        reloaded.openDaily(day)
        precondition(reloaded.selectedID == dailyID && reloaded.notes.count == 3)
        precondition(reloaded.notes.first(where: { $0.id == dailyID })?.body == "Keep my words")
        reloaded.appendTimestamp(day)
        let fieldnotesReload = JotStore(fileURL: url)
        precondition(fieldnotesReload.notes.first(where: { $0.id == dailyID })?.body.contains("Keep my words\n\n[") == true)
        let oldJSON = "[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"title\":\"old\",\"body\":\"kept\",\"updatedAt\":0}]"
        let oldNotes = try JSONDecoder().decode([JotNote].self, from: Data(oldJSON.utf8))
        precondition(oldNotes.first?.journalDay == nil)
        print("PASS: daily pages are idempotent, preserve content, append timestamps, and read older notes")
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let logs = [
            SessionLog(startedAt: now.addingTimeInterval(-300), endedAt: now, durationSeconds: 300, phase: .focus, completed: true, taskID: nil, taskTitleSnapshot: ""),
            SessionLog(startedAt: now.addingTimeInterval(-900), endedAt: now.addingTimeInterval(-300), durationSeconds: 600, phase: .focus, completed: true, taskID: nil, taskTitleSnapshot: ""),
            SessionLog(startedAt: now, endedAt: now, durationSeconds: 1500, phase: .focus, completed: false, taskID: nil, taskTitleSnapshot: ""),
            SessionLog(startedAt: now, endedAt: now, durationSeconds: 300, phase: .shortBreak, completed: true, taskID: nil, taskTitleSnapshot: ""),
            SessionLog(startedAt: now, endedAt: now.addingTimeInterval(60), durationSeconds: 300, phase: .focus, completed: true, taskID: nil, taskTitleSnapshot: ""),
            SessionLog(startedAt: now.addingTimeInterval(-86400), endedAt: now.addingTimeInterval(-86400), durationSeconds: 300, phase: .focus, completed: true, taskID: nil, taskTitleSnapshot: "")
        ]
        precondition(FocusDaySummary.calculate(logs, day: now, calendar: calendar, now: now) == FocusDaySummary(count: 2, seconds: 900))
        precondition(FocusDaySummary.calculate(logs, day: now.addingTimeInterval(-86400), calendar: calendar, now: now) == FocusDaySummary(count: 1, seconds: 300))
        print("PASS: Rhythm excludes skipped, break, future, and other-day sessions and sums actual planned focus durations")
    }
}
