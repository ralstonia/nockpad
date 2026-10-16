import SwiftData
import SwiftUI

struct KanbanBoardView: View {
    var onEdit: (TaskItem) -> Void

    @Environment(TimerEngine.self) private var engine
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortIndex) private var tasks: [TaskItem]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(KanbanColumn.allCases) { column in
                    KanbanColumnView(
                        column: column,
                        tasks: tasks.filter { $0.column == column }.sorted { $0.sortIndex < $1.sortIndex },
                        onEdit: onEdit,
                        onDrop: { payload, neighbor in
                            drop(payload, onto: column, before: neighbor)
                        },
                        onAdd: { addTask(in: column) },
                        onStart: { startFocus($0) }
                    )
                    .frame(width: 260)
                }
            }
            .padding(20)
        }
        .background(FocusTheme.paper)
    }

    private func drop(_ payload: TaskDragPayload, onto column: KanbanColumn, before neighbor: TaskItem?) {
        guard let task = tasks.first(where: { $0.id == payload.id }) else { return }
        TaskStore.move(task, to: column, before: neighbor, among: tasks)
        if column == .doing, engine.activeTaskID == nil {
            engine.bindTask(task.id)
        }
        try? modelContext.save()
    }

    private func startFocus(_ task: TaskItem) {
        engine.bindTask(task.id)
        if task.column != .doing {
            TaskStore.move(task, to: .doing, before: nil, among: tasks)
            try? modelContext.save()
        }
        engine.selectPhase(.focus)
        if !engine.isRunning {
            engine.reset()
            engine.start()
        }
    }

    private func addTask(in column: KanbanColumn) {
        let task = TaskItem(
            title: "New task",
            column: column,
            sortIndex: TaskStore.nextSortIndex(in: column, tasks: tasks)
        )
        modelContext.insert(task)
        try? modelContext.save()
        onEdit(task)
    }
}

private struct KanbanColumnView: View {
    let column: KanbanColumn
    let tasks: [TaskItem]
    var onEdit: (TaskItem) -> Void
    var onDrop: (TaskDragPayload, TaskItem?) -> Void
    var onAdd: () -> Void
    var onStart: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(column.title, systemImage: column.systemImage)
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            Text(column.help)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(tasks) { task in
                        TaskCardView(task: task, onStart: { onStart(task) })
                            .draggable(TaskDragPayload(id: task.id))
                            .dropDestination(for: TaskDragPayload.self) { items, _ in
                                guard let payload = items.first else { return false }
                                onDrop(payload, task)
                                return true
                            }
                            .onTapGesture(count: 2) { onEdit(task) }
                            .contextMenu {
                                Button("Edit") { onEdit(task) }
                                Button("Start focus") { onStart(task) }
                            }
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
            }
            .frame(minHeight: 420)
            .dropDestination(for: TaskDragPayload.self) { items, _ in
                guard let payload = items.first else { return false }
                onDrop(payload, nil)
                return true
            }

            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(FocusTheme.columnTint(column), in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(FocusTheme.hairline, lineWidth: 1)
        )
    }
}

struct TaskCardView: View {
    let task: TaskItem
    var onStart: () -> Void
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            HStack {
                PomodoroPips(completed: task.completedPomodoros, estimated: task.estimatedPomodoros)
                Spacer()
                if engine.activeTaskID == task.id {
                    Image(systemName: "timer")
                        .foregroundStyle(FocusTheme.accent)
                }
                Button(action: onStart) {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.plain)
                .help("Start a focus on this task")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FocusTheme.card, in: RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay(Rectangle().stroke(FocusTheme.hairline))
    }
}
