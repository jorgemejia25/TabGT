import Foundation

enum SSHPreflightIssue: Equatable {
    case privateKeyNotFound(path: String)
    case passwordNotStored
    case invalidDestination
}

enum SSHPreflightValidator {
    static func validate(host: SSHHost) -> SSHPreflightIssue? {
        guard SSHInputValidator.destination(for: host) != nil else {
            return .invalidDestination
        }

        guard let credential = host.credentialRef else { return nil }

        switch credential.kind {
        case .privateKey:
            let keyPath = (credential.label as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: keyPath) else {
                return .privateKeyNotFound(path: keyPath)
            }

        case .password:
            guard let account = credential.keychainAccount,
                  SSHCredentialStorage.containsPassword(account: account) else {
                return .passwordNotStored
            }

        case .agent:
            break
        }

        return nil
    }
}

enum SSHConnectionDiagnostics {
    static let connectTimeoutSeconds = 15

    static func message(for issue: SSHPreflightIssue, host: SSHHost) -> String {
        switch issue {
        case .privateKeyNotFound(let path):
            return "Private key not found at \(path). Check the key path in the connection settings."
        case .passwordNotStored:
            return "No password is stored in Keychain for \(host.displayAddress). Edit the connection and save the password again."
        case .invalidDestination:
            return "The connection target is invalid. Check the username and host address."
        }
    }

    static func message(forExitCode code: Int32, host: SSHHost) -> String {
        switch code {
        case 255:
            return "SSH could not connect to \(host.displayAddress). Review the terminal output for details."
        case 130:
            return "Connection to \(host.displayAddress) was interrupted."
        default:
            return "SSH session to \(host.displayAddress) ended unexpectedly (exit code \(code))."
        }
    }

    static func connectingMessage(for host: SSHHost) -> String {
        "Connecting to \(host.displayAddress)…"
    }

    static func timeoutMessage(for host: SSHHost) -> String {
        "Connection timed out after \(connectTimeoutSeconds)s while reaching \(host.displayAddress). Check the host, port, firewall, and network."
    }

    /// Returns a user-facing message when OpenSSH output matches a known failure.
    static func parseError(from output: String, host: SSHHost) -> String? {
        let normalized = output.lowercased()

        if normalized.contains("operation timed out")
            || normalized.contains("connection timed out")
            || normalized.contains("timed out waiting") {
            return timeoutMessage(for: host)
        }

        if normalized.contains("connection refused") {
            return "Connection refused by \(host.displayAddress). Verify that SSH is running and port \(host.port) is open."
        }

        if normalized.contains("no route to host") {
            return "No route to host \(host.address). Check your network or VPN."
        }

        if normalized.contains("network is unreachable") {
            return "Network is unreachable while connecting to \(host.displayAddress)."
        }

        if normalized.contains("could not resolve hostname")
            || normalized.contains("name or service not known") {
            return "Could not resolve hostname \"\(host.address)\". Check the address or DNS settings."
        }

        if normalized.contains("host key verification failed") {
            return "Host key verification failed for \(host.address). The server identity may have changed."
        }

        if normalized.contains("too many authentication failures") {
            return "Too many authentication failures for \(host.displayAddress). Verify your keys and agent."
        }

        if normalized.contains("permission denied") {
            return "Authentication failed for \(host.displayAddress). Check your username, password, or SSH key."
        }

        if normalized.contains("identity file")
            && (normalized.contains("not accessible") || normalized.contains("no such file")) {
            return "The configured SSH key could not be read. Check the key path and file permissions."
        }

        if normalized.contains("ssh: connect to host") && normalized.contains("port \(host.port)") {
            if normalized.contains("network is unreachable") {
                return "Network is unreachable while connecting to \(host.displayAddress)."
            }
        }

        if normalized.contains("ssh_exchange_identification")
            || normalized.contains("kex_exchange_identification") {
            return "SSH handshake failed with \(host.displayAddress). The server may be blocking the connection."
        }

        return nil
    }

    /// Heuristic for the first successful bytes from an interactive remote shell.
    static func looksConnected(_ output: String) -> Bool {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 24 else { return false }

        let normalized = trimmed.lowercased()
        if normalized.contains("last login:") { return true }
        if normalized.contains("welcome to") { return true }

        let lines = trimmed.split(whereSeparator: \.isNewline).map(String.init)
        if let lastLine = lines.last?.trimmingCharacters(in: .whitespacesAndNewlines),
           lastLine.hasSuffix("$") || lastLine.hasSuffix("#") || lastLine.hasSuffix("%") {
            return true
        }

        return trimmed.count >= 96 && parseError(from: output, host: placeholderHost) == nil
    }

    private static let placeholderHost = SSHHost(
        name: "host",
        address: "example.com",
        username: "user"
    )
}
