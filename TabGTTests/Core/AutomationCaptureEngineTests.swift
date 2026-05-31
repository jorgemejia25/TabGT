import Foundation
import Testing
@testable import TabGT

struct AutomationCaptureEngineTests {
    @Test func capturesRegexGroupFromOutput() {
        var draft = AutomationDraft()
        draft.captureMode = .regexGroup
        draft.extractPattern = #"([A-Z]+-\d+)"#
        draft.captureGroupIndex = 1
        draft.caseSensitive = true

        #expect(
            AutomationCaptureEngine.previewCapture(
                sample: "Sample line with PROJ-12345 in output",
                draft: draft
            ) == "PROJ-12345"
        )
    }

    @Test func entireMatchStopsAtNonDigitSuffix() {
        var draft = AutomationDraft()
        draft.captureMode = .entireMatch
        draft.extractPattern = #"PREFIX-\d+"#
        draft.caseSensitive = true

        #expect(
            AutomationCaptureEngine.previewCapture(
                sample: "Working on PREFIX-18237 for release",
                draft: draft
            ) == "PREFIX-18237"
        )
        #expect(
            AutomationCaptureEngine.previewCapture(
                sample: "PREFIX-18237-extra",
                draft: draft
            ) == "PREFIX-18237"
        )
        #expect(
            AutomationCaptureEngine.previewCapture(
                sample: "PREFIX-ABC",
                draft: draft
            ) == nil
        )
    }

    @Test func clipDraftValidationRequiresValue() {
        let draft = ClipDraft(clip: CapturedClip(
            value: "PROJ-1",
            sourceLabel: "Manual",
            capturedAt: Date()
        ))
        #expect(draft.isValid)

        var emptyDraft = ClipDraft(clip: CapturedClip(
            value: "PROJ-1",
            sourceLabel: "Manual",
            capturedAt: Date()
        ))
        emptyDraft.value = "   "
        #expect(!emptyDraft.isValid)
    }
}
