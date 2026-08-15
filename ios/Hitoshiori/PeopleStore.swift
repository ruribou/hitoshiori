import Foundation
import Observation

@MainActor
protocol PeopleFetching: Sendable {
    func fetchPeople() async throws -> [Person]
}

extension APIClient: PeopleFetching {}

@MainActor
@Observable
final class PeopleStore {
    var people: [Person] = []
    var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    private let client: any PeopleFetching

    init(client: any PeopleFetching = APIClient.development) {
        self.client = client
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            people = try await client.fetchPeople()
        } catch {
            guard !RequestFailure.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func apply(_ updatedPerson: UpdatedPerson) {
        guard let index = people.firstIndex(where: { $0.id == updatedPerson.id }) else { return }

        let current = people[index]
        people[index] = Person(
            id: updatedPerson.id,
            name: updatedPerson.name,
            note: updatedPerson.note,
            lastEncounteredAt: updatedPerson.lastEncounteredAt,
            encountersCount: current.encountersCount
        )
    }
}

enum RequestFailure {
    static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
