import AppKit
import UserNotifications
import os

nonisolated private let logger = Logger(subsystem: "com.nazarkryp.MacTweaks", category: "Errors")

/// Shows an error to the user: as a notification when allowed, else as an alert.
enum ErrorReporter {
    static func report(_ error: Error, context: String) {
        logger.error("\(context, privacy: .public): \(error.localizedDescription, privacy: .public)")
        Task {
            if await notify(title: context, body: error.localizedDescription) { return }
            showAlert(title: context, body: error.localizedDescription)
        }
    }

    private static func notify(title: String, body: String) async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert]) else { return false }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            return true
        } catch {
            logger.error("Cannot show a notification: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private static func showAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = body
        NSApp.activate()
        alert.runModal()
    }
}
