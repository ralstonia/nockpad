import SwiftData
import SwiftUI

struct TimerView: View {
    var onEdit: (TaskItem) -> Void

    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortIndex) private var tasks: [TaskItem]
    @Query(sort: \SessionLog.endedAt, order: .reverse) private var sessions: [SessionLog]
    @State private var draft = ""
    @State private var listFilter: TaskListFilter = .open

    var body: some View {
        HSplitView {
            taskStore
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
            timerStage
                .frame(minWidth: 480)
        }
    }

    private var taskStore: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tasks")
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                HStack(spacing: 8) {
                    TextField("Add a task and press Return", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTask)
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(FocusTheme.accent)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Picker("Filter", selection: $listFilter) {
                    ForEach(TaskListFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(16)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredTasks, id: \.id) { task in
                        TaskRow(task: task, isActive: engine.activeTaskID == task.id)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 0, style: .continuous)
                                    .fill(engine.activeTaskID == task.id ? FocusTheme.accent.opacity(0.16) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { engine.bindTask(task.id) }
                            .contextMenu { taskMenu(task) }
                    }
                }
                .padding(10)
            }
        }
        .background(FocusTheme.card)
    }

    private var timerStage: some View {
        VStack(spacing: 28) {
            Picker("Phase", selection: Binding(
                get: { engine.phase },
                set: { engine.selectPhase($0) }
            )) {
                ForEach(TimerPhase.allCases) { phase in
                    Text(phase.title).tag(phase)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .disabled(engine.isRunning)

            VStack(alignment: .leading, spacing: 20) {
                Text("┌─ \(engine.phase.title.uppercased()) ─────────────────────┐")
                    .foregroundStyle(FocusTheme.ringColor(for: engine.phase))
                Text(engine.clockLabel)
                    .font(.system(size: 88, weight: .light, design: .monospaced))
                    .monospacedDigit()
                let filled = Int(engine.progress * 28)
                Text("[" + String(repeating: "━", count: filled) + String(repeating: "·", count: 28 - filled) + "]")
                    .foregroundStyle(FocusTheme.ringColor(for: engine.phase))
                    .accessibilityLabel("\(Int(engine.progress * 100)) percent remaining")
                Text("task > " + (activeTask?.title ?? "no task selected"))
                    .foregroundStyle(.secondary).lineLimit(2)
                Text("└────────────────────────────────┘").foregroundStyle(FocusTheme.hairline)
            }
            .padding(24)
            .background(FocusTheme.card)
            .overlay(Rectangle().stroke(FocusTheme.hairline))

            HStack(spacing: 12) {
                Button(engine.isRunning ? "Pause" : "Start") {
                    engine.toggle()
                }
                .keyboardShortcut(.space, modifiers: [.command])
                .buttonStyle(TerminalButtonStyle())
                .tint(FocusTheme.ringColor(for: engine.phase))
                .controlSize(.large)

                Button("Skip") { engine.skip() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .controlSize(.large)

                Button("Reset") { engine.reset() }
                    .controlSize(.large)
            }

            HStack(spacing: 20) {
                StatChip(title: "Today", value: "\(todayFocusCount)", symbol: "checkmark.circle")
                StatChip(title: "Streak", value: "\(engine.consecutiveFocusCount)", symbol: "flame")
                StatChip(
                    title: "Until long",
                    value: "\(remainingUntilLong)",
                    symbol: "leaf"
                )
            }

            if let active = activeTask {
                HStack(spacing: 8) {
                    PomodoroPips(completed: active.completedPomodoros, estimated: active.estimatedPomodoros)
                    Spacer()
                    Button("Edit") { onEdit(active) }
                    Button("Mark done") { markDone(active) }
                        .disabled(active.column == .done)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 420)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activeTask: TaskItem? {
        tasks.first(where: { $0.id == engine.activeTaskID })
    }

    private var filteredTasks: [TaskItem] {
        let base: [TaskItem]
        switch listFilter {
        case .open:
            base = tasks.filter { $0.column != .done }
        case .doing:
            base = tasks.filter { $0.column == .doing }
        case .done:
            base = tasks.filter { $0.column == .done }
        }
        return base.sorted { lhs, rhs in
            if lhs.column == rhs.column {
                return lhs.sortIndex < rhs.sortIndex
            }
            return columnRank(lhs.column) < columnRank(rhs.column)
        }
    }

    private var todayFocusCount: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return sessions.filter { $0.completed && $0.phase == .focus && $0.endedAt >= start }.count
    }

    private var remainingUntilLong: Int {
        let cycle = max(2, settings.focusesUntilLongBreak)
        let used = engine.consecutiveFocusCount % cycle
        return cycle - used
    }

    private func columnRank(_ column: KanbanColumn) -> Int {
        KanbanColumn.allCases.firstIndex(of: column) ?? 0
    }

    private func addTask() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let task = TaskItem(
            title: title,
            column: .backlog,
            sortIndex: TaskStore.nextSortIndex(in: .backlog, tasks: tasks)
        )
        modelContext.insert(task)
        engine.bindTask(task.id)
        draft = ""
        try? modelContext.save()
    }

    private func markDone(_ task: TaskItem) {
        TaskStore.move(task, to: .done, before: nil, among: tasks)
        try? modelContext.save()
    }

    @ViewBuilder
    private func taskMenu(_ task: TaskItem) -> some View {
        Button("Start focus") {
            engine.bindTask(task.id)
            if task.column != .doing {
                TaskStore.move(task, to: .doing, before: nil, among: tasks)
            }
            engine.selectPhase(.focus)
            engine.reset()
            engine.start()
        }
        Button("Edit") { onEdit(task) }
        Divider()
        ForEach(KanbanColumn.allCases) { column in
            Button("Move to \(column.title)") {
                TaskStore.move(task, to: column, before: nil, among: tasks)
                try? modelContext.save()
            }
        }
        Divider()
        Button("Delete", role: .destructive) {
            if engine.activeTaskID == task.id { engine.bindTask(nil) }
            modelContext.delete(task)
            try? modelContext.save()
        }
    }
}

private enum TaskListFilter: String, CaseIterable, Identifiable {
    case open, doing, done
    var id: String { rawValue }
    var title: String {
        switch self {
        case .open: "Open"
        case .doing: "Doing"
        case .done: "Done"
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2)
                Spacer()
                if isActive {
                    Image(systemName: "timer")
                        .foregroundStyle(FocusTheme.accent)
                }
            }
            HStack {
                Text(task.column.title)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(FocusTheme.columnTint(task.column), in: Capsule())
                PomodoroPips(completed: task.completedPomodoros, estimated: task.estimatedPomodoros)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PomodoroPips: View {
    var completed: Int
    var estimated: Int

    var body: some View {
        HStack(spacing: 3) {
            let count = max(estimated, completed, 1)
            ForEach(0..<min(count, 8), id: \.self) { index in
                Circle()
                    .fill(index < completed ? FocusTheme.accent : Color.secondary.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
            if count > 8 {
                Text("+\(count - 8)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("\(completed) of \(estimated) pomodoros")
    }
}

private struct StatChip: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(FocusTheme.accent)
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 88)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 0, style: .continuous))
    }
}
