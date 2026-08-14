import Foundation

/// Rails API のクライアント。
/// 開発中は compose で立てた backend を叩く。シミュレータからはホストの
/// localhost がそのまま見えるので、追加設定なしで http://localhost:3000 に届く。
struct BackendClient: Sendable {
    var baseURL: URL

    static let development = BackendClient(baseURL: URL(string: "http://localhost:3000")!)

    /// Rails 標準のヘルスチェック(/up)の HTTP ステータスを返す。
    func health() async throws -> Int {
        let (_, response) = try await URLSession.shared.data(from: baseURL.appending(path: "up"))

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return http.statusCode
    }
}
