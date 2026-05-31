import Combine
import Foundation

@MainActor
final class SessionsViewModel: ObservableObject {
    @Published private(set) var sessions: [TerminalSession]
    @Published var layout: WorkspaceLayout

    private weak var automations: AutomationsViewModel?

    func wireAutomations(_ automations: AutomationsViewModel) {
        self.automations = automations
    }

    init(sessions: [TerminalSession] = []) {
        self.sessions = sessions

        let group = TerminalGroup(
            sessionIDs: sessions.map(\.id),
            selectedSessionID: sessions.first?.id
        )
        self.layout = WorkspaceLayout(
            root: .group(group),
            focusedGroupID: group.id
        )
    }

    var selectedSession: TerminalSession? {
        guard let group = layout.root.group(id: layout.focusedGroupID),
              let selectedSessionID = group.selectedSessionID
        else {
            return nil
        }

        return session(for: selectedSessionID)
    }

    func selectedSession(in group: TerminalGroup) -> TerminalSession? {
        guard let selectedSessionID = group.selectedSessionID else {
            return nil
        }

        return session(for: selectedSessionID)
    }

    func openSSHSession(
        for host: SSHHost,
        workingDirectory folder: StartupFolder? = nil
    ) {
        let defaultFolder = ProfileResolver.resolvedDefaultFolder(
            folders: host.startupFolders,
            defaultID: host.defaultStartupFolderID
        )
        let selectedFolder = folder ?? defaultFolder
        let remotePath = selectedFolder?.path

        let title = ProfileResolver.sessionTitle(
            baseName: host.name,
            folder: selectedFolder,
            defaultFolder: defaultFolder
        )

        let preflightIssue = SSHPreflightValidator.validate(host: host)
        let initialState: ConnectionState = preflightIssue == nil ? .connecting : .failed
        let connectionMessage: String? = preflightIssue.map {
            SSHConnectionDiagnostics.message(for: $0, host: host)
        } ?? SSHConnectionDiagnostics.connectingMessage(for: host)

        let session = TerminalSession(
            title: title,
            kind: .ssh(hostID: host.id, workingDirectory: remotePath),
            state: initialState,
            connectionMessage: connectionMessage,
            encoding: TerminalEncodingResolver.fromProcessEnvironment()
        )
        sessions.append(session)
        attachSession(session.id, to: layout.focusedGroupID)
    }

    func openLocalSession(
        profile: LocalTerminalProfile,
        workingDirectory folder: StartupFolder? = nil,
        in groupID: UUID? = nil
    ) {
        let targetGroupID = groupID ?? layout.focusedGroupID
        let defaultFolder = ProfileResolver.resolvedDefaultFolder(
            folders: profile.startupFolders,
            defaultID: profile.defaultStartupFolderID
        )
        let selectedFolder = folder ?? defaultFolder
        let (resolvedPath, warning) = ProfileResolver.resolveLocalWorkingDirectory(for: selectedFolder)

        var transcript: [TerminalLine] = []
        if let warning {
            transcript.append(TerminalLine(style: .warning, text: warning))
        }

        let title = ProfileResolver.sessionTitle(
            baseName: profile.name,
            folder: selectedFolder,
            defaultFolder: defaultFolder
        )

        let session = TerminalSession(
            title: title,
            kind: .localShell(profileID: profile.id, workingDirectory: resolvedPath),
            state: .connected,
            encoding: TerminalEncodingResolver.fromProcessEnvironment(),
            transcript: transcript
        )
        sessions.append(session)
        attachSession(session.id, to: targetGroupID)
    }

    func openLocalSession() {
        openLocalSession(profile: fallbackLocalProfile(), in: layout.focusedGroupID)
    }

    func openLocalSession(in groupID: UUID) {
        openLocalSession(profile: fallbackLocalProfile(), in: groupID)
    }

    func openLocalSession(
        profile: LocalTerminalProfile,
        workingDirectory folder: StartupFolder? = nil
    ) {
        openLocalSession(profile: profile, workingDirectory: folder, in: layout.focusedGroupID)
    }

    private func fallbackLocalProfile() -> LocalTerminalProfile {
        LocalProfileSeeds.profiles().first ?? LocalTerminalProfile(
            name: "zsh",
            shellPath: "/bin/zsh",
            shellArgs: ["-l"]
        )
    }

    func select(_ session: TerminalSession) {
        select(session.id, in: layout.focusedGroupID)
    }

    func select(_ sessionID: UUID, in groupID: UUID) {
        mutateLayout { layout in
            layout.root.updateGroup(id: groupID) { group in
                guard group.sessionIDs.contains(sessionID) else { return }
                group.selectedSessionID = sessionID
            }
            layout.focusedGroupID = groupID
        }
    }

    /// Selects the tab at a zero-based index within the focused (or specified) group.
    func selectTab(at index: Int, in groupID: UUID? = nil) {
        let targetGroupID = groupID ?? layout.focusedGroupID
        guard let group = layout.root.group(id: targetGroupID),
              group.sessionIDs.indices.contains(index) else {
            return
        }

        select(group.sessionIDs[index], in: targetGroupID)
    }

    /// Human-readable label for a workspace split/group (Tab 1, Tab 2, …).
    func groupDisplayLabel(for groupID: UUID) -> String {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            return "Tab"
        }
        return "Tab \(index + 1)"
    }

    func focusGroup(_ groupID: UUID) {
        guard layout.root.group(id: groupID) != nil else { return }
        mutateLayout { layout in
            layout.focusedGroupID = groupID
        }
    }

    func close(_ sessionID: UUID, in groupID: UUID) {
        mutateLayout { layout in
            layout.root.updateGroup(id: groupID) { group in
                group.sessionIDs.removeAll { $0 == sessionID }
                if group.selectedSessionID == sessionID {
                    group.selectedSessionID = group.sessionIDs.last
                }
            }
        }

        pruneUnreferencedSession(sessionID)
    }

    func close(_ session: TerminalSession) {
        close(session.id, in: layout.focusedGroupID)
    }

    func closeGroupTabs(_ groupID: UUID) {
        let removedIDs = layout.root.group(id: groupID)?.sessionIDs ?? []
        mutateLayout { layout in
            layout.root.updateGroup(id: groupID) { group in
                group.sessionIDs.removeAll()
                group.selectedSessionID = nil
            }
        }

        for sessionID in removedIDs {
            pruneUnreferencedSession(sessionID)
        }
    }

    func splitGroup(_ groupID: UUID, axis: TerminalSplitAxis) {
        splitGroup(groupID, placement: axis == .horizontal ? .right : .down)
    }

    func splitGroup(_ groupID: UUID, placement: TerminalSplitPlacement) {
        guard let group = layout.root.group(id: groupID) else { return }

        // Capture the active session before the layout mutation changes focus.
        let sourceSession = selectedSession(in: group)

        let newGroup = TerminalGroup()
        let currentNode = WorkspaceNode.group(group)
        let newNode = WorkspaceNode.group(newGroup)
        let split = TerminalSplit(
            axis: placement.axis,
            leading: placement == .left || placement == .up ? newNode : currentNode,
            trailing: placement == .left || placement == .up ? currentNode : newNode
        )

        mutateLayout { layout in
            layout.root.replaceGroup(id: groupID, with: .split(split))
            layout.focusedGroupID = newGroup.id
        }

        // Open a fresh session matching the active one in the new pane so the
        // user lands in the same host/profile and working directory.
        if let source = sourceSession {
            let duplicateState: ConnectionState = {
                if case .ssh = source.kind { return .connecting }
                return .connected
            }()
            let duplicate = TerminalSession(
                title: source.title,
                kind: source.kind,
                state: duplicateState,
                connectionMessage: duplicateState == .connecting
                    ? "Connecting to \(source.title)…"
                    : nil,
                encoding: source.encoding
            )
            sessions.append(duplicate)
            attachSession(duplicate.id, to: newGroup.id)
        }
    }

    func moveTabToNewSplit(sessionID: UUID, from sourceGroupID: UUID, placement: TerminalSplitPlacement) {
        guard session(for: sessionID) != nil,
              let sourceGroup = layout.root.group(id: sourceGroupID),
              sourceGroup.sessionIDs.contains(sessionID)
        else {
            return
        }

        moveTabToNewSplit(
            sessionID: sessionID,
            from: sourceGroupID,
            around: sourceGroupID,
            placement: placement
        )
    }

    func moveTabToNewSplit(
        sessionID: UUID,
        from sourceGroupID: UUID?,
        around targetGroupID: UUID,
        placement: TerminalSplitPlacement
    ) {
        guard session(for: sessionID) != nil,
              layout.root.group(id: targetGroupID) != nil
        else {
            return
        }

        if let sourceGroupID,
           layout.root.group(id: sourceGroupID)?.sessionIDs.contains(sessionID) != true {
            return
        }

        guard layout.root.group(id: targetGroupID) != nil else { return }
        let newGroup = TerminalGroup(
            sessionIDs: [sessionID],
            selectedSessionID: sessionID
        )

        mutateLayout { layout in
            layout.root.removeSessionFromGroups(sessionID)

            guard let updatedTarget = layout.root.group(id: targetGroupID) else { return }

            let targetNode = WorkspaceNode.group(updatedTarget)
            let newNode = WorkspaceNode.group(newGroup)
            let split = TerminalSplit(
                axis: placement.axis,
                leading: placement == .left || placement == .up ? newNode : targetNode,
                trailing: placement == .left || placement == .up ? targetNode : newNode
            )

            layout.root.replaceGroup(id: targetGroupID, with: .split(split))
            layout.focusedGroupID = newGroup.id
        }
    }

    func moveTab(sessionID: UUID, to targetGroupID: UUID, before targetSessionID: UUID? = nil) {
        guard session(for: sessionID) != nil else { return }

        mutateLayout { layout in
            layout.root.removeSessionFromGroups(sessionID)
            layout.root.updateGroup(id: targetGroupID) { group in
                if let targetSessionID,
                   let index = group.sessionIDs.firstIndex(of: targetSessionID),
                   targetSessionID != sessionID {
                    group.sessionIDs.insert(sessionID, at: index)
                } else {
                    group.sessionIDs.append(sessionID)
                }
                group.selectedSessionID = sessionID
            }
            layout.focusedGroupID = targetGroupID
        }
    }

    func closeGroup(_ groupID: UUID) {
        let removedIDs = layout.root.group(id: groupID)?.sessionIDs ?? []
        let collapsed = mutateLayoutReturning { layout -> Bool in
            layout.root.removeGroup(id: groupID)
        }

        if !collapsed {
            closeGroupTabs(groupID)
            return
        }

        for sessionID in removedIDs {
            pruneUnreferencedSession(sessionID)
        }

        mutateLayout { layout in
            if layout.root.group(id: layout.focusedGroupID) == nil,
               let firstGroup = layout.root.firstGroup() {
                layout.focusedGroupID = firstGroup.id
            }
        }
    }

    var groups: [TerminalGroup] {
        layout.root.groups()
    }

    func updateSplitRatio(_ splitID: UUID, ratio: Double) {
        mutateLayout { layout in
            layout.root.updateSplit(id: splitID) { split in
                split.ratio = min(max(ratio, 0.18), 0.82)
            }
        }
    }

    func submitCommand(_ text: String, for sessionID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        var session = sessions[index]
        session.transcript.append(
            TerminalLine(style: .command, text: commandPromptPrefix(for: session) + trimmed)
        )

        if let automations {
            let clips = AutomationCaptureEngine.processText(
                trimmed,
                rules: automations.rules,
                source: .commandInput,
                sessionTitle: session.title
            )
            clips.forEach { automations.addCapturedClip($0) }
        }

        for line in mockOutput(for: trimmed, session: session) {
            session.transcript.append(line)
        }

        sessions[index] = session
    }

    static func preview() -> SessionsViewModel {
        SessionsViewModel(sessions: PreviewData.sessions)
    }

    func session(for id: UUID) -> TerminalSession? {
        sessions.first { $0.id == id }
    }

    func updateTerminalGeometry(sessionID: UUID, columns: Int, rows: Int) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard sessions[index].columns != columns || sessions[index].rows != rows else { return }
        sessions[index].columns = columns
        sessions[index].rows = rows
    }

    func updateSessionEncoding(sessionID: UUID, encoding: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        guard sessions[index].encoding != encoding else { return }
        sessions[index].encoding = encoding
    }

    func updateSessionState(
        sessionID: UUID,
        state: ConnectionState,
        message: String? = nil,
        replacesMessage: Bool = false
    ) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        var session = sessions[index]
        session.state = state
        if replacesMessage {
            session.connectionMessage = message
        }
        sessions[index] = session
    }

    func noteSSHConnected(sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].state = .connected
        sessions[index].connectionMessage = nil
    }

    func noteSSHFailure(sessionID: UUID, message: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].state = .failed
        sessions[index].connectionMessage = message
    }

    private func commandPromptPrefix(for session: TerminalSession) -> String {
        switch session.kind {
        case .ssh:
            return "$ "
        case .localShell:
            return "% "
        case .diagnostic:
            return "> "
        }
    }

    private func mockOutput(for command: String, session: TerminalSession) -> [TerminalLine] {
        let lowered = command.lowercased()

        if lowered.hasPrefix("git status") {
            return [TerminalLine(style: .output, text: " M TabGT/Root/InspectorPanel.swift")]
        }

        if lowered.hasPrefix("git checkout") || lowered.hasPrefix("git switch") {
            let branch = command.split(separator: " ").last.map(String.init) ?? "branch"
            return [TerminalLine(style: .output, text: "Switched to branch '\(branch)'")]
        }

        if lowered.hasPrefix("/bookmark") {
            return [TerminalLine(style: .system, text: "mock: bookmark saved")]
        }

        if lowered.hasPrefix("make deploy") {
            return [
                TerminalLine(style: .output, text: "Building release artifact..."),
                TerminalLine(style: .output, text: "Deploy queued for \(session.title)")
            ]
        }

        return [TerminalLine(style: .output, text: "mock: \(command)")]
    }

    private func attachSession(_ sessionID: UUID, to groupID: UUID) {
        mutateLayout { layout in
            layout.root.updateGroup(id: groupID) { group in
                if !group.sessionIDs.contains(sessionID) {
                    group.sessionIDs.append(sessionID)
                }
                group.selectedSessionID = sessionID
            }
            layout.focusedGroupID = groupID
        }
    }

    private func pruneUnreferencedSession(_ sessionID: UUID) {
        guard !layout.root.containsSession(sessionID) else { return }
        sessions.removeAll { $0.id == sessionID }
        TerminalViewPool.shared.remove(for: sessionID)
    }

    /// Reassigns `layout` so `@Published` emits and SwiftUI picks up nested struct changes.
    private func mutateLayout(_ transform: (inout WorkspaceLayout) -> Void) {
        var next = layout
        transform(&next)
        layout = next
    }

    private func mutateLayoutReturning<T>(_ transform: (inout WorkspaceLayout) -> T) -> T {
        var next = layout
        let value = transform(&next)
        layout = next
        return value
    }
}

extension WorkspaceNode {
    func group(id: UUID) -> TerminalGroup? {
        switch self {
        case .group(let group):
            return group.id == id ? group : nil
        case .split(let split):
            return split.leading.group(id: id) ?? split.trailing.group(id: id)
        }
    }

    func containsSession(_ sessionID: UUID) -> Bool {
        switch self {
        case .group(let group):
            return group.sessionIDs.contains(sessionID)
        case .split(let split):
            return split.leading.containsSession(sessionID) || split.trailing.containsSession(sessionID)
        }
    }

    func firstGroup() -> TerminalGroup? {
        switch self {
        case .group(let group):
            return group
        case .split(let split):
            return split.leading.firstGroup() ?? split.trailing.firstGroup()
        }
    }

    func groups() -> [TerminalGroup] {
        switch self {
        case .group(let group):
            return [group]
        case .split(let split):
            return split.leading.groups() + split.trailing.groups()
        }
    }

    mutating func updateGroup(id: UUID, _ update: (inout TerminalGroup) -> Void) {
        switch self {
        case .group(var group):
            guard group.id == id else { return }
            update(&group)
            self = .group(group)
        case .split(var split):
            split.leading.updateGroup(id: id, update)
            split.trailing.updateGroup(id: id, update)
            self = .split(split)
        }
    }

    mutating func replaceGroup(id: UUID, with replacement: WorkspaceNode) {
        switch self {
        case .group(let group):
            guard group.id == id else { return }
            self = replacement
        case .split(var split):
            split.leading.replaceGroup(id: id, with: replacement)
            split.trailing.replaceGroup(id: id, with: replacement)
            self = .split(split)
        }
    }

    mutating func removeSessionFromGroups(_ sessionID: UUID) {
        switch self {
        case .group(var group):
            group.sessionIDs.removeAll { $0 == sessionID }
            if group.selectedSessionID == sessionID {
                group.selectedSessionID = group.sessionIDs.last
            }
            self = .group(group)
        case .split(var split):
            split.leading.removeSessionFromGroups(sessionID)
            split.trailing.removeSessionFromGroups(sessionID)
            self = .split(split)
        }
    }

    mutating func removeGroup(id: UUID) -> Bool {
        switch self {
        case .group:
            return false
        case .split(var split):
            if split.leading.id == id {
                self = split.trailing
                return true
            }

            if split.trailing.id == id {
                self = split.leading
                return true
            }

            if split.leading.removeGroup(id: id) {
                self = .split(split)
                return true
            }

            if split.trailing.removeGroup(id: id) {
                self = .split(split)
                return true
            }

            return false
        }
    }

    mutating func updateSplit(id: UUID, _ update: (inout TerminalSplit) -> Void) {
        switch self {
        case .group:
            return
        case .split(var split):
            if split.id == id {
                update(&split)
            } else {
                split.leading.updateSplit(id: id, update)
                split.trailing.updateSplit(id: id, update)
            }
            self = .split(split)
        }
    }
}
