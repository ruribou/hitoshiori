import Foundation

@MainActor
extension RecordViewModel {
    var tagNamesForSubmission: [String] {
        var names = tags.compactMap { selectedTagNames.contains($0.name) ? $0.name : nil }

        for addedTagName in addedTagNames where !names.contains(addedTagName) {
            names.append(addedTagName)
        }

        let unconfirmedTagName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !unconfirmedTagName.isEmpty, !names.contains(unconfirmedTagName) {
            names.append(unconfirmedTagName)
        }
        return names
    }

    func addNewTag() {
        let trimmedTagName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTagName.isEmpty else { return }

        if let existingTag = tags.first(where: { normalized($0.name) == normalized(trimmedTagName) }) {
            selectedTagNames.insert(existingTag.name)
        } else if !addedTagNames.contains(where: { normalized($0) == normalized(trimmedTagName) }) {
            addedTagNames.append(trimmedTagName)
        }

        newTagName = ""
    }

    func removeAddedTag(named name: String) {
        addedTagNames.removeAll { $0 == name }
    }
}
