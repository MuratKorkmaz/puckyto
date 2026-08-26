import Foundation
import UserNotifications

/// macOS notifications for agent events: reply finished, awaiting approval.
/// Rate-limited per session so long sessions do not flood you with notifications.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private var lastNotify: [String: Date] = [:]

    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// `kind` rate-limits the event types of one session separately (done / approval).
    @MainActor
    func notify(sessionID: UUID, kind: String, title: String, body: String, minInterval: TimeInterval) {
        guard AppStore.shared.notificationsEnabled else { return }
        let key = "\(sessionID.uuidString)-\(kind)"
        let now = Date()
        if let last = lastNotify[key], now.timeIntervalSince(last) < minInterval { return }
        lastNotify[key] = now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["sessionID": sessionID.uuidString]
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Focus the matching terminal when a notification is clicked
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let idString = info["sessionID"] as? String, let id = UUID(uuidString: idString) {
            Task { @MainActor in AppStore.shared.focusSession(id) }
        }
        completionHandler()
    }

    /// Show notifications even while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
