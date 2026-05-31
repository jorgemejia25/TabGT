import Foundation

final class SessionCoordinator {
    private(set) var sessions: [TerminalSession]
    private(set) var selectedSessionID: UUID?

    init(sessions: [TerminalSession] = []) {
        self.sessions = sessions
        self.selectedSessionID = sessions.first?.id
    }

    var selectedSession: TerminalSession? {
        guard let selectedSessionID else { return nil }
        return sessions.first { $0.id == selectedSessionID }
    }

    @discardableResult
    func createSession(
        title: String,
        kind: TerminalSessionKind,
        state: ConnectionState = .connecting,
        transcript: [TerminalLine] = []
    ) -> TerminalSession {
        let session = TerminalSession(
            title: title,
            kind: kind,
            state: state,
            transcript: transcript
        )
        sessions.append(session)
        selectedSessionID = session.id
        return session
    }

    func selectSession(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        selectedSessionID = id
    }

    func closeSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id {
            selectedSessionID = sessions.last?.id
        }
    }

    func appendLine(_ line: TerminalLine, to sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[index].transcript.append(line)
    }
}
