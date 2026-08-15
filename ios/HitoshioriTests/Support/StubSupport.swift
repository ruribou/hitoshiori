import Foundation
import Testing

@testable import Hitoshiori

enum StubError: Error, LocalizedError {
    case unavailable
    case unexpectedCall

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "接続できませんでした"
        case .unexpectedCall:
            "テストスタブに想定外の呼び出しがありました"
        }
    }
}

func nextResult<Value>(from results: inout [Result<Value, Error>]) throws -> Value {
    guard !results.isEmpty else {
        Issue.record("スタブの結果が足りません")
        throw StubError.unexpectedCall
    }

    return try results.removeFirst().get()
}

func person(id: Int, name: String) -> Person {
    Person(id: id, name: name, note: "", lastEncounteredAt: nil, encountersCount: 0)
}
