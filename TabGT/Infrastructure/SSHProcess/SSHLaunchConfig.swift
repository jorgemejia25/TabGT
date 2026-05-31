import Foundation

struct SSHLaunchConfig: Hashable {
    var args: [String]
    var extraEnvironment: [String: String] = [:]
}

enum SSHConfigBuilder {
    static let sshPath = "/usr/bin/ssh"

    static func launchConfig(for host: SSHHost, workingDirectory: String?) -> SSHLaunchConfig? {
        guard let destination = SSHInputValidator.destination(for: host) else {
            return nil
        }

        var args: [String] = []
        var extraEnv: [String: String] = [:]

        args += [
            "-p", "\(host.port)",
            "-o", "ConnectTimeout=\(SSHConnectionDiagnostics.connectTimeoutSeconds)",
            "-o", "BatchMode=no"
        ]

        if let credential = host.credentialRef {
            switch credential.kind {
            case .privateKey:
                let keyPath = (credential.label as NSString).expandingTildeInPath
                args += ["-i", keyPath]

            case .password:
                // Let SSH_ASKPASS read the stored password from Keychain so the
                // secret is never written into the helper script.
                if let account = credential.keychainAccount,
                   SSHCredentialStorage.containsPassword(account: account),
                   let scriptPath = SSHAskPassHelper.write(account: account) {
                    extraEnv["SSH_ASKPASS"] = scriptPath
                    // Force ssh to use the askpass helper even when a TTY is present.
                    extraEnv["SSH_ASKPASS_REQUIRE"] = "force"
                    // Some SSH versions require DISPLAY to be set to use askpass.
                    if extraEnv["DISPLAY"] == nil {
                        extraEnv["DISPLAY"] = ":0"
                    }
                }

            case .agent:
                // SSH config alias or agent — let the system ssh config handle auth.
                break
            }
        }

        args.append(destination)

        if let remoteCommand = buildRemoteCommand(host: host, workingDirectory: workingDirectory) {
            args += ["-t", remoteCommand]
        }

        return SSHLaunchConfig(args: args, extraEnvironment: extraEnv)
    }

    // MARK: - Remote startup command

    private static func buildRemoteCommand(host: SSHHost, workingDirectory: String?) -> String? {
        let dir = workingDirectory.flatMap { $0.isEmpty ? nil : $0 }
        let shell = host.remoteShell.flatMap(SSHInputValidator.normalizedRemoteShell)

        guard dir != nil || shell != nil else { return nil }

        if let dir, isWindowsPath(dir) {
            return buildWindowsRemoteCommand(dir: dir, shell: shell)
        }

        // Unix: cd to directory and exec the shell as a login shell.
        let shellExpr = shell ?? "\"$SHELL\""
        if let dir {
            let escaped = dir.replacingOccurrences(of: "'", with: "'\\''")
            return "cd '\(escaped)' && exec \(shellExpr) -l"
        } else {
            return "exec \(shellExpr) -l"
        }
    }

    // MARK: - Windows path support

    /// Returns true when `path` looks like a Windows absolute path (e.g. `C:\...` or `C:/...`).
    private static func isWindowsPath(_ path: String) -> Bool {
        let chars = Array(path)
        if chars.count >= 3, chars[0].isLetter, chars[1] == ":",
           chars[2] == "\\" || chars[2] == "/" {
            return true
        }
        return path.contains("\\")
    }

    /// Builds a remote command for a Windows SSH server (OpenSSH for Windows).
    /// Uses PowerShell by default; falls back to cmd when the configured shell is cmd.exe.
    private static func buildWindowsRemoteCommand(dir: String, shell: String?) -> String? {
        let resolvedShell = shell ?? "powershell"
        let lower = resolvedShell.lowercased()

        if lower.hasSuffix("cmd.exe") || lower == "cmd" {
            // cmd: /d lets cd cross drive letters.
            // Escape double quotes inside the path.
            let escaped = dir.replacingOccurrences(of: "\"", with: "\\\"")
            return "cmd /k \"cd /d \\\"\(escaped)\\\"\""
        } else {
            // PowerShell / pwsh: single quotes inside a PS string are doubled.
            let escaped = dir.replacingOccurrences(of: "'", with: "''")
            return "\(resolvedShell) -NoExit -Command \"Set-Location '\(escaped)'\""
        }
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

    /// Writes the script and returns its path, or nil on failure.
    static func write(account: String) -> String? {
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

        let scriptURL = dir.appendingPathComponent(UUID().uuidString)
        let script = """
        #!/bin/sh
        exec /usr/bin/security find-generic-password -s \(shellQuoted(SSHCredentialStorage.service)) -a \(shellQuoted(account)) -w
        """

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700 as NSNumber],
                ofItemAtPath: scriptURL.path
            )
            return scriptURL.path
        } catch {
            return nil
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    /// Removes stale askpass scripts from previous sessions.
    static func cleanup() {
        try? FileManager.default.removeItem(at: scriptDirectory)
    }
}
