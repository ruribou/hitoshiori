import Foundation
import Testing

@testable import Hitoshiori

@MainActor
struct RecordViewModelTests {
    @Test("名前または既存人物があり、保存中でなければ保存できる")
    func canSaveWithPersonInputWhenNotSaving() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())

        #expect(!viewModel.canSave)

        viewModel.updateName("たなか")

        #expect(viewModel.canSave)
        viewModel.updateName(" \n ")
        #expect(!viewModel.canSave)

        viewModel.updateName("さとう")
        viewModel.isSaving = true
        #expect(!viewModel.canSave)
    }

    @Test("入力済みの人物は確認なしに今日の一人へ置き換えない")
    func keepsInputWhenReminderPersonWouldReplaceIt() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.updateName("さとう")

        let didSelect = viewModel.selectExistingPersonIfInputIsEmpty(id: 42, name: "たなか")

        #expect(!didSelect)
        #expect(viewModel.name == "さとう")
        #expect(viewModel.selectedPerson == nil)

        viewModel.selectExistingPerson(id: 42, name: "たなか")

        #expect(viewModel.name == "たなか")
        #expect(viewModel.selectedPerson?.id == 42)
    }

    @Test("ロード済みの人物を今日の一人として選ぶ")
    func selectsLoadedPersonWhenReminderMatchesExistingPerson() async {
        let client = StubRecordAPIClient()
        client.peopleResults = [
            .success([
                Person(
                    id: 42,
                    name: "登録済みのたなか",
                    note: "",
                    lastEncounteredAt: nil,
                    encountersCount: 7
                )
            ])
        ]
        let viewModel = RecordViewModel(client: client)

        await viewModel.load()
        viewModel.selectExistingPerson(id: 42, name: "たなか")

        #expect(viewModel.name == "登録済みのたなか")
        #expect(viewModel.selectedPerson?.encountersCount == 7)
    }

    @Test("今日の一人を既存人物として引き継いで記録する")
    func savesTodayReminderPersonAsExistingPerson() async {
        let client = StubRecordAPIClient()
        let viewModel = RecordViewModel(client: client)

        viewModel.selectExistingPerson(id: 42, name: "たなか")
        viewModel.topic = "久しぶりに連絡した"
        await viewModel.save()

        #expect(viewModel.name == "")
        #expect(client.createCalls.first?.person == .existing(id: 42))
        #expect(client.createCalls.first?.topic == "久しぶりに連絡した")
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
        #expect(viewModel.addedTagNames.isEmpty)
        #expect(viewModel.didSave)
    }

    @Test("取得失敗後に再読み込みすると人物候補を回復できる")
    func recoversPeopleWhenLoadingIsRetried() async {
        let client = StubRecordAPIClient()
        client.healthResults = [.success(200), .success(200)]
        client.peopleResults = [
            .failure(StubError.unavailable),
            .success([person(id: 1, name: "たなか")])
        ]
        client.tagResults = [.success([]), .success([])]
        let viewModel = RecordViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.people.isEmpty)
        #expect(viewModel.errorMessage != nil)

        await viewModel.load()

        #expect(viewModel.people.map(\.id) == [1])
        #expect(viewModel.errorMessage == nil)
    }

    @Test("ヘルスチェックの失敗は技術詳細を出さずに未接続として扱う")
    func treatsNonSuccessHealthStatusAsUnreachable() async {
        let client = StubRecordAPIClient()
        client.healthResults = [.success(500)]
        let viewModel = RecordViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.backendStatus == .unreachable)
        #expect(viewModel.errorMessage == "サーバーに接続できません。接続を確認して、もう一度試してください。")
    }

    @Test("取得失敗は理由を表示する")
    func showsErrorWhenLoadingPeopleFails() async {
        let client = StubRecordAPIClient()
        client.peopleResults = [.failure(StubError.unavailable)]
        let viewModel = RecordViewModel(client: client)

        await viewModel.load()

        #expect(viewModel.errorMessage == "記録に必要な情報を読み込めませんでした。接続を確認して、もう一度試してください。")
    }

    @Test("保存に失敗しても入力内容を保持し、名前を直すとエラーを消す")
    func preservesInputAndClearsErrorWhenNameChanges() async {
        let client = StubRecordAPIClient()
        client.createEncounterResults = [.failure(StubError.unavailable)]
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
        #expect(viewModel.errorMessage == "記録を保存できませんでした。接続を確認して、もう一度試してください。")

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

    @Test("空のメモへの音声文字起こしは先頭に改行を入れない")
    func appendsTranscriptionToEmptyMemo() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())

        viewModel.beginMemoTranscription()
        viewModel.updateMemo(withTranscription: "こんにちは")

        #expect(viewModel.memo == "こんにちは")
    }

    @Test("音声文字起こしを開始していないメモは変更しない")
    func ignoresTranscriptionWithoutStarting() {
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.memo = "手入力したメモ"

        viewModel.updateMemo(withTranscription: "こんにちは")

        #expect(viewModel.memo == "手入力したメモ")
    }

    @Test("音声文字起こし終了後の遅延結果は手修正を上書きしない")
    func preservesEditsAfterVoiceMemoFinishes() async {
        let transcriber = StubSpeechTranscriber()
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.memo = "手入力したメモ"
        transcriber.finalTranscript = "最終結果"

        await viewModel.startVoiceMemo(using: transcriber)
        transcriber.transcript = "途中の結果"
        viewModel.updateMemo(withTranscription: transcriber.transcript)

        await viewModel.stopVoiceMemo(using: transcriber)

        #expect(transcriber.stopAndWaitCallCount == 1)
        #expect(viewModel.memo == "手入力したメモ\n最終結果")

        viewModel.memo = "手修正後のメモ"
        viewModel.updateMemo(withTranscription: "遅れて届いた結果")

        #expect(viewModel.memo == "手修正後のメモ")
    }

    @Test("画面遷移時の停止で最終文字起こしをメモへ反映する")
    func finishesVoiceMemoWhenLeavingRecordView() async {
        let transcriber = StubSpeechTranscriber()
        let viewModel = RecordViewModel(client: StubRecordAPIClient())
        viewModel.memo = "手入力したメモ"
        transcriber.finalTranscript = "最終結果"

        await viewModel.startVoiceMemo(using: transcriber)
        await viewModel.stopVoiceMemo(using: transcriber)

        #expect(transcriber.stopAndWaitCallCount == 1)
        #expect(transcriber.state == .idle)
        #expect(viewModel.memo == "手入力したメモ\n最終結果")
    }

    @Test("保存前に音声文字起こしを終了して最終結果を送る")
    func savesAfterFinishingVoiceMemo() async {
        let client = StubRecordAPIClient()
        let transcriber = StubSpeechTranscriber()
        let viewModel = RecordViewModel(client: client)
        viewModel.updateName("たなか")
        transcriber.finalTranscript = "最終結果"

        await viewModel.startVoiceMemo(using: transcriber)
        await viewModel.save(using: transcriber)

        #expect(transcriber.stopAndWaitCallCount == 1)
        #expect(transcriber.state == .idle)
        #expect(client.createCalls.last?.memo == "最終結果")
    }

}

@MainActor
final class StubRecordAPIClient: RecordAPIClient {
    struct CreateEncounterCall: Equatable {
        let person: EncounterPersonTarget
        let metAt: Date?
        let topic: String?
        let memo: String?
        let tagNames: [String]
    }

    struct DeleteEncounterCall: Equatable {
        let id: Int
        let removeEmptyPerson: Bool
    }

    var healthResults: [Result<Int, Error>] = [.success(200)]
    var peopleResults: [Result<[Person], Error>] = [.success([])]
    var tagResults: [Result<[Hitoshiori.Tag], Error>] = [.success([])]
    var createEncounterResults: [Result<Encounter, Error>] = [.success(.fixture)]
    var deleteEncounterResults: [Result<Void, Error>] = [.success(())]
    private(set) var createCalls: [CreateEncounterCall] = []
    private(set) var deleteCalls: [DeleteEncounterCall] = []

    func health() async throws -> Int {
        try nextResult(from: &healthResults)
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
        return try nextResult(from: &createEncounterResults)
    }

    func deleteEncounter(id: Int, removeEmptyPerson: Bool) async throws {
        deleteCalls.append(DeleteEncounterCall(id: id, removeEmptyPerson: removeEmptyPerson))
        try nextResult(from: &deleteEncounterResults)
    }

    func fetchPeople() async throws -> [Person] {
        try nextResult(from: &peopleResults)
    }

    func fetchTags() async throws -> [Hitoshiori.Tag] {
        try nextResult(from: &tagResults)
    }
}

@MainActor
private final class StubSpeechTranscriber: SpeechTranscribing {
    var state: SpeechTranscriptionState = .idle
    var transcript = ""
    var errorMessage: String?
    var finalTranscript = ""
    private(set) var startCallCount = 0
    private(set) var stopAndWaitCallCount = 0

    func start() async {
        startCallCount += 1
        state = .recording
    }

    func stop() {
        guard state == .recording else { return }
        state = .finishing
    }

    func stopAndWaitForFinalResult() async {
        stopAndWaitCallCount += 1
        stop()
        await Task.yield()
        transcript = finalTranscript
        state = .idle
    }

    func refreshPermissionState() {}
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
