import Foundation

enum SnippetExpansionEngine {
    /// Returns the token currently being typed at the end of the line prefix (before the cursor).
    static func currentToken(from linePrefix: String) -> String {
        guard !linePrefix.isEmpty else { return "" }
        return linePrefix.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? linePrefix
    }

    /// Finds the best matching snippet for a typed token (exact trigger preferred, then prefix).
    static func matchingSnippet(for typedToken: String, in snippets: [CommandSnippet]) -> CommandSnippet? {
        let query = typedToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return nil }

        return snippets
            .filter { snippet in
                let trigger = snippet.trigger.lowercased()
                return trigger.hasPrefix(query) || trigger == query
            }
            .sorted { lhs, rhs in
                let lhsExact = lhs.trigger.lowercased() == query
                let rhsExact = rhs.trigger.lowercased() == query
                if lhsExact != rhsExact { return lhsExact }
                return lhs.trigger.count < rhs.trigger.count
            }
            .first
    }

    /// Computes how many backspaces to send and the replacement text for an expansion.
    static func expansionDelta(from token: String, to command: String) -> (backspaces: Int, text: String) {
        (backspaces: token.count, text: command)
    }
}
