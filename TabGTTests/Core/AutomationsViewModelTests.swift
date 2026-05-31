import Foundation
import Testing
@testable import TabGT

@MainActor
struct AutomationsViewModelTests {
    @Test func liveStartsWithNoRulesWhenStorageIsEmpty() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let viewModel = AutomationsViewModel(
            clipRepository: LocalClipTrayRepository(customBaseURL: directory),
            ruleRepository: LocalAutomationRuleRepository(customBaseURL: directory)
        )

        #expect(viewModel.rules.isEmpty)
        #expect(viewModel.capturedClips.isEmpty)
    }

    @Test func saveClipEditorDraftUpdatesStoredClip() {
        let clipID = UUID(uuidString: "00000000-0000-0000-0000-000000000901")!
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let viewModel = AutomationsViewModel(
            capturedClips: [
                CapturedClip(
                    id: clipID,
                    value: "PROJ-1",
                    sourceLabel: "Manual",
                    capturedAt: Date(),
                    description: "Before"
                )
            ],
            clipRepository: LocalClipTrayRepository(customBaseURL: directory),
            ruleRepository: LocalAutomationRuleRepository(customBaseURL: directory)
        )

        viewModel.saveClipEditorDraft(ClipDraft(clip: CapturedClip(
            id: clipID,
            value: "PROJ-99",
            sourceLabel: "Manual",
            capturedAt: Date(),
            description: "After"
        )))

        #expect(viewModel.capturedClips.count == 1)
        #expect(viewModel.capturedClips[0].value == "PROJ-99")
        #expect(viewModel.capturedClips[0].description == "After")

        let reloaded = try? LocalClipTrayRepository(customBaseURL: directory).loadAll()
        #expect(reloaded?.first?.value == "PROJ-99")
        #expect(reloaded?.first?.description == "After")
    }
}
