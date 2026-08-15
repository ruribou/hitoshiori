import Foundation
import Observation
import UIKit

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
        case reachable(Int)
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
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, selectedPerson == nil else { return [] }

        return people.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var canSave: Bool {
        selectedPerson != nil || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        isLoading = true

        async let fetchedPeople = client.fetchPeople()
        async let fetchedTags = client.fetchTags()
        async let healthStatus = client.health()

        do {
            people = try await fetchedPeople
        } catch {
            people = []
        }

        do {
            tags = try await fetchedTags
        } catch {
            tags = []
        }

        do {
            backendStatus = .reachable(try await healthStatus)
        } catch {
            backendStatus = .unreachable
        }

        isLoading = false
    }

    func select(person: Person) {
        selectedPerson = person
        name = person.name
    }

    func updateName(_ updatedName: String) {
        name = updatedName
        if selectedPerson?.name != updatedName {
            selectedPerson = nil
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

        let person: EncounterPersonTarget
        if let selectedPerson {
            person = .existing(id: selectedPerson.id)
        } else {
            person = .named(name.trimmingCharacters(in: .whitespacesAndNewlines))
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            resetForm()
            didSave = true
            isSaving = false

            try? await Task.sleep(for: .seconds(1.2))
            didSave = false
            await refreshSuggestionsAndTags()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func refreshSuggestionsAndTags() async {
        async let fetchedPeople = client.fetchPeople()
        async let fetchedTags = client.fetchTags()

        if let people = try? await fetchedPeople {
            self.people = people
        }
        if let tags = try? await fetchedTags {
            self.tags = tags
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

    private func optionalValue(from value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
