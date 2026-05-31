import Testing
@testable import TabGT

struct SessionCoordinatorTests {
    @Test func createSelectAndCloseSession() {
        let coordinator = SessionCoordinator()
        let session = coordinator.createSession(
            title: "local zsh",
            kind: .localShell(profileID: LocalProfileSeeds.zshProfileID, workingDirectory: nil),
            state: .connected
        )

        #expect(coordinator.sessions.count == 1)
        #expect(coordinator.selectedSessionID == session.id)

        coordinator.closeSession(session.id)

        #expect(coordinator.sessions.isEmpty)
        #expect(coordinator.selectedSessionID == nil)
    }

    @Test func appendLineToExistingSession() {
        let coordinator = SessionCoordinator()
        let session = coordinator.createSession(title: "api", kind: .diagnostic)

        coordinator.appendLine(
            TerminalLine(style: .output, text: "ok"),
            to: session.id
        )

        #expect(coordinator.selectedSession?.transcript.last?.text == "ok")
    }
}
