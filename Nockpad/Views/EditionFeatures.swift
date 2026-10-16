import Foundation
import SwiftData
import SwiftUI

/// Editions are independent choices, not upgrades that replace the Original.
enum NockpadEdition: String, CaseIterable {
    case original, `return`, quiet, fieldnotes, rhythm

    static var current: Self {
        Self(rawValue: Bundle.main.object(forInfoDictionaryKey: "NockpadEdition") as? String ?? "") ?? .original
    }

    var title: String {
        switch self {
        case .original: "Original"
        case .return: "Return"
        case .quiet: "Quiet"
        case .fieldnotes: "Fieldnotes"
        case .rhythm: "Rhythm"
        }
    }

    var appName: String { self == .original ? "Nockpad" : "Nockpad \(title)" }
    var credit: String { self == .original ? "Original by Ram" : "\(title) · designed by Codex" }
    var description: String {
        switch self {
        case .original: "The balanced timer, board, and jotpad that started it all."
        case .return: "Leave a next step. Return with less friction."
        case .quiet: "One intention. A little room to work."
        case .fieldnotes: "A notebook for the work between the timers."
        case .rhythm: "Notice your working patterns without scoring your worth."
        }
    }
    var bundleID: String { "app.nockpad.mac" + (self == .original ? "" : ".\(rawValue)") }
}

struct ReturnPad: View {
    @Environment(TimerEngine.self) private var engine
    @AppStorage("return.contextID") private var contextID = "unassigned"
    @AppStorage("return.context") private var context = ""
    @AppStorage("return.stoppedAt") private var stoppedAt = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("~/return · leave a breadcrumb").foregroundStyle(FocusTheme.accent)
                Spacer()
                if stoppedAt > 0 {
                    Text(Date(timeIntervalSince1970: stoppedAt), style: .relative).foregroundStyle(.secondary)
                }
            }
            if !context.isEmpty { Text("You were working on: \(context)").lineLimit(2) }
            BreadcrumbEditor(contextID: contextID).id(contextID)
            HStack {
                Text("A sentence is enough. No form to complete.").foregroundStyle(.secondary)
                Spacer()
                Button("[ begin a 5-minute focus ]") { engine.beginFocus(minutes: 5) }
                    .disabled(engine.isRunning)
            }
        }.font(.system(.callout, design: .monospaced)).padding(16).background(FocusTheme.card)
    }
}

private struct BreadcrumbEditor: View {
    @AppStorage private var text: String
    init(contextID: String) {
        _text = AppStorage(wrappedValue: "", "return.breadcrumb.\(contextID)")
    }
    var body: some View {
        TextField("Next concrete step — optional, saved as you type", text: $text, axis: .vertical)
            .textFieldStyle(.plain).lineLimit(1...3).padding(10).border(FocusTheme.hairline)
    }
}

struct QuietStage: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @AppStorage("quiet.intention") private var intention = ""
    @AppStorage("quiet.showClock") private var showClock = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            Text("ONE THING").tracking(3).foregroundStyle(FocusTheme.accent)
            TextField("What deserves your attention?", text: $intention, axis: .vertical)
                .font(.system(size: 30, weight: .light, design: .monospaced))
                .textFieldStyle(.plain).lineLimit(1...4)
            Text(engine.isRunning ? "\(engine.phase.title.lowercased()) is underway. You can stay here." : "Start when you are ready.")
                .foregroundStyle(.secondary)
            if showClock {
                Text(engine.clockLabel).font(.system(size: 48, weight: .light, design: .monospaced)).monospacedDigit()
            }
            HStack(spacing: 16) {
                Button(engine.isRunning ? "[ pause ]" : "[ start ]") { engine.toggle() }
                Button("[ reset ]") { engine.reset() }
                Button(showClock ? "[ hide time ]" : "[ show time ]") { showClock.toggle() }
            }
            HStack {
                Text("focus length").foregroundStyle(.secondary)
                ForEach([15, 25, 45], id: \.self) { minutes in
                    Button("[ \(minutes)m ]") {
                        settings.focusMinutes = minutes
                        engine.selectPhase(.focus)
                        engine.reset()
                    }.disabled(engine.isRunning)
                }
            }
            Text("Silent defaults. No foreground jumps. Board and notes are still a tab away.")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
        }.padding(60).frame(maxWidth: 850, maxHeight: .infinity)
    }
}

struct FocusDaySummary: Equatable {
    let count: Int
    let seconds: Int

    static func calculate(_ sessions: [SessionLog], day: Date, calendar: Calendar = .current, now: Date = .now) -> Self {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return Self(count: 0, seconds: 0) }
        let completed = sessions.filter {
            $0.phase == .focus && $0.completed && $0.endedAt >= interval.start && $0.endedAt < interval.end && $0.endedAt <= now
        }
        return Self(count: completed.count, seconds: completed.reduce(0) { $0 + max(0, $1.durationSeconds) })
    }
}

struct RhythmView: View {
    @Query(sort: \SessionLog.endedAt, order: .reverse) private var sessions: [SessionLog]
    @Environment(TimerEngine.self) private var engine
    @AppStorage("rhythm.dailyGoal") private var dailyGoal = 4

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let today = FocusDaySummary.calculate(sessions, day: timeline.date, now: timeline.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("~/rhythm").font(.system(size: 28, design: .monospaced)).foregroundStyle(FocusTheme.accent)
                    Text("A record of work, not a verdict on your day.").foregroundStyle(.secondary)
                    HStack(spacing: 36) {
                        metric("completed focuses", value: "\(today.count)")
                        metric("focus minutes", value: "\(today.seconds / 60)")
                        metric("your daily target", value: "\(dailyGoal)")
                    }
                    Stepper("Daily target: \(dailyGoal) sessions", value: $dailyGoal, in: 1...16)
                    Text(today.count >= dailyGoal ? "Your target is met. Rest is a valid next step." : "\(max(0, dailyGoal - today.count)) sessions to your chosen target. Adjust it whenever you need.")
                        .foregroundStyle(.secondary)
                    Button("[ begin a 10-minute focus ]") { engine.beginFocus(minutes: 10) }.disabled(engine.isRunning)
                    Divider()
                    Text("LAST SEVEN DAYS").foregroundStyle(FocusTheme.accent)
                    ForEach((0..<7).reversed(), id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .day, value: -offset, to: timeline.date) ?? timeline.date
                        let summary = FocusDaySummary.calculate(sessions, day: date, now: timeline.date)
                        HStack {
                            Text(date, format: .dateTime.weekday(.abbreviated).month().day()).frame(width: 140, alignment: .leading)
                            Text(String(repeating: "━", count: min(summary.count, 30))).foregroundStyle(FocusTheme.accent)
                            Spacer()
                            Text("\(summary.count) · \(summary.seconds / 60)m")
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("Only completed focus sessions count; breaks and skipped sessions are excluded. Days use your local timezone.")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    Divider()
                    DailyReflection(dayKey: JotStore.dayKey(timeline.date)).id(JotStore.dayKey(timeline.date))
                    Text("RECENT SESSIONS").foregroundStyle(FocusTheme.accent)
                    ForEach(Array(sessions.prefix(12))) { session in
                        HStack {
                            Text(session.endedAt, format: .dateTime.hour().minute())
                            Text(session.phase.title)
                            Text(session.completed ? "completed" : "skipped").foregroundStyle(.secondary)
                            Spacer()
                            Text(session.taskTitleSnapshot.isEmpty ? "unassigned" : session.taskTitleSnapshot).lineLimit(1)
                        }.font(.system(.caption, design: .monospaced))
                    }
                }.padding(36).frame(maxWidth: 960, alignment: .leading)
            }
        }
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 38, weight: .light, design: .monospaced))
            Text(label).foregroundStyle(.secondary)
        }
    }
}

private struct DailyReflection: View {
    @AppStorage private var text: String
    init(dayKey: String) { _text = AppStorage(wrappedValue: "", "rhythm.reflection.\(dayKey)") }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHAT HELPED? WHAT GOT IN THE WAY?").foregroundStyle(FocusTheme.accent)
            TextField("An optional reflection. Saved locally as you type.", text: $text, axis: .vertical)
                .lineLimit(3...8).textFieldStyle(.plain).padding(12).border(FocusTheme.hairline)
        }
    }
}
