import Foundation

struct Tag: Codable, Equatable, Sendable {
    let id: Int
    let name: String
}

struct Person: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let note: String
    let lastEncounteredAt: Date?
    let encountersCount: Int
}

struct PersonDetail: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let note: String
    let lastEncounteredAt: Date?
    let encounters: [EncounterHistory]
}

struct Encounter: Codable, Equatable, Sendable {
    let id: Int
    let metAt: Date
    let topic: String?
    let memo: String?
    let tags: [Tag]
    let person: EncounterPerson
}

struct EncounterHistory: Codable, Equatable, Sendable {
    let id: Int
    let metAt: Date
    let topic: String?
    let memo: String?
    let tags: [Tag]
}

struct EncounterPerson: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let lastEncounteredAt: Date?
}

struct UpdatedPerson: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let note: String
    let lastEncounteredAt: Date?
}

struct Reminder: Codable, Equatable, Sendable {
    let id: Int
    let remindOn: String
    let person: ReminderPerson
}

struct ReminderPerson: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let note: String
    let lastEncounteredAt: Date?
    let lastEncounter: ReminderEncounter
}

struct ReminderEncounter: Codable, Equatable, Sendable {
    let metAt: Date
    let topic: String?
    let tags: [Tag]
}

struct EncounterResponse: Codable, Equatable, Sendable {
    let encounter: Encounter
}

struct PeopleResponse: Codable, Equatable, Sendable {
    let people: [Person]
}

struct PersonDetailResponse: Codable, Equatable, Sendable {
    let person: PersonDetail
}

struct PersonResponse: Codable, Equatable, Sendable {
    let person: UpdatedPerson
}

struct TagsResponse: Codable, Equatable, Sendable {
    let tags: [Tag]
}

struct ReminderResponse: Codable, Equatable, Sendable {
    let reminder: Reminder?
}

struct APIErrorResponse: Codable, Equatable, Sendable {
    let errors: [String: [String]]

    var message: String {
        errors
            .sorted { $0.key < $1.key }
            .flatMap { field, messages in
                messages.map { "\(field): \($0)" }
            }
            .joined(separator: "\n")
    }
}

enum APIJSON {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
