import Foundation
import Testing
@testable import TabGT

struct DirectoryPathNormalizerTests {
    @Test func normalizesFileURL() {
        let normalized = DirectoryPathNormalizer.normalize("file:///Users/test/project")
        #expect(normalized == "/Users/test/project")
    }

    @Test func normalizesPercentEncoding() {
        let normalized = DirectoryPathNormalizer.normalize("file:///Users/test/My%20Project")
        #expect(normalized == "/Users/test/My Project")
    }

    @Test func expandsTildePath() {
        let normalized = DirectoryPathNormalizer.normalize("~/Developer")
        #expect(normalized?.contains("Developer") == true)
        #expect(normalized?.contains("~") == false)
    }

    @Test func rejectsEmptyInput() {
        #expect(DirectoryPathNormalizer.normalize(nil) == nil)
        #expect(DirectoryPathNormalizer.normalize("   ") == nil)
    }
}

struct SSHRemoteListingTests {
    @Test func unixListCommandQuotesPath() {
        let command = SSHRemoteListing.unixListCommand(for: "/var/log/my dir")
        #expect(command.contains("ls -1Ap"))
        #expect(command.contains("'"))
    }

    @Test func parsesUnixOutputWithDirectoriesAndFiles() {
        let output = """
        src/
        README.md
        """

        let entries = SSHRemoteListing.parseUnixOutput(output, parentPath: "/Users/dev/project")
        #expect(entries.count == 2)
        #expect(entries.first?.isDirectory == true)
        #expect(entries.first?.path == "/Users/dev/project/src")
        #expect(entries.last?.isDirectory == false)
        #expect(entries.last?.name == "README.md")
    }

    @Test func windowsListCommandUsesPowerShell() {
        let command = SSHRemoteListing.windowsListCommand(for: "C:\\Users\\dev")
        #expect(command.contains("Get-ChildItem"))
        #expect(command.contains("C:/Users/dev"))
    }

    @Test func parsesWindowsOutputWithMixedSeparators() {
        let output = """
        Users/
        Program Files/
        pagefile.sys
        """

        let entries = SSHRemoteListing.parseWindowsOutput(output, parentPath: "C:/")
        #expect(entries.count == 3)
        #expect(entries.first?.path == "C:\\Program Files")
        #expect(entries.first?.isDirectory == true)
        #expect(entries[1].path == "C:\\Users")
        #expect(entries.last?.isDirectory == false)
    }

    @Test func windowsPathNormalizesMixedSeparators() {
        #expect(WindowsPath.normalize("c:/Users/dev") == "C:\\Users\\dev")
        #expect(WindowsPath.driveRoot(for: "C:/Users/dev") == "C:\\")
        #expect(WindowsPath.parent(of: "C:\\Users\\dev") == "C:\\Users")
        #expect(WindowsPath.join("C:\\Users", "dev") == "C:\\Users\\dev")
        #expect(WindowsPath.forRemoteCommand("C:\\Users\\dev") == "C:/Users/dev")
    }

    @Test func normalizesWindowsDirectoryFromOSC() {
        let normalized = DirectoryPathNormalizer.normalize("c:/Users/dev/project")
        #expect(normalized == "C:\\Users\\dev\\project")
    }

    @Test func buildsUnixChangeDirectoryCommand() {
        let session = TerminalSession(
            title: "local",
            kind: .localShell(profileID: UUID(), workingDirectory: "/tmp"),
            state: .connected
        )

        let command = WorkspaceDirectoryCommand.changeDirectory(for: "/var/log", session: session, host: nil)
        #expect(command == "cd '/var/log'")
    }

    @Test func buildsWindowsChangeDirectoryCommand() {
        let hostID = UUID()
        let session = TerminalSession(
            title: "win",
            kind: .ssh(hostID: hostID, workingDirectory: "C:\\Users\\dev"),
            state: .connected
        )
        let host = SSHHost(
            id: hostID,
            name: "win",
            address: "example.com",
            username: "dev",
            remoteShell: "powershell.exe"
        )

        let command = WorkspaceDirectoryCommand.changeDirectory(
            for: "C:/Users/dev/project",
            session: session,
            host: host
        )
        #expect(command == "Set-Location 'C:\\Users\\dev\\project'")
    }

    @Test func buildsCmdChangeDirectoryCommand() {
        let hostID = UUID()
        let session = TerminalSession(
            title: "win",
            kind: .ssh(hostID: hostID, workingDirectory: "C:\\Users\\dev"),
            state: .connected
        )
        let host = SSHHost(
            id: hostID,
            name: "win",
            address: "example.com",
            username: "dev",
            remoteShell: "cmd.exe"
        )

        let command = WorkspaceDirectoryCommand.changeDirectory(
            for: "C:\\Users\\dev",
            session: session,
            host: host
        )
        #expect(command == "cd /d \"C:\\Users\\dev\"")
    }

    @Test func execConfigOmitsInteractiveTTYFlag() throws {
        let host = SSHHost(name: "server", address: "example.com", username: "deploy")
        let config = try #require(SSHConfigBuilder.execConfig(for: host, remoteCommand: "ls"))
        #expect(!config.args.contains("-t"))
        #expect(config.args.last == "ls")
    }

    @Test func launchConfigIncludesUnixShellIntegrationWithoutStartupFolder() throws {
        let host = SSHHost(name: "server", address: "example.com", username: "deploy")
        let config = try #require(SSHConfigBuilder.launchConfig(for: host, workingDirectory: nil))
        #expect(config.args.contains("-t"))
        let remoteCommand = try #require(config.args.last)
        #expect(remoteCommand.contains("__tabgt_osc7"))
        #expect(remoteCommand.contains("export -f __tabgt_osc7"))
        #expect(remoteCommand.contains("PROMPT_COMMAND"))
        #expect(remoteCommand.contains("bash -lc"))
        #expect(remoteCommand.contains("exec \"$SHELL\" -l"))
    }

    @Test func launchConfigStartupFolderDoesNotBlockShellLaunch() throws {
        let host = SSHHost(name: "server", address: "example.com", username: "deploy")
        let config = try #require(
            SSHConfigBuilder.launchConfig(for: host, workingDirectory: "/missing/path")
        )
        let remoteCommand = try #require(config.args.last)
        #expect(remoteCommand.contains("cd '/missing/path' 2>/dev/null || true"))
        #expect(remoteCommand.contains("exec \"$SHELL\" -l"))
    }

    @Test func launchConfigLoadsPowerShellProfileForWindowsIntegration() throws {
        let host = SSHHost(
            name: "win",
            address: "example.com",
            username: "dev",
            remoteShell: "powershell.exe"
        )
        let config = try #require(
            SSHConfigBuilder.launchConfig(for: host, workingDirectory: "C:\\Users\\dev")
        )
        let remoteCommand = try #require(config.args.last)
        #expect(remoteCommand.contains("-EncodedCommand"))
        let decoded = try #require(decodedPowerShellScript(from: remoteCommand))
        #expect(decoded.contains("Set-Location -LiteralPath 'C:\\Users\\dev'"))
        #expect(decoded.contains("__tabgt_git"))
        #expect(!remoteCommand.contains("-NoProfile"))
    }

    @Test func launchConfigUsesDefaultWindowsShellWithoutStartupFolder() throws {
        let host = SSHHost(
            name: "win",
            address: "example.com",
            username: "dev",
            remoteShell: "powershell.exe"
        )
        let config = try #require(SSHConfigBuilder.launchConfig(for: host, workingDirectory: nil))
        #expect(config.args.contains("-t"))
        let remoteCommand = try #require(config.args.last)
        let decoded = try #require(decodedPowerShellScript(from: remoteCommand))
        #expect(!decoded.contains("Set-Location"))
        #expect(decoded.contains("__tabgt_git"))
    }

    private func decodedPowerShellScript(from remoteCommand: String) -> String? {
        guard let range = remoteCommand.range(of: "-EncodedCommand ") else { return nil }
        let encoded = remoteCommand[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return String(data: data, encoding: .utf16LittleEndian)
    }
}

struct WorkspacePathDisplayTests {
    @Test func compactPathUsesTildeForHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = home + "/Documents/TabGT"
        #expect(WorkspacePathDisplay.compact(path) == "~/Documents/TabGT")
        #expect(WorkspacePathDisplay.currentFolderName(path) == "TabGT")
    }

    @Test func parentNavigationForUnixAndWindows() {
        #expect(WorkspacePathNavigation.parent(of: "/Users/dev/project") == "/Users/dev")
        #expect(WorkspacePathNavigation.canGoUp(from: "/") == false)
        #expect(WorkspacePathNavigation.parent(of: "C:\\Users\\dev") == "C:\\Users")
        #expect(WorkspacePathNavigation.parent(of: "C:\\Users") == "C:\\")
        #expect(WorkspacePathNavigation.canGoUp(from: "C:\\") == false)
    }
}

struct TerminalDirectoryParserTests {
    @Test func parsesPowerShellSetLocation() {
        let command = "Set-Location 'C:\\Users\\dev\\Documents'"
        #expect(TerminalDirectoryParser.directory(fromCommand: command) == "C:\\Users\\dev\\Documents")
    }

    @Test func parsesUnixCd() {
        #expect(TerminalDirectoryParser.directory(fromCommand: "cd '/var/log'") == "/var/log")
        #expect(TerminalDirectoryParser.directory(fromCommand: "cd src") == "src")
    }

    @Test func resolvesRelativeAgainstCurrentDirectory() {
        let resolved = TerminalDirectoryParser.resolve("src", relativeTo: "/Users/dev/project")
        #expect(resolved == "/Users/dev/project/src")
    }

    @Test func normalizesWindowsFileURLFromOSC() {
        let normalized = DirectoryPathNormalizer.normalize("file:///C:/Users/dev/Documents")
        #expect(normalized == "C:\\Users\\dev\\Documents")
    }

    @Test func normalizesWindowsFileURLWithBackslashes() {
        let normalized = DirectoryPathNormalizer.normalize("file:\\C:\\Users\\dev\\Documents")
        #expect(normalized == "C:\\Users\\dev\\Documents")
    }

    @Test func normalizeSessionPathDoesNotJoinOSCURLWithCurrentDirectory() {
        let normalized = DirectoryPathNormalizer.normalizeSessionPath(
            "file:///C:/Users/dev/Documents",
            relativeTo: "C:\\Users\\dev\\Development"
        )
        #expect(normalized == "C:\\Users\\dev\\Documents")
    }
}

@MainActor
struct LocalDirectoryListerTests {
    @Test func listsSortedEntries() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tabgt-list-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data().write(to: root.appendingPathComponent("zebra.txt"))
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("alpha", isDirectory: true),
            withIntermediateDirectories: true
        )

        let lister = LocalDirectoryLister()
        let entries = try await lister.listDirectory(at: root.path)

        #expect(entries.count == 2)
        #expect(entries[0].isDirectory)
        #expect(entries[0].name == "alpha")
        #expect(entries[1].name == "zebra.txt")
    }

    @Test func rejectsInvalidPath() async {
        let lister = LocalDirectoryLister()
        do {
            _ = try await lister.listDirectory(at: "/path/that/does/not/exist/tabgt")
            Issue.record("Expected invalid path error")
        } catch let error as DirectoryListingError {
            #expect(error == .invalidPath)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

struct WorkspaceFolderTreeViewModelTests {
    @Test @MainActor func unavailableWithoutSession() {
        let viewModel = WorkspaceFolderTreeViewModel()
        viewModel.bind(session: nil, host: nil)

        #expect(viewModel.phase == .unavailable("No active session"))
    }

    @Test @MainActor func unavailableForDiagnosticSession() {
        let session = TerminalSession(
            title: "diag",
            kind: .diagnostic,
            state: .connected
        )
        let viewModel = WorkspaceFolderTreeViewModel()
        viewModel.bind(session: session, host: nil)

        #expect(viewModel.phase == .unavailable("Not available for diagnostic sessions"))
    }

    @Test @MainActor func unavailableForConnectingSSHSession() {
        let hostID = UUID()
        let session = TerminalSession(
            title: "ssh",
            kind: .ssh(hostID: hostID, workingDirectory: "~/workspace"),
            state: .connecting,
            currentDirectory: "~/workspace"
        )
        let host = SSHHost(id: hostID, name: "server", address: "example.com", username: "deploy")
        let viewModel = WorkspaceFolderTreeViewModel()
        viewModel.bind(session: session, host: host)

        #expect(viewModel.phase == .unavailable("Connect to browse remote folders"))
    }

    @Test @MainActor func loadsLocalTree() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tabgt-tree-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("nested", isDirectory: true),
            withIntermediateDirectories: true
        )

        let session = TerminalSession(
            title: "local",
            kind: .localShell(profileID: UUID(), workingDirectory: root.path),
            state: .connected,
            currentDirectory: root.path
        )

        let viewModel = WorkspaceFolderTreeViewModel()
        viewModel.bind(session: session, host: nil)

        try await Task.sleep(nanoseconds: 400_000_000)

        #expect(viewModel.phase == .ready)
        #expect(viewModel.currentFolderName == root.lastPathComponent)
        #expect(viewModel.visibleRows.contains { $0.name == "nested" && $0.isDirectory })
        #expect(viewModel.canGoUp)
    }
}

struct TerminalSessionDirectoryTests {
    @Test func effectiveDirectoryPrefersCurrentDirectory() {
        let session = TerminalSession(
            title: "local",
            kind: .localShell(profileID: UUID(), workingDirectory: "/tmp/startup"),
            state: .connected,
            currentDirectory: "/tmp/live"
        )

        #expect(session.effectiveDirectory == "/tmp/live")
    }

    @Test func effectiveDirectoryFallsBackToStartupPath() {
        let session = TerminalSession(
            title: "local",
            kind: .localShell(profileID: UUID(), workingDirectory: "/tmp/startup"),
            state: .connected
        )

        #expect(session.effectiveDirectory == "/tmp/startup")
    }
}
