import Foundation

struct FileTreeEntry: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var isDirectory: Bool
}

enum DirectoryListingError: LocalizedError, Equatable {
    case invalidPath
    case notConnected
    case commandFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Directory path is invalid or inaccessible."
        case .notConnected:
            return "Connect to browse remote folders."
        case .commandFailed(let message):
            return message
        case .timedOut:
            return "Directory listing timed out."
        }
    }
}

protocol DirectoryListingService {
    func listDirectory(at path: String) async throws -> [FileTreeEntry]
}

enum DirectoryListingServiceFactory {
    static func make(for session: TerminalSession, host: SSHHost?) -> DirectoryListingService? {
        switch session.kind {
        case .localShell:
            return LocalDirectoryLister()
        case .ssh:
            guard let host, session.state == .connected else { return nil }
            return SSHDirectoryLister(host: host)
        case .diagnostic:
            return nil
        }
    }
}

enum FileTreeSorting {
    static func sorted(_ entries: [FileTreeEntry]) -> [FileTreeEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

/// Windows path helpers for remote SSH listings.
///
/// TabGT runs on macOS, so `NSString` path APIs do not split `C:\Users\...` correctly.
/// Remote commands use forward slashes to avoid cmd.exe eating backslashes over SSH.
enum WindowsPath {
    static func normalize(_ path: String) -> String {
        var value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return value }

        value = value.replacingOccurrences(of: "/", with: "\\")
        while value.contains("\\\\") {
            value = value.replacingOccurrences(of: "\\\\", with: "\\")
        }

        if value.count >= 2,
           value[value.startIndex].isLetter,
           value[value.index(after: value.startIndex)] == ":" {
            let drive = value.prefix(1).uppercased()
            value = drive + String(value.dropFirst())
        }

        if value.count > 3, value.hasSuffix("\\") {
            value = String(value.dropLast())
        }

        return value
    }

    static func driveRoot(for path: String) -> String {
        let normalized = normalize(path)
        let chars = Array(normalized)
        guard chars.count >= 2, chars[1] == ":" else { return normalized }
        return String(chars[0]) + ":\\"
    }

    static func lastComponent(_ path: String) -> String {
        let normalized = normalize(path)
        let root = driveRoot(for: normalized)
        if normalized == root {
            return root
        }

        guard let last = normalized.split(separator: "\\", omittingEmptySubsequences: true).last else {
            return normalized
        }
        return String(last)
    }

    static func parent(of path: String) -> String? {
        let normalized = normalize(path)
        let root = driveRoot(for: normalized)
        guard normalized != root else { return nil }

        guard let lastSeparator = normalized.lastIndex(of: "\\") else { return root }
        var parent = String(normalized[..<lastSeparator])
        if parent.hasSuffix(":") {
            parent += "\\"
        }
        return parent == normalized ? nil : parent
    }

    static func join(_ parent: String, _ childName: String) -> String {
        let parentNorm = normalize(parent)
        let child = childName.trimmingCharacters(in: CharacterSet(charactersIn: "\\/"))
        guard !child.isEmpty else { return parentNorm }

        if parentNorm.hasSuffix("\\") {
            return normalize(parentNorm + child)
        }
        return normalize(parentNorm + "\\" + child)
    }

    static func forRemoteCommand(_ path: String) -> String {
        normalize(path).replacingOccurrences(of: "\\", with: "/")
    }
}

/// Compact labels and parent navigation for the workspace folder browser.
enum WorkspacePathDisplay {
    static func compact(_ path: String) -> String {
        if SSHConfigBuilder.isWindowsPath(path) {
            return WindowsPath.normalize(path)
        }

        let expanded = ProfileResolver.expandLocalPath(path)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if expanded == home { return "~" }
        if expanded.hasPrefix(home + "/") {
            return "~" + String(expanded.dropFirst(home.count))
        }
        return expanded
    }

    static func currentFolderName(_ path: String) -> String {
        if SSHConfigBuilder.isWindowsPath(path) {
            return WindowsPath.lastComponent(path)
        }
        if path == "/" { return "/" }
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? path : name
    }
}

enum WorkspacePathNavigation {
    static func parent(of path: String) -> String? {
        if SSHConfigBuilder.isWindowsPath(path) {
            return WindowsPath.parent(of: path)
        }
        if path == "/" { return nil }
        let parent = (path as NSString).deletingLastPathComponent
        return parent == path ? nil : parent
    }

    static func canGoUp(from path: String) -> Bool {
        parent(of: path) != nil
    }
}

/// Builds shell commands to change directory from the workspace folder tree.
enum WorkspaceDirectoryCommand {
    static func changeDirectory(for path: String, session: TerminalSession, host: SSHHost?) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch session.kind {
        case .diagnostic:
            return nil
        case .ssh:
            guard session.state == .connected else { return nil }
            return remoteChangeDirectory(for: trimmed, host: host)
        case .localShell:
            return unixChangeDirectory(for: ProfileResolver.expandLocalPath(trimmed))
        }
    }

    private static func remoteChangeDirectory(for path: String, host: SSHHost?) -> String {
        if SSHConfigBuilder.isWindowsPath(path) {
            return windowsChangeDirectory(for: WindowsPath.normalize(path), shell: host?.remoteShell)
        }
        return unixChangeDirectory(for: path)
    }

    private static func unixChangeDirectory(for path: String) -> String {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        return "cd '\(escaped)'"
    }

    private static func windowsChangeDirectory(for path: String, shell: String?) -> String {
        let lower = shell?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "powershell"
        if lower.hasSuffix("cmd.exe") || lower == "cmd" {
            let escaped = path.replacingOccurrences(of: "\"", with: "\\\"")
            return "cd /d \"\(escaped)\""
        }

        let escaped = path.replacingOccurrences(of: "'", with: "''")
        return "Set-Location '\(escaped)'"
    }
}
