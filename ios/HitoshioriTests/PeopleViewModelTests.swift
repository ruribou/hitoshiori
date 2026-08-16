import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct PeopleViewModelTests {
    @Test("人物一覧をAPIの順序のまま表示する")
    func loadsPeople() async {
        let client = StubPeopleAPIClient()
        client.peopleResults = [.success([person(id: 2, name: "すずき"), person(id: 1, name: "たなか")])]
        let store = PeopleStore(client: client)

        #expect(!store.hasLoaded)

        await store.load()

        #expect(store.people.map(\.id) == [2, 1])
        #expect(store.errorMessage == nil)
        #expect(store.hasLoaded)
    }

    @Test("人物一覧の取得失敗時は既存の表示を保持して理由を表示する")
    func preservesPeopleWhenLoadingFails() async {
        let client = StubPeopleAPIClient()
        let store = PeopleStore(client: client)
        store.people = [person(id: 1, name: "たなか")]
        client.peopleResults = [.failure(StubError.unavailable)]

        await store.load()

        #expect(store.people.map(\.id) == [1])
        #expect(store.errorMessage == "接続できませんでした")
        #expect(store.hasLoaded)
    }

    @Test("人物一覧の取得キャンセルはエラー表示にしない")
    func preservesPeopleWhenLoadingIsCancelled() async {
        let client = StubPeopleAPIClient()
        let store = PeopleStore(client: client)
        store.people = [person(id: 1, name: "たなか")]
        client.peopleResults = [.failure(URLError(.cancelled))]

        await store.load()

        #expect(store.people.map(\.id) == [1])
        #expect(store.errorMessage == nil)
    }

    @Test("同時に人物一覧を読み込んでもAPI呼び出しは1回に抑える")
    func ignoresConcurrentPeopleLoads() async {
        let client = StubPeopleAPIClient()
        client.peopleResults = [.success([person(id: 1, name: "たなか")])]
        client.peopleDelay = .milliseconds(20)
        let store = PeopleStore(client: client)

        let firstLoad = Task { @MainActor in await store.load() }
        await Task.yield()
        await store.load()
        await firstLoad.value

        #expect(client.peopleFetchCallCount == 1)
        #expect(store.people.map(\.id) == [1])
    }

    @Test("人物詳細は指定したIDで取得する")
    func loadsPersonDetail() async {
        let client = StubPeopleAPIClient()
        client.personResults = [.success(personDetail(id: 4, name: "たなか"))]
        let viewModel = PersonDetailViewModel(client: client)

        #expect(!viewModel.hasLoaded)

        await viewModel.load(id: 4)

        #expect(client.fetchedPersonIDs == [4])
        #expect(viewModel.person?.name == "たなか")
        #expect(viewModel.person?.encounters.map(\.id) == [2, 1])
        #expect(viewModel.hasLoaded)
    }

    @Test("人物詳細の取得キャンセルはエラー表示にしない")
    func preservesDetailWhenLoadingIsCancelled() async {
        let client = StubPeopleAPIClient()
        let viewModel = PersonDetailViewModel(client: client)
        viewModel.person = personDetail(id: 1, name: "たなか")
        client.personResults = [.failure(URLError(.cancelled))]

        await viewModel.load(id: 1)

        #expect(viewModel.person?.name == "たなか")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("人物詳細の取得失敗後も読み込み済み状態になる")
    func marksDetailAsLoadedWhenLoadingFails() async {
        let client = StubPeopleAPIClient()
        let viewModel = PersonDetailViewModel(client: client)
        client.personResults = [.failure(StubError.unavailable)]

        await viewModel.load(id: 1)

        #expect(viewModel.hasLoaded)
        #expect(viewModel.errorMessage == "接続できませんでした")
    }

    @Test("同時に人物詳細を読み込んでもAPI呼び出しは1回に抑える")
    func ignoresConcurrentDetailLoads() async {
        let client = StubPeopleAPIClient()
        client.personResults = [.success(personDetail(id: 1, name: "たなか"))]
        client.personDelay = .milliseconds(20)
        let viewModel = PersonDetailViewModel(client: client)

        let firstLoad = Task { @MainActor in await viewModel.load(id: 1) }
        await Task.yield()
        await viewModel.load(id: 1)
        await firstLoad.value

        #expect(client.fetchedPersonIDs == [1])
        #expect(viewModel.person?.name == "たなか")
    }

    @Test("空の名前は通信せずに保存を拒否する")
    func rejectsBlankNameBeforeUpdating() async {
        let client = StubPeopleAPIClient()
        let viewModel = PersonDetailViewModel(client: client)

        let didSave = await viewModel.save(id: 1, name: " \n ", note: "メモ")

        #expect(!didSave)
        #expect(client.updateCalls.isEmpty)
        #expect(viewModel.errorMessage == "名前を入力してください")
    }

    @Test("編集保存後に詳細と共有ストアを更新して再取得する")
    func updatesPersonAndReloadsDetail() async {
        let client = StubPeopleAPIClient()
        let store = PeopleStore(client: client)
        store.people = [person(id: 1, name: "たなか")]
        client.personResults = [
            .success(personDetail(id: 1, name: "たなか")),
            .success(personDetail(id: 1, name: "田中太郎"))
        ]
        client.updateResults = [.success(updatedPerson(name: "田中太郎", note: "○○大学"))]
        let viewModel = PersonDetailViewModel(client: client, peopleStore: store)
        await viewModel.load(id: 1)

        let didSave = await viewModel.save(id: 1, name: " 田中太郎 ", note: "○○大学")

        #expect(didSave)
        #expect(client.updateCalls == [UpdateCall(id: 1, name: "田中太郎", note: "○○大学")])
        #expect(client.fetchedPersonIDs == [1, 1])
        #expect(viewModel.person?.name == "田中太郎")
        #expect(store.people.first?.name == "田中太郎")
    }

    @Test("保存後の詳細再取得に失敗してもPATCHの結果を表示する")
    func keepsUpdatedPersonWhenReloadFailsAfterSaving() async {
        let client = StubPeopleAPIClient()
        client.personResults = [
            .success(personDetail(id: 1, name: "たなか")),
            .failure(StubError.unavailable)
        ]
        client.updateResults = [.success(updatedPerson(name: "田中太郎", note: "○○大学"))]
        let viewModel = PersonDetailViewModel(client: client)
        await viewModel.load(id: 1)

        let didSave = await viewModel.save(id: 1, name: "田中太郎", note: "○○大学")

        #expect(didSave)
        #expect(viewModel.person?.name == "田中太郎")
        #expect(viewModel.errorMessage == "接続できませんでした")
    }

    @Test("保存失敗時は再取得せず編集状態を維持する")
    func keepsEditingWhenUpdatingFails() async {
        let client = StubPeopleAPIClient()
        client.personResults = [.success(personDetail(id: 1, name: "たなか"))]
        client.updateResults = [.failure(StubError.unavailable)]
        let viewModel = PersonDetailViewModel(client: client)
        await viewModel.load(id: 1)

        let didSave = await viewModel.save(id: 1, name: "田中太郎", note: "○○大学")

        #expect(!didSave)
        #expect(viewModel.errorMessage == "接続できませんでした")
        #expect(client.fetchedPersonIDs == [1])
    }

    @Test("保存の通信キャンセルはエラー表示にしない")
    func doesNotShowErrorWhenUpdatingIsCancelled() async {
        let client = StubPeopleAPIClient()
        client.updateResults = [.failure(URLError(.cancelled))]
        let viewModel = PersonDetailViewModel(client: client)

        let didSave = await viewModel.save(id: 1, name: "田中太郎", note: "○○大学")

        #expect(!didSave)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("編集をキャンセルすると編集時のエラーを消す")
    func clearsErrorWhenEditingIsCancelled() {
        let viewModel = PersonDetailViewModel(client: StubPeopleAPIClient())
        viewModel.errorMessage = "接続できませんでした"

        viewModel.cancelEditing()

        #expect(viewModel.errorMessage == nil)
    }

    @Test("人物名の修正は記録画面のサジェストにも反映される")
    func sharesUpdatedPeopleWithRecordSuggestions() async {
        let client = StubPeopleAPIClient()
        client.peopleResults = [.success([person(id: 1, name: "たなか")])]
        let store = PeopleStore(client: client)
        let recordViewModel = RecordViewModel(client: client, peopleStore: store)
        client.personResults = [
            .success(personDetail(id: 1, name: "たなか")),
            .success(personDetail(id: 1, name: "田中太郎"))
        ]
        client.updateResults = [.success(updatedPerson(name: "田中太郎", note: "メモ"))]
        let detailViewModel = PersonDetailViewModel(client: client, peopleStore: store)

        await store.load()
        await detailViewModel.load(id: 1)
        _ = await detailViewModel.save(id: 1, name: "田中太郎", note: "メモ")
        recordViewModel.updateName("田中")

        #expect(recordViewModel.suggestions.map(\.name) == ["田中太郎"])
    }

    @Test("最後に会った日を相対表記にする")
    func describesLastEncounterDateRelatively() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let referenceDate = date("2026-08-16T00:30:00Z")

        #expect(
            EncounterDateText.relativeDescription(
                for: date("2026-08-16T00:00:00Z"),
                relativeTo: referenceDate,
                calendar: calendar
            ) == "今日"
        )
        #expect(
            EncounterDateText.relativeDescription(
                for: date("2026-08-15T23:00:00Z"),
                relativeTo: referenceDate,
                calendar: calendar
            ) == "1日前"
        )
        #expect(
            EncounterDateText.relativeDescription(
                for: date("2026-08-13T23:00:00Z"),
                relativeTo: referenceDate,
                calendar: calendar
            ) == "3日前"
        )
        #expect(
            EncounterDateText.relativeDescription(for: nil, relativeTo: referenceDate, calendar: calendar)
                == "会った記録なし"
        )
    }

    private func personDetail(id: Int, name: String) -> PersonDetail {
        PersonDetail(
            id: id,
            name: name,
            note: "メモ",
            lastEncounteredAt: date("2026-08-14T10:00:00Z"),
            encounters: [
                EncounterHistory(
                    id: 2,
                    metAt: date("2026-08-14T10:00:00Z"),
                    topic: "勉強会",
                    memo: "次はRailsの話をする",
                    tags: [Tag(id: 1, name: "STECH")]
                ),
                EncounterHistory(
                    id: 1,
                    metAt: date("2026-08-10T10:00:00Z"),
                    topic: "ハッカソン",
                    memo: nil,
                    tags: []
                )
            ]
        )
    }

    private func updatedPerson(name: String, note: String) -> UpdatedPerson {
        UpdatedPerson(id: 1, name: name, note: note, lastEncounteredAt: date("2026-08-14T10:00:00Z"))
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

@MainActor
private final class StubPeopleAPIClient: PeopleAPIClient, RecordAPIClient {
    var peopleResults: [Result<[Person], Error>] = [.success([])]
    var personResults: [Result<PersonDetail, Error>] = [.failure(StubError.unavailable)]
    var updateResults: [Result<UpdatedPerson, Error>] = [.success(.fixture)]
    var peopleDelay: Duration?
    var personDelay: Duration?
    private(set) var peopleFetchCallCount = 0
    private(set) var fetchedPersonIDs: [Int] = []
    private(set) var updateCalls: [UpdateCall] = []

    func health() async throws -> Int { 200 }

    func createEncounter(
        for person: EncounterPersonTarget,
        metAt: Date?,
        topic: String?,
        memo: String?,
        tagNames: [String]
    ) async throws -> Encounter {
        .fixture
    }

    func deleteEncounter(id: Int, removeEmptyPerson: Bool) async throws {}

    func fetchPeople() async throws -> [Person] {
        peopleFetchCallCount += 1
        if let peopleDelay {
            try? await Task.sleep(for: peopleDelay)
        }
        return try nextResult(from: &peopleResults)
    }

    func fetchPerson(id: Int) async throws -> PersonDetail {
        fetchedPersonIDs.append(id)
        if let personDelay {
            try? await Task.sleep(for: personDelay)
        }
        return try nextResult(from: &personResults)
    }

    func updatePerson(id: Int, name: String, note: String) async throws -> UpdatedPerson {
        updateCalls.append(UpdateCall(id: id, name: name, note: note))
        return try nextResult(from: &updateResults)
    }

    func fetchTags() async throws -> [Hitoshiori.Tag] { [] }
}

private struct UpdateCall: Equatable {
    let id: Int
    let name: String
    let note: String
}

private extension Encounter {
    static let fixture = Encounter(
        id: 1,
        metAt: .now,
        topic: nil,
        memo: nil,
        tags: [],
        person: EncounterPerson(id: 1, name: "たなか", lastEncounteredAt: nil)
    )
}

private extension UpdatedPerson {
    static let fixture = UpdatedPerson(id: 1, name: "たなか", note: "", lastEncounteredAt: nil)
}
