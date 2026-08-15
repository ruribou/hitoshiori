import Foundation

enum EncounterPersonTarget: Equatable, Sendable {
    case existing(id: Int)
    case named(String)
}

enum APIError: Error, Equatable, LocalizedError, Sendable {
    case invalidResponse
    case badRequest(APIErrorResponse)
    case notFound(APIErrorResponse)
    case unprocessableEntity(APIErrorResponse)
    case unexpectedStatus(Int)

    var message: String {
        switch self {
        case .invalidResponse:
            "サーバーから正しい応答を受け取れませんでした"
        case .badRequest(let response),
             .notFound(let response),
             .unprocessableEntity(let response):
            response.message
        case .unexpectedStatus(let statusCode):
            "サーバーエラーが発生しました (HTTP \(statusCode))"
        }
    }

    var errorDescription: String? {
        message
    }
}

/// Rails APIとの通信を担当するクライアント。
struct APIClient: Sendable {
    let baseURL: URL

    static let development = APIClient(baseURL: URL(string: "http://localhost:3000")!)

    /// Rails標準のヘルスチェック(`/up`)のHTTPステータスを返す。
    func health() async throws -> Int {
        let (_, response) = try await URLSession.shared.data(
            from: baseURL.appending(path: "up")
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return httpResponse.statusCode
    }

    func createEncounter(
        for person: EncounterPersonTarget,
        metAt: Date? = nil,
        topic: String? = nil,
        memo: String? = nil,
        tagNames: [String] = []
    ) async throws -> Encounter {
        let personID: Int?
        let personName: String?

        switch person {
        case .existing(let id):
            personID = id
            personName = nil
        case .named(let name):
            personID = nil
            personName = name
        }

        let body = CreateEncounterRequest(
            encounter: .init(
                personID: personID,
                personName: personName,
                metAt: metAt,
                topic: topic,
                memo: memo,
                tagNames: tagNames
            )
        )
        let response: EncounterResponse = try await send(
            path: "api/v1/encounters",
            method: "POST",
            body: APIJSON.makeEncoder().encode(body)
        )
        return response.encounter
    }

    func fetchPeople() async throws -> [Person] {
        let response: PeopleResponse = try await send(path: "api/v1/people")
        return response.people
    }

    func fetchPerson(id: Int) async throws -> PersonDetail {
        let response: PersonDetailResponse = try await send(path: "api/v1/people/\(id)")
        return response.person
    }

    func updatePerson(id: Int, name: String, note: String) async throws -> UpdatedPerson {
        let body = UpdatePersonRequest(person: .init(name: name, note: note))
        let response: PersonResponse = try await send(
            path: "api/v1/people/\(id)",
            method: "PATCH",
            body: APIJSON.makeEncoder().encode(body)
        )
        return response.person
    }

    func fetchTags() async throws -> [Tag] {
        let response: TagsResponse = try await send(path: "api/v1/tags")
        return response.tags
    }

    func fetchTodayReminder() async throws -> Reminder? {
        let response: ReminderResponse = try await send(path: "api/v1/reminders/today")
        return response.reminder
    }

    private func send<Response: Decodable & Sendable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return try APIJSON.makeDecoder().decode(Response.self, from: data)
        case 400:
            throw APIError.badRequest(Self.decodeError(from: data))
        case 404:
            throw APIError.notFound(Self.decodeError(from: data))
        case 422:
            throw APIError.unprocessableEntity(Self.decodeError(from: data))
        default:
            throw APIError.unexpectedStatus(httpResponse.statusCode)
        }
    }

    private static func decodeError(from data: Data) -> APIErrorResponse {
        (try? APIJSON.makeDecoder().decode(APIErrorResponse.self, from: data))
            ?? APIErrorResponse(errors: ["base": ["サーバーエラーが発生しました"]])
    }
}

private struct CreateEncounterRequest: Encodable, Sendable {
    let encounter: EncounterPayload

    struct EncounterPayload: Encodable, Sendable {
        let personID: Int?
        let personName: String?
        let metAt: Date?
        let topic: String?
        let memo: String?
        let tagNames: [String]
    }
}

private struct UpdatePersonRequest: Encodable, Sendable {
    let person: PersonPayload

    struct PersonPayload: Encodable, Sendable {
        let name: String
        let note: String
    }
}
