import Combine
import Foundation

@MainActor
final class SessionInputBridge: ObservableObject {
    struct Request: Equatable {
        let id = UUID()
        let sessionID: UUID
        let text: String
        let submit: Bool
    }

    @Published private(set) var latestRequest: Request?
    private var pendingBySession: [UUID: Request] = [:]

    func send(text: String, to sessionID: UUID, submit: Bool) {
        let request = Request(sessionID: sessionID, text: text, submit: submit)
        latestRequest = request
        pendingBySession[sessionID] = request
    }

    func pendingRequest(for sessionID: UUID) -> Request? {
        pendingBySession[sessionID]
    }

    func markConsumed(_ requestID: UUID, for sessionID: UUID) {
        if pendingBySession[sessionID]?.id == requestID {
            pendingBySession.removeValue(forKey: sessionID)
        }
    }
}
