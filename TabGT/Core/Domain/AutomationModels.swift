import Foundation

enum AutomationKind: String, CaseIterable, Hashable, Identifiable, Codable {
    case commandCapture
    case urlExtractor
    case gitBranchWatch
    case outputRegex
    case sessionBookmark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .commandCapture:
            return "Command Capture"
        case .urlExtractor:
            return "URL Extractor"
        case .gitBranchWatch:
            return "Git Branch Watch"
        case .outputRegex:
            return "Output Regex"
        case .sessionBookmark:
            return "Session Bookmark"
        }
    }

    var systemImage: String {
        switch self {
        case .commandCapture:
            return "terminal"
        case .urlExtractor:
            return "link"
        case .gitBranchWatch:
            return "arrow.triangle.branch"
        case .outputRegex:
            return "text.magnifyingglass"
        case .sessionBookmark:
            return "bookmark"
        }
    }

    var summary: String {
        switch self {
        case .commandCapture:
            return "Capture arguments from slash commands or shell input."
        case .urlExtractor:
            return "Pull URLs from terminal output into the clip tray."
        case .gitBranchWatch:
            return "Save branch names from git checkout or switch commands."
        case .outputRegex:
            return "Extract any value using a custom regular expression."
        case .sessionBookmark:
            return "Store notes or paths sent through a bookmark command."
        }
    }
}

enum AutomationSource: String, CaseIterable, Hashable, Identifiable, Codable {
    case commandInput
    case terminalOutput
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .commandInput:
            return "Command input"
        case .terminalOutput:
            return "Terminal output"
        case .both:
            return "Input and output"
        }
    }
}

enum AutomationCaptureMode: String, CaseIterable, Hashable, Identifiable, Codable {
    case argumentAfterTrigger
    case regexGroup
    case entireMatch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .argumentAfterTrigger:
            return "Argument after trigger"
        case .regexGroup:
            return "Regex capture group"
        case .entireMatch:
            return "Entire regex match"
        }
    }

    var hint: String {
        switch self {
        case .argumentAfterTrigger:
            return "Uses text that follows the trigger pattern."
        case .regexGroup:
            return "Uses a capture group from the extract pattern."
        case .entireMatch:
            return "Uses the full regex match as the captured value."
        }
    }
}

struct AutomationRule: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var kind: AutomationKind
    var triggerPattern: String
    var isEnabled: Bool
    var notes: String = ""
    var source: AutomationSource = .commandInput
    var captureMode: AutomationCaptureMode = .argumentAfterTrigger
    var extractPattern: String = ""
    var captureGroupIndex: Int = 1
    var caseSensitive: Bool = true
    var keepOnlyLatest: Bool = false
}

struct CapturedClip: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var value: String
    var sourceLabel: String
    var capturedAt: Date
    var description: String?
    var ruleID: UUID?
    var keepOnlyLatest: Bool = false
}

struct ClipDraft: Hashable {
    var id: UUID?
    var value: String = ""
    var description: String = ""

    var isEditing: Bool { id != nil }

    init(clip: CapturedClip? = nil) {
        guard let clip else { return }
        id = clip.id
        value = clip.value
        description = clip.description ?? ""
    }

    var isValid: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct AutomationDraft: Hashable {
    var id: UUID?
    var name: String = ""
    var kind: AutomationKind = .commandCapture
    var triggerPattern: String = ""
    var isEnabled: Bool = true
    var notes: String = ""
    var source: AutomationSource = .commandInput
    var captureMode: AutomationCaptureMode = .argumentAfterTrigger
    var extractPattern: String = ""
    var captureGroupIndex: Int = 1
    var caseSensitive: Bool = true
    var keepOnlyLatest: Bool = false

    var isEditing: Bool { id != nil }

    init(rule: AutomationRule? = nil) {
        guard let rule else { return }
        id = rule.id
        name = rule.name
        kind = rule.kind
        triggerPattern = rule.triggerPattern
        isEnabled = rule.isEnabled
        notes = rule.notes
        source = rule.source
        captureMode = rule.captureMode
        extractPattern = rule.extractPattern
        captureGroupIndex = rule.captureGroupIndex
        caseSensitive = rule.caseSensitive
        keepOnlyLatest = rule.keepOnlyLatest
    }

    func asRule() -> AutomationRule {
        AutomationRule(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            triggerPattern: triggerPattern.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            source: source,
            captureMode: captureMode,
            extractPattern: extractPattern.trimmingCharacters(in: .whitespacesAndNewlines),
            captureGroupIndex: max(0, captureGroupIndex),
            caseSensitive: caseSensitive,
            keepOnlyLatest: keepOnlyLatest
        )
    }

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrigger = triggerPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedTrigger.isEmpty else { return false }

        switch captureMode {
        case .argumentAfterTrigger:
            return true
        case .regexGroup, .entireMatch:
            return !extractPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

extension AutomationKind {
    func defaultDraft() -> AutomationDraft {
        var draft = AutomationDraft()
        draft.kind = self

        switch self {
        case .commandCapture:
            draft.name = "Custom Command"
            draft.triggerPattern = "/my-command"
            draft.source = .commandInput
            draft.captureMode = .argumentAfterTrigger
        case .urlExtractor:
            draft.name = "URL Extractor"
            draft.triggerPattern = "https?://"
            draft.source = .terminalOutput
            draft.captureMode = .entireMatch
            draft.extractPattern = #"https?://[^\s]+"#
            draft.captureGroupIndex = 0
        case .gitBranchWatch:
            draft.name = "Git Branch Watch"
            draft.triggerPattern = "git checkout|git switch"
            draft.source = .commandInput
            draft.captureMode = .argumentAfterTrigger
        case .outputRegex:
            draft.name = "Output Regex"
            draft.triggerPattern = ".*"
            draft.source = .terminalOutput
            draft.captureMode = .regexGroup
            draft.extractPattern = #"([A-Z]+-\d+)"#
            draft.captureGroupIndex = 1
        case .sessionBookmark:
            draft.name = "Session Bookmark"
            draft.triggerPattern = "/bookmark"
            draft.source = .commandInput
            draft.captureMode = .argumentAfterTrigger
        }

        return draft
    }

    /// Sample terminal line shown in the automation editor preview.
    func previewSample(for draft: AutomationDraft) -> String {
        switch self {
        case .commandCapture, .sessionBookmark:
            let trigger = draft.triggerPattern.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(trigger.isEmpty ? "/my-command" : trigger) captured-value"
        case .gitBranchWatch:
            return "git checkout feature/example"
        case .urlExtractor:
            return "Deploy ready: https://example.internal/releases/42"
        case .outputRegex:
            return "Sample line with PROJ-12345 in output"
        }
    }
}
