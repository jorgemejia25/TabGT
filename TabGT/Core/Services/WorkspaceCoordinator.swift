import Combine
import Foundation

@MainActor
final class WorkspaceCoordinator: ObservableObject {
    static let shared = WorkspaceCoordinator()

    @Published private(set) var sessions: [TerminalSession] = []

    private var windowLayouts: [UUID: WorkspaceLayout] = [:]
    private var windowIsMain: [UUID: Bool] = [:]
    private(set) var mainWindowID: UUID?

    var openDetachedWindow: ((DetachedWindowPayload) -> Void)?
    private var windowCloseHandlers: [UUID: () -> Void] = [:]

    init() {}

    func layout(for windowID: UUID) -> WorkspaceLayout {
        windowLayouts[windowID] ?? defaultLayout()
    }

    func isMainWindow(_ windowID: UUID) -> Bool {
        windowIsMain[windowID] == true
    }

    func registerWindow(
        id: UUID,
        isMain: Bool,
        sessions initialSessions: [TerminalSession] = [],
        layout: WorkspaceLayout? = nil
    ) {
        windowIsMain[id] = isMain
        if isMain {
            mainWindowID = id
        }

        if !initialSessions.isEmpty {
            for session in initialSessions where !sessions.contains(where: { $0.id == session.id }) {
                sessions.append(session)
            }
        }

        if let layout {
            windowLayouts[id] = layout
            notifyLayoutChanged()
        } else if windowLayouts[id] == nil {
            let group = TerminalGroup(
                sessionIDs: initialSessions.map(\.id),
                selectedSessionID: initialSessions.first?.id
            )
            windowLayouts[id] = WorkspaceLayout(
                root: .group(group),
                focusedGroupID: group.id
            )
            notifyLayoutChanged()
        }
    }

    func unregisterWindow(_ windowID: UUID) {
        windowLayouts.removeValue(forKey: windowID)
        windowIsMain.removeValue(forKey: windowID)
        if mainWindowID == windowID {
            mainWindowID = nil
        }
    }

    func updateLayout(for windowID: UUID, _ transform: (inout WorkspaceLayout) -> Void) {
        var next = layout(for: windowID)
        let previous = next
        transform(&next)
        guard next != previous else { return }
        windowLayouts[windowID] = next
        notifyLayoutChanged()
    }

    func session(for id: UUID) -> TerminalSession? {
        sessions.first { $0.id == id }
    }

    func containsSession(_ sessionID: UUID) -> Bool {
        windowLayouts.values.contains { $0.root.containsSession(sessionID) }
    }

    func appendSession(_ session: TerminalSession) {
        sessions.append(session)
    }

    func removeSession(_ sessionID: UUID) {
        sessions.removeAll { $0.id == sessionID }
        TerminalViewPool.shared.remove(for: sessionID)
    }

    func updateSession(_ sessionID: UUID, _ update: (inout TerminalSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let previous = sessions[index]
        var session = previous
        update(&session)
        guard session != previous else { return }
        sessions[index] = session
    }

    func configureWindowOpening(_ handler: @escaping (DetachedWindowPayload) -> Void) {
        openDetachedWindow = handler
    }

    func registerCloseHandler(for windowID: UUID, handler: @escaping () -> Void) {
        windowCloseHandlers[windowID] = handler
    }

    func unregisterCloseHandler(for windowID: UUID) {
        windowCloseHandlers.removeValue(forKey: windowID)
    }

    @discardableResult
    func detachSession(
        sessionID: UUID,
        fromWindowID: UUID,
        fromGroupID: UUID
    ) -> DetachedWindowPayload? {
        guard session(for: sessionID) != nil,
              windowLayouts[fromWindowID]?.root.group(id: fromGroupID)?.sessionIDs.contains(sessionID) == true
        else {
            return nil
        }

        let newGroup = TerminalGroup(
            sessionIDs: [sessionID],
            selectedSessionID: sessionID
        )
        let newWindowID = UUID()
        let detachedLayout = WorkspaceLayout(
            root: .group(newGroup),
            focusedGroupID: newGroup.id
        )

        updateLayout(for: fromWindowID) { layout in
            layout.root.removeSessionFromGroups(sessionID)
            if windowIsMain[fromWindowID] == true {
                ensureMainWindowHasGroup(&layout)
            }
        }

        registerWindow(id: newWindowID, isMain: false, layout: detachedLayout)

        let payload = DetachedWindowPayload(
            windowID: newWindowID,
            focusedGroupID: newGroup.id
        )
        openDetachedWindow?(payload)
        return payload
    }

    func attachSession(
        sessionID: UUID,
        fromWindow sourceWindowID: UUID,
        toWindow targetWindowID: UUID,
        toGroup targetGroupID: UUID,
        before targetSessionID: UUID? = nil
    ) {
        guard session(for: sessionID) != nil else { return }

        updateLayout(for: sourceWindowID) { layout in
            layout.root.removeSessionFromGroups(sessionID)
            if windowIsMain[sourceWindowID] == true {
                ensureMainWindowHasGroup(&layout)
            }
        }

        updateLayout(for: targetWindowID) { layout in
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

        closeWindowIfEmpty(sourceWindowID)
    }

    func attachSessionToNewSplit(
        sessionID: UUID,
        fromWindow sourceWindowID: UUID,
        toWindow targetWindowID: UUID,
        around targetGroupID: UUID,
        placement: TerminalSplitPlacement
    ) {
        guard session(for: sessionID) != nil,
              layout(for: targetWindowID).root.group(id: targetGroupID) != nil
        else {
            return
        }

        updateLayout(for: sourceWindowID) { layout in
            layout.root.removeSessionFromGroups(sessionID)
            if windowIsMain[sourceWindowID] == true {
                ensureMainWindowHasGroup(&layout)
            }
        }

        let newGroup = TerminalGroup(
            sessionIDs: [sessionID],
            selectedSessionID: sessionID
        )

        updateLayout(for: targetWindowID) { layout in
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

        closeWindowIfEmpty(sourceWindowID)
    }

    func closeWindowIfEmpty(_ windowID: UUID) {
        guard windowIsMain[windowID] != true else { return }

        let layout = layout(for: windowID)
        let hasTabs = layout.root.groups().contains { !$0.sessionIDs.isEmpty }
        guard !hasTabs else { return }

        windowCloseHandlers[windowID]?()
        windowCloseHandlers.removeValue(forKey: windowID)
        unregisterWindow(windowID)
    }

    private func defaultLayout() -> WorkspaceLayout {
        let group = TerminalGroup()
        return WorkspaceLayout(root: .group(group), focusedGroupID: group.id)
    }

    private func ensureMainWindowHasGroup(_ layout: inout WorkspaceLayout) {
        let groups = layout.root.groups()
        if groups.isEmpty || groups.allSatisfy({ $0.sessionIDs.isEmpty }) {
            let emptyGroup = TerminalGroup()
            layout.root = .group(emptyGroup)
            layout.focusedGroupID = emptyGroup.id
        }
    }

    private func notifyLayoutChanged() {
        objectWillChange.send()
    }
}
