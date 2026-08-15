import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct RecordViewModelTests {
    @Test("名前または既存人物があれば保存できる")
    func canSaveWithNameOrSelectedPerson() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())

        #expect(!viewModel.canSave)

        viewModel.updateName("たなか")

        #expect(viewModel.canSave)
    }

    @Test("入力名で既存人物をかな種別を問わず部分一致検索する")
    func filtersExistingPeopleByNormalizedPartialName() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.people = [person(id: 1, name: "たなか")]

        for query in ["たなか", "タナカ", "ﾀﾅｶ"] {
            viewModel.updateName(query)

            #expect(viewModel.suggestions.map(\.id) == [1])
        }
    }

    @Test("既存人物を選んだ後の末尾空白は選択状態を維持してperson_idを送る")
    func keepsSelectedPersonForWhitespaceAndSavesExistingPerson() async {
        let client = StubRecordAPIClient()
        let viewModel = RecordViewModel(client: client)
        let selectedPerson = person(id: 1, name: "たなか")

        viewModel.select(person: selectedPerson)
        viewModel.updateName("たなか ")

        #expect(viewModel.selectedPerson?.id == 1)

        await viewModel.save()

        #expect(client.createCalls.last?.person == .existing(id: 1))
    }

    @Test("手入力した名前は空白を除去して新規人物として送る")
    func savesTrimmedNameAsNewPerson() async {
        let client = StubRecordAPIClient()
        let viewModel = RecordViewModel(client: client)
        viewModel.tags = [Tag(id: 1, name: "STECH")]
        viewModel.updateName(" たなか ")
        viewModel.topic = "勉強会"
        viewModel.memo = "次はRailsの話をする"
        viewModel.newTagName = "ハッカソン"
        viewModel.toggleTag(named: "STECH")

        await viewModel.save()

        #expect(client.createCalls.last?.person == .named("たなか"))
        #expect(client.createCalls.last?.tagNames == ["STECH", "ハッカソン"])
        #expect(viewModel.name.isEmpty)
        #expect(viewModel.topic.isEmpty)
        #expect(viewModel.memo.isEmpty)
        #expect(viewModel.newTagName.isEmpty)
        #expect(viewModel.selectedTagNames.isEmpty)
        #expect(viewModel.didSave)
    }

    @Test("取得失敗後に再読み込みすると人物候補を回復できる")
    func recoversPeopleWhenLoadingIsRetried() async {
        let client = StubRecordAPIClient()
        client.peopleResults = [.failure(.unavailable), .success([person(id: 1, name: "たなか")])]
        client.tagResults = [.success([]), .success([])]
        let viewModel = RecordViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.people.isEmpty)
        #expect(viewModel.errorMessage != nil)

        await viewModel.load()

        #expect(viewModel.people.map(\.id) == [1])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("HTTP 500のヘルスチェックは未接続として扱う")
    func treatsNonSuccessHealthStatusAsUnreachable() async {
        let client = StubRecordAPIClient()
        client.healthResults = [.success(500)]
        let viewModel = RecordViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.backendStatus == .unreachable)
        #expect(viewModel.errorMessage?.contains("HTTP 500") == true)
    }

    @Test("取得失敗は理由を表示する")
    func showsErrorWhenLoadingPeopleFails() async {
        let client = StubRecordAPIClient()
        client.peopleResults = [.failure(.unavailable)]
        let viewModel = RecordViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.errorMessage == "接続できませんでした")
    }

    @Test("保存に失敗しても入力内容を保持し、名前を直すとエラーを消す")
    func preservesInputAndClearsErrorWhenNameChanges() async {
        let client = StubRecordAPIClient()
        client.createEncounterResult = .failure(.unavailable)
        let viewModel = RecordViewModel(client: client)
        viewModel.updateName("たなか")
        viewModel.topic = "勉強会"
        viewModel.memo = "次はRailsの話をする"
        viewModel.newTagName = "STECH"

        await viewModel.save()

        #expect(viewModel.name == "たなか")
        #expect(viewModel.topic == "勉強会")
        #expect(viewModel.memo == "次はRailsの話をする")
        #expect(viewModel.newTagName == "STECH")
        #expect(viewModel.errorMessage == "接続できませんでした")

        viewModel.updateName("たなかさん")

        #expect(viewModel.errorMessage == nil)
    }

    @Test("タグを2回選ぶと選択を解除する")
    func deselectsTagWhenToggledTwice() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.tags = [Tag(id: 1, name: "STECH")]

        viewModel.toggleTag(named: "STECH")
        viewModel.toggleTag(named: "STECH")

        #expect(viewModel.tagNamesForSubmission.isEmpty)
    }

    @Test("音声文字起こしは既存メモの末尾へ逐次追記する")
    func appendsTranscriptionToExistingMemo() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.memo = "前に手入力したメモ"

        viewModel.beginMemoTranscription()
        viewModel.updateMemo(withTranscription: "こんにちは")

        #expect(viewModel.memo == "前に手入力したメモ\nこんにちは")

        viewModel.updateMemo(withTranscription: "こんにちは。次のイベントで会いましょう")

        #expect(viewModel.memo == "前に手入力したメモ\nこんにちは。次のイベントで会いましょう")
    }

    private func person(id: Int, name: String) -> Person {
        Person(id: id, name: name, note: "", lastEncounteredAt: nil, encountersCount: 0)
    }
}

@MainActor
private final class StubRecordAPIClient: RecordAPIClient {
    struct CreateEncounterCall: Equatable {
        let person: EncounterPersonTarget
        let metAt: Date?
        let topic: String?
        let memo: String?
        let tagNames: [String]
    }

    enum StubError: Error, LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "接続できませんでした"
            }
        }
    }

    var healthResults: [Result<Int, StubError>] = [.success(200)]
    var peopleResults: [Result<[Person], StubError>] = [.success([])]
    var tagResults: [Result<[Hitoshiori.Tag], StubError>] = [.success([])]
    var createEncounterResult: Result<Encounter, StubError> = .success(.fixture)
    private(set) var createCalls: [CreateEncounterCall] = []

    func health() async throws -> Int {
        try nextResult(from: &healthResults, default: 200)
    }

    func createEncounter(
        for person: EncounterPersonTarget,
        metAt: Date?,
        topic: String?,
        memo: String?,
        tagNames: [String]
    ) async throws -> Encounter {
        createCalls.append(
            CreateEncounterCall(
                person: person,
                metAt: metAt,
                topic: topic,
                memo: memo,
                tagNames: tagNames
            )
        )
        return try createEncounterResult.get()
    }

    func fetchPeople() async throws -> [Person] {
        try nextResult(from: &peopleResults, default: [])
    }

    func fetchTags() async throws -> [Hitoshiori.Tag] {
        try nextResult(from: &tagResults, default: [])
    }

    private func nextResult<Value>(
        from results: inout [Result<Value, StubError>],
        default defaultValue: Value
    ) throws -> Value {
        guard !results.isEmpty else { return defaultValue }
        return try results.removeFirst().get()
    }
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
