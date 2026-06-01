import Foundation

struct SnippetProfileContext: Equatable {
    var folders: [StartupFolder]
    var defaultFolderID: UUID?
}

enum SnippetLaunchResolver {
    static func profileContext(
        for session: TerminalSession,
        hosts: [SSHHost],
        profiles: [LocalTerminalProfile]
    ) -> SnippetProfileContext? {
        switch session.kind {
        case .ssh(let hostID, _):
            guard let host = hosts.first(where: { $0.id == hostID }) else { return nil }
            return SnippetProfileContext(
                folders: host.startupFolders,
                defaultFolderID: host.defaultStartupFolderID
            )

        case .localShell(let profileID, _):
            guard let profile = profiles.first(where: { $0.id == profileID }) else { return nil }
            return SnippetProfileContext(
                folders: profile.startupFolders,
                defaultFolderID: profile.defaultStartupFolderID
            )

        case .diagnostic:
            return nil
        }
    }

    static func resolvedFolder(
        startupFolderID: UUID?,
        in context: SnippetProfileContext
    ) -> StartupFolder? {
        if let startupFolderID,
           let folder = context.folders.first(where: { $0.id == startupFolderID }) {
            return folder
        }

        return ProfileResolver.resolvedDefaultFolder(
            folders: context.folders,
            defaultID: context.defaultFolderID
        )
    }

    static func folderLabel(
        startupFolderID: UUID?,
        in context: SnippetProfileContext
    ) -> String {
        if let startupFolderID,
           let folder = context.folders.first(where: { $0.id == startupFolderID }) {
            return folder.name
        }

        if let defaultFolder = ProfileResolver.resolvedDefaultFolder(
            folders: context.folders,
            defaultID: context.defaultFolderID
        ) {
            return "\(defaultFolder.name) (default)"
        }

        return "Profile default"
    }

    static func launchSummary(for snippet: CommandSnippet, context: SnippetProfileContext?) -> String {
        if snippet.launchMode == .newTabCopy {
            guard let context else { return "New tab copy" }
            let folder = folderLabel(startupFolderID: snippet.startupFolderID, in: context)
            return "New tab · \(folder)"
        }

        if let context, snippet.startupFolderID != nil {
            let folder = folderLabel(startupFolderID: snippet.startupFolderID, in: context)
            return "Current tab · New tab: \(folder)"
        }

        return "Current tab"
    }

    static func launchInNewTab(
        snippet: CommandSnippet,
        copying sourceSessionID: UUID,
        sessions: SessionsViewModel,
        hosts: [SSHHost],
        profiles: [LocalTerminalProfile],
        inputBridge: SessionInputBridge
    ) {
        guard let source = sessions.session(for: sourceSessionID) else { return }

        let profileContext = profileContext(for: source, hosts: hosts, profiles: profiles)
        let folder = profileContext.map {
            resolvedFolder(startupFolderID: snippet.startupFolderID, in: $0)
        } ?? nil

        switch source.kind {
        case .ssh(let hostID, _):
            guard let host = hosts.first(where: { $0.id == hostID }) else { return }
            sessions.openSSHSession(for: host, workingDirectory: folder)

        case .localShell(let profileID, _):
            guard let profile = profiles.first(where: { $0.id == profileID }) else { return }
            sessions.openLocalSession(profile: profile, workingDirectory: folder)

        case .diagnostic:
            return
        }

        guard let newSessionID = sessions.selectedSession?.id else { return }
        inputBridge.send(text: snippet.command, to: newSessionID, submit: true)
    }
}
