import AppKit
import Foundation
import UserNotifications

enum NotificationService {
    static func requestAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func cancelPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nockpad.phase.end"])
    }

    static func schedulePhaseEnd(at date: Date, phase: TimerPhase) {
        cancelPending()
        let content = UNMutableNotificationContent()
        content.title = phase == .focus ? "Focus complete" : "Break complete"
        content.body = phase == .focus ? "Time for a break." : "Ready for the next focus."
        content.sound = .default
        let seconds = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "nockpad.phase.end", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func notifyNow(phase: TimerPhase) {
        let content = UNMutableNotificationContent()
        content.title = phase == .focus ? "Focus complete" : "Break complete"
        content.body = phase == .focus ? "Time for a break." : "Ready for the next focus."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "nockpad.phase.now.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func playCompletionSound() {
        NSSound(named: "Glass")?.play()
    }
}
