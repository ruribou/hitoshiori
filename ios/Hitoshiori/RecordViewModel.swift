import Foundation
import Observation

@MainActor
protocol RecordAPIClient: PeopleFetching {
    func health() async throws -> Int
    func createEncounter(
        for person: EncounterPersonTarget,
        metAt: Date?,
        topic: String?,
        memo: String?,
        tagNames: [String]
    ) async throws -> Encounter
    func deleteEncounter(id: Int, removeEmptyPerson: Bool) async throws
    func fetchTags() async throws -> [Tag]
}

extension APIClient: RecordAPIClient {}

@MainActor
@Observable
final class RecordViewModel {
    enum BackendStatus: Equatable {
        case checking
        case reachable
        case unreachable
    }

    var name = ""
    var topic = ""
    var memo = ""
    var newTagName = ""
    var tags: [Tag] = []
    var selectedTagNames: Set<String> = []
    var backendStatus: BackendStatus = .checking
    var isLoading = false
    var isSaving = false
    var isUndoing = false
    var didSave = false
    var errorMessage: String?
    private(set) var lastSavedPersonName: String?

    private let client: any RecordAPIClient
    private let peopleStore: PeopleStore
    private(set) var selectedPerson: Person?
    private var memoBeforeTranscription: String?
    private var isStoppingVoiceMemo = false
    private var lastSavedDraft: RecordDraft?
    private var lastSavedEncounterID: Int?
    private var lastSavedPersonWasNew = false

    init(
        client: any RecordAPIClient = APIClient.development,
        peopleStore: PeopleStore? = nil
    ) {
        self.client = client
        self.peopleStore = peopleStore ?? PeopleStore(client: client)
    }

    var people: [Person] {
        get { peopleStore.people }
        set { peopleStore.people = newValue }
    }

    var suggestions: [Person] {
        let query = normalized(trimmedName)
        guard !query.isEmpty, selectedPerson == nil else { return [] }

        return people.filter { normalized($0.name).contains(query) }
    }

    var canSave: Bool {
        !isSaving && hasPersonInput
    }

    private var hasPersonInput: Bool {
        selectedPerson != nil || !trimmedName.isEmpty
    }

    var addedTagNames: [String] = []

    func load() async {
        errorMessage = nil

        async let healthStatus = client.health()
        await refreshPeopleAndTags()

        do {
            let statusCode = try await healthStatus
            if (200..<300).contains(statusCode) {
                backendStatus = .reachable
            } else {
                backendStatus = .unreachable
                appendErrorMessage(Self.connectionErrorMessage)
            }
        } catch {
            backendStatus = .unreachable
            appendErrorMessage(Self.connectionErrorMessage)
        }
    }

    func select(person: Person) {
        selectedPerson = person
        name = person.name
    }

    func clearSelectedPerson() {
        selectedPerson = nil
        name = ""
        errorMessage = nil
    }

    func selectExistingPerson(id: Int, name: String) {
        if let person = people.first(where: { $0.id == id }) {
            select(person: person)
            return
        }

        select(
            person: Person(
                id: id,
                name: name,
                note: "",
                lastEncounteredAt: nil,
                encountersCount: 0
            )
        )
    }

    @discardableResult
    func selectExistingPersonIfInputIsEmpty(id: Int, name: String) -> Bool {
        guard !hasPersonInput else { return false }

        selectExistingPerson(id: id, name: name)
        return true
    }

    func updateName(_ updatedName: String) {
        name = updatedName
        errorMessage = nil

        if let selectedPerson,
           normalized(selectedPerson.name) != normalized(trimmedName) {
            self.selectedPerson = nil
        }
    }

    func toggleTag(named name: String) {
        if selectedTagNames.contains(name) {
            selectedTagNames.remove(name)
        } else {
            selectedTagNames.insert(name)
        }
    }

    func beginMemoTranscription() {
        memoBeforeTranscription = memo
    }

    func updateMemo(withTranscription transcript: String) {
        guard let memoBeforeTranscription else { return }

        if memoBeforeTranscription.isEmpty || transcript.isEmpty {
            memo = memoBeforeTranscription + transcript
        } else {
            memo = "\(memoBeforeTranscription)\n\(transcript)"
        }
    }

    func endMemoTranscription() {
        memoBeforeTranscription = nil
    }

    func startVoiceMemo(using transcriber: any SpeechTranscribing) async {
        beginMemoTranscription()
        await transcriber.start()

        if !transcriber.isRecording {
            endMemoTranscription()
        }
    }

    func finishVoiceMemo(with transcript: String) {
        updateMemo(withTranscription: transcript)
        endMemoTranscription()
    }

    func stopVoiceMemo(using transcriber: any SpeechTranscribing) async {
        guard !isStoppingVoiceMemo, transcriber.isRecording || transcriber.isFinishing else { return }

        isStoppingVoiceMemo = true
        defer { isStoppingVoiceMemo = false }
        await transcriber.stopAndWaitForFinalResult()
        finishVoiceMemo(with: transcriber.transcript)
    }

    func save(using transcriber: any SpeechTranscribing) async {
        if transcriber.isRecording || transcriber.isFinishing {
            await stopVoiceMemo(using: transcriber)
        }

        await save()
    }

    func save() async {
        guard canSave else { return }

        didSave = false

        let person: EncounterPersonTarget
        if let selectedPerson {
            person = .existing(id: selectedPerson.id)
        } else {
            person = .named(trimmedName)
        }

        let draft = RecordDraft(
            name: name,
            topic: topic,
            memo: memo,
            newTagName: newTagName,
            selectedTagNames: selectedTagNames,
            addedTagNames: addedTagNames,
            selectedPerson: selectedPerson
        )
        let savedPersonName = selectedPerson?.name ?? trimmedName
        let shouldRemoveEmptyPerson = selectedPerson == nil

        isSaving = true
        errorMessage = nil

        do {
            let encounter = try await client.createEncounter(
                for: person,
                metAt: nil,
                topic: optionalValue(from: topic),
                memo: optionalValue(from: memo),
                tagNames: tagNamesForSubmission
            )
            resetForm()
            lastSavedDraft = draft
            lastSavedEncounterID = encounter.id
            lastSavedPersonWasNew = shouldRemoveEmptyPerson
            lastSavedPersonName = savedPersonName
            didSave = true
            isSaving = false
            await refreshPeopleAndTags()
        } catch {
            errorMessage = Self.messageForSaveFailure(error)
            isSaving = false
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func refreshPeopleAndTags() async {
        isLoading = true
        defer { isLoading = false }

        async let loadedPeople: Void = peopleStore.load()
        async let fetchedTags = client.fetchTags()
        var didFailToLoad = false

        await loadedPeople
        if peopleStore.errorMessage != nil {
            didFailToLoad = true
        }

        do {
            tags = try await fetchedTags
        } catch {
            didFailToLoad = true
        }

        if didFailToLoad {
            appendErrorMessage(Self.loadingErrorMessage)
        }
    }

    private func appendErrorMessage(_ message: String) {
        if let errorMessage, !errorMessage.isEmpty {
            self.errorMessage = "\(errorMessage)\n\(message)"
        } else {
            errorMessage = message
        }
    }

    private func resetForm() {
        name = ""
        topic = ""
        memo = ""
        newTagName = ""
        selectedPerson = nil
        selectedTagNames = []
        addedTagNames = []
        endMemoTranscription()
    }

    func normalized(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
            .applyingTransform(.hiraganaToKatakana, reverse: false) ?? value
    }

    private func optionalValue(from value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private struct RecordDraft {
    let name: String
    let topic: String
    let memo: String
    let newTagName: String
    let selectedTagNames: Set<String>
    let addedTagNames: [String]
    let selectedPerson: Person?
}

@MainActor
extension RecordViewModel {
    func restoreLastSavedDraft() {
        guard let lastSavedDraft else { return }

        name = lastSavedDraft.name
        topic = lastSavedDraft.topic
        memo = lastSavedDraft.memo
        newTagName = lastSavedDraft.newTagName
        selectedTagNames = lastSavedDraft.selectedTagNames
        addedTagNames = lastSavedDraft.addedTagNames
        selectedPerson = lastSavedDraft.selectedPerson
        self.lastSavedDraft = nil
        lastSavedEncounterID = nil
        lastSavedPersonWasNew = false
        lastSavedPersonName = nil
        didSave = false
    }

    func undoLastSavedRecord() async {
        guard let lastSavedEncounterID, !isUndoing else { return }

        isUndoing = true
        errorMessage = nil
        defer { isUndoing = false }

        do {
            try await client.deleteEncounter(
                id: lastSavedEncounterID,
                removeEmptyPerson: lastSavedPersonWasNew
            )
            restoreLastSavedDraft()
            await refreshPeopleAndTags()
        } catch {
            errorMessage = "記録を取り消せませんでした。接続を確認して、もう一度試してください。"
        }
    }

    func dismissSavedFeedback() {
        didSave = false
        lastSavedDraft = nil
        lastSavedEncounterID = nil
        lastSavedPersonWasNew = false
        lastSavedPersonName = nil
    }

    private static let connectionErrorMessage = "サーバーに接続できません。接続を確認して、もう一度試してください。"
    private static let loadingErrorMessage = "記録に必要な情報を読み込めませんでした。接続を確認して、もう一度試してください。"

    private static func messageForSaveFailure(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .badRequest(let response), .unprocessableEntity(let response):
                return response.message
            case .invalidResponse, .notFound, .unexpectedStatus:
                break
            }
        }
        return "記録を保存できませんでした。接続を確認して、もう一度試してください。"
    }
}
