import Foundation
import Testing
@testable import TabGT

@MainActor
struct SnippetRepositoryTests {
    @Test func loadAllReturnsEmptyWhenFileMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LocalSnippetRepository(customBaseURL: directory)

        let snippets = try repository.loadAll()
        #expect(snippets.isEmpty)
    }

    @Test func saveAndLoadRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = LocalSnippetRepository(customBaseURL: directory)

        let snippets = [
            CommandSnippet(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000701")!,
                title: "Git Status",
                trigger: "gs",
                command: "git status --short",
                tags: ["git"]
            ),
            CommandSnippet(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000702")!,
                title: "List Files",
                trigger: "ls",
                command: "ls -la",
                tags: []
            )
        ]

        try repository.saveAll(snippets)
        let loaded = try repository.loadAll()

        #expect(loaded.count == 2)
        #expect(loaded.map(\.trigger).sorted() == ["gs", "ls"])
        #expect(loaded.first(where: { $0.trigger == "gs" })?.command == "git status --short")
    }

    @Test func documentEncodingRoundTrip() throws {
        let snippets = PreviewData.commandSnippets
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()

        let document = SnippetsDocument(snippets: snippets)
        let data = try encoder.encode(document)
        let decoded = try decoder.decode(SnippetsDocument.self, from: data)

        #expect(decoded.snippets.count == snippets.count)
        #expect(decoded.snippets.map(\.trigger).sorted() == snippets.map(\.trigger).sorted())
    }
}

@MainActor
struct SnippetExpansionEngineTests {
    @Test func currentTokenReturnsLastWord() {
        #expect(SnippetExpansionEngine.currentToken(from: "tabgt % gs") == "gs")
        #expect(SnippetExpansionEngine.currentToken(from: "deploy") == "deploy")
        #expect(SnippetExpansionEngine.currentToken(from: "") == "")
    }

    @Test func matchingSnippetPrefersExactTrigger() {
        let snippets = PreviewData.commandSnippets
        let match = SnippetExpansionEngine.matchingSnippet(for: "gs", in: snippets)
        #expect(match?.title == "Git Status")
    }

    @Test func expansionDeltaComputesBackspaces() {
        let delta = SnippetExpansionEngine.expansionDelta(from: "gs", to: "git status --short")
        #expect(delta.backspaces == 2)
        #expect(delta.text == "git status --short")
    }
}

@MainActor
struct SnippetsViewModelTests {
    @Test @MainActor func saveRejectsDuplicateTrigger() {
        let bridge = SessionInputBridge()
        let viewModel = SnippetsViewModel(
            snippets: [
                CommandSnippet(title: "Existing", trigger: "gs", command: "git status")
            ],
            inputBridge: bridge
        )

        viewModel.presentCreateEditor()
        viewModel.editorDraft.title = "Duplicate"
        viewModel.editorDraft.trigger = "GS"
        viewModel.editorDraft.command = "git diff"

        let saved = viewModel.saveEditorDraft(viewModel.editorDraft)
        #expect(saved == false)
        #expect(viewModel.editorError != nil)
        #expect(viewModel.snippets.count == 1)
    }
}
