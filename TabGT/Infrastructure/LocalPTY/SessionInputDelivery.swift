import Foundation

/// Delivers queued terminal input when a SwiftTerm view becomes ready.
enum SessionInputDelivery {
    @MainActor
    static func deliverIfNeeded(
        to terminal: TabGTTerminalView,
        sessionID: UUID,
        sessions: SessionsViewModel,
        inputBridge: SessionInputBridge,
        isInputDeliveryReady: Bool,
        lastRequestID: inout UUID?
    ) {
        guard isInputDeliveryReady else { return }
        guard let session = sessions.session(for: sessionID),
              session.state == .connected else {
            return
        }
        guard let request = inputBridge.pendingRequest(for: sessionID),
              request.id != lastRequestID else {
            return
        }

        lastRequestID = request.id
        terminal.insertText(request.text, submit: request.submit)
        inputBridge.markConsumed(request.id, for: sessionID)
    }
}
