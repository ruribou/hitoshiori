import Foundation
import Observation

@MainActor
protocol TodayReminderFetching: Sendable {
    func fetchTodayReminder() async throws -> Reminder?
}

extension APIClient: TodayReminderFetching {}

@MainActor
@Observable
final class TodayReminderViewModel {
    private(set) var reminder: Reminder?
    private(set) var isLoading = false

    private let client: any TodayReminderFetching

    init(client: any TodayReminderFetching = APIClient.development) {
        self.client = client
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            reminder = try await client.fetchTodayReminder()
        } catch {
            // 想起カードを取得できなくても、記録フローは妨げない。
        }
    }
}
