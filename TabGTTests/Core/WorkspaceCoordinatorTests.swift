import Foundation
import Testing
@testable import TabGT

struct WorkspaceCoordinatorTests {
    @MainActor
    @Test func detachSessionMovesTabToNewWindowLayout() {
        let coordinator = WorkspaceCoordinator()
        let mainWindowID = UUID()
        let session = PreviewData.sessions[0]
        coordinator.registerWindow(id: mainWindowID, isMain: true, sessions: [session])
        let sourceGroupID = coordinator.layout(for: mainWindowID).focusedGroupID
        let payload = coordinator.detachSession(
            sessionID: session.id,
            fromWindowID: mainWindowID,
            fromGroupID: sourceGroupID
        )

        #expect(payload != nil)

        let mainLayout = coordinator.layout(for: mainWindowID)
        #expect(mainLayout.root.containsSession(session.id) == false)

        let detachedLayout = coordinator.layout(for: payload!.windowID)
        #expect(detachedLayout.root.containsSession(session.id) == true)
        #expect(coordinator.session(for: session.id) != nil)
    }

    @MainActor
    @Test func attachSessionMovesTabBetweenWindows() {
        let coordinator = WorkspaceCoordinator()
        let mainWindowID = UUID()
        let detachedWindowID = UUID()
        let session = PreviewData.sessions[0]

        coordinator.registerWindow(id: mainWindowID, isMain: true, sessions: [session])
        let _ = coordinator.layout(for: mainWindowID).focusedGroupID

        let detachedGroup = TerminalGroup(sessionIDs: [], selectedSessionID: nil)
        coordinator.registerWindow(
            id: detachedWindowID,
            isMain: false,
            layout: WorkspaceLayout(root: .group(detachedGroup), focusedGroupID: detachedGroup.id)
        )

        coordinator.attachSession(
            sessionID: session.id,
            fromWindow: mainWindowID,
            toWindow: detachedWindowID,
            toGroup: detachedGroup.id
        )

        #expect(coordinator.layout(for: mainWindowID).root.containsSession(session.id) == false)
        #expect(coordinator.layout(for: detachedWindowID).root.containsSession(session.id) == true)
    }

    @MainActor
    @Test func closeWindowIfEmptyOnlyClosesDetachedWindows() {
        let coordinator = WorkspaceCoordinator()
        var closedWindowID: UUID?

        let mainWindowID = UUID()
        coordinator.registerWindow(id: mainWindowID, isMain: true)

        let detachedWindowID = UUID()
        let detachedGroup = TerminalGroup()
        coordinator.registerWindow(
            id: detachedWindowID,
            isMain: false,
            layout: WorkspaceLayout(root: .group(detachedGroup), focusedGroupID: detachedGroup.id)
        )
        coordinator.registerCloseHandler(for: detachedWindowID) {
            closedWindowID = detachedWindowID
        }

        coordinator.closeWindowIfEmpty(mainWindowID)
        #expect(closedWindowID == nil)

        coordinator.closeWindowIfEmpty(detachedWindowID)
        #expect(closedWindowID == detachedWindowID)
    }

    @Test func dragPayloadEncodesOptionalSourceWindowID() throws {
        let windowID = UUID()
        let groupID = UUID()
        let sessionID = UUID()

        let payload = TerminalTabDragPayload(
            sessionID: sessionID,
            sourceGroupID: groupID,
            sourceWindowID: windowID
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(TerminalTabDragPayload.self, from: data)

        #expect(decoded.sessionID == sessionID)
        #expect(decoded.sourceGroupID == groupID)
        #expect(decoded.sourceWindowID == windowID)

        let legacy = TerminalTabDragPayload(string: "\(sessionID.uuidString)|\(groupID.uuidString)")
        #expect(legacy?.sourceWindowID == nil)
    }
}
