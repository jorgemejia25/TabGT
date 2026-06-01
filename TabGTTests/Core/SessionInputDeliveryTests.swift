import AppKit
import Foundation
import Testing
@testable import TabGT

@MainActor
struct SessionInputDeliveryTests {
    @Test func defersDeliveryUntilSessionIsConnected() {
        let bridge = SessionInputBridge()
        let sessions = SessionsViewModel()
        let hostID = UUID()
        let host = SSHHost(
            id: hostID,
            name: "staging",
            address: "staging.internal",
            username: "dev"
        )
        sessions.openSSHSession(for: host)
        guard let sessionID = sessions.selectedSession?.id else {
            Issue.record("Expected SSH session")
            return
        }

        bridge.send(text: "make deploy", to: sessionID, submit: true)

        let terminal = TabGTTerminalView(frame: .zero)
        var lastRequestID: UUID?
        SessionInputDelivery.deliverIfNeeded(
            to: terminal,
            sessionID: sessionID,
            sessions: sessions,
            inputBridge: bridge,
            isInputDeliveryReady: true,
            lastRequestID: &lastRequestID
        )

        #expect(bridge.pendingRequest(for: sessionID)?.text == "make deploy")
        #expect(lastRequestID == nil)

        sessions.noteSSHConnected(sessionID: sessionID)
        SessionInputDelivery.deliverIfNeeded(
            to: terminal,
            sessionID: sessionID,
            sessions: sessions,
            inputBridge: bridge,
            isInputDeliveryReady: true,
            lastRequestID: &lastRequestID
        )

        #expect(bridge.pendingRequest(for: sessionID) == nil)
        #expect(lastRequestID != nil)
    }

    @Test func defersDeliveryUntilSSHInputIsReady() {
        let bridge = SessionInputBridge()
        let sessions = SessionsViewModel()
        let host = SSHHost(
            name: "staging",
            address: "staging.internal",
            username: "dev"
        )
        sessions.openSSHSession(for: host)
        guard let sessionID = sessions.selectedSession?.id else {
            Issue.record("Expected SSH session")
            return
        }

        sessions.noteSSHConnected(sessionID: sessionID)
        bridge.send(text: "npm run dev", to: sessionID, submit: true)

        let terminal = TabGTTerminalView(frame: .zero)
        var lastRequestID: UUID?
        SessionInputDelivery.deliverIfNeeded(
            to: terminal,
            sessionID: sessionID,
            sessions: sessions,
            inputBridge: bridge,
            isInputDeliveryReady: false,
            lastRequestID: &lastRequestID
        )

        #expect(bridge.pendingRequest(for: sessionID)?.text == "npm run dev")

        SessionInputDelivery.deliverIfNeeded(
            to: terminal,
            sessionID: sessionID,
            sessions: sessions,
            inputBridge: bridge,
            isInputDeliveryReady: true,
            lastRequestID: &lastRequestID
        )

        #expect(bridge.pendingRequest(for: sessionID) == nil)
    }
}
