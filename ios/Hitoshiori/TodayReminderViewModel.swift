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
    private(set) var errorMessage: String?
    private(set) var isCardVisible = true

    private let client: any TodayReminderFetching
    private let calendar: Calendar
    private let referenceDate: () -> Date
    private var cachedReminder: Reminder?
    private var isLoading = false

    // reminders/today はRails側でAsia/TokyoのDate.currentを基準に返す。
    private static let japanCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    init(
        client: any TodayReminderFetching = APIClient.development,
        calendar: Calendar = TodayReminderViewModel.japanCalendar,
        referenceDate: @escaping () -> Date = { .now }
    ) {
        self.client = client
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    var reminder: Reminder? {
        guard let cachedReminder, cachedReminder.remindOn == todayIdentifier else { return nil }
        return cachedReminder
    }

    func load() async {
        guard !isLoading else { return }

        if reminder != nil {
            isCardVisible = true
            return
        }

        cachedReminder = nil

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let fetchedReminder = try await client.fetchTodayReminder(),
                  fetchedReminder.remindOn == todayIdentifier else {
                return
            }

            cachedReminder = fetchedReminder
            isCardVisible = true
        } catch {
            guard !RequestFailure.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func dismissCard() {
        isCardVisible = false
    }

    func recordDidFinish(didSave: Bool, personID: Int?) {
        guard didSave, let personID, personID == reminder?.person.id else { return }
        dismissCard()
    }

    private var todayIdentifier: String {
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate())
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
