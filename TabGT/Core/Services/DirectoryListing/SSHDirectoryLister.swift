import Foundation

enum SSHRemoteListing {
    static func listCommand(for path: String) -> String {
        if SSHConfigBuilder.isWindowsPath(path) {
            return windowsListCommand(for: path)
        }
        return unixListCommand(for: path)
    }

    static func unixListCommand(for path: String) -> String {
        let escaped = shellSingleQuoted(path)
        return "ls -1Ap \(escaped)"
    }

    static func windowsListCommand(for path: String) -> String {
        let remotePath = WindowsPath.forRemoteCommand(path)
        let escaped = remotePath.replacingOccurrences(of: "'", with: "''")
        return "powershell -NoProfile -Command \"Get-ChildItem -LiteralPath '\(escaped)' -Force | ForEach-Object { if ($_.PSIsContainer) { $_.Name + '/' } else { $_.Name } }\""
    }

    static func parseOutput(_ output: String, parentPath: String) -> [FileTreeEntry] {
        if SSHConfigBuilder.isWindowsPath(parentPath) {
            return parseWindowsOutput(output, parentPath: parentPath)
        }
        return parseUnixOutput(output, parentPath: parentPath)
    }

    static func parseUnixOutput(_ output: String, parentPath: String) -> [FileTreeEntry] {
        let normalizedParent = parentPath.hasSuffix("/") ? String(parentPath.dropLast()) : parentPath
        let entries = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .map { line -> FileTreeEntry in
                let isDirectory = line.hasSuffix("/")
                let name = isDirectory ? String(line.dropLast()) : line
                let childPath = normalizedParent.isEmpty ? name : "\(normalizedParent)/\(name)"
                return FileTreeEntry(name: name, path: childPath, isDirectory: isDirectory)
            }

        return FileTreeSorting.sorted(entries)
    }

    static func parseWindowsOutput(_ output: String, parentPath: String) -> [FileTreeEntry] {
        let normalizedParent = WindowsPath.normalize(parentPath)
        let entries = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .map { line -> FileTreeEntry in
                let isDirectory = line.hasSuffix("/")
                let name = isDirectory ? String(line.dropLast()) : line
                let childPath = WindowsPath.join(normalizedParent, name)
                return FileTreeEntry(name: name, path: childPath, isDirectory: isDirectory)
            }

        return FileTreeSorting.sorted(entries)
    }

    static func shellSingleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

struct SSHDirectoryLister: DirectoryListingService {
    let host: SSHHost
    private let timeoutSeconds: TimeInterval

    init(host: SSHHost, timeoutSeconds: TimeInterval = 12) {
        self.host = host
        self.timeoutSeconds = timeoutSeconds
    }

    func listDirectory(at path: String) async throws -> [FileTreeEntry] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DirectoryListingError.invalidPath
        }

        let remoteCommand = SSHRemoteListing.listCommand(for: trimmed)
        guard let config = SSHConfigBuilder.execConfig(for: host, remoteCommand: remoteCommand) else {
            throw DirectoryListingError.commandFailed("Invalid SSH host configuration.")
        }

        let result = try await SSHProcessRunner.run(
            executable: SSHConfigBuilder.sshPath,
            args: config.args,
            environment: config.extraEnvironment,
            timeout: timeoutSeconds
        )

        guard result.exitCode == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if message.localizedCaseInsensitiveContains("timed out") {
                throw DirectoryListingError.timedOut
            }
            throw DirectoryListingError.commandFailed(
                message.isEmpty ? "Remote directory listing failed." : message
            )
        }

        return SSHRemoteListing.parseOutput(result.stdout, parentPath: trimmed)
    }

    func currentWorkingDirectory() async throws -> String {
        guard let config = SSHConfigBuilder.execConfig(for: host, remoteCommand: "pwd") else {
            throw DirectoryListingError.commandFailed("Invalid SSH host configuration.")
        }

        let result = try await SSHProcessRunner.run(
            executable: SSHConfigBuilder.sshPath,
            args: config.args,
            environment: config.extraEnvironment,
            timeout: timeoutSeconds
        )

        guard result.exitCode == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw DirectoryListingError.commandFailed(
                message.isEmpty ? "Could not resolve remote working directory." : message
            )
        }

        let pwd = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pwd.isEmpty else {
            throw DirectoryListingError.commandFailed("Could not resolve remote working directory.")
        }

        return pwd
    }
}

enum SSHProcessRunner {
    struct Result {
        var exitCode: Int32
        var stdout: String
        var stderr: String
    }

    static func run(
        executable: String,
        args: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval
    ) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args

                var mergedEnvironment = ProcessInfo.processInfo.environment
                for (key, value) in environment {
                    mergedEnvironment[key] = value
                }
                process.environment = mergedEnvironment

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let group = DispatchGroup()
                group.enter()

                var timedOut = false
                let timeoutWork = DispatchWorkItem {
                    timedOut = true
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

                process.terminationHandler = { _ in
                    timeoutWork.cancel()
                    group.leave()
                }

                do {
                    try process.run()
                } catch {
                    timeoutWork.cancel()
                    continuation.resume(throwing: DirectoryListingError.commandFailed(error.localizedDescription))
                    return
                }

                group.wait()

                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if timedOut {
                    continuation.resume(throwing: DirectoryListingError.timedOut)
                    return
                }

                continuation.resume(returning: Result(
                    exitCode: process.terminationStatus,
                    stdout: stdout,
                    stderr: stderr
                ))
            }
        }
    }
}
