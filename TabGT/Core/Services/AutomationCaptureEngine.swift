import Foundation

enum AutomationCaptureEngine {
    /// Runs all enabled rules matching `source` against every non-empty line in `text`.
    /// Returns one `CapturedClip` per successful match.
    static func processText(
        _ text: String,
        rules: [AutomationRule],
        source: AutomationSource,
        sessionTitle: String
    ) -> [CapturedClip] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { stripANSI($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var clips: [CapturedClip] = []
        for rule in rules where rule.isEnabled && (rule.source == source || rule.source == .both) {
            let draft = AutomationDraft(rule: rule)
            for line in lines {
                if let value = previewCapture(sample: line, draft: draft) {
                    clips.append(CapturedClip(
                        value: value,
                        sourceLabel: "\(rule.name) · \(sessionTitle)",
                        capturedAt: Date(),
                        ruleID: rule.id,
                        keepOnlyLatest: rule.keepOnlyLatest
                    ))
                }
            }
        }
        return clips
    }

    static func stripANSI(_ text: String) -> String {
        // Strips CSI sequences (ESC[...m) and other single-char ESC sequences
        let pattern = "\u{1B}\\[[0-9;]*[A-Za-z]|\u{1B}[^\\[]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    static func previewCapture(sample: String, draft: AutomationDraft) -> String? {
        let trimmedSample = sample.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSample.isEmpty else { return nil }

        switch draft.captureMode {
        case .argumentAfterTrigger:
            return captureArgumentAfterTrigger(in: trimmedSample, draft: draft)
        case .regexGroup:
            return captureRegexGroup(in: trimmedSample, draft: draft, entireMatch: false)
        case .entireMatch:
            return captureRegexGroup(in: trimmedSample, draft: draft, entireMatch: true)
        }
    }

    private static func captureArgumentAfterTrigger(in sample: String, draft: AutomationDraft) -> String? {
        let trigger = draft.triggerPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trigger.isEmpty else { return nil }

        let haystack = draft.caseSensitive ? sample : sample.lowercased()
        let needle = draft.caseSensitive ? trigger : trigger.lowercased()

        if haystack.hasPrefix(needle) {
            let remainder = String(sample.dropFirst(trigger.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return remainder.isEmpty ? nil : remainder
        }

        if let range = haystack.range(of: needle) {
            let start = sample.index(sample.startIndex, offsetBy: haystack.distance(from: haystack.startIndex, to: range.upperBound))
            let remainder = String(sample[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return remainder.isEmpty ? nil : remainder
        }

        return nil
    }

    private static func captureRegexGroup(
        in sample: String,
        draft: AutomationDraft,
        entireMatch: Bool
    ) -> String? {
        let pattern = draft.extractPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return nil }

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: draft.caseSensitive ? [] : [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(sample.startIndex..<sample.endIndex, in: sample)
        guard let match = regex.firstMatch(in: sample, options: [], range: range) else {
            return nil
        }

        if entireMatch {
            guard let matchRange = Range(match.range, in: sample) else { return nil }
            return String(sample[matchRange])
        }

        let groupIndex = draft.captureGroupIndex
        guard groupIndex < match.numberOfRanges,
              let groupRange = Range(match.range(at: groupIndex), in: sample) else {
            return nil
        }

        let value = String(sample[groupRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
