import Foundation

struct GitRepoState: Hashable {
    var branch: String? = nil
    var isDetached: Bool = false
    var modifiedCount: Int = 0
    var stagedCount: Int = 0
    var untrackedCount: Int = 0
    var aheadCount: Int = 0
    var behindCount: Int = 0
    var lastCommitHash: String? = nil
    var lastCommitMessage: String? = nil

    var isClean: Bool {
        modifiedCount == 0 && stagedCount == 0 && untrackedCount == 0
    }

    var statusSummary: String {
        if isClean { return "Clean" }
        var parts: [String] = []
        if stagedCount > 0    { parts.append("\(stagedCount) staged") }
        if modifiedCount > 0  { parts.append("\(modifiedCount) modified") }
        if untrackedCount > 0 { parts.append("\(untrackedCount) untracked") }
        return parts.joined(separator: " · ")
    }
}
