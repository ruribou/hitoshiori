import Foundation
import Observation

@MainActor
protocol PeopleAPIClient: Sendable {
    func fetchPeople() async throws -> [Person]
    func fetchPerson(id: Int) async throws -> PersonDetail
    func updatePerson(id: Int, name: String, note: String) async throws -> UpdatedPerson
}

extension APIClient: PeopleAPIClient {}

@MainActor
@Observable
final class PeopleListViewModel {
    var people: [Person] = []
    var isLoading = false
    var errorMessage: String?

    private let client: any PeopleAPIClient

    init(client: any PeopleAPIClient = APIClient.development) {
        self.client = client
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            people = try await client.fetchPeople()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class PersonDetailViewModel {
    var person: PersonDetail?
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    private let client: any PeopleAPIClient

    init(client: any PeopleAPIClient = APIClient.development) {
        self.client = client
    }

    func load(id: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            person = try await client.fetchPerson(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginEditing() {
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
            _ = try await client.updatePerson(id: id, name: trimmedName, note: note)
            await load(id: id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
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
        case 1:
            "1日前"
        default:
            "\(dayCount)日前"
        }
    }
}
