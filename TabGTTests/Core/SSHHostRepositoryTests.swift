import Foundation
@testable import TabGT
import Testing

struct SSHHostRepositoryTests {
    @Test func firstLoadCreatesEmptyCatalog() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let repository = SSHHostRepository(fileManager: SSHHostTestFileManager(baseDirectory: tempDirectory))
        let loaded = try repository.loadAll()

        #expect(loaded.groups.isEmpty)
        #expect(loaded.hosts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: repository.sshHostsFileURL.path))
    }

    @Test func saveLoadRoundTripPreservesHosts() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fileManager = SSHHostTestFileManager(baseDirectory: tempDirectory)
        let repository = SSHHostRepository(fileManager: fileManager)

        let host = SSHHost(
            name: "staging-app",
            address: "staging.internal",
            port: 2222,
            username: "developer",
            credentialRef: CredentialRef(kind: .privateKey, label: "~/.ssh/id_ed25519")
        )

        try repository.saveAll(groups: [], hosts: [host])
        let loaded = try repository.loadAll()
        let directoryPermissions = try permissions(at: repository.profilesDirectoryURL)
        let filePermissions = try permissions(at: repository.sshHostsFileURL)

        #expect(loaded.hosts.count == 1)
        #expect(loaded.hosts.first?.name == "staging-app")
        #expect(loaded.hosts.first?.port == 2222)
        #expect(loaded.hosts.first?.credentialRef?.kind == .privateKey)
        #expect(loaded.hosts.first?.credentialRef?.label == "~/.ssh/id_ed25519")
        #expect(FileManager.default.fileExists(atPath: repository.backupFileURL.path))
        #expect(directoryPermissions == 0o700)
        #expect(filePermissions == 0o600)
    }

    @Test func loadCatalogRecoversFromBackupWhenPrimaryIsCorrupt() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fileManager = SSHHostTestFileManager(baseDirectory: tempDirectory)
        let repository = SSHHostRepository(fileManager: fileManager)
        let host = SSHHost(name: "worker", address: "10.0.0.2", username: "ops")

        try repository.saveAll(groups: [], hosts: [host])
        try "not-json".write(to: repository.sshHostsFileURL, atomically: true, encoding: .utf8)

        let loaded = try repository.loadCatalog()

        #expect(loaded.hosts.count == 1)
        #expect(loaded.hosts.first?.name == "worker")
    }

    @Test func loadCatalogMigratesLegacySandboxFileWhenPrimaryIsEmpty() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let fileManager = SSHHostTestFileManager(baseDirectory: tempDirectory)
        fileManager.simulatedHomeDirectory = tempDirectory.appendingPathComponent("Home", isDirectory: true)
        try FileManager.default.createDirectory(at: fileManager.simulatedHomeDirectory!, withIntermediateDirectories: true)

        let repository = SSHHostRepository(fileManager: fileManager)
        let legacyHost = SSHHost(name: "legacy-host", address: "192.168.0.10", username: "admin")

        let legacyDirectory = fileManager.simulatedHomeDirectory!
            .appendingPathComponent(SSHHostRepository.legacySandboxHostsRelativePath)
            .deletingLastPathComponent()
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let legacyDocument = SSHHostsDocument(groups: [], hosts: [legacyHost])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let legacyData = try encoder.encode(legacyDocument)
        try legacyData.write(to: legacyDirectory.appendingPathComponent("ssh-hosts.json"))

        let loaded = try repository.loadCatalog()

        #expect(loaded.hosts.count == 1)
        #expect(loaded.hosts.first?.name == "legacy-host")
        #expect(FileManager.default.fileExists(atPath: repository.sshHostsFileURL.path))
    }

    @Test func documentEncodesCredentialRef() throws {
        let host = SSHHost(
            name: "api-east-01",
            address: "10.18.4.21",
            username: "deploy",
            credentialRef: CredentialRef(kind: .password, label: "Password")
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()

        let document = SSHHostsDocument(groups: [], hosts: [host])
        let data = try encoder.encode(document)
        let decoded = try decoder.decode(SSHHostsDocument.self, from: data)

        #expect(decoded.hosts.first?.credentialRef?.kind == .password)
        #expect(decoded.hosts.first?.credentialRef?.label == "Password")
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func permissions(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.posixPermissions] as? Int ?? -1
    }
}

private final class SSHHostTestFileManager: FileManager {
    private let baseDirectory: URL
    var simulatedHomeDirectory: URL?

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
        super.init()
    }

    override var homeDirectoryForCurrentUser: URL {
        simulatedHomeDirectory ?? super.homeDirectoryForCurrentUser
    }

    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        guard directory == .applicationSupportDirectory else {
            return super.urls(for: directory, in: domainMask)
        }
        return [baseDirectory]
    }
}
