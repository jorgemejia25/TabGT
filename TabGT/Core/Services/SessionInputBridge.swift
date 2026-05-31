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

    func send(text: String, to sessionID: UUID, submit: Bool) {
        latestRequest = Request(sessionID: sessionID, text: text, submit: submit)
    }
}
