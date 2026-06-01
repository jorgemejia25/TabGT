import Foundation

struct ClaudeSessionState: Hashable {
    var isActive: Bool = false
    var currentTool: String? = nil
    var modifiedFiles: [String] = []
    var workingDirectory: String? = nil
    var sessionStartedAt: Date? = nil
    var lastActivityAt: Date? = nil
    var estimatedCost: Double? = nil
}
