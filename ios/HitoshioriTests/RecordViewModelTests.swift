import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct RecordViewModelTests {
    @Test
    func 名前または既存人物があれば保存できる() {
        let viewModel = RecordViewModel()

        #expect(!viewModel.canSave)

        viewModel.updateName("たなか")

        #expect(viewModel.canSave)
    }

    @Test
    func 入力名で既存人物を部分一致検索する() {
        let viewModel = RecordViewModel()
        viewModel.people = [
            Person(id: 1, name: "田中太郎", note: "", lastEncounteredAt: nil, encountersCount: 0),
            Person(id: 2, name: "佐藤花子", note: "", lastEncounteredAt: nil, encountersCount: 0)
        ]

        viewModel.updateName("田中")

        #expect(viewModel.suggestions.map(\.id) == [1])
    }

    @Test
    func 既存人物を選んだ後に名前を変えると新規人物扱いに戻る() {
        let viewModel = RecordViewModel()
        let person = Person(id: 1, name: "たなか", note: "", lastEncounteredAt: nil, encountersCount: 0)

        viewModel.select(person: person)
        #expect(viewModel.selectedPerson?.id == 1)

        viewModel.updateName("田中太郎")

        #expect(viewModel.selectedPerson == nil)
        #expect(viewModel.canSave)
    }

    @Test
    func 選択タグと入力タグを保存用のタグ名に混ぜる() {
        let viewModel = RecordViewModel()
        viewModel.tags = [
            Tag(id: 1, name: "ハッカソン"),
            Tag(id: 2, name: "STECH")
        ]

        viewModel.toggleTag(named: "STECH")
        viewModel.newTagName = "勉強会"

        #expect(viewModel.tagNamesForSubmission == ["STECH", "勉強会"])
    }

    @Test
    func 保存に失敗しても入力内容を保持する() async {
        let viewModel = RecordViewModel(client: FailingRecordAPIClient())
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
    }
}

private struct FailingRecordAPIClient: RecordAPIClient {
    func health() async throws -> Int { 200 }

    func createEncounter(
        for person: EncounterPersonTarget,
        metAt: Date?,
        topic: String?,
        memo: String?,
        tagNames: [String]
    ) async throws -> Encounter {
        throw ConnectionError()
    }

    func fetchPeople() async throws -> [Person] { [] }

    func fetchTags() async throws -> [Hitoshiori.Tag] { [] }

    private struct ConnectionError: LocalizedError {
        var errorDescription: String? { "接続できませんでした" }
    }
}
