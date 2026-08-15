import SwiftUI

@MainActor
struct PeopleListView: View {
    @State private var viewModel: PeopleListViewModel

    private let client: any PeopleAPIClient

    init(client: any PeopleAPIClient = APIClient.development) {
        self.client = client
        _viewModel = State(initialValue: PeopleListViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.people.isEmpty, !viewModel.isLoading, viewModel.errorMessage == nil {
                    ContentUnavailableView(
                        "まだ人物の記録はありません",
                        systemImage: "person.2",
                        description: Text("記録すると、ここに人が並びます")
                    )
                } else {
                    ForEach(viewModel.people, id: \.id) { person in
                        NavigationLink {
                            PersonDetailView(personID: person.id, client: client) {
                                await viewModel.load()
                            }
                        } label: {
                            PersonRow(person: person)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    ErrorMessageRow(message: errorMessage)
                }
            }
            .overlay {
                if viewModel.isLoading, viewModel.people.isEmpty {
                    ProgressView("人物を読み込み中…")
                }
            }
            .navigationTitle("人物")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }
}

@MainActor
struct PersonDetailView: View {
    let personID: Int
    let didUpdate: @MainActor () async -> Void

    @State private var viewModel: PersonDetailViewModel
    @State private var isEditing = false
    @State private var draftName = ""
    @State private var draftNote = ""

    init(
        personID: Int,
        client: any PeopleAPIClient = APIClient.development,
        didUpdate: @escaping @MainActor () async -> Void = {}
    ) {
        self.personID = personID
        self.didUpdate = didUpdate
        _viewModel = State(initialValue: PersonDetailViewModel(client: client))
    }

    var body: some View {
        List {
            if let person = viewModel.person {
                Section {
                    LabeledContent("名前", value: person.name)

                    if !person.note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
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
            if viewModel.isLoading, viewModel.person == nil {
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
        .sheet(isPresented: $isEditing) {
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
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
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

                            isEditing = false
                            await didUpdate()
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
        viewModel.beginEditing()
        isEditing = true
    }
}

private struct PersonRow: View {
    let person: Person

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(person.name)
                .font(.body.weight(.semibold))

            HStack(spacing: 8) {
                Text(EncounterDateText.relativeDescription(for: person.lastEncounteredAt))
                Text("\(person.encountersCount)回記録")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

private struct EncounterHistoryRow: View {
    let encounter: EncounterHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(encounter.metAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline.weight(.semibold))

            if let topic = encounter.topic, !topic.isEmpty {
                Text(topic)
            }

            if !encounter.tags.isEmpty {
                Text(encounter.tags.map { "#\($0.name)" }.joined(separator: " "))
                    .font(.footnote)
                    .foregroundStyle(.tint)
            }

            if let memo = encounter.memo, !memo.isEmpty {
                Text(memo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ErrorMessageRow: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
    }
}

#Preview("人物一覧") {
    PeopleListView()
}
