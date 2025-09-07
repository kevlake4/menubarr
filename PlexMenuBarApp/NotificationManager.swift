import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error { print("🔔 Auth error:", error.localizedDescription) }
            print("🔔 Notifications granted:", granted)
            self.dumpSettings()
        }
    }

    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { err in
            if let err = err { print("🔔 Schedule error:", err.localizedDescription) }
        }
    }

    func sendTest() {
        send(title: "Test Notification", body: "If you see this, notifications are working ✅")
    }

    // Completion-handler variant avoids selector conflict across SDKs
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    private func dumpSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            print("🔔 Settings: auth=\(s.authorizationStatus.rawValue) alert=\(s.alertSetting.rawValue) sound=\(s.soundSetting.rawValue)")
        }
    }
}
