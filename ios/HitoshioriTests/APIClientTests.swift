import Foundation
import Testing

@testable import Hitoshiori

struct APIClientTests {
    @Test
    func developmentClientPointsAtLocalCompose() {
        #expect(APIClient.development.baseURL.absoluteString == "http://localhost:3000")
    }

    @Test
    func decodesEncounterResponse() throws {
        let response = try decode(
            EncounterResponse.self,
            from: #"""
            {
              "encounter": {
                "id": 1,
                "met_at": "2026-08-14T10:00:00Z",
                "topic": "ハッカソンで同じチーム",
                "memo": "音声文字起こしのテキスト。Rails が好きらしい。",
                "tags": [
                  { "id": 1, "name": "ハッカソン" },
                  { "id": 2, "name": "STECH" }
                ],
                "person": { "id": 1, "name": "たなか", "last_encountered_at": "2026-08-14T10:00:00Z" }
              }
            }
            """#
        )

        #expect(response.encounter.id == 1)
        #expect(response.encounter.tags.map(\.name) == ["ハッカソン", "STECH"])
        #expect(response.encounter.person.name == "たなか")
    }

    @Test
    func decodesValidationErrorResponse() throws {
        let response = try decode(
            APIErrorResponse.self,
            from: #"""
            { "errors": { "person_name": ["を入力してください"] } }
            """#
        )

        #expect(response.errors == ["person_name": ["を入力してください"]])
        #expect(response.message == "person_name: を入力してください")
    }

    @Test
    func decodesBadRequestErrorResponse() throws {
        let response = try decode(
            APIErrorResponse.self,
            from: #"""
            { "errors": { "encounter": ["を入力してください"] } }
            """#
        )

        #expect(response.errors == ["encounter": ["を入力してください"]])
    }

    @Test
    func decodesNotFoundErrorResponse() throws {
        let response = try decode(
            APIErrorResponse.self,
            from: #"""
            { "errors": { "base": ["not found"] } }
            """#
        )

        #expect(response.errors == ["base": ["not found"]])
    }

    @Test
    func decodesPeopleResponse() throws {
        let response = try decode(
            PeopleResponse.self,
            from: #"""
            {
              "people": [
                {
                  "id": 1,
                  "name": "たなか",
                  "note": "",
                  "last_encountered_at": "2026-08-14T10:00:00Z",
                  "encounters_count": 3
                }
              ]
            }
            """#
        )

        #expect(response.people.count == 1)
        #expect(response.people[0].name == "たなか")
        #expect(response.people[0].encountersCount == 3)
    }

    @Test
    func decodesPersonDetailResponse() throws {
        let response = try decode(
            PersonDetailResponse.self,
            from: #"""
            {
              "person": {
                "id": 1,
                "name": "たなか",
                "note": "Rails 好き。○○大学",
                "last_encountered_at": "2026-08-14T10:00:00Z",
                "encounters": [
                  {
                    "id": 1,
                    "met_at": "2026-08-14T10:00:00Z",
                    "topic": "ハッカソンで同じチーム",
                    "memo": "…",
                    "tags": [{ "id": 1, "name": "ハッカソン" }]
                  }
                ]
              }
            }
            """#
        )

        #expect(response.person.note == "Rails 好き。○○大学")
        #expect(response.person.encounters.first?.memo == "…")
    }

    @Test
    func decodesUpdatedPersonResponse() throws {
        let response = try decode(
            PersonResponse.self,
            from: #"""
            {
              "person": {
                "id": 1,
                "name": "田中太郎",
                "note": "○○大学。Rails 好き",
                "last_encountered_at": "2026-08-14T10:00:00Z"
              }
            }
            """#
        )

        #expect(response.person.name == "田中太郎")
        #expect(response.person.lastEncounteredAt != nil)
    }

    @Test
    func decodesTagsResponse() throws {
        let response = try decode(
            TagsResponse.self,
            from: #"""
            {
              "tags": [
                { "id": 2, "name": "STECH" },
                { "id": 1, "name": "ハッカソン" }
              ]
            }
            """#
        )

        #expect(response.tags.map(\.name) == ["STECH", "ハッカソン"])
    }

    @Test
    func decodesTodayReminderResponse() throws {
        let response = try decode(
            ReminderResponse.self,
            from: #"""
            {
              "reminder": {
                "id": 1,
                "remind_on": "2026-08-14",
                "person": {
                  "id": 1,
                  "name": "たなか",
                  "note": "",
                  "last_encountered_at": "2026-07-01T10:00:00Z",
                  "last_encounter": {
                    "met_at": "2026-07-01T10:00:00Z",
                    "topic": "ハッカソンで同じチーム",
                    "tags": [{ "id": 1, "name": "ハッカソン" }]
                  }
                }
              }
            }
            """#
        )

        #expect(response.reminder?.remindOn == "2026-08-14")
        #expect(response.reminder?.person.lastEncounter.tags.first?.name == "ハッカソン")
    }

    @Test
    func decodesEmptyTodayReminderResponse() throws {
        let response = try decode(
            ReminderResponse.self,
            from: #"""
            { "reminder": null }
            """#
        )

        #expect(response.reminder == nil)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        try APIJSON.makeDecoder().decode(type, from: Data(json.utf8))
    }
}
