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
    static let authorizationRequestedKey = "hasRequestedDailyReminderNotificationAuthorization"

    private let center: any LocalNotificationCenter
    private let defaults: UserDefaults

    init(
        center: any LocalNotificationCenter = SystemLocalNotificationCenter(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    func configure() async {
        await requestAuthorizationIfNeeded()

        center.removePendingNotificationRequests(withIdentifiers: [DailyReminderNotification.identifier])
        try? await center.add(DailyReminderNotification.makeRequest())
    }

    private func requestAuthorizationIfNeeded() async {
        guard !defaults.bool(forKey: Self.authorizationRequestedKey) else { return }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            defaults.set(true, forKey: Self.authorizationRequestedKey)
        } catch {
            // 次回の起動時に再試行する。通知の失敗は記録・閲覧を妨げない。
        }
    }
}

enum DailyReminderNotification {
    static let identifier = "daily-reminder"

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
