import SwiftUI

struct TodayReminderSection: View {
    let reminder: Reminder
    @Bindable var viewModel: RecordViewModel
    @Binding var isVisible: Bool
    let onShowPerson: () -> Void
    @State private var isConfirmingPersonReplacement = false

    var body: some View {
        Section {
            TodayReminderCard(
                reminder: reminder,
                onShowPerson: onShowPerson,
                onRecord: recordReminderPerson,
                onDismiss: { isVisible = false }
            )
        }
        .confirmationDialog(
            "入力中の名前を「\(reminder.person.name)」に置き換えますか？",
            isPresented: $isConfirmingPersonReplacement,
            titleVisibility: .visible
        ) {
            Button("置き換える", role: .destructive) {
                replacePersonInputWithReminder()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("入力中の人物は保存されません。")
        }
    }

    private func recordReminderPerson() {
        if viewModel.selectExistingPersonIfInputIsEmpty(
            id: reminder.person.id,
            name: reminder.person.name
        ) {
            isVisible = false
            return
        }

        isConfirmingPersonReplacement = true
    }

    private func replacePersonInputWithReminder() {
        viewModel.selectExistingPerson(id: reminder.person.id, name: reminder.person.name)
        isVisible = false
    }
}

struct TodayReminderCard: View {
    let reminder: Reminder
    let onShowPerson: () -> Void
    let onRecord: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("今日の一人", systemImage: "bookmark.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)

                Spacer()

                Button("閉じる", systemImage: "xmark") {
                    onDismiss()
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("今日の一人を閉じる")
            }

            Button(action: onShowPerson) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(reminder.person.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let lastEncounterDescription = ReminderCardText.lastEncounterDescription(
                        for: reminder.person.lastEncounteredAt
                    ) {
                        Text(lastEncounterDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let lastEncounter = reminder.person.lastEncounter {
                        if let topic = lastEncounter.topic, !topic.isEmpty {
                            Text(topic)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }

                        TagListText(tags: lastEncounter.tags)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("人物の詳細を開きます")

            Button("記録する", systemImage: "square.and.pencil", action: onRecord)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}

enum ReminderCardText {
    static func lastEncounterDescription(
        for date: Date?,
        relativeTo referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> String? {
        guard let date else { return nil }

        let relativeDescription = EncounterDateText.relativeDescription(
            for: date,
            relativeTo: referenceDate,
            calendar: calendar
        )
        return "最後に会った日: \(relativeDescription)"
    }
}

struct TagListText: View {
    let tags: [Tag]

    var body: some View {
        if !tags.isEmpty {
            Text(tags.map { "#\($0.name)" }.joined(separator: " "))
                .font(.footnote)
                .foregroundStyle(.tint)
        }
    }
}

struct BackendStatusIndicator: View {
    let status: RecordViewModel.BackendStatus

    var body: some View {
        switch status {
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
