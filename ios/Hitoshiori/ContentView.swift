import SwiftUI
import UIKit

@MainActor
struct ContentView: View {
    @State private var peopleStore = PeopleStore()

    var body: some View {
        TabView {
            RecordView(peopleStore: peopleStore)
                .tabItem {
                    Label("記録", systemImage: "square.and.pencil")
                }

            PeopleListView(store: peopleStore)
                .tabItem {
                    Label("人物", systemImage: "person.2")
                }
        }
    }
}

@MainActor
private struct RecordView: View {
    @State private var viewModel: RecordViewModel
    @State private var transcriber: any SpeechTranscribing
    @Environment(\.scenePhase) private var scenePhase

    init(
        peopleStore: PeopleStore,
        transcriber: any SpeechTranscribing = SpeechTranscriber()
    ) {
        _viewModel = State(initialValue: RecordViewModel(peopleStore: peopleStore))
        _transcriber = State(initialValue: transcriber)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("今日、誰と会った？", systemImage: "person.crop.circle.badge.plus")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    backendStatusLabel
                }

                TextField("名前・あだ名", text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.updateName($0) }
                ))
                .textContentType(.name)
                .autocorrectionDisabled()
                .submitLabel(.done)

                if viewModel.selectedPerson != nil {
                    Label("既存の人物として記録します", systemImage: "person.fill.checkmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !viewModel.suggestions.isEmpty {
                    ForEach(viewModel.suggestions, id: \.id) { person in
                        Button {
                            viewModel.select(person: person)
                        } label: {
                            HStack {
                                Text(person.name)
                                Spacer()
                                Text("既存の人物")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            Section("タグ") {
                if viewModel.isLoading, viewModel.tags.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("タグを読み込み中…")
                        Spacer()
                    }
                } else if viewModel.tags.isEmpty {
                    Text("よく使うタグは保存後にここに並びます")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 82), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(viewModel.tags, id: \.id) { tag in
                            TagChip(
                                name: tag.name,
                                isSelected: viewModel.selectedTagNames.contains(tag.name)
                            ) {
                                viewModel.toggleTag(named: tag.name)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                TextField("新しいタグを1つ追加", text: $viewModel.newTagName)
                    .autocorrectionDisabled()
            }

            Section("話したこと") {
                TextField("話題（任意）", text: $viewModel.topic)

                Button {
                    if transcriber.isRecording {
                        transcriber.stop()
                    } else {
                        Task { await viewModel.startVoiceMemo(using: transcriber) }
                    }
                } label: {
                    Label(
                        microphoneButtonTitle,
                        systemImage: transcriber.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(transcriber.isRecording ? .red : .accentColor)
                .disabled(transcriber.isRequestingPermission || transcriber.isFinishing || transcriber.needsSettings)

                if transcriber.isRecording {
                    Label("録音・文字起こし中", systemImage: "waveform")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                } else if transcriber.isFinishing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("文字起こしを完了中…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if transcriber.isRequestingPermission {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("マイクと音声認識を確認中…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                TextEditor(text: $viewModel.memo)
                    .frame(minHeight: 88)
                    .accessibilityLabel("メモ（任意）")
                    .disabled(transcriber.isRecording || transcriber.isFinishing)
            }

            if transcriber.needsSettings {
                Section {
                    Text("音声メモにはマイクと音声認識の許可が必要です。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("設定を開く") {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(settingsURL)
                    }
                }
            }

            if let errorMessage = displayedErrorMessage {
                errorSection(errorMessage)
            }

            Section {
                Button {
                    Task { await viewModel.save(using: transcriber) }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSaving {
                            ProgressView()
                                .padding(.trailing, 6)
                        }
                        Text("記録する")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(!viewModel.canSave || viewModel.isSaving)
            }
        }
        .overlay(alignment: .top) {
            if viewModel.didSave {
                Label("記録しました", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .refreshable { await viewModel.load() }
        .sensoryFeedback(.success, trigger: viewModel.didSave)
        .animation(.default, value: viewModel.didSave)
        .task { await viewModel.load() }
        .task { transcriber.refreshPermissionState() }
        .task(id: viewModel.didSave) {
            guard viewModel.didSave else { return }

            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            viewModel.didSave = false
        }
        .onChange(of: transcriber.transcript) { _, transcript in
            viewModel.updateMemo(withTranscription: transcript)
        }
        .onChange(of: transcriber.state) { _, state in
            guard state == .idle else { return }
            viewModel.finishVoiceMemo(with: transcriber.transcript)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                transcriber.refreshPermissionState()
            } else {
                finishVoiceMemoIfNeeded()
            }
        }
        .onDisappear {
            finishVoiceMemoIfNeeded()
        }
    }

    private var microphoneButtonTitle: String {
        if transcriber.isFinishing {
            "文字起こしを完了中…"
        } else if transcriber.isRecording {
            "文字起こしを停止"
        } else {
            "話してメモを入力"
        }
    }

    private var displayedErrorMessage: String? {
        let messages = [transcriber.errorMessage, viewModel.errorMessage]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }

    @ViewBuilder
    private func errorSection(_ message: String) -> some View {
        Section {
            ErrorMessageLabel(message: message)
        }
    }

    private func finishVoiceMemoIfNeeded() {
        guard transcriber.isRecording || transcriber.isFinishing else { return }

        Task { await viewModel.stopVoiceMemo(using: transcriber) }
    }

    @ViewBuilder
    private var backendStatusLabel: some View {
        switch viewModel.backendStatus {
        case .checking:
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("backend に接続中")
        case .reachable:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("backend に接続済み")
        case .unreachable:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("backend に未接続")
        }
    }
}

private struct TagChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemFill), in: Capsule())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ContentView()
}
