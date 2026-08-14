import SwiftUI

/// 環境構築の疎通確認用の仮画面。
/// 実装が始まったら「今日誰と会った?」の記録画面に置き換える。
struct ContentView: View {
    private enum Status {
        case checking
        case reachable(Int)
        case unreachable(String)
    }

    @State private var status: Status = .checking

    private let client = BackendClient.development

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("ひとしおり")
                    .font(.largeTitle.bold())
                Text("環境構築の疎通確認用の仮画面")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            statusLabel

            Button("再チェック") {
                Task { await check() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task { await check() }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .checking:
            Label("backend に接続中…", systemImage: "ellipsis.circle")
                .foregroundStyle(.secondary)
        case .reachable(let code):
            Label("backend 到達 OK (HTTP \(code))", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .unreachable(let message):
            VStack(spacing: 4) {
                Label("backend に届きません", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("`docker compose up -d` を確認してください")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func check() async {
        status = .checking
        do {
            status = .reachable(try await client.health())
        } catch {
            status = .unreachable(error.localizedDescription)
        }
    }
}

#Preview {
    ContentView()
}
