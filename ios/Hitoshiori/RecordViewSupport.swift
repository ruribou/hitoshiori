import SwiftUI

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

                    Text("最後に会った日: \(EncounterDateText.relativeDescription(for: reminder.person.lastEncounteredAt))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let lastEncounter = reminder.person.lastEncounter {
                        if let topic = lastEncounter.topic, !topic.isEmpty {
                            Text(topic)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }

                        if !lastEncounter.tags.isEmpty {
                            Text(lastEncounter.tags.map { "#\($0.name)" }.joined(separator: " "))
                                .font(.footnote)
                                .foregroundStyle(.tint)
                        }
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
