import SwiftUI
import UIKit

// 記録画面と、それ専用の小さなUI部品を同じ見通しで保つ。
// swiftlint:disable file_length

private enum AppTab: Hashable {
    case record
    case people
}

@MainActor
struct ContentView: View {
    @State private var peopleStore: PeopleStore
    @State private var recordViewModel: RecordViewModel
    @State private var transcriber: any SpeechTranscribing
    @State private var reminderViewModel = TodayReminderViewModel()
    @State private var notificationScheduler = LocalNotificationScheduler()
    @State private var selectedTab: AppTab = .record
    @State private var peoplePath: [Int] = []
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = PeopleStore()
        _peopleStore = State(initialValue: store)
        _recordViewModel = State(initialValue: RecordViewModel(peopleStore: store))
        _transcriber = State(initialValue: SpeechTranscriber())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordView(
                viewModel: recordViewModel,
                reminder: reminderViewModel.reminder,
                isReminderVisible: reminderViewModel.isCardVisible,
                reminderErrorMessage: reminderViewModel.errorMessage,
                onShowPerson: showPerson,
                onDismissReminder: reminderViewModel.dismissCard,
                onRecordFinished: reminderViewModel.recordDidFinish,
                transcriber: transcriber
            )
                .tabItem {
                    Label("記録", systemImage: "square.and.pencil")
                }
                .tag(AppTab.record)

            PeopleListView(store: peopleStore, path: $peoplePath)
                .tabItem {
                    Label("人物", systemImage: "person.2")
                }
                .tag(AppTab.people)
        }
        .task { await reminderViewModel.load() }
        .task { await notificationScheduler.configure() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await reminderViewModel.load() }
        }
    }

    private func showPerson(id: Int) {
        selectedTab = .people
        peoplePath = [id]
    }
}

@MainActor
// swiftlint:disable type_body_length
private struct RecordView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var viewModel: RecordViewModel
    @FocusState private var focusedField: RecordField?
    @State private var isErrorDismissed = false
    private let reminder: Reminder?
    private let isReminderVisible: Bool
    private let reminderErrorMessage: String?
    private let onShowPerson: (Int) -> Void
    private let onDismissReminder: () -> Void
    private let onRecordFinished: (Bool, Int?) -> Void
    private let transcriber: any SpeechTranscribing

    init(
        viewModel: RecordViewModel,
        reminder: Reminder?,
        isReminderVisible: Bool,
        reminderErrorMessage: String?,
        onShowPerson: @escaping (Int) -> Void,
        onDismissReminder: @escaping () -> Void,
        onRecordFinished: @escaping (Bool, Int?) -> Void,
        transcriber: any SpeechTranscribing
    ) {
        _viewModel = Bindable(wrappedValue: viewModel)
        self.reminder = reminder
        self.isReminderVisible = isReminderVisible
        self.reminderErrorMessage = reminderErrorMessage
        self.onShowPerson = onShowPerson
        self.onDismissReminder = onDismissReminder
        self.onRecordFinished = onRecordFinished
        self.transcriber = transcriber
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RecordHeader()

                if let reminder, isReminderVisible {
                    TodayReminderSection(
                        reminder: reminder,
                        viewModel: viewModel,
                        onShowPerson: { onShowPerson(reminder.person.id) },
                        onDismiss: onDismissReminder
                    )
                }

                if viewModel.didSave {
                    SavedRecordBanner(
                        personName: viewModel.lastSavedPersonName ?? "この人",
                        isUndoing: viewModel.isUndoing,
                        onUndo: {
                            Task { await viewModel.undoLastSavedRecord() }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let errorMessage = displayedErrorMessage {
                    RecordErrorBanner(message: errorMessage) {
                        isErrorDismissed = true
                    }
                }

                RecordSection(
                    title: "だれと",
                    detail: "名前だけで始められます",
                    symbol: "person.crop.circle.badge.plus"
                ) {
                    if let selectedPerson = viewModel.selectedPerson {
                        SelectedPersonToken(person: selectedPerson) {
                            viewModel.clearSelectedPerson()
                            focusedField = .name
                        }
                    } else {
                        TextField("名前・あだ名", text: Binding(
                            get: { viewModel.name },
                            set: { viewModel.updateName($0) }
                        ))
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($focusedField, equals: .name)
                        .recordInputSurface()

                        if !viewModel.suggestions.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(viewModel.suggestions, id: \.id) { person in
                                    SuggestionRow(person: person) {
                                        viewModel.select(person: person)
                                        focusedField = nil
                                    }

                                    if person.id != viewModel.suggestions.last?.id {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                            .background(
                                Color(uiColor: .tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                    }
                }

                RecordSection(
                    title: "タグ",
                    detail: "覚えておきたい場面を選べます",
                    symbol: "number"
                ) {
                    if viewModel.isLoading, viewModel.tags.isEmpty {
                        ProgressView("タグを読み込み中…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HitoshioriDesign.Spacing.small)
                    } else if viewModel.tags.isEmpty, viewModel.addedTagNames.isEmpty {
                        Text("よく使うタグは、記録するとここに並びます")
                            .font(HitoshioriDesign.Typography.metadata)
                            .foregroundStyle(.secondary)
                    } else {
                        TagFlowLayout(spacing: HitoshioriDesign.Spacing.small) {
                            ForEach(viewModel.tags, id: \.id) { tag in
                                TagChip(
                                    name: tag.name,
                                    isSelected: viewModel.selectedTagNames.contains(tag.name)
                                ) {
                                    viewModel.toggleTag(named: tag.name)
                                }
                            }

                            ForEach(viewModel.addedTagNames, id: \.self) { name in
                                AddedTagChip(name: name) {
                                    viewModel.removeAddedTag(named: name)
                                }
                            }
                        }
                        .sensoryFeedback(.selection, trigger: viewModel.selectedTagNames)
                    }

                    HStack(spacing: HitoshioriDesign.Spacing.small) {
                        TextField("タグを入力", text: $viewModel.newTagName)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focusedField, equals: .tag)
                            .onSubmit { viewModel.addNewTag() }

                        Button("追加") {
                            viewModel.addNewTag()
                            focusedField = .tag
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .recordInputSurface()
                }

                RecordSection(
                    title: "話したこと",
                    detail: "話題はひとこと、メモはあとで思い出すための内容です",
                    symbol: "text.bubble"
                ) {
                    VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.small) {
                        Text("話題")
                            .font(.subheadline.weight(.semibold))
                        TextField("例：同じイベントで会った", text: $viewModel.topic)
                            .focused($focusedField, equals: .topic)
                            .recordInputSurface()
                    }

                    VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.small) {
                        HStack {
                            Text("メモ")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("任意")
                                .font(HitoshioriDesign.Typography.metadata)
                                .foregroundStyle(.secondary)
                        }

                        VoiceMemoButton(
                            title: microphoneButtonTitle,
                            isRecording: transcriber.isRecording,
                            isDisabled: transcriber.isRequestingPermission ||
                                transcriber.isFinishing ||
                                transcriber.needsSettings
                        ) {
                            if transcriber.isRecording {
                                transcriber.stop()
                            } else {
                                Task { await viewModel.startVoiceMemo(using: transcriber) }
                            }
                        }

                        voiceMemoStatus

                        ZStack(alignment: .topLeading) {
                            if viewModel.memo.isEmpty {
                                Text("印象に残ったこと、次に話したいことなど")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $viewModel.memo)
                                .focused($focusedField, equals: .memo)
                                .scrollContentBackground(.hidden)
                                .accessibilityLabel("メモ（任意）")
                                .disabled(transcriber.isRecording || transcriber.isFinishing)
                        }
                        .frame(minHeight: 112)
                        .padding(HitoshioriDesign.Spacing.small)
                        .background(
                            Color(uiColor: .tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }

                    if transcriber.needsSettings {
                        Divider()
                        Text("音声メモにはマイクと音声認識の許可が必要です。")
                            .font(HitoshioriDesign.Typography.metadata)
                            .foregroundStyle(.secondary)
                        Button("設定を開く") {
                            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(settingsURL)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, HitoshioriDesign.Spacing.large)
            .padding(.top, 20)
            .padding(.bottom, HitoshioriDesign.Spacing.large)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveBar
        }
        .refreshable { await viewModel.load() }
        .sensoryFeedback(.success, trigger: viewModel.didSave)
        .animation(.default, value: viewModel.didSave)
        .task { await viewModel.load() }
        .task { transcriber.refreshPermissionState() }
        .task(id: viewModel.didSave) {
            guard viewModel.didSave else { return }

            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            viewModel.dismissSavedFeedback()
        }
        .onChange(of: combinedErrorMessage) { _, _ in
            isErrorDismissed = false
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    focusedField = nil
                }
            }
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

    private var combinedErrorMessage: String? {
        ErrorMessageText.combined([
            transcriber.errorMessage,
            viewModel.errorMessage,
            reminderErrorMessage
        ])
    }

    private var displayedErrorMessage: String? {
        isErrorDismissed ? nil : combinedErrorMessage
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                focusedField = nil
                Task { await saveRecord() }
            } label: {
                HStack(spacing: HitoshioriDesign.Spacing.small) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bookmark.fill")
                    }
                    Text(viewModel.isSaving ? "記録中…" : "栞を挟む")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSave)
            .padding(.horizontal, HitoshioriDesign.Spacing.large)
            .padding(.vertical, HitoshioriDesign.Spacing.small)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var voiceMemoStatus: some View {
        if transcriber.isRecording {
            Label("録音・文字起こし中", systemImage: "waveform")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(HitoshioriDesign.Palette.danger)
                .frame(minHeight: 20, alignment: .leading)
        } else if transcriber.isFinishing {
            HStack(spacing: HitoshioriDesign.Spacing.small) {
                ProgressView()
                Text("文字起こしを完了中…")
                    .font(HitoshioriDesign.Typography.metadata)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 20, alignment: .leading)
        } else if transcriber.isRequestingPermission {
            HStack(spacing: HitoshioriDesign.Spacing.small) {
                ProgressView()
                Text("マイクと音声認識を確認中…")
                    .font(HitoshioriDesign.Typography.metadata)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 20, alignment: .leading)
        } else {
            Color.clear
                .frame(height: 20)
                .accessibilityHidden(true)
        }
    }

    private func finishVoiceMemoIfNeeded() {
        guard transcriber.isRecording || transcriber.isFinishing else { return }

        Task { await viewModel.stopVoiceMemo(using: transcriber) }
    }

    private func saveRecord() async {
        let reminderPersonID = reminder?.person.id
        let selectedPersonID = viewModel.selectedPerson?.id

        await viewModel.save(using: transcriber)

        onRecordFinished(viewModel.didSave, selectedPersonID == reminderPersonID ? selectedPersonID : nil)
    }

}
// swiftlint:enable type_body_length

private struct VoiceMemoButton: View {
    let title: String
    let isRecording: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: isRecording ? "stop.circle.fill" : "mic")
        }
        .disabled(isDisabled)
    }

    @ViewBuilder
    var body: some View {
        if isRecording {
            button
                .buttonStyle(.borderedProminent)
                .tint(HitoshioriDesign.Palette.danger)
        } else {
            button
                .buttonStyle(.bordered)
        }
    }
}

private enum RecordField: Hashable {
    case name
    case tag
    case topic
    case memo
}

private struct RecordHeader: View {
    var body: some View {
        HStack(alignment: .top, spacing: HitoshioriDesign.Spacing.medium) {
            Image(systemName: "bookmark.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 52)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.xSmall) {
                Text("今日、誰と会った？")
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text("あとで思い出せるように、ひとことだけ残しましょう。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RecordSection<Content: View>: View {
    let title: String
    let detail: String
    let symbol: String
    @ViewBuilder let content: Content

    init(
        title: String,
        detail: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: HitoshioriDesign.Spacing.small) {
                Image(systemName: symbol)
                    .foregroundStyle(.tint)
                    .frame(width: 20)
                Text(title)
                    .font(HitoshioriDesign.Typography.sectionTitle)
                Text(detail)
                    .font(HitoshioriDesign.Typography.metadata)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            content
        }
        .padding(HitoshioriDesign.Spacing.large)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: HitoshioriDesign.CornerRadius.card, style: .continuous)
        )
    }
}

private struct SelectedPersonToken: View {
    let person: Person
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: HitoshioriDesign.Spacing.small) {
            Image(systemName: "person.fill.checkmark")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body.weight(.semibold))
                Text("既存の人物として記録します")
                    .font(HitoshioriDesign.Typography.metadata)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("選択を解除", action: onClear)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .padding(HitoshioriDesign.Spacing.medium)
        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct SuggestionRow: View {
    let person: Person
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: HitoshioriDesign.Spacing.medium) {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(
                        "\(EncounterDateText.relativeDescription(for: person.lastEncounteredAt)) ・ " +
                            "\(person.encountersCount)回記録"
                    )
                        .font(HitoshioriDesign.Typography.metadata)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, HitoshioriDesign.Spacing.medium)
            .frame(minHeight: 56)
        }
        .buttonStyle(.plain)
        .accessibilityHint("既存の人物として選択します")
    }
}

private struct SavedRecordBanner: View {
    let personName: String
    let isUndoing: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: HitoshioriDesign.Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(HitoshioriDesign.Palette.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(personName)さんに栞を挟みました")
                    .font(.subheadline.weight(.semibold))
                Text("今なら保存を取り消せます")
                    .font(HitoshioriDesign.Typography.metadata)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(isUndoing ? "取り消し中…" : "取り消す", action: onUndo)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .disabled(isUndoing)
        }
        .padding(HitoshioriDesign.Spacing.medium)
        .background(
            HitoshioriDesign.Palette.success.opacity(0.12),
            in: RoundedRectangle(cornerRadius: HitoshioriDesign.CornerRadius.card, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct RecordErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: HitoshioriDesign.Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(HitoshioriDesign.Palette.danger)
            Text(message)
                .font(HitoshioriDesign.Typography.metadata)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("閉じる", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .accessibilityLabel("エラーを閉じる")
        }
        .padding(HitoshioriDesign.Spacing.medium)
        .background(
            HitoshioriDesign.Palette.danger.opacity(0.12),
            in: RoundedRectangle(cornerRadius: HitoshioriDesign.CornerRadius.card, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct TagChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                }
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? HitoshioriDesign.Palette.selectedChipText : .primary)
        .background {
            Capsule().fill(
                isSelected
                    ? AnyShapeStyle(.tint)
                    : AnyShapeStyle(HitoshioriDesign.Palette.chipBackground)
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AddedTagChip: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .background(.tint.opacity(0.12), in: Capsule())
        .accessibilityLabel("\(name)を削除")
    }
}

private struct TagFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let layout = rows(for: proposal.width, subviews: subviews)
        let width = proposal.width ?? layout.map(\.width).max() ?? 0
        let height = layout.last.map { $0.offsetY + $0.height } ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let layout = rows(for: bounds.width, subviews: subviews)
        for row in layout {
            var originX = bounds.minX
            for subviewIndex in row.indices {
                let size = subviews[subviewIndex].sizeThatFits(.unspecified)
                subviews[subviewIndex].place(
                    at: CGPoint(x: originX, y: bounds.minY + row.offsetY),
                    proposal: ProposedViewSize(size)
                )
                originX += size.width + (subviewIndex == row.indices.last ? 0 : spacing)
            }
        }
    }

    private func rows(for availableWidth: CGFloat?, subviews: Subviews) -> [TagFlowRow] {
        let maximumWidth = availableWidth ?? .greatestFiniteMagnitude
        var rows: [TagFlowRow] = []
        var currentIndices: [Int] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        var rowY: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = currentIndices.isEmpty ? size.width : currentWidth + spacing + size.width

            if !currentIndices.isEmpty, proposedWidth > maximumWidth {
                rows.append(
                    TagFlowRow(
                        indices: currentIndices,
                        width: currentWidth,
                        height: currentHeight,
                        offsetY: rowY
                    )
                )
                rowY += currentHeight + spacing
                currentIndices = []
                currentWidth = 0
                currentHeight = 0
            }

            currentIndices.append(index)
            currentWidth += currentIndices.count == 1 ? size.width : spacing + size.width
            currentHeight = max(currentHeight, size.height)
        }

        if !currentIndices.isEmpty {
            rows.append(
                TagFlowRow(
                    indices: currentIndices,
                    width: currentWidth,
                    height: currentHeight,
                    offsetY: rowY
                )
            )
        }

        return rows
    }
}

private struct TagFlowRow {
    let indices: [Int]
    let width: CGFloat
    let height: CGFloat
    let offsetY: CGFloat
}

private extension View {
    func recordInputSurface() -> some View {
        padding(.horizontal, HitoshioriDesign.Spacing.medium)
            .frame(minHeight: 48)
            .background(
                Color(uiColor: .tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

#Preview {
    ContentView()
}

// swiftlint:enable file_length
