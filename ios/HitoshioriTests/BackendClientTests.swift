import Foundation
import Testing

@testable import Hitoshiori

// テストターゲットが動くことの確認用。
// 実装が進んだら中身を差し替える。
struct BackendClientTests {
    @Test
    func developmentClientPointsAtLocalCompose() {
        #expect(BackendClient.development.baseURL.absoluteString == "http://localhost:3000")
    }
}
