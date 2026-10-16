import AppKit
import SwiftData
import SwiftUI

struct MenuBarLabel: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        Text(engine.menuBarLabel)
            .monospacedDigit()
    }
}

struct MenuBarContent: View {
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \TaskItem.sortIndex) private var tasks: [TaskItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(engine.phase.title)
                .font(.headline)
            Text(engine.clockLabel)
                .font(.system(.title, design: .rounded).monospacedDigit())
            if let task = tasks.first(where: { $0.id == engine.activeTaskID }) {
                Text(task.title)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Divider()
            Button(engine.isRunning ? "Pause" : "Start") { engine.toggle() }
            Button("Skip phase") { engine.skip() }
            Button("Reset") { engine.reset() }
            Divider()
            if engine.ambientIsPlaying {
                Button("Mute ambient noise") { engine.stopAmbient() }
            }
            Button("Open Jotpad") {
                NSApp.activate(ignoringOtherApps: true)
                NockpadAppDelegate.showMainWindow()
                NotificationCenter.default.post(name: .nockpadJotpad, object: nil)
            }
            Button("Open Nockpad") {
                NSApp.activate(ignoringOtherApps: true)
                NockpadAppDelegate.showMainWindow()
            }
        }
        .padding(12)
        .frame(width: 220)
    }
}
