import AppKit
import SwiftData
import SwiftUI

final class NockpadAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            Self.showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Self.showMainWindow()
        }
        return true
    }

    @MainActor
    static func showMainWindow() {
        if let window = NSApp.windows.first(where: { $0.title == "Nockpad" && $0.canBecomeMain }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct NockpadApp: App {
    @NSApplicationDelegateAdaptor(NockpadAppDelegate.self) private var appDelegate
    @State private var settings = AppSettings()
    @State private var engine: TimerEngine

    private let container: ModelContainer?
    private let storageError: String?

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _engine = State(initialValue: TimerEngine(settings: settings, onFocusStop: {
            NSApp.activate(ignoringOtherApps: true)
            NockpadAppDelegate.showMainWindow()
        }))

        let schema = Schema([TaskItem.self, SessionLog.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            storageError = nil
        } catch {
            container = nil
            storageError = error.localizedDescription
        }
    }

    var body: some Scene {
        Window("Nockpad", id: "main") {
            if let container {
                RootView()
                    .environment(engine)
                    .environment(settings)
                    .modelContainer(container)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Could not open saved tasks").font(.title2)
                    Text("Nockpad has stopped rather than use temporary storage. Your existing files have not been replaced. Quit and reopen the app; if this continues, keep a backup before troubleshooting.")
                    Text(storageError ?? "Unknown storage error").foregroundStyle(.secondary).textSelection(.enabled)
                    Button("Quit Nockpad") { NSApp.terminate(nil) }
                }
                .padding(32).frame(width: 560)
                .font(.system(.body, design: .monospaced))
                .preferredColorScheme(.dark)
            }
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .nockpadNewTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            CommandMenu("Workspace") {
                Button("Open Jotpad") {
                    NSApp.activate(ignoringOtherApps: true)
                    NockpadAppDelegate.showMainWindow()
                    NotificationCenter.default.post(name: .nockpadJotpad, object: nil)
                }
                .keyboardShortcut("j", modifiers: [.command, .shift])
            }
            CommandMenu("Timer") {
                Button(engine.isRunning ? "Pause" : "Start") { engine.toggle() }
                    .keyboardShortcut(.space, modifiers: [.command])
                Button("Skip Phase") { engine.skip() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Reset Phase") { engine.reset() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(engine)
                .environment(settings)
        }

        MenuBarExtra {
            if let container {
                MenuBarContent()
                    .environment(engine)
                    .modelContainer(container)
            } else {
                Text("Saved tasks could not be opened")
                Button("Open Nockpad") {
                    NSApp.activate(ignoringOtherApps: true)
                    NockpadAppDelegate.showMainWindow()
                }
            }
        } label: {
            MenuBarLabel()
                .environment(engine)
        }
    }
}

extension Notification.Name {
    static let nockpadJotpad = Notification.Name("nockpadJotpad")
    static let nockpadNewTask = Notification.Name("nockpadNewTask")
}
