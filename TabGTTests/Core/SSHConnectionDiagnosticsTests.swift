import Foundation
@testable import TabGT
import Testing

@MainActor
struct SSHConnectionDiagnosticsTests {
    private let host = SSHHost(
        name: "api",
        address: "10.0.0.5",
        port: 2222,
        username: "deploy"
    )

    @Test func parseTimeoutError() {
        let message = SSHConnectionDiagnostics.parseError(
            from: "ssh: connect to host 10.0.0.5 port 2222: Operation timed out",
            host: host
        )

        #expect(message?.contains("timed out") == true)
        #expect(message?.contains("10.0.0.5") == true)
    }

    @Test func parseConnectionRefusedError() {
        let message = SSHConnectionDiagnostics.parseError(
            from: "ssh: connect to host 10.0.0.5 port 2222: Connection refused",
            host: host
        )

        #expect(message?.contains("Connection refused") == true)
        #expect(message?.contains("2222") == true)
    }

    @Test func parseAuthenticationFailure() {
        let message = SSHConnectionDiagnostics.parseError(
            from: "deploy@10.0.0.5: Permission denied (publickey,password).",
            host: host
        )

        #expect(message?.contains("Authentication failed") == true)
    }

    @Test func parseHostKeyVerificationFailure() {
        let message = SSHConnectionDiagnostics.parseError(
            from: "Host key verification failed.",
            host: host
        )

        #expect(message?.contains("Host key verification failed") == true)
    }

    @Test func parseConnectionClosedAfterHandshake() {
        let message = SSHConnectionDiagnostics.parseError(
            from: "Connection to 13.223.28.152 closed.\n",
            host: host
        )

        #expect(message?.contains("closed immediately") == true)
        #expect(message?.contains(host.displayAddress) == true)
    }

    @Test func looksConnectedDetectsLastLoginBanner() {
        #expect(
            SSHConnectionDiagnostics.looksConnected(
                "Last login: Sun May 31 09:12:01 2026 from 192.168.1.10\n"
            )
        )
    }

    @Test func looksConnectedDetectsShellPrompt() {
        #expect(
            SSHConnectionDiagnostics.looksConnected(
                "Welcome to Ubuntu 24.04 LTS\n\ndeploy@api-east-01:~$ "
            )
        )
    }

    @Test func preflightDetectsMissingPrivateKey() {
        let host = SSHHost(
            name: "lab",
            address: "192.168.1.10",
            username: "pi",
            credentialRef: CredentialRef(kind: .privateKey, label: "/tmp/missing-key")
        )

        #expect(SSHPreflightValidator.validate(host: host) == .privateKeyNotFound(path: "/tmp/missing-key"))
    }

    @Test func preflightAcceptsInlinePrivateKeyInKeychain() throws {
        let account = "inline-key-test-account"
        defer {
            SSHCredentialStorage.deletePassword(account: account)
            SSHPrivateKeyHelper.removeKeyFile(account: account)
        }

        try SSHCredentialStorage.savePassword(
            "-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----",
            account: account
        )

        let host = SSHHost(
            name: "lab",
            address: "192.168.1.10",
            username: "pi",
            credentialRef: CredentialRef(
                kind: .privateKey,
                label: "Inline private key",
                keychainAccount: account
            )
        )

        #expect(SSHPreflightValidator.validate(host: host) == nil)
    }

    @Test func launchConfigUsesInlinePrivateKeyPath() throws {
        let account = "inline-key-launch-test"
        defer {
            SSHCredentialStorage.deletePassword(account: account)
            SSHPrivateKeyHelper.removeKeyFile(account: account)
            SSHPrivateKeyHelper.cleanup()
        }

        let pem = "-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----"
        try SSHCredentialStorage.savePassword(pem, account: account)

        let host = SSHHost(
            name: "lab",
            address: "192.168.1.10",
            username: "pi",
            credentialRef: CredentialRef(
                kind: .privateKey,
                label: "Inline private key",
                keychainAccount: account
            )
        )

        let config = try #require(SSHConfigBuilder.launchConfig(for: host, workingDirectory: nil))
        let identityIndex = try #require(config.args.firstIndex(of: "-i"))
        let keyPath = config.args[identityIndex + 1]

        #expect(FileManager.default.fileExists(atPath: keyPath))
        let contents = try String(contentsOfFile: keyPath, encoding: .utf8)
        #expect(contents == pem)
    }

    @Test func preflightDetectsMissingStoredPassword() {
        let host = SSHHost(
            name: "staging",
            address: "staging.internal",
            username: "developer",
            credentialRef: CredentialRef(
                kind: .password,
                label: "Staging password",
                keychainAccount: "missing-account"
            )
        )

        #expect(SSHPreflightValidator.validate(host: host) == .passwordNotStored)
    }

    @Test func launchConfigIncludesConnectTimeout() throws {
        let host = SSHHost(name: "safe", address: "example.com", username: "deploy")
        let config = try #require(SSHConfigBuilder.launchConfig(for: host, workingDirectory: nil))

        #expect(config.args.contains("ConnectTimeout=\(SSHConnectionDiagnostics.connectTimeoutSeconds)"))
    }

    @Test func launchConfigIncludesConnectionAttemptsWhenRetriesEnabled() throws {
        SSHConnectionSettings.retriesEnabled = true
        SSHConnectionSettings.maxRetries = 4
        defer {
            SSHConnectionSettings.retriesEnabled = SSHConnectionSettings.defaultRetriesEnabled
            SSHConnectionSettings.maxRetries = SSHConnectionSettings.defaultMaxRetries
        }

        let host = SSHHost(name: "safe", address: "example.com", username: "deploy")
        let config = try #require(SSHConfigBuilder.launchConfig(for: host, workingDirectory: nil))

        #expect(config.args.contains("ConnectionAttempts=4"))
    }

    @Test func launchConfigUsesSingleAttemptWhenRetriesDisabled() throws {
        SSHConnectionSettings.retriesEnabled = false
        defer {
            SSHConnectionSettings.retriesEnabled = SSHConnectionSettings.defaultRetriesEnabled
        }

        let host = SSHHost(name: "safe", address: "example.com", username: "deploy")
        let config = try #require(SSHConfigBuilder.launchConfig(for: host, workingDirectory: nil))

        #expect(config.args.contains("ConnectionAttempts=1"))
    }
}

@MainActor
struct SessionsViewModelSSHStateTests {
    @Test func openSSHSessionStartsConnecting() {
        let viewModel = SessionsViewModel()
        let host = SSHHost(
            name: "api-east-01",
            address: "10.18.4.21",
            username: "deploy",
            credentialRef: CredentialRef(kind: .agent, label: "SSH Agent")
        )

        viewModel.openSSHSession(for: host)

        guard let session = viewModel.sessions.last else {
            Issue.record("Expected SSH session")
            return
        }

        #expect(session.state == .connecting)
        #expect(session.connectionMessage?.contains(host.displayAddress) == true)
    }

    @Test func noteSSHFailureUpdatesSessionState() {
        let viewModel = SessionsViewModel()
        let host = PreviewData.hosts[0]
        viewModel.openSSHSession(for: host)

        guard let sessionID = viewModel.sessions.last?.id else {
            Issue.record("Expected SSH session")
            return
        }

        viewModel.noteSSHFailure(sessionID: sessionID, message: "Authentication failed.")

        guard let session = viewModel.session(for: sessionID) else {
            Issue.record("Expected SSH session")
            return
        }

        #expect(session.state == .failed)
        #expect(session.connectionMessage == "Authentication failed.")
    }

    @Test func noteSSHReconnectingUpdatesSessionState() {
        let viewModel = SessionsViewModel()
        let host = PreviewData.hosts[0]
        viewModel.openSSHSession(for: host)

        guard let sessionID = viewModel.sessions.last?.id else {
            Issue.record("Expected SSH session")
            return
        }

        viewModel.noteSSHReconnecting(
            sessionID: sessionID,
            message: "Reconnecting to \(host.displayAddress) (attempt 2 of 3)…"
        )

        guard let session = viewModel.session(for: sessionID) else {
            Issue.record("Expected SSH session")
            return
        }

        #expect(session.state == .reconnecting)
        #expect(session.connectionMessage?.contains("attempt 2") == true)
    }

    @Test func noteSSHConnectedClearsConnectingMessage() {
        let viewModel = SessionsViewModel()
        let host = PreviewData.hosts[0]
        viewModel.openSSHSession(for: host)

        guard let sessionID = viewModel.sessions.last?.id else {
            Issue.record("Expected SSH session")
            return
        }

        viewModel.noteSSHConnected(sessionID: sessionID)

        guard let session = viewModel.session(for: sessionID) else {
            Issue.record("Expected SSH session")
            return
        }

        #expect(session.state == .connected)
        #expect(session.connectionMessage == nil)
    }
}
