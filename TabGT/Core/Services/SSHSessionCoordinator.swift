import Foundation
import SwiftTerm

/// Tracks SSH handshake output and process lifecycle for a single terminal session.
@MainActor
final class SSHSessionCoordinator: NSObject, LocalProcessTerminalViewDelegate {
    private enum Phase {
        case handshake
        case connected
        case failed
    }

    private let sessionID: UUID
    private let host: SSHHost
    private weak var sessions: SessionsViewModel?

    var terminalView: TabGTTerminalView?
    var lastRequestID: UUID?

    private var phase: Phase = .handshake
    private var outputBuffer = ""
    private var timeoutTask: Task<Void, Never>?

    init(sessionID: UUID, host: SSHHost, sessions: SessionsViewModel) {
        self.sessionID = sessionID
        self.host = host
        self.sessions = sessions
        super.init()
        startTimeoutWatchdog()
    }

    deinit {
        timeoutTask?.cancel()
    }

    func processConnectionOutput(_ text: String) {
        guard phase == .handshake else { return }

        outputBuffer += text
        if outputBuffer.count > 8_192 {
            outputBuffer = String(outputBuffer.suffix(4_096))
        }

        if let message = SSHConnectionDiagnostics.parseError(from: outputBuffer, host: host) {
            markFailed(message)
            return
        }

        if SSHConnectionDiagnostics.looksConnected(outputBuffer) {
            markConnected()
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        sessions?.updateTerminalGeometry(sessionID: sessionID, columns: newCols, rows: newRows)
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        timeoutTask?.cancel()

        guard let exitCode else {
            sessions?.updateSessionState(sessionID: sessionID, state: .disconnected)
            return
        }

        if exitCode == 0 {
            sessions?.updateSessionState(sessionID: sessionID, state: .disconnected, message: nil, replacesMessage: true)
            return
        }

        switch phase {
        case .handshake:
            let message = SSHConnectionDiagnostics.message(forExitCode: exitCode, host: host)
            markFailed(message)
        case .connected:
            sessions?.updateSessionState(
                sessionID: sessionID,
                state: .disconnected,
                message: SSHConnectionDiagnostics.message(forExitCode: exitCode, host: host),
                replacesMessage: true
            )
        case .failed:
            break
        }
    }

    func publishInitialGeometry(from source: TabGTTerminalView) {
        sizeChanged(
            source: source,
            newCols: source.terminal.cols,
            newRows: source.terminal.rows
        )
    }

    private func markConnected() {
        guard phase == .handshake else { return }
        phase = .connected
        timeoutTask?.cancel()
        sessions?.noteSSHConnected(sessionID: sessionID)
    }

    private func markFailed(_ message: String) {
        guard phase != .failed else { return }
        phase = .failed
        timeoutTask?.cancel()
        sessions?.noteSSHFailure(sessionID: sessionID, message: message)
    }

    private func startTimeoutWatchdog() {
        let gracePeriod = SSHConnectionDiagnostics.connectTimeoutSeconds + 5
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(gracePeriod))
            guard let self, phase == .handshake else { return }
            markFailed(SSHConnectionDiagnostics.timeoutMessage(for: host))
        }
    }
}
