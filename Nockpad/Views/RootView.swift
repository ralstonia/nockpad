import SwiftData
import SwiftUI

enum AppPane: String, CaseIterable, Identifiable, Hashable {
    case timer
    case board
    case jotpad
    case rhythm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: "Timer"
        case .board: "Board"
        case .jotpad: "Jotpad"
        case .rhythm: "Rhythm"
        }
    }

    var systemImage: String {
        switch self {
        case .timer: "timer"
        case .board: "rectangle.split.3x1"
        case .jotpad: "note.text"
        case .rhythm: "chart.bar"
        }
    }
}

struct RootView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @State private var jotStore = JotStore()
    @State private var pane: AppPane = NockpadEdition.current == .fieldnotes ? .jotpad : (NockpadEdition.current == .rhythm ? .rhythm : .timer)
    @AppStorage("return.contextID") private var returnContextID = "unassigned"
    @AppStorage("return.context") private var returnContext = ""
    @AppStorage("return.stoppedAt") private var returnStoppedAt = 0.0

    private var panes: [AppPane] { NockpadEdition.current == .rhythm ? [.timer, .board, .jotpad, .rhythm] : [.timer, .board, .jotpad] }
    @State private var editorTask: TaskItem?
    @State private var isCreatingTask = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Text(">_ " + NockpadEdition.current.appName.uppercased()).fontWeight(.bold).foregroundStyle(FocusTheme.accent)
                ForEach(Array(panes.enumerated()), id: \.element.id) { index, item in
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
                case .timer:
                    if NockpadEdition.current == .quiet {
                        QuietStage()
                    } else {
                        VStack(spacing: 0) {
                            if NockpadEdition.current == .return { ReturnPad() }
                            TimerView(onEdit: { editorTask = $0 })
                        }
                    }
                case .board: KanbanBoardView(onEdit: { editorTask = $0 })
                case .jotpad: JotpadView(store: jotStore)
                case .rhythm: RhythmView()
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(FocusTheme.hairline).frame(height: 1)
            HStack {
                Text("\(engine.isRunning ? "● RUNNING" : "■ IDLE")  \(engine.phase.title.uppercased())  \(engine.clockLabel)")
                Spacer()
                if engine.ambientIsPlaying {
                    Button("[ ambient: on · mute ]") { engine.stopAmbient() }
                }
                Text(NockpadEdition.current.credit)
            }.font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                .padding(12).background(FocusTheme.card)
        }
        .font(.system(.body, design: .monospaced))
        .buttonStyle(TerminalButtonStyle())
        .tint(FocusTheme.accent)
        .foregroundStyle(FocusTheme.ink)
        .background(FocusTheme.paper)
        .preferredColorScheme(.dark)
        .frame(minWidth: 980, minHeight: NockpadEdition.current == .return ? 780 : 640)
        .onReceive(NotificationCenter.default.publisher(for: .nockpadJotpad)) { _ in pane = .jotpad }
        .onAppear {
            TaskStore.seedIfEmpty(context: modelContext, existing: tasks)
            NotificationService.requestAccess()
            engine.refreshIdleDuration()
        }
        .onChange(of: engine.activeTaskID) { _, _ in
            if NockpadEdition.current == .return {
                returnContextID = engine.activeTaskID?.uuidString ?? "unassigned"
                returnContext = tasks.first(where: { $0.id == engine.activeTaskID })?.title ?? "Unassigned focus"
                returnStoppedAt = 0
            }
        }
        .onChange(of: engine.focusStopCount) { _, _ in
            if NockpadEdition.current == .return {
                returnContextID = engine.activeTaskID?.uuidString ?? "unassigned"
                returnContext = tasks.first(where: { $0.id == engine.activeTaskID })?.title ?? "Unassigned focus"
                returnStoppedAt = Date().timeIntervalSince1970
                pane = .timer
            }
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

        if event.countsAsPomodoro, let taskID = event.taskID,
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
