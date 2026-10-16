import SwiftData
import SwiftUI

enum AppPane: String, CaseIterable, Identifiable, Hashable {
    case timer
    case board
    case jotpad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: "Timer"
        case .board: "Board"
        case .jotpad: "Jotpad"
        }
    }

    var systemImage: String {
        switch self {
        case .timer: "timer"
        case .board: "rectangle.split.3x1"
        case .jotpad: "note.text"
        }
    }
}

struct RootView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @State private var jotStore = JotStore()
    @State private var pane: AppPane = .timer
    @State private var editorTask: TaskItem?
    @State private var isCreatingTask = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Text(">_ NOCKPAD").fontWeight(.bold).foregroundStyle(FocusTheme.accent)
                ForEach(Array(AppPane.allCases.enumerated()), id: \.element.id) { index, item in
                    Button("[\(index + 1)] \(item.title.lowercased())") { pane = item }
                        .foregroundStyle(pane == item ? FocusTheme.accent : .secondary)
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
                Spacer()
                Button("[ + task ]") { isCreatingTask = true }
            }.padding(16).background(FocusTheme.card)
            Rectangle().fill(FocusTheme.hairline).frame(height: 1)
            Group {
                switch pane {
                case .timer: TimerView(onEdit: { editorTask = $0 })
                case .board: KanbanBoardView(onEdit: { editorTask = $0 })
                case .jotpad: JotpadView(store: jotStore)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(FocusTheme.hairline).frame(height: 1)
            HStack {
                Text("\(engine.isRunning ? "● RUNNING" : "■ IDLE")  \(engine.phase.title.uppercased())  \(engine.clockLabel)")
                Spacer()
                if engine.ambientIsPlaying {
                    Button("[ ambient: on · mute ]") { engine.stopAmbient() }
                }
                Text("⌘1 timer  ⌘2 board  ⌘3 jotpad")
            }.font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                .padding(12).background(FocusTheme.card)
        }
        .font(.system(.body, design: .monospaced))
        .buttonStyle(TerminalButtonStyle())
        .tint(FocusTheme.accent)
        .foregroundStyle(FocusTheme.ink)
        .background(FocusTheme.paper)
        .preferredColorScheme(.dark)
        .frame(minWidth: 980, minHeight: 640)
        .onReceive(NotificationCenter.default.publisher(for: .nockpadJotpad)) { _ in pane = .jotpad }
        .onAppear {
            TaskStore.seedIfEmpty(context: modelContext, existing: tasks)
            NotificationService.requestAccess()
            engine.refreshIdleDuration()
        }
        .onChange(of: engine.lastCompletion) { _, event in
            guard let event else { return }
            record(event)
        }
        .onChange(of: settings.focusMinutes) { _, _ in engine.refreshIdleDuration() }
        .onChange(of: settings.shortBreakMinutes) { _, _ in engine.refreshIdleDuration() }
        .onChange(of: settings.longBreakMinutes) { _, _ in engine.refreshIdleDuration() }
        .sheet(item: $editorTask) { task in
            TaskEditorSheet(task: task)
        }
        .sheet(isPresented: $isCreatingTask) {
            NewTaskSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .nockpadNewTask)) { _ in
            isCreatingTask = true
        }
    }

    private func record(_ event: SessionCompletion) {
        let title = tasks.first(where: { $0.id == event.taskID })?.title ?? ""
        let log = SessionLog(
            startedAt: event.startedAt,
            endedAt: .now,
            durationSeconds: event.durationSeconds,
            phase: event.phase,
            completed: event.completed,
            taskID: event.taskID,
            taskTitleSnapshot: title
        )
        modelContext.insert(log)

        if event.completed, event.phase == .focus, let taskID = event.taskID,
           let task = tasks.first(where: { $0.id == taskID }) {
            task.completedPomodoros += 1
            if task.column == .backlog || task.column == .ready {
                TaskStore.move(task, to: .doing, before: nil, among: tasks)
            }
            task.updatedAt = .now
        }
        try? modelContext.save()
    }
}
