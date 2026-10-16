import SwiftUI

enum FocusTheme {
    static let accent = Color(red: 0.57, green: 0.84, blue: 0.64)
    static let focusRing = accent
    static let shortBreak = Color(red: 0.28, green: 0.52, blue: 0.42)
    static let longBreak = Color(red: 0.32, green: 0.44, blue: 0.62)
    static let paper = Color(red: 0.055, green: 0.067, blue: 0.071)
    static let card = Color(red: 0.08, green: 0.095, blue: 0.10)
    static let hairline = Color(red: 0.23, green: 0.30, blue: 0.28)

    static let ink = Color(red: 0.82, green: 0.87, blue: 0.82)

    static let softSpring = Animation.spring(response: 0.38, dampingFraction: 0.86)

    static func ringColor(for phase: TimerPhase) -> Color {
        switch phase {
        case .focus: focusRing
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }

    static func columnTint(_ column: KanbanColumn) -> Color {
        switch column {
        case .backlog: Color(nsColor: .secondaryLabelColor).opacity(0.12)
        case .ready: Color(red: 0.85, green: 0.72, blue: 0.32).opacity(0.18)
        case .doing: focusRing.opacity(0.16)
        case .done: shortBreak.opacity(0.16)
        }
    }
}

struct TimerRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: progress)
        }
    }
}

struct TerminalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(configuration.isPressed ? FocusTheme.accent.opacity(0.18) : Color.clear)
            .overlay(Rectangle().stroke(FocusTheme.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
