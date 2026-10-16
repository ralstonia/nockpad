import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Durations") {
                Stepper("Focus: \(settings.focusMinutes) min", value: $settings.focusMinutes, in: 1...90)
                Stepper("Short break: \(settings.shortBreakMinutes) min", value: $settings.shortBreakMinutes, in: 1...30)
                Stepper("Long break: \(settings.longBreakMinutes) min", value: $settings.longBreakMinutes, in: 5...45)
                Stepper(
                    "Focuses until long break: \(settings.focusesUntilLongBreak)",
                    value: $settings.focusesUntilLongBreak,
                    in: 2...12
                )
            }
            Section("Behavior") {
                Toggle("Auto-start next phase", isOn: $settings.autoStartNext)
                Toggle("Quiet ticking during focus", isOn: $settings.tickingEnabled)
                Toggle("Ambient noise when focus stops", isOn: $settings.ambientOnStop)
                Toggle("Bring window forward when focus stops", isOn: $settings.bringForwardOnStop)
                Toggle("Play sound when a phase ends", isOn: $settings.soundEnabled)
                Toggle("Notification at phase end", isOn: $settings.notifyOnComplete)
            }
            Section("About") {
                LabeledContent("App", value: NockpadEdition.current.appName)
                LabeledContent("Edition", value: NockpadEdition.current.credit)
                Text(NockpadEdition.current.description)
                LabeledContent("Storage", value: "On this Mac, via SwiftData")
                Text("Tasks live on a local Kanban board. Start a focus from a card or the timer list; completed pomodoros stay attached to the task.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 500)
        .preferredColorScheme(.dark)
        .font(.system(.body, design: .monospaced))
        .tint(FocusTheme.accent)
        .onChange(of: settings.ambientOnStop) { _, _ in engine.refreshAudio() }
        .onChange(of: settings.tickingEnabled) { _, _ in engine.refreshAudio() }
        .onChange(of: settings.focusMinutes) { _, _ in engine.refreshIdleDuration() }
        .onChange(of: settings.shortBreakMinutes) { _, _ in engine.refreshIdleDuration() }
        .onChange(of: settings.longBreakMinutes) { _, _ in engine.refreshIdleDuration() }
    }
}
