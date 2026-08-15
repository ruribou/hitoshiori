import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct TodayReminderViewModelTests {
    @Test("今日の一人を取得して表示対象にする")
    func loadsTodayReminder() async {
        let client = StubTodayReminderClient()
        client.results = [.success(reminder(personName: "たなか"))]
        let viewModel = TodayReminderViewModel(client: client)

        await viewModel.load()

        #expect(client.fetchCallCount == 1)
        #expect(viewModel.reminder?.person.name == "たなか")
    }

    @Test("対象がいない日は表示対象を空にする")
    func clearsReminderWhenTodayHasNoTarget() async {
        let client = StubTodayReminderClient()
        client.results = [.success(reminder(personName: "たなか")), .success(nil)]
        let viewModel = TodayReminderViewModel(client: client)

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.reminder == nil)
    }

    @Test("取得に失敗しても前回の今日の一人を維持する")
    func keepsReminderWhenLoadingFails() async {
        let client = StubTodayReminderClient()
        client.results = [.success(reminder(personName: "たなか")), .failure(StubError.unavailable)]
        let viewModel = TodayReminderViewModel(client: client)

        await viewModel.load()
        await viewModel.load()

        #expect(viewModel.reminder?.person.name == "たなか")
    }

    private func reminder(personName: String) -> Reminder {
        Reminder(
            id: 1,
            remindOn: "2026-08-15",
            person: ReminderPerson(
                id: 1,
                name: personName,
                note: "",
                lastEncounteredAt: nil,
                lastEncounter: nil
            )
        )
    }
}

@MainActor
private final class StubTodayReminderClient: TodayReminderFetching {
    var results: [Result<Reminder?, Error>] = [.success(nil)]
    private(set) var fetchCallCount = 0

    func fetchTodayReminder() async throws -> Reminder? {
        fetchCallCount += 1
        return try nextResult(from: &results)
    }
}
