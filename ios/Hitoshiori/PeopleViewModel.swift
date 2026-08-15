import Foundation
import Observation

@MainActor
protocol PeopleAPIClient: PeopleFetching {
    func fetchPerson(id: Int) async throws -> PersonDetail
    func updatePerson(id: Int, name: String, note: String) async throws -> UpdatedPerson
}

extension APIClient: PeopleAPIClient {}

@MainActor
@Observable
final class PersonDetailViewModel {
    var person: PersonDetail?
    var isLoading = false
    private(set) var hasLoaded = false
    var isSaving = false
    var errorMessage: String?

    private let client: any PeopleAPIClient
    private let peopleStore: PeopleStore

    init(
        client: any PeopleAPIClient = APIClient.development,
        peopleStore: PeopleStore? = nil
    ) {
        self.client = client
        self.peopleStore = peopleStore ?? PeopleStore(client: client)
    }

    func load(id: Int) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            person = try await client.fetchPerson(id: id)
        } catch {
            guard !RequestFailure.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func beginEditing() {
        errorMessage = nil
    }

    func cancelEditing() {
        errorMessage = nil
    }

    func save(id: Int, name: String, note: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "名前を入力してください"
            return false
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let updatedPerson = try await client.updatePerson(id: id, name: trimmedName, note: note)
            apply(updatedPerson, toCurrentPersonWithID: id)
            peopleStore.apply(updatedPerson)
            await load(id: id)
            return true
        } catch {
            guard !RequestFailure.isCancellation(error) else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func apply(_ updatedPerson: UpdatedPerson, toCurrentPersonWithID id: Int) {
        guard let person, person.id == id else { return }

        self.person = PersonDetail(
            id: updatedPerson.id,
            name: updatedPerson.name,
            note: updatedPerson.note,
            lastEncounteredAt: updatedPerson.lastEncounteredAt,
            encounters: person.encounters
        )
    }
}

enum EncounterDateText {
    static func relativeDescription(
        for date: Date?,
        relativeTo referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        guard let date else { return "会った記録なし" }

        let startOfEncounterDay = calendar.startOfDay(for: date)
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
        let dayCount = calendar.dateComponents(
            [.day],
            from: startOfEncounterDay,
            to: startOfReferenceDay
        ).day ?? 0

        return switch dayCount {
        case ...0:
            "今日"
        default:
            "\(dayCount)日前"
        }
    }
}
