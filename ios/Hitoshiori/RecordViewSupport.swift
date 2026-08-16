import SwiftUI

struct TodayReminderSection: View {
    let reminder: Reminder
    let viewModel: RecordViewModel
    let onShowPerson: () -> Void
    let onDismiss: () -> Void
    @State private var isConfirmingPersonReplacement = false

    var body: some View {
        Section {
            TodayReminderCard(
                reminder: reminder,
                onShowPerson: onShowPerson,
                onRecord: recordReminderPerson,
                onDismiss: onDismiss
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
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
            return
        }

        isConfirmingPersonReplacement = true
    }

    private func replacePersonInputWithReminder() {
        viewModel.selectExistingPerson(id: reminder.person.id, name: reminder.person.name)
    }
}

struct TodayReminderCard: View {
    let reminder: Reminder
    let onShowPerson: () -> Void
    let onRecord: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.medium) {
            HStack {
                Label("今日の一人", systemImage: "bookmark.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)

                Spacer()

                Button("閉じる", systemImage: "xmark") {
                    onDismiss()
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                .accessibilityLabel("今日の一人を閉じる")
            }

            Button(action: onShowPerson) {
                VStack(alignment: .leading, spacing: HitoshioriDesign.Spacing.small) {
                    Text(reminder.person.name)
                        .font(HitoshioriDesign.Typography.sectionTitle)
                        .foregroundStyle(.primary)

                    Text(EncounterDateText.relativeDescription(for: reminder.person.lastEncounteredAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

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

            Button("この人で記録をはじめる", systemImage: "person.badge.plus", action: onRecord)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("この人で記録をはじめる")
                .accessibilityHint("人物を選択して、下の記録するボタンで保存します")
        }
        .padding(HitoshioriDesign.Spacing.medium)
        .background(
            HitoshioriDesign.Palette.reminderBackground,
            in: RoundedRectangle(cornerRadius: HitoshioriDesign.CornerRadius.card, style: .continuous)
        )
        .padding(.horizontal, HitoshioriDesign.Spacing.large)
        .padding(.vertical, HitoshioriDesign.Spacing.xSmall)
    }
}

struct TagListText: View {
    let tags: [Tag]

    var body: some View {
        if !tags.isEmpty {
            Text(tags.map { "#\($0.name)" }.joined(separator: " "))
                .font(HitoshioriDesign.Typography.metadata)
                .foregroundStyle(.tint)
        }
    }
}

enum ErrorMessageText {
    static func combined(_ messages: [String?]) -> String? {
        let nonEmptyMessages = messages
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return nonEmptyMessages.isEmpty ? nil : nonEmptyMessages.joined(separator: "\n")
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
                .foregroundStyle(HitoshioriDesign.Palette.success)
                .accessibilityLabel("backend に接続済み")
        case .unreachable:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(HitoshioriDesign.Palette.danger)
                .accessibilityLabel("backend に未接続")
        }
    }
}
