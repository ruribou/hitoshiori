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
    private(set) var errorMessage: String?

    private let client: any TodayReminderFetching
    private let calendar: Calendar
    private let referenceDate: () -> Date
    private var loadedOn: Date?

    init(
        client: any TodayReminderFetching = APIClient.development,
        calendar: Calendar = .current,
        referenceDate: @escaping () -> Date = { .now }
    ) {
        self.client = client
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    func load(force: Bool = false) async {
        guard !isLoading else { return }

        let today = calendar.startOfDay(for: referenceDate())
        guard force || loadedOn != today else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            reminder = try await client.fetchTodayReminder()
            loadedOn = today
        } catch {
            guard !RequestFailure.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
