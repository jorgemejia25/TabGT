import AppKit
import Combine
import Foundation

@MainActor
final class AutomationsViewModel: ObservableObject {
    @Published var rules: [AutomationRule]
    @Published private(set) var capturedClips: [CapturedClip]
    @Published var editorDraft = AutomationDraft()
    @Published var isEditorPresented = false
    @Published var clipEditorDraft = ClipDraft()
    @Published var isClipEditorPresented = false

    private let clipRepository: LocalClipTrayRepository
    private let ruleRepository: LocalAutomationRuleRepository

    init(
        rules: [AutomationRule] = [],
        capturedClips: [CapturedClip] = [],
        clipRepository: LocalClipTrayRepository? = nil,
        ruleRepository: LocalAutomationRuleRepository? = nil
    ) {
        self.rules = rules
        self.capturedClips = capturedClips
        self.clipRepository = clipRepository ?? LocalClipTrayRepository()
        self.ruleRepository = ruleRepository ?? LocalAutomationRuleRepository()
    }

    static func live() -> AutomationsViewModel {
        let clipRepo = LocalClipTrayRepository()
        let ruleRepo = LocalAutomationRuleRepository()
        let clips = (try? clipRepo.loadAll()) ?? []
        let rules = (try? ruleRepo.loadAll()) ?? []
        return AutomationsViewModel(
            rules: rules,
            capturedClips: clips,
            clipRepository: clipRepo,
            ruleRepository: ruleRepo
        )
    }

    static func preview() -> AutomationsViewModel {
        AutomationsViewModel(
            rules: PreviewData.automationRules,
            capturedClips: PreviewData.capturedClips
        )
    }

    func copyToPasteboard(_ clip: CapturedClip) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clip.value, forType: .string)
    }

    @discardableResult
    func addManualClip(_ value: String, description: String? = nil) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let trimmedDescription = description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let clip = CapturedClip(
            value: trimmed,
            sourceLabel: "Manual",
            capturedAt: Date(),
            description: trimmedDescription?.isEmpty == false ? trimmedDescription : nil
        )
        insertClip(clip)
        return true
    }

    func addCapturedClip(_ clip: CapturedClip) {
        if clip.keepOnlyLatest, let ruleID = clip.ruleID {
            capturedClips.removeAll { $0.ruleID == ruleID }
        }
        insertClip(clip)
    }

    func removeClip(_ clip: CapturedClip) {
        capturedClips.removeAll { $0.id == clip.id }
        persistClips()
    }

    func presentEditClip(for clip: CapturedClip) {
        clipEditorDraft = ClipDraft(clip: clip)
        isClipEditorPresented = true
    }

    func dismissClipEditor() {
        isClipEditorPresented = false
        clipEditorDraft = ClipDraft()
    }

    func saveClipEditorDraft(_ draft: ClipDraft) {
        guard draft.isValid,
              let clipID = draft.id,
              let index = capturedClips.firstIndex(where: { $0.id == clipID }) else {
            return
        }

        let trimmedValue = draft.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        capturedClips[index].value = trimmedValue
        capturedClips[index].description = trimmedDescription.isEmpty ? nil : trimmedDescription
        persistClips()
        dismissClipEditor()
    }

    func deleteClipFromEditor() {
        guard let clipID = clipEditorDraft.id,
              let clip = capturedClips.first(where: { $0.id == clipID }) else {
            return
        }
        removeClip(clip)
        dismissClipEditor()
    }

    func toggleRule(_ rule: AutomationRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index].isEnabled.toggle()
        persistRules()
    }

    func presentCreateEditor(kind: AutomationKind = .commandCapture) {
        editorDraft = kind.defaultDraft()
        isEditorPresented = true
    }

    func presentEditEditor(for rule: AutomationRule) {
        editorDraft = AutomationDraft(rule: rule)
        isEditorPresented = true
    }

    func dismissEditor() {
        isEditorPresented = false
        editorDraft = AutomationDraft()
    }

    func saveEditorDraft(_ draft: AutomationDraft) {
        guard draft.isValid else { return }
        let rule = draft.asRule()

        if let existingIndex = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[existingIndex] = rule
        } else {
            rules.append(rule)
        }

        persistRules()
        dismissEditor()
    }

    func deleteRule(_ rule: AutomationRule) {
        rules.removeAll { $0.id == rule.id }
        persistRules()
        if editorDraft.id == rule.id {
            dismissEditor()
        }
    }

    func applyKindDefaults(to draft: inout AutomationDraft) {
        let defaults = draft.kind.defaultDraft()
        draft.source = defaults.source
        draft.captureMode = defaults.captureMode
        draft.extractPattern = defaults.extractPattern
        draft.captureGroupIndex = defaults.captureGroupIndex

        if draft.triggerPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.triggerPattern = defaults.triggerPattern
        }
    }

    func previewCapture(sample: String, draft: AutomationDraft) -> String? {
        AutomationCaptureEngine.previewCapture(sample: sample, draft: draft)
    }

    func relativeCaptureTime(for clip: CapturedClip) -> String {
        Self.relativeFormatter.localizedString(for: clip.capturedAt, relativeTo: Date())
    }

    private func insertClip(_ clip: CapturedClip) {
        capturedClips.insert(clip, at: 0)
        persistClips()
    }

    private func persistClips() {
        do {
            try clipRepository.saveAll(capturedClips)
        } catch {
            // Persistence failures are non-fatal for the UI slice.
        }
    }

    private func persistRules() {
        do {
            try ruleRepository.saveAll(rules)
        } catch {
            // Persistence failures are non-fatal for the UI slice.
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
