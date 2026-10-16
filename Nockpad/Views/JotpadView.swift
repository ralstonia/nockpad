import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct JotNote: Codable, Identifiable {
    var id = UUID()
    var title = "Untitled"
    var body = ""
    var updatedAt = Date()
    var journalDay: String?
}

@Observable
@MainActor
final class JotStore {
    var notes: [JotNote] = []
    var selectedID: UUID?
    var error: String?
    var lastSaved: Date?
    private let fileURL: URL
    private var loadFailed = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nockpad/Jotpad.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                notes = try JSONDecoder().decode([JotNote].self, from: Data(contentsOf: self.fileURL))
            }
            selectedID = notes.first?.id
        } catch {
            loadFailed = true
            self.error = "Could not load jotpad. Existing file has been preserved: \(error.localizedDescription)"
        }
    }

    func add(title: String = "Untitled", body: String = "", journalDay: String? = nil) {
        guard !loadFailed else { return }
        let note = JotNote(title: title, body: body, journalDay: journalDay)
        notes.insert(note, at: 0)
        selectedID = note.id
        save()
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    func openDaily(_ date: Date = .now) {
        let key = Self.dayKey(date)
        if let note = notes.first(where: { $0.journalDay == key }) {
            selectedID = note.id
        } else {
            add(title: key, body: "## On my mind\n\n\n## Working notes\n\n\n## Next steps\n", journalDay: key)
        }
    }

    func appendTimestamp(_ date: Date = .now) {
        guard let id = selectedID, let note = notes.first(where: { $0.id == id }) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        update(id, body: note.body + "\n\n[" + formatter.string(from: date) + "] ")
    }

    func update(_ id: UUID, title: String? = nil, body: String? = nil) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        if let title { notes[index].title = title }
        if let body { notes[index].body = body }
        notes[index].updatedAt = .now
        save()
    }

    func save() {
        guard !loadFailed else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(notes).write(to: fileURL, options: .atomic)
            error = nil
            lastSaved = .now
        } catch {
            self.error = "Unsaved changes — \(error.localizedDescription)"
        }
    }
}

struct JotpadView: View {
    @Bindable var store: JotStore
    @State private var search = ""
    @State private var isExporting = false
    @State private var exportDocument = MarkdownNoteDocument(text: "")
    @State private var exportError: String?
    @FocusState private var editorFocused: Bool

    private var matches: [JotNote] {
        store.notes.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 14) {
                Text(NockpadEdition.current == .fieldnotes ? "~/fieldnotes" : "~/jotpad").foregroundStyle(FocusTheme.accent)
                if NockpadEdition.current == .fieldnotes {
                    Button("[ today's page ]") { store.openDaily(); search = ""; editorFocused = true }
                }
                TextField("/ search notes", text: $search)
                    .textFieldStyle(.plain)
                    .padding(8).border(FocusTheme.hairline)
                Button("[ + new note ]") { store.add(); editorFocused = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(matches) { note in
                            Button {
                                store.selectedID = note.id
                                editorFocused = true
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text((store.selectedID == note.id ? "> " : "  ") + (note.title.isEmpty ? "Untitled" : note.title))
                                        .lineLimit(1)
                                    Text(note.body.isEmpty ? "empty page" : note.body.replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary).lineLimit(2)
                                    Text(note.updatedAt, style: .date).font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                                }
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(store.selectedID == note.id ? FocusTheme.accent.opacity(0.1) : .clear)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Text("\(store.notes.count) notes · on this Mac")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            }
            .padding(18).frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
            .background(FocusTheme.card)

            VStack(alignment: .leading, spacing: 16) {
                if let note = store.notes.first(where: { $0.id == store.selectedID }) {
                    HStack {
                        Text("#").foregroundStyle(FocusTheme.accent)
                        TextField("Note title", text: Binding(
                            get: { store.notes.first(where: { $0.id == note.id })?.title ?? "" },
                            set: { store.update(note.id, title: $0) }
                        ))
                        .textFieldStyle(.plain).font(.system(size: 22, weight: .medium, design: .monospaced))
                        Button("[ copy ]") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(note.title + "\n\n" + note.body, forType: .string)
                        }
                    }
                    if NockpadEdition.current == .fieldnotes {
                        HStack {
                            Button("[ append timestamp ]") { store.appendTimestamp() }
                            Button("[ export Markdown ]") {
                                exportDocument = MarkdownNoteDocument(text: "# " + note.title + "\n\n" + note.body)
                                isExporting = true
                            }
                        }
                        if let exportError { Text(exportError).foregroundStyle(.orange) }
                    }
                    Rectangle().fill(FocusTheme.hairline).frame(height: 1)
                    TextEditor(text: Binding(
                        get: { store.notes.first(where: { $0.id == note.id })?.body ?? "" },
                        set: { store.update(note.id, body: $0) }
                    ))
                    .font(.system(size: 15, design: .monospaced))
                    .lineSpacing(6).scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    HStack {
                        Text("\(note.body.split(whereSeparator: { $0.isWhitespace }).count) words")
                        Spacer()
                        Text(store.error == nil ? "● saved locally" : "! unsaved")
                    }.font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                } else {
                    Spacer()
                    Text("A place for unfinished thoughts.").font(.system(size: 22, design: .monospaced))
                    Text("Scratch an idea, keep a log, or leave yourself a breadcrumb.")
                        .foregroundStyle(.secondary)
                    Button("[ create your first note ]") { store.add(); editorFocused = true }
                    Spacer()
                }
                if let error = store.error {
                    Text(error).foregroundStyle(.orange).textSelection(.enabled)
                    Button("Retry save") { store.save() }
                }
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .plainText, defaultFilename: "Nockpad-note.md") { result in
            switch result {
            case .success: exportError = nil
            case .failure(let error): exportError = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}

struct MarkdownNoteDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
