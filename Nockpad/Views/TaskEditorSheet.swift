import SwiftData
import SwiftUI

struct TaskEditorSheet: View {
    @Bindable var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortIndex) private var tasks: [TaskItem]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $task.title)
                TextField("Notes", text: $task.notes, axis: .vertical)
                    .lineLimit(4...10)
                Picker("Column", selection: Binding(
                    get: { task.column },
                    set: { TaskStore.move(task, to: $0, before: nil, among: tasks) }
                )) {
                    ForEach(KanbanColumn.allCases) { column in
                        Text(column.title).tag(column)
                    }
                }
                Stepper("Estimated pomodoros: \(task.estimatedPomodoros)", value: $task.estimatedPomodoros, in: 1...20)
                Stepper("Completed pomodoros: \(task.completedPomodoros)", value: $task.completedPomodoros, in: 0...40)
            }
            .formStyle(.grouped)
            .navigationTitle("Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        task.updatedAt = .now
                        try? modelContext.save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) {
                        modelContext.delete(task)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 380)
    }
}

struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerEngine.self) private var engine
    @Query(sort: \TaskItem.sortIndex) private var tasks: [TaskItem]
    @State private var title = ""
    @State private var notes = ""
    @State private var column: KanbanColumn = .backlog
    @State private var estimate = 1

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
                Picker("Column", selection: $column) {
                    ForEach(KanbanColumn.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Stepper("Estimated pomodoros: \(estimate)", value: $estimate, in: 1...20)
            }
            .formStyle(.grouped)
            .navigationTitle("New Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let task = TaskItem(
            title: trimmed,
            notes: notes,
            column: column,
            sortIndex: TaskStore.nextSortIndex(in: column, tasks: tasks),
            estimatedPomodoros: estimate
        )
        modelContext.insert(task)
        engine.bindTask(task.id)
        try? modelContext.save()
        dismiss()
    }
}
