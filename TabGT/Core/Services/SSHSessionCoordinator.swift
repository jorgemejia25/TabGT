import Foundation
import SwiftTerm

/// Tracks SSH handshake output and process lifecycle for a single terminal session.
@MainActor
final class SSHSessionCoordinator: TerminalMetricsCoordinator {
    private enum Phase {
        case handshake
        case connected
        case failed
    }

    private let host: SSHHost
    private let launchConfig: SSHLaunchConfig

    var lastRetryRequestID: UUID?
    var onInputDeliveryReady: (() -> Void)?

    private var phase: Phase = .handshake
    private var outputBuffer = ""
    private var timeoutTask: Task<Void, Never>?
    private var attemptNumber = 1
    private var ignoreNextTermination = false

    private var maxAttempts: Int {
        SSHConnectionSettings.retriesEnabled ? SSHConnectionSettings.maxRetries : 1
    }

    init(
        sessionID: UUID,
        host: SSHHost,
        launchConfig: SSHLaunchConfig,
        sessions: SessionsViewModel
    ) {
        self.host = host
        self.launchConfig = launchConfig
        super.init(sessionID: sessionID, sessions: sessions)
        setInputDeliveryReady(false)
        startTimeoutWatchdog()
    }

    @MainActor
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
            handleHandshakeFailure(message)
            return
        }

        if SSHConnectionDiagnostics.looksConnected(outputBuffer) {
            markConnected()
        }
    }

    override func processTerminated(source: TerminalView, exitCode: Int32?) {
        if ignoreNextTermination {
            ignoreNextTermination = false
            return
        }

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
            handleHandshakeFailure(message)
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

    /// User-initiated retry from the connection panel.
    func retryConnection() {
        attemptNumber = 1
        outputBuffer = ""
        phase = .handshake
        setInputDeliveryReady(false)
        timeoutTask?.cancel()
        startTimeoutWatchdog()
        sessions?.noteSSHReconnecting(
            sessionID: sessionID,
            message: SSHConnectionDiagnostics.connectingMessage(for: host)
        )
        relaunchSSHProcess()
    }

    func finishConnectionMonitoring() {
        // Handshake monitoring stops via `phase`; keep the callback for retries.
    }

    private func markConnected() {
        guard phase == .handshake else { return }
        phase = .connected
        attemptNumber = 1
        timeoutTask?.cancel()
        finishConnectionMonitoring()
        sessions?.noteSSHConnected(sessionID: sessionID)
        Task { @MainActor in
            await probeWorkingDirectoryIfNeeded()
            if isWindowsRemoteShell {
                try? await Task.sleep(for: .milliseconds(500))
            }
            setInputDeliveryReady(true)
            onInputDeliveryReady?()
        }
    }

    private var isWindowsRemoteShell: Bool {
        if let shell = host.remoteShell,
           SSHInputValidator.isWindowsRemoteShell(shell) {
            return true
        }

        guard let session = sessions?.session(for: sessionID),
              let directory = session.kind.workingDirectory else {
            return false
        }

        return SSHConfigBuilder.isWindowsPath(directory)
    }

    private func probeWorkingDirectoryIfNeeded() async {
        guard let sessions,
              let session = sessions.session(for: sessionID),
              session.effectiveDirectory == nil else {
            return
        }

        let lister = SSHDirectoryLister(host: host)
        guard let pwd = try? await lister.currentWorkingDirectory() else { return }
        sessions.updateCurrentDirectory(sessionID: sessionID, directory: pwd)
    }

    private func handleHandshakeFailure(_ message: String) {
        guard phase != .failed else { return }

        if SSHConnectionSettings.retriesEnabled, attemptNumber < maxAttempts {
            scheduleRetry(afterFailure: message)
            return
        }

        markFailed(message)
    }

    private func scheduleRetry(afterFailure message: String) {
        attemptNumber += 1
        outputBuffer = ""
        phase = .handshake
        setInputDeliveryReady(false)
        timeoutTask?.cancel()
        startTimeoutWatchdog()

        sessions?.noteSSHReconnecting(
            sessionID: sessionID,
            message: SSHConnectionDiagnostics.reconnectingMessage(
                attempt: attemptNumber,
                maxAttempts: maxAttempts,
                host: host
            )
        )

        relaunchSSHProcess()
    }

    private func relaunchSSHProcess() {
        ignoreNextTermination = true
        let extraEnvironment = SSHConfigBuilder.refreshedExtraEnvironment(for: host, from: launchConfig)
        terminalView?.relaunchProcess(
            executable: SSHConfigBuilder.sshPath,
            args: launchConfig.args,
            extraEnvironment: extraEnvironment
        )
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
            handleHandshakeFailure(SSHConnectionDiagnostics.timeoutMessage(for: host))
        }
    }
}
