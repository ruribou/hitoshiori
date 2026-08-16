import SwiftUI

@MainActor
struct PeopleListView: View {
    @State private var store: PeopleStore
    @Binding private var path: [Int]

    private let client: any PeopleAPIClient

    init(
        store: PeopleStore = PeopleStore(),
        client: any PeopleAPIClient = APIClient.development,
        path: Binding<[Int]>
    ) {
        _store = State(initialValue: store)
        _path = path
        self.client = client
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(store.people, id: \.id) { person in
                    NavigationLink(value: person.id) {
                        PersonRow(person: person)
                    }
                }

                if let errorMessage = store.errorMessage {
                    ErrorMessageRow(message: errorMessage)
                }
            }
            .overlay {
                if !store.hasLoaded {
                    ProgressView("人物を読み込み中…")
                } else if store.people.isEmpty, store.errorMessage == nil {
                    ContentUnavailableView(
                        "まだ人物の記録はありません",
                        systemImage: "person.2",
                        description: Text("記録すると、ここに人が並びます")
                    )
                }
            }
            .navigationTitle("人物")
            .refreshable { await store.load() }
            .task { await store.load() }
            .navigationDestination(for: Int.self) { personID in
                PersonDetailView(personID: personID, client: client, peopleStore: store)
            }
        }
    }
}

@MainActor
struct PersonDetailView: View {
    let personID: Int

    @State private var viewModel: PersonDetailViewModel
    @State private var isEditing = false
    @State private var didSaveEdit = false
    @State private var draftName = ""
    @State private var draftNote = ""

    init(
        personID: Int,
        client: any PeopleAPIClient = APIClient.development,
        peopleStore: PeopleStore? = nil
    ) {
        self.personID = personID
        _viewModel = State(
            initialValue: PersonDetailViewModel(client: client, peopleStore: peopleStore)
        )
    }

    var body: some View {
        List {
            if let person = viewModel.person {
                Section {
                    LabeledContent("名前", value: person.name)

                    if !person.note.isEmpty {
                        VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.small) {
                            Text("メモ")
                                .font(.subheadline.weight(.semibold))
                            Text(person.note)
                                .textSelection(.enabled)
                        }
                    }
                }

                Section("接触履歴") {
                    if person.encounters.isEmpty {
                        Text("接触履歴はまだありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(person.encounters, id: \.id) { encounter in
                            EncounterHistoryRow(encounter: encounter)
                        }
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                ErrorMessageRow(message: errorMessage)
            }
        }
        .overlay {
            if !viewModel.hasLoaded {
                ProgressView("人物を読み込み中…")
            }
        }
        .navigationTitle(viewModel.person?.name ?? "人物の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("編集") {
                    openEditor()
                }
                .disabled(viewModel.person == nil)
            }
        }
        .refreshable { await viewModel.load(id: personID) }
        .task { await viewModel.load(id: personID) }
        .sheet(isPresented: $isEditing, onDismiss: cancelEditingIfNeeded) {
            editor
        }
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section("人物") {
                    TextField("名前・あだ名", text: $draftName)
                        .textContentType(.name)

                    TextEditor(text: $draftNote)
                        .frame(minHeight: 120)
                        .accessibilityLabel("メモ")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ErrorMessageLabel(message: errorMessage)
                    }
                }
            }
            .navigationTitle("人物を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        isEditing = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            let didSave = await viewModel.save(
                                id: personID,
                                name: draftName,
                                note: draftNote
                            )
                            guard didSave else { return }

                            didSaveEdit = true
                            isEditing = false
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func openEditor() {
        guard let person = viewModel.person else { return }

        draftName = person.name
        draftNote = person.note
        didSaveEdit = false
        viewModel.beginEditing()
        isEditing = true
    }

    private func cancelEditingIfNeeded() {
        guard !didSaveEdit else { return }
        viewModel.cancelEditing()
    }
}

private struct PersonRow: View {
    let person: Person

    var body: some View {
        VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.xSmall) {
            Text(person.name)
                .font(.body.weight(.semibold))

            HStack(spacing: HitoshioriDesign.Spacing.medium) {
                Text(EncounterDateText.relativeDescription(for: person.lastEncounteredAt))
                Text("\(person.encountersCount)回記録")
            }
            .font(HitoshioriDesign.Typography.metadata)
            .foregroundStyle(.secondary)
        }
    }
}

private struct EncounterHistoryRow: View {
    let encounter: EncounterHistory

    var body: some View {
        VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.medium) {
            Text(encounter.metAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline.weight(.semibold))

            if let topic = encounter.topic, !topic.isEmpty {
                Text(topic)
            }

            TagListText(tags: encounter.tags)

            if let memo = encounter.memo, !memo.isEmpty {
                Text(memo)
                    .font(HitoshioriDesign.Typography.metadata)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, HitoshioriDesign.Spacing.xxSmall)
    }
}

private struct ErrorMessageRow: View {
    let message: String

    var body: some View {
        ErrorMessageLabel(message: message)
    }
}

private struct PeopleListPreview: View {
    @State private var path: [Int] = []

    var body: some View {
        PeopleListView(path: $path)
    }
}

#Preview("人物一覧") {
    PeopleListPreview()
}
