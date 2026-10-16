import Foundation
import SwiftData
import CoreTransferable

enum KanbanColumn: String, CaseIterable, Identifiable, Codable {
    case backlog
    case ready
    case doing
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backlog: "Backlog"
        case .ready: "Ready"
        case .doing: "Doing"
        case .done: "Done"
        }
    }

    var systemImage: String {
        switch self {
        case .backlog: "tray"
        case .ready: "sparkle"
        case .doing: "bolt.fill"
        case .done: "checkmark.circle.fill"
        }
    }

    var help: String {
        switch self {
        case .backlog: "Captured, not yet committed"
        case .ready: "Next up — queued for a focus"
        case .doing: "Active work"
        case .done: "Shipped"
        }
    }
}

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var columnRaw: String
    var sortIndex: Int
    var estimatedPomodoros: Int
    var completedPomodoros: Int
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    var column: KanbanColumn {
        get { KanbanColumn(rawValue: columnRaw) ?? .backlog }
        set {
            columnRaw = newValue.rawValue
            updatedAt = .now
            if newValue == .done {
                if completedAt == nil { completedAt = .now }
            } else {
                completedAt = nil
            }
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        column: KanbanColumn = .backlog,
        sortIndex: Int = 0,
        estimatedPomodoros: Int = 1,
        completedPomodoros: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.columnRaw = column.rawValue
        self.sortIndex = sortIndex
        self.estimatedPomodoros = max(1, estimatedPomodoros)
        self.completedPomodoros = max(0, completedPomodoros)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

@Model
final class SessionLog {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var phaseRaw: String
    var completed: Bool
    var taskID: UUID?
    var taskTitleSnapshot: String

    var phase: TimerPhase {
        TimerPhase(rawValue: phaseRaw) ?? .focus
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date = .now,
        durationSeconds: Int,
        phase: TimerPhase,
        completed: Bool,
        taskID: UUID?,
        taskTitleSnapshot: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.phaseRaw = phase.rawValue
        self.completed = completed
        self.taskID = taskID
        self.taskTitleSnapshot = taskTitleSnapshot
    }
}

enum TimerPhase: String, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }

    var systemImage: String {
        switch self {
        case .focus: "brain.head.profile"
        case .shortBreak: "cup.and.saucer"
        case .longBreak: "figure.walk"
        }
    }
}

struct TaskDragPayload: Codable, Transferable, Hashable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

enum TaskStore {
    static func nextSortIndex(in column: KanbanColumn, tasks: [TaskItem]) -> Int {
        (tasks.filter { $0.column == column }.map(\.sortIndex).max() ?? -1) + 1
    }

    static func move(
        _ task: TaskItem,
        to column: KanbanColumn,
        before neighbor: TaskItem?,
        among all: [TaskItem]
    ) {
        var columnTasks = all
            .filter { $0.column == column || $0.id == task.id }
            .sorted { $0.sortIndex < $1.sortIndex }
        columnTasks.removeAll { $0.id == task.id }
        task.column = column
        task.updatedAt = .now
        if let neighbor, let idx = columnTasks.firstIndex(where: { $0.id == neighbor.id }) {
            columnTasks.insert(task, at: idx)
        } else {
            columnTasks.append(task)
        }
        for (index, item) in columnTasks.enumerated() {
            item.sortIndex = index
        }
    }

    static func seedIfEmpty(context: ModelContext, existing: [TaskItem]) {
        guard existing.isEmpty else { return }
        let samples: [(String, String, KanbanColumn, Int)] = [
            ("Draft the weekly note", "Outline first, then a first pass.", .doing, 3),
            ("Triage the inbox", "Move captured work onto the board.", .ready, 1),
            ("Read the research follow-up", "Capture questions before the next focus.", .backlog, 2),
            ("Ship Nockpad v1", "Timer, store, and kanban.", .done, 4),
        ]
        for (index, sample) in samples.enumerated() {
            let task = TaskItem(
                title: sample.0,
                notes: sample.1,
                column: sample.2,
                sortIndex: index,
                estimatedPomodoros: sample.3,
                completedPomodoros: sample.2 == .done ? sample.3 : (sample.2 == .doing ? 1 : 0),
                completedAt: sample.2 == .done ? .now : nil
            )
            context.insert(task)
        }
        try? context.save()
    }
}
