import Foundation
import Observation

@MainActor
protocol RecordAPIClient: Sendable {
    func health() async throws -> Int
    func createEncounter(
        for person: EncounterPersonTarget,
        metAt: Date?,
        topic: String?,
        memo: String?,
        tagNames: [String]
    ) async throws -> Encounter
    func fetchPeople() async throws -> [Person]
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
    var people: [Person] = []
    var tags: [Tag] = []
    var selectedTagNames: Set<String> = []
    var backendStatus: BackendStatus = .checking
    var isLoading = false
    var isSaving = false
    var didSave = false
    var errorMessage: String?

    private let client: any RecordAPIClient
    private(set) var selectedPerson: Person?

    init(client: any RecordAPIClient = APIClient.development) {
        self.client = client
    }

    var suggestions: [Person] {
        let query = normalized(trimmedName)
        guard !query.isEmpty, selectedPerson == nil else { return [] }

        return people.filter { normalized($0.name).contains(query) }
    }

    var canSave: Bool {
        selectedPerson != nil || !trimmedName.isEmpty
    }

    var tagNamesForSubmission: [String] {
        var names = tags.compactMap { selectedTagNames.contains($0.name) ? $0.name : nil }
        let typedTagName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !typedTagName.isEmpty, !names.contains(typedTagName) {
            names.append(typedTagName)
        }
        return names
    }

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
                appendErrorMessage("backend が HTTP \(statusCode) を返しています")
            }
        } catch {
            backendStatus = .unreachable
            appendErrorMessage(error.localizedDescription)
        }
    }

    func select(person: Person) {
        selectedPerson = person
        name = person.name
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

    func save() async {
        guard canSave else { return }

        didSave = false

        let person: EncounterPersonTarget
        if let selectedPerson {
            person = .existing(id: selectedPerson.id)
        } else {
            person = .named(trimmedName)
        }

        isSaving = true
        errorMessage = nil

        do {
            _ = try await client.createEncounter(
                for: person,
                metAt: nil,
                topic: optionalValue(from: topic),
                memo: optionalValue(from: memo),
                tagNames: tagNamesForSubmission
            )
            resetForm()
            didSave = true
            isSaving = false
            await refreshPeopleAndTags()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func refreshPeopleAndTags() async {
        isLoading = true
        defer { isLoading = false }

        async let fetchedPeople = client.fetchPeople()
        async let fetchedTags = client.fetchTags()
        var errors: [String] = []

        do {
            people = try await fetchedPeople
        } catch {
            errors.append(error.localizedDescription)
        }

        do {
            tags = try await fetchedTags
        } catch {
            errors.append(error.localizedDescription)
        }

        for errorMessage in errors {
            appendErrorMessage(errorMessage)
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
    }

    private func normalized(_ value: String) -> String {
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
