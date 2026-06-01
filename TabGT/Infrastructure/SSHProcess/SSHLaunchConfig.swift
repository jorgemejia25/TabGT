import Foundation

struct SSHLaunchConfig: Hashable {
    var args: [String]
    var extraEnvironment: [String: String] = [:]
}

enum SSHConfigBuilder {
    static let sshPath = "/usr/bin/ssh"

    static func launchConfig(for host: SSHHost, workingDirectory: String?) -> SSHLaunchConfig? {
        guard var config = execConfig(for: host, remoteCommand: nil) else { return nil }

        if let remoteCommand = buildRemoteCommand(host: host, workingDirectory: workingDirectory) {
            config.args += ["-t", remoteCommand]
        }

        return config
    }

    /// Non-interactive SSH invocation for one-shot remote commands (directory listing).
    static func execConfig(for host: SSHHost, remoteCommand: String?) -> SSHLaunchConfig? {
        guard let destination = SSHInputValidator.destination(for: host) else {
            return nil
        }

        var args = baseSSHArgs(for: host)
        var extraEnv: [String: String] = [:]
        applyCredentialOptions(for: host, args: &args, extraEnvironment: &extraEnv)
        args.append(destination)

        if let remoteCommand, !remoteCommand.isEmpty {
            args.append(remoteCommand)
        }

        return SSHLaunchConfig(args: args, extraEnvironment: extraEnv)
    }

    /// Rebuilds credential-related environment variables so temp askpass/key files exist
    /// before SSH starts or retries.
    static func refreshedExtraEnvironment(for host: SSHHost, from config: SSHLaunchConfig) -> [String: String] {
        var extraEnv = config.extraEnvironment
        applyCredentialEnvironment(for: host, extraEnvironment: &extraEnv)
        return extraEnv
    }

    private static func baseSSHArgs(for host: SSHHost) -> [String] {
        [
            "-p", "\(host.port)",
            "-o", "ConnectTimeout=\(SSHConnectionDiagnostics.connectTimeoutSeconds)",
            "-o", "ConnectionAttempts=\(SSHConnectionSettings.openSSHConnectionAttempts)",
            "-o", "BatchMode=no"
        ]
    }

    private static func applyCredentialOptions(
        for host: SSHHost,
        args: inout [String],
        extraEnvironment: inout [String: String]
    ) {
        guard let credential = host.credentialRef else { return }

        switch credential.kind {
        case .privateKey:
            if let keyPath = SSHPrivateKeyHelper.resolvedKeyPath(for: credential) {
                args += ["-i", keyPath]
            }

        case .password:
            applyCredentialEnvironment(for: host, extraEnvironment: &extraEnvironment)

        case .agent:
            break
        }
    }

    private static func applyCredentialEnvironment(
        for host: SSHHost,
        extraEnvironment: inout [String: String]
    ) {
        guard let credential = host.credentialRef,
              credential.kind == .password,
              let account = credential.keychainAccount,
              SSHCredentialStorage.containsPassword(account: account),
              let scriptPath = SSHAskPassHelper.write(account: account) else {
            return
        }

        extraEnvironment["SSH_ASKPASS"] = scriptPath
        extraEnvironment["SSH_ASKPASS_REQUIRE"] = "force"
        if extraEnvironment["DISPLAY"] == nil {
            extraEnvironment["DISPLAY"] = ":0"
        }
    }

    // MARK: - Remote startup command

    private static func buildRemoteCommand(host: SSHHost, workingDirectory: String?) -> String? {
        let dir = workingDirectory.flatMap { $0.isEmpty ? nil : $0 }
        let shell = host.remoteShell.flatMap(SSHInputValidator.normalizedRemoteShell)
        let usesWindowsShell = shell.map(SSHInputValidator.isWindowsRemoteShell) ?? false
        let usesWindowsPath = dir.map(isWindowsPath) ?? false

        if usesWindowsPath || usesWindowsShell {
            return ShellIntegration.windowsRemoteLaunchCommand(directory: dir, shell: shell)
        }

        return ShellIntegration.unixRemoteLaunchCommand(directory: dir, shell: shell)
    }

    // MARK: - Windows path support

    /// Returns true when `path` looks like a Windows absolute path (e.g. `C:\...` or `C:/...`).
    nonisolated static func isWindowsPath(_ path: String) -> Bool {
        let chars = Array(path)
        if chars.count >= 3, chars[0].isLetter, chars[1] == ":",
           chars[2] == "\\" || chars[2] == "/" {
            return true
        }
        return path.contains("\\")
    }
}

// MARK: - Input validation

enum SSHInputValidator {
    nonisolated private static let usernameCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"
    )
    nonisolated private static let hostCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:-"
    )
    nonisolated private static let unixShellCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._/+-"
    )
    nonisolated private static let windowsShells: Set<String> = [
        "cmd",
        "cmd.exe",
        "powershell",
        "powershell.exe",
        "pwsh",
        "pwsh.exe"
    ]

    nonisolated static func destination(for host: SSHHost) -> String? {
        let user = host.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = host.address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidUsername(user), isValidHostAddress(address) else { return nil }
        return "\(user)@\(address)"
    }

    nonisolated static func isValidUsername(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 64
            && value.rangeOfCharacter(from: usernameCharacters.inverted) == nil
    }

    nonisolated static func isValidHostAddress(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 253
            && value.first != "-"
            && value.rangeOfCharacter(from: hostCharacters.inverted) == nil
    }

    nonisolated static func isValidRemoteShell(_ value: String) -> Bool {
        normalizedRemoteShell(value) != nil
    }

    nonisolated static func isWindowsRemoteShell(_ value: String) -> Bool {
        windowsShells.contains(value.lowercased())
    }

    nonisolated static func normalizedRemoteShell(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if windowsShells.contains(lower) {
            return trimmed
        }

        guard trimmed.hasPrefix("/"),
              trimmed.count <= 256,
              trimmed.rangeOfCharacter(from: unixShellCharacters.inverted) == nil else {
            return nil
        }

        return trimmed
    }
}

// MARK: - SSH_ASKPASS helper

/// Writes a tiny SSH_ASKPASS script that reads the password from Keychain.
enum SSHAskPassHelper {
    private static var scriptDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tabgt-askpass", isDirectory: true)
    }

    /// Ensures the askpass script exists and returns its path, or nil on failure.
    static func write(account: String) -> String? {
        let scriptURL = scriptURL(for: account)
        let dir = scriptDirectory
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700 as NSNumber],
                ofItemAtPath: dir.path
            )
        } catch {
            return nil
        }

        let script = """
        #!/bin/sh
        exec /usr/bin/security find-generic-password -s \(shellQuoted(SSHCredentialStorage.service)) -a \(shellQuoted(account)) -w
        """

        for _ in 0..<2 {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try script.write(to: scriptURL, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o700 as NSNumber],
                    ofItemAtPath: scriptURL.path
                )
                return scriptURL.path
            } catch {
                continue
            }
        }

        return nil
    }

    private static func scriptURL(for account: String) -> URL {
        let safeName = account
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return scriptDirectory.appendingPathComponent("\(safeName).askpass")
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    /// Removes stale askpass scripts from previous app sessions.
    static func cleanup() {
        try? FileManager.default.removeItem(at: scriptDirectory)
    }
}
