import Foundation

/// Parses `cd` / `Set-Location` commands so the workspace can track manual navigation.
enum TerminalDirectoryParser {
    static func directory(fromCommand line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let path = matchSetLocation(trimmed) { return path }
        if let path = matchCmdChangeDirectory(trimmed) { return path }
        if let path = matchUnixChangeDirectory(trimmed) { return path }
        return nil
    }

    static func resolve(_ path: String, relativeTo currentDirectory: String?) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed.lowercased().hasPrefix("file:") {
            return DirectoryPathNormalizer.normalize(trimmed) ?? trimmed
        }

        if SSHConfigBuilder.isWindowsPath(trimmed) {
            return WindowsPath.normalize(trimmed)
        }

        if trimmed.hasPrefix("/") {
            return trimmed
        }

        if trimmed.hasPrefix("~") {
            return ProfileResolver.expandLocalPath(trimmed)
        }

        guard let currentDirectory, !currentDirectory.isEmpty else { return trimmed }

        if SSHConfigBuilder.isWindowsPath(currentDirectory) {
            return WindowsPath.join(currentDirectory, trimmed)
        }

        let base = currentDirectory.hasSuffix("/") ? String(currentDirectory.dropLast()) : currentDirectory
        return base + "/" + trimmed
    }

    private static func matchSetLocation(_ line: String) -> String? {
        let patterns = [
            #"^(?:set-location|sl)\s+'([^']*)'"#,
            #"^(?:set-location|sl)\s+"([^"]*)""#,
            #"^(?:set-location|sl)\s+([^;\s].*)$"#
        ]

        for pattern in patterns {
            if let path = firstCapture(in: line, pattern: pattern, options: [.caseInsensitive]) {
                return path
            }
        }
        return nil
    }

    private static func matchCmdChangeDirectory(_ line: String) -> String? {
        firstCapture(
            in: line,
            pattern: #"^cd\s+/d\s+"([^"]+)""#,
            options: [.caseInsensitive]
        )
    }

    private static func matchUnixChangeDirectory(_ line: String) -> String? {
        if let quoted = firstCapture(in: line, pattern: #"^cd\s+'([^']*)'"#, options: [.caseInsensitive]) {
            return quoted
        }
        if let quoted = firstCapture(in: line, pattern: #"^cd\s+"([^"]*)""#, options: [.caseInsensitive]) {
            return quoted
        }
        if let bare = firstCapture(in: line, pattern: #"^cd\s+([^;\s'""]+)$"#, options: [.caseInsensitive]) {
            return bare
        }
        return nil
    }

    private static func firstCapture(
        in line: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let value = String(line[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
