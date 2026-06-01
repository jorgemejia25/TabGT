import Foundation

struct SSHHost: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var address: String
    var port: Int = 22
    var username: String
    var groupID: UUID?
    var tags: [String] = []
    var credentialRef: CredentialRef?
    var lastConnectedAt: Date?
    var startupFolders: [StartupFolder] = []
    var defaultStartupFolderID: UUID?
    var remoteShell: String?

    var displayAddress: String {
        "\(username)@\(address):\(port)"
    }
}

struct HostGroup: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var colorName: String
    var sortOrder: Int
}

enum CredentialKind: String, CaseIterable, Hashable, Codable {
    case password
    case privateKey
    case agent
}

struct CredentialRef: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var kind: CredentialKind
    var label: String
    var keychainAccount: String?
}

struct HostKeyRecord: Identifiable, Hashable {
    var id: UUID = UUID()
    var hostID: UUID
    var algorithm: String
    var fingerprint: String
    var trustedAt: Date
}

struct CommandSnippet: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var title: String
    var trigger: String
    var command: String
    var tags: [String] = []
    var notes: String = ""
    var launchMode: SnippetLaunchMode = .currentTab
    /// When `launchMode` is `.newTabCopy`, opens the duplicate tab in this profile folder.
    /// `nil` uses the profile or host default startup folder.
    var startupFolderID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, trigger, command, tags, notes, launchMode, startupFolderID
    }

    init(
        id: UUID = UUID(),
        title: String,
        trigger: String,
        command: String,
        tags: [String] = [],
        notes: String = "",
        launchMode: SnippetLaunchMode = .currentTab,
        startupFolderID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.trigger = trigger
        self.command = command
        self.tags = tags
        self.notes = notes
        self.launchMode = launchMode
        self.startupFolderID = startupFolderID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        trigger = try container.decode(String.self, forKey: .trigger)
        command = try container.decode(String.self, forKey: .command)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        launchMode = try container.decodeIfPresent(SnippetLaunchMode.self, forKey: .launchMode) ?? .currentTab
        startupFolderID = try container.decodeIfPresent(UUID.self, forKey: .startupFolderID)
    }
}

enum SnippetLaunchMode: String, CaseIterable, Hashable, Codable {
    case currentTab
    case newTabCopy

    var label: String {
        switch self {
        case .currentTab:
            return "Current tab"
        case .newTabCopy:
            return "New tab copy"
        }
    }

    var detail: String {
        switch self {
        case .currentTab:
            return "Insert or run in the active terminal tab."
        case .newTabCopy:
            return "Open a copy of the active tab, then run the command."
        }
    }
}

struct AppSettings: Hashable {
    var openNewSessionsInTabs = true
    var confirmBeforeClosingConnectedSession = true
    var preferredLocalShell = "/bin/zsh"
}

enum TerminalSessionKind: Hashable {
    case ssh(hostID: UUID, workingDirectory: String?)
    case localShell(profileID: UUID, workingDirectory: String?)
    case diagnostic
}

extension TerminalSessionKind {
    var hostID: UUID? {
        if case .ssh(let hostID, _) = self { return hostID }
        return nil
    }

    var profileID: UUID? {
        if case .localShell(let profileID, _) = self { return profileID }
        return nil
    }

    var workingDirectory: String? {
        switch self {
        case .ssh(_, let path), .localShell(_, let path):
            return path
        case .diagnostic:
            return nil
        }
    }
}

enum ConnectionState: String, CaseIterable, Hashable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed

    var label: String {
        rawValue.capitalized
    }
}

enum TerminalLineStyle: String, Hashable {
    case command
    case output
    case warning
    case error
    case system
}

struct TerminalLine: Identifiable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var style: TerminalLineStyle
    var text: String
}

struct TerminalSession: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var kind: TerminalSessionKind
    var state: ConnectionState
    var connectionMessage: String?
    var startedAt: Date = Date()
    var columns: Int = 120
    var rows: Int = 32
    var encoding: String = "UTF-8"
    var transcript: [TerminalLine] = []
    /// Live working directory reported by the shell (OSC 7) or initialized at session open.
    var currentDirectory: String?
    /// Claude Code session state, populated when hooks are installed on the remote host.
    var claudeSession: ClaudeSessionState?
    /// Git repo state for the current working directory, populated via PROMPT_COMMAND OSC sequences.
    var gitRepoState: GitRepoState?
}

extension TerminalSession {
    /// Best-known directory for workspace browsing: live CWD, then startup path.
    var effectiveDirectory: String? {
        if let currentDirectory, !currentDirectory.isEmpty {
            return currentDirectory
        }
        return kind.workingDirectory
    }
}

enum TerminalSplitAxis: String, CaseIterable, Hashable {
    case horizontal
    case vertical
}

enum TerminalSplitPlacement: String, CaseIterable, Hashable {
    case left
    case right
    case up
    case down

    var axis: TerminalSplitAxis {
        switch self {
        case .left, .right:
            return .horizontal
        case .up, .down:
            return .vertical
        }
    }
}

struct WorkspaceLayout: Hashable {
    var root: WorkspaceNode
    var focusedGroupID: UUID
}

indirect enum WorkspaceNode: Identifiable, Hashable {
    case group(TerminalGroup)
    case split(TerminalSplit)

    var id: UUID {
        switch self {
        case .group(let group):
            return group.id
        case .split(let split):
            return split.id
        }
    }
}

struct TerminalGroup: Identifiable, Hashable {
    var id: UUID = UUID()
    var sessionIDs: [UUID] = []
    var selectedSessionID: UUID?
}

struct TerminalSplit: Identifiable, Hashable {
    var id: UUID = UUID()
    var axis: TerminalSplitAxis
    var leading: WorkspaceNode
    var trailing: WorkspaceNode
    var ratio: Double = 0.5
}
