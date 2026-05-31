import Foundation

struct SnippetDraft: Hashable {
    var id: UUID?
    var title: String = ""
    var trigger: String = ""
    var command: String = ""
    var tags: String = ""
    var notes: String = ""
    var autoTriggerEnabled: Bool = true

    var isEditing: Bool { id != nil }

    init(snippet: CommandSnippet? = nil) {
        guard let snippet else { return }
        id = snippet.id
        title = snippet.title
        trigger = snippet.trigger
        command = snippet.command
        tags = snippet.tags.joined(separator: ", ")
        notes = snippet.notes
        autoTriggerEnabled = false
    }

    func asSnippet() -> CommandSnippet {
        CommandSnippet(
            id: id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            trigger: trigger.trimmingCharacters(in: .whitespacesAndNewlines),
            command: command.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty },
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum SnippetTriggerSuggester {
    static func suggest(from title: String, command: String, existingTriggers: Set<String>) -> String {
        let commandToken = command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init) ?? ""

        let commandCandidate = sanitize(commandToken
            .replacingOccurrences(of: "/", with: "")
            .prefix(12))

        if !commandCandidate.isEmpty, !existingTriggers.contains(commandCandidate) {
            return commandCandidate
        }

        let words = title
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .map(String.init)
            .filter { !$0.isEmpty }

        if words.count >= 2 {
            let initials = words.prefix(3).compactMap(\.first).map { String($0).lowercased() }.joined()
            if !initials.isEmpty, !existingTriggers.contains(initials) {
                return initials
            }
        }

        let slug = sanitize(title.lowercased().prefix(12))
        return uniqueTrigger(slug, existing: existingTriggers)
    }

    private static func sanitize(_ value: String.SubSequence) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func uniqueTrigger(_ base: String, existing: Set<String>) -> String {
        guard !base.isEmpty else { return "snip" }
        if !existing.contains(base) { return base }

        var index = 2
        while existing.contains("\(base)\(index)") {
            index += 1
        }
        return "\(base)\(index)"
    }
}
