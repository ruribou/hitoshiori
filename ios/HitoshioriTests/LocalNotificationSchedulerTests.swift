import Testing
import UserNotifications

@testable import Hitoshiori

@MainActor
struct LocalNotificationSchedulerTests {
    @Test("通知を拒否しても毎日20時の通知を登録する")
    func registersDailyNotificationAfterAuthorizationIsDenied() async throws {
        let center = StubLocalNotificationCenter()
        center.authorizationResults = [.success(false)]
        let scheduler = LocalNotificationScheduler(center: center)

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

    @Test("通知許可を毎起動時に確認し、通知を洗い替える")
    func requestsAuthorizationAndReplacesNotificationOnEveryLaunch() async {
        let center = StubLocalNotificationCenter()
        center.authorizationResults = [.success(true), .success(true)]
        let scheduler = LocalNotificationScheduler(center: center)

        await scheduler.configure()
        await scheduler.configure()

        #expect(center.authorizationOptions.count == 2)
        #expect(center.removedRequestIdentifiers == [
            [DailyReminderNotification.identifier],
            [DailyReminderNotification.identifier]
        ])
        #expect(center.addedRequests.count == 2)
        #expect(center.operations == [.authorization, .remove, .add, .authorization, .remove, .add])
    }

    @Test("フォアグラウンドでもバナーと音を提示する")
    func presentsForegroundNotificationWithBannerAndSound() {
        #expect(DailyReminderNotification.foregroundPresentationOptions == [.banner, .sound])
    }
}

@MainActor
private final class StubLocalNotificationCenter: LocalNotificationCenter {
    enum Operation: Equatable {
        case authorization
        case remove
        case add
    }

    var authorizationResults: [Result<Bool, Error>] = [.success(true)]
    private(set) var authorizationOptions: [UNAuthorizationOptions] = []
    private(set) var removedRequestIdentifiers: [[String]] = []
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var operations: [Operation] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        operations.append(.authorization)
        authorizationOptions.append(options)
        return try nextResult(from: &authorizationResults)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        operations.append(.remove)
        removedRequestIdentifiers.append(identifiers)
    }

    func add(_ request: UNNotificationRequest) async throws {
        operations.append(.add)
        addedRequests.append(request)
    }
}
