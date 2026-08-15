import Foundation
import Testing
import UserNotifications

@testable import Hitoshiori

@MainActor
struct LocalNotificationSchedulerTests {
    @Test("通知を拒否しても毎日20時の通知を登録する")
    func registersDailyNotificationAfterAuthorizationIsDenied() async throws {
        let center = StubLocalNotificationCenter()
        center.authorizationResults = [.success(false)]
        let defaults = makeDefaults()
        let scheduler = LocalNotificationScheduler(center: center, defaults: defaults)

        await scheduler.configure()

        #expect(center.authorizationOptions == [[.alert, .sound]])
        #expect(center.removedRequestIdentifiers == [[DailyReminderNotification.identifier]])
        #expect(center.addedRequests.count == 1)

        let request = try #require(center.addedRequests.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(request.identifier == DailyReminderNotification.identifier)
        #expect(request.content.title == "ひとしおり")
        #expect(request.content.body == "今日の一人を見てみましょう")
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 20)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test("通知権限は初回だけ尋ね、通知は起動ごとに洗い替える")
    func requestsAuthorizationOnceAndReplacesNotificationOnEveryLaunch() async {
        let center = StubLocalNotificationCenter()
        let defaults = makeDefaults()
        let scheduler = LocalNotificationScheduler(center: center, defaults: defaults)

        await scheduler.configure()
        await scheduler.configure()

        #expect(center.authorizationOptions.count == 1)
        #expect(center.removedRequestIdentifiers == [
            [DailyReminderNotification.identifier],
            [DailyReminderNotification.identifier]
        ])
        #expect(center.addedRequests.count == 2)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LocalNotificationSchedulerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private final class StubLocalNotificationCenter: LocalNotificationCenter {
    var authorizationResults: [Result<Bool, Error>] = [.success(true)]
    private(set) var authorizationOptions: [UNAuthorizationOptions] = []
    private(set) var removedRequestIdentifiers: [[String]] = []
    private(set) var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationOptions.append(options)
        return try nextResult(from: &authorizationResults)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedRequestIdentifiers.append(identifiers)
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
}
