import Combine
import Foundation

@MainActor
final class SnippetsViewModel: ObservableObject {
    struct InputFill: Equatable {
        let sessionID: UUID
        let text: String
        let submit: Bool
    }

    @Published var snippets: [CommandSnippet]
    @Published var editorDraft = SnippetDraft()
    @Published var isEditorPresented = false
    @Published var editorError: String?
    @Published private(set) var pendingInputFill: InputFill?

    private let inputBridge: SessionInputBridge
    private let repository: LocalSnippetRepository
    private weak var sessions: SessionsViewModel?
    private weak var connections: ConnectionsViewModel?
    private weak var terminalProfiles: TerminalProfilesViewModel?

    init(
        snippets: [CommandSnippet],
        inputBridge: SessionInputBridge,
        repository: LocalSnippetRepository? = nil
    ) {
        self.snippets = snippets
        self.inputBridge = inputBridge
        self.repository = repository ?? LocalSnippetRepository()
    }

    static func live(inputBridge: SessionInputBridge) -> SnippetsViewModel {
        let repository = LocalSnippetRepository()
        let snippets = (try? repository.loadAll()) ?? []
        return SnippetsViewModel(snippets: snippets, inputBridge: inputBridge, repository: repository)
    }

    static func preview(inputBridge: SessionInputBridge) -> SnippetsViewModel {
        SnippetsViewModel(
            snippets: PreviewData.commandSnippets,
            inputBridge: inputBridge
        )
    }

    func wireLaunchDependencies(
        sessions: SessionsViewModel,
        connections: ConnectionsViewModel,
        terminalProfiles: TerminalProfilesViewModel
    ) {
        self.sessions = sessions
        self.connections = connections
        self.terminalProfiles = terminalProfiles
    }

    func profileContext(for session: TerminalSession) -> SnippetProfileContext? {
        guard let connections, let terminalProfiles else { return nil }
        return SnippetLaunchResolver.profileContext(
            for: session,
            hosts: connections.hosts,
            profiles: terminalProfiles.profiles
        )
    }

    func matchingSnippets(for input: String) -> [CommandSnippet] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }

        return snippets
            .filter { snippet in
                snippet.trigger.lowercased().hasPrefix(query)
                    || snippet.title.lowercased().contains(query)
                    || snippet.command.lowercased().hasPrefix(query)
            }
            .sorted { lhs, rhs in
                let lhsExact = lhs.trigger.lowercased() == query
                let rhsExact = rhs.trigger.lowercased() == query
                if lhsExact != rhsExact { return lhsExact }
                return lhs.trigger.count < rhs.trigger.count
            }
    }

    func presentCreateEditor(prefill: SnippetDraft? = nil) {
        editorDraft = prefill ?? SnippetDraft()
        editorError = nil
        isEditorPresented = true
    }

    func presentEditEditor(for snippet: CommandSnippet) {
        editorDraft = SnippetDraft(snippet: snippet)
        editorError = nil
        isEditorPresented = true
    }

    func dismissEditor() {
        isEditorPresented = false
        editorDraft = SnippetDraft()
        editorError = nil
    }

    func applyAutomaticTrigger(to draft: inout SnippetDraft) {
        guard draft.autoTriggerEnabled else { return }
        draft.trigger = SnippetTriggerSuggester.suggest(
            from: draft.title,
            command: draft.command,
            existingTriggers: Set(snippets.map(\.trigger).filter { $0 != draft.trigger })
        )
    }

    @discardableResult
    func saveEditorDraft(_ draft: SnippetDraft) -> Bool {
        guard draft.isValid else { return false }
        let snippet = draft.asSnippet()

        if let conflict = triggerConflict(for: snippet) {
            editorError = "Trigger \"\(snippet.trigger)\" is already used by \"\(conflict.title)\"."
            return false
        }

        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
        } else {
            snippets.append(snippet)
        }

        editorError = nil
        persist()
        dismissEditor()
        return true
    }

    func deleteSnippet(_ snippet: CommandSnippet) {
        snippets.removeAll { $0.id == snippet.id }
        if editorDraft.id == snippet.id {
            dismissEditor()
        }
        persist()
    }

    func insert(_ snippet: CommandSnippet, for sessionID: UUID, submit: Bool) {
        inputBridge.send(text: snippet.command, to: sessionID, submit: submit)
        if !submit {
            pendingInputFill = InputFill(sessionID: sessionID, text: snippet.command, submit: false)
        }
    }

    func run(_ snippet: CommandSnippet, from sourceSessionID: UUID) {
        insert(snippet, for: sourceSessionID, submit: true)
    }

    func runInNewTab(_ snippet: CommandSnippet, from sourceSessionID: UUID) {
        guard let sessions,
              let connections,
              let terminalProfiles else {
            return
        }

        SnippetLaunchResolver.launchInNewTab(
            snippet: snippet,
            copying: sourceSessionID,
            sessions: sessions,
            hosts: connections.hosts,
            profiles: terminalProfiles.profiles,
            inputBridge: inputBridge
        )
    }

    func createFromCommand(_ command: String, sessionID: UUID?) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var draft = SnippetDraft()
        draft.title = trimmed.split(separator: " ").first.map(String.init) ?? "Snippet"
        draft.command = trimmed
        applyAutomaticTrigger(to: &draft)
        presentCreateEditor(prefill: draft)
    }

    func createFromAutomation(_ rule: AutomationRule) {
        var draft = SnippetDraft()
        draft.title = rule.name
        draft.command = rule.triggerPattern.hasSuffix(" ") ? rule.triggerPattern : "\(rule.triggerPattern) "
        draft.notes = rule.notes
        draft.tags = rule.kind.label
        applyAutomaticTrigger(to: &draft)
        presentCreateEditor(prefill: draft)
    }

    func consumePendingInputFill(for sessionID: UUID) -> InputFill? {
        guard let fill = pendingInputFill, fill.sessionID == sessionID else { return nil }
        pendingInputFill = nil
        return fill
    }

    func clearPendingInputFill() {
        pendingInputFill = nil
    }

    private func triggerConflict(for snippet: CommandSnippet) -> CommandSnippet? {
        let normalized = snippet.trigger.lowercased()
        return snippets.first {
            $0.id != snippet.id && $0.trigger.lowercased() == normalized
        }
    }

    private func persist() {
        do {
            try repository.saveAll(snippets)
        } catch {
            // Persistence failures are non-fatal for the UI slice.
        }
    }
}
