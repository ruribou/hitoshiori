import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct TodayReminderViewModelTests {
    @Test("今日の一人を取得して表示対象にする")
    func loadsTodayReminder() async {
        let client = StubTodayReminderClient()
        client.results = [.success(reminder(personName: "たなか"))]
        let viewModel = makeViewModel(client: client)

        await viewModel.load()

        #expect(client.fetchCallCount == 1)
        #expect(viewModel.reminder?.person.name == "たなか")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("対象がいないときは同じ日に再取得する")
    func retriesWhenNoReminderIsAvailable() async {
        let client = StubTodayReminderClient()
        client.results = [.success(nil), .success(reminder(personName: "たなか"))]
        let referenceDate = ReferenceDate(value: date("2026-08-15T00:00:00Z"))
        let viewModel = makeViewModel(client: client, referenceDate: referenceDate)

        await viewModel.load()
        await viewModel.load()

        #expect(client.fetchCallCount == 2)
        #expect(viewModel.reminder?.person.name == "たなか")
    }

    @Test("同じ日に複数回呼んでも今日の一人は1回だけ取得する")
    func loadsOnlyOncePerDay() async {
        let client = StubTodayReminderClient()
        client.results = [.success(reminder(personName: "たなか"))]
        let viewModel = makeViewModel(client: client)

        await viewModel.load()
        await viewModel.load()

        #expect(client.fetchCallCount == 1)
    }

    @Test("日付が変わると今日の一人を再取得する")
    func reloadsWhenDayChanges() async {
        let client = StubTodayReminderClient()
        client.results = [
            .success(reminder(personName: "たなか")),
            .success(reminder(personName: "すずき", remindOn: "2026-08-16"))
        ]
        let referenceDate = ReferenceDate(value: date("2026-08-15T00:00:00Z"))
        let viewModel = makeViewModel(client: client, referenceDate: referenceDate)

        await viewModel.load()
        referenceDate.value = date("2026-08-16T00:00:00Z")
        await viewModel.load()

        #expect(client.fetchCallCount == 2)
        #expect(viewModel.reminder?.person.name == "すずき")
    }

    @Test("日付が変わった取得失敗では前日の今日の一人を表示しない")
    func hidesPreviousDayReminderWhenLoadingFailsOnNewDay() async {
        let client = StubTodayReminderClient()
        client.results = [.success(reminder(personName: "たなか")), .failure(StubError.unavailable)]
        let referenceDate = ReferenceDate(value: date("2026-08-15T00:00:00Z"))
        let viewModel = makeViewModel(client: client, referenceDate: referenceDate)

        await viewModel.load()
        referenceDate.value = date("2026-08-16T00:00:00Z")
        await viewModel.load()

        #expect(viewModel.reminder == nil)
        #expect(viewModel.errorMessage == "接続できませんでした")
    }

    @Test("取得キャンセルは失敗として表示しない")
    func doesNotRecordErrorWhenLoadingIsCancelled() async {
        let client = StubTodayReminderClient()
        client.results = [.failure(CancellationError())]
        let viewModel = makeViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.errorMessage == nil)
    }

    @Test("取得中の追加要求は捨てて二重に通信しない")
    func ignoresLoadRequestWhileAlreadyLoading() async {
        let client = StubTodayReminderClient()
        client.delay = .milliseconds(20)
        client.results = [.success(reminder(personName: "たなか"))]
        let viewModel = makeViewModel(client: client)

        let firstLoad = Task { @MainActor in await viewModel.load() }
        await Task.yield()
        await viewModel.load()
        await firstLoad.value

        #expect(client.fetchCallCount == 1)
    }

    @Test("閉じた今日の一人は復帰時に再表示する")
    func restoresDismissedCardWhenLoadingCachedReminder() async {
        let client = StubTodayReminderClient()
        client.results = [.success(reminder(personName: "たなか"))]
        let viewModel = makeViewModel(client: client)

        await viewModel.load()
        viewModel.dismissCard()
        #expect(!viewModel.isCardVisible)

        await viewModel.load()

        #expect(viewModel.isCardVisible)
        #expect(client.fetchCallCount == 1)
    }

    @Test("人物を選択しただけでは今日の一人カードを閉じない")
    func keepsCardVisibleUntilReminderPersonIsSaved() async {
        let client = StubTodayReminderClient()
        client.results = [.success(reminder(personName: "たなか"))]
        let viewModel = makeViewModel(client: client)

        await viewModel.load()
        viewModel.recordDidFinish(didSave: false, personID: 1)
        #expect(viewModel.isCardVisible)

        viewModel.recordDidFinish(didSave: true, personID: 2)
        #expect(viewModel.isCardVisible)

        viewModel.recordDidFinish(didSave: true, personID: 1)
        #expect(!viewModel.isCardVisible)
    }

    @Test("JSTで日付が変わるとUTCでは同日のままでも再取得する")
    func reloadsWhenJapanDayChangesBeforeUTCDayChanges() async {
        let client = StubTodayReminderClient()
        client.results = [
            .success(reminder(personName: "たなか", remindOn: "2026-08-15")),
            .success(reminder(personName: "すずき", remindOn: "2026-08-16"))
        ]
        let referenceDate = ReferenceDate(value: date("2026-08-15T14:59:00Z"))
        let viewModel = TodayReminderViewModel(
            client: client,
            referenceDate: { referenceDate.value }
        )

        await viewModel.load()
        referenceDate.value = date("2026-08-15T15:01:00Z")
        await viewModel.load()

        #expect(client.fetchCallCount == 2)
        #expect(viewModel.reminder?.person.name == "すずき")
    }

    @Test("未接触の人物は人物一覧と同じ表記にする")
    func describesPersonWithoutEncounterConsistently() {
        #expect(EncounterDateText.relativeDescription(for: nil) == "会った記録なし")
    }

    @Test("想起取得の失敗を記録画面のエラー表示に合流できる")
    func combinesReminderErrorWithRecordErrors() {
        #expect(
            ErrorMessageText.combined(["記録を保存できませんでした", "接続できませんでした"])
                == "記録を保存できませんでした\n接続できませんでした"
        )
    }

    private func makeViewModel(
        client: StubTodayReminderClient,
        referenceDate: ReferenceDate? = nil
    ) -> TodayReminderViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let resolvedReferenceDate = referenceDate ?? ReferenceDate(value: date("2026-08-15T00:00:00Z"))
        return TodayReminderViewModel(
            client: client,
            calendar: calendar,
            referenceDate: { resolvedReferenceDate.value }
        )
    }

    private func reminder(personName: String, remindOn: String = "2026-08-15") -> Reminder {
        Reminder(
            id: 1,
            remindOn: remindOn,
            person: ReminderPerson(
                id: 1,
                name: personName,
                note: "",
                lastEncounteredAt: nil,
                lastEncounter: nil
            )
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

@MainActor
private final class ReferenceDate {
    var value: Date

    init(value: Date) {
        self.value = value
    }
}

@MainActor
private final class StubTodayReminderClient: TodayReminderFetching {
    var results: [Result<Reminder?, Error>] = [.success(nil)]
    var delay: Duration?
    private(set) var fetchCallCount = 0

    func fetchTodayReminder() async throws -> Reminder? {
        fetchCallCount += 1
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return try nextResult(from: &results)
    }
}
