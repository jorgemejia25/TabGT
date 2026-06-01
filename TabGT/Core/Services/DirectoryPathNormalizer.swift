import Foundation

/// Normalizes directory paths from OSC 7 and SwiftTerm callbacks.
enum DirectoryPathNormalizer {
    /// Returns a filesystem path suitable for listing, or nil when the input is empty/invalid.
    static func normalize(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        if value.lowercased().hasPrefix("file:") {
            value = fileURLPath(from: value) ?? value
        }

        if let decoded = value.removingPercentEncoding {
            value = decoded
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if SSHConfigBuilder.isWindowsPath(value) {
            return WindowsPath.normalize(value)
        }

        if value.hasPrefix("~") {
            return ProfileResolver.expandLocalPath(value)
        }

        return value
    }

    /// Normalizes cwd values from OSC 7, shell commands, and relative paths.
    static func normalizeSessionPath(_ raw: String?, relativeTo base: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if let absolute = normalize(raw), isAbsolute(absolute) {
            return absolute
        }

        let resolved = TerminalDirectoryParser.resolve(raw, relativeTo: base)
        return normalize(resolved) ?? resolved
    }

    static func isAbsolute(_ path: String) -> Bool {
        if path.hasPrefix("/") { return true }

        if SSHConfigBuilder.isWindowsPath(path) {
            let normalized = WindowsPath.normalize(path)
            let chars = Array(normalized)
            return chars.count >= 2 && chars[0].isLetter && chars[1] == ":"
        }

        return false
    }

    private static func fileURLPath(from value: String) -> String? {
        let lowercased = value.lowercased()

        if lowercased.hasPrefix("file://") {
            var remainder = String(value.dropFirst(7))
            if remainder.hasPrefix("/") {
                remainder = String(remainder.dropFirst())
            }
            return normalizeFilePathRemainder(remainder)
        }

        if lowercased.hasPrefix("file:\\") || lowercased.hasPrefix("file:/") {
            var remainder = String(value.dropFirst(5))
            while let first = remainder.first, first == "/" || first == "\\" {
                remainder = String(remainder.dropFirst())
            }
            return normalizeFilePathRemainder(remainder)
        }

        guard let url = URL(string: value), url.scheme == "file" else {
            return nil
        }

        return url.path
    }

    private static func normalizeFilePathRemainder(_ remainder: String) -> String? {
        guard !remainder.isEmpty else { return nil }

        if remainder.count >= 2,
           remainder.first?.isLetter == true,
           remainder[remainder.index(remainder.startIndex, offsetBy: 1)] == ":" {
            return WindowsPath.normalize(remainder)
        }

        return remainder.hasPrefix("/") ? remainder : "/" + remainder
    }
}
