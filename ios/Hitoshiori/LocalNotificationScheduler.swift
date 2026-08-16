import Foundation
import UserNotifications

@MainActor
protocol LocalNotificationCenter: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

@MainActor
final class SystemLocalNotificationCenter: LocalNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
}

@MainActor
final class LocalNotificationScheduler {
    private let center: any LocalNotificationCenter

    init(center: any LocalNotificationCenter = SystemLocalNotificationCenter()) {
        self.center = center
    }

    func configure() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])

        center.removePendingNotificationRequests(withIdentifiers: [DailyReminderNotification.identifier])
        try? await center.add(DailyReminderNotification.makeRequest())
    }
}

enum DailyReminderNotification {
    static let identifier = "daily-reminder"
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [.banner, .sound]

    static func makeRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "ひとしおり"
        content.body = "今日の一人を見てみましょう"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: 20, minute: 0),
            repeats: true
        )
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
