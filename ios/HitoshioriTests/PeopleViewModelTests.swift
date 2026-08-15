import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct PeopleViewModelTests {
    @Test("人物一覧をAPIの順序のまま表示する")
    func loadsPeople() async {
        let client = StubPeopleAPIClient()
        client.peopleResults = [.success([person(id: 2, name: "すずき"), person(id: 1, name: "たなか")])]
        let viewModel = PeopleListViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.people.map(\.id) == [2, 1])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("人物一覧の取得失敗時は既存の表示を保持して理由を表示する")
    func preservesPeopleWhenLoadingFails() async {
        let client = StubPeopleAPIClient()
        let viewModel = PeopleListViewModel(client: client)
        viewModel.people = [person(id: 1, name: "たなか")]
        client.peopleResults = [.failure(.unavailable)]

        await viewModel.load()

        #expect(viewModel.people.map(\.id) == [1])
        #expect(viewModel.errorMessage == "接続できませんでした")
    }

    @Test("人物詳細は指定したIDで取得する")
    func loadsPersonDetail() async {
        let client = StubPeopleAPIClient()
        client.personResults = [.success(personDetail(id: 4, name: "たなか"))]
        let viewModel = PersonDetailViewModel(client: client)

        await viewModel.load(id: 4)

        #expect(client.fetchedPersonIDs == [4])
        #expect(viewModel.person?.name == "たなか")
        #expect(viewModel.person?.encounters.map(\.id) == [2, 1])
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

    @Test("編集保存後に詳細を再取得する")
    func updatesPersonAndReloadsDetail() async {
        let client = StubPeopleAPIClient()
        client.personResults = [
            .success(personDetail(id: 1, name: "たなか")),
            .success(personDetail(id: 1, name: "田中太郎"))
        ]
        let viewModel = PersonDetailViewModel(client: client)
        await viewModel.load(id: 1)

        let didSave = await viewModel.save(id: 1, name: " 田中太郎 ", note: "○○大学")

        #expect(didSave)
        #expect(client.updateCalls == [UpdateCall(id: 1, name: "田中太郎", note: "○○大学")])
        #expect(client.fetchedPersonIDs == [1, 1])
        #expect(viewModel.person?.name == "田中太郎")
    }

    @Test("最後に会った日を相対表記にする")
    func describesLastEncounterDateRelatively() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let referenceDate = date("2026-08-15T12:00:00Z")

        #expect(
            EncounterDateText.relativeDescription(
                for: date("2026-08-12T23:00:00Z"),
                relativeTo: referenceDate,
                calendar: calendar
            ) == "3日前"
        )
        #expect(
            EncounterDateText.relativeDescription(for: nil, relativeTo: referenceDate, calendar: calendar)
                == "会った記録なし"
        )
    }

    private func person(id: Int, name: String) -> Person {
        Person(id: id, name: name, note: "", lastEncounteredAt: nil, encountersCount: 0)
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

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}

@MainActor
private final class StubPeopleAPIClient: PeopleAPIClient {
    enum StubError: Error, LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "接続できませんでした"
            }
        }
    }

    var peopleResults: [Result<[Person], StubError>] = [.success([])]
    var personResults: [Result<PersonDetail, StubError>] = [.failure(.unavailable)]
    var updateResults: [Result<UpdatedPerson, StubError>] = [.success(.fixture)]
    private(set) var fetchedPersonIDs: [Int] = []
    private(set) var updateCalls: [UpdateCall] = []

    func fetchPeople() async throws -> [Person] {
        try nextResult(from: &peopleResults, default: [])
    }

    func fetchPerson(id: Int) async throws -> PersonDetail {
        fetchedPersonIDs.append(id)
        return try nextResult(from: &personResults, default: .fixture)
    }

    func updatePerson(id: Int, name: String, note: String) async throws -> UpdatedPerson {
        updateCalls.append(UpdateCall(id: id, name: name, note: note))
        return try nextResult(from: &updateResults, default: .fixture)
    }

    private func nextResult<Value>(
        from results: inout [Result<Value, StubError>],
        default defaultValue: Value
    ) throws -> Value {
        guard !results.isEmpty else { return defaultValue }
        return try results.removeFirst().get()
    }
}

private struct UpdateCall: Equatable {
    let id: Int
    let name: String
    let note: String
}

private extension PersonDetail {
    static let fixture = PersonDetail(
        id: 1,
        name: "たなか",
        note: "",
        lastEncounteredAt: nil,
        encounters: []
    )
}

private extension UpdatedPerson {
    static let fixture = UpdatedPerson(id: 1, name: "たなか", note: "", lastEncounteredAt: nil)
}
