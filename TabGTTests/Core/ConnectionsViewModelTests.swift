import Foundation
@testable import TabGT
import Testing

@MainActor
struct ConnectionsViewModelTests {
    @Test func saveAddsHostAndSelectsIt() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let repository = SSHHostRepository(fileManager: SSHHostTestFileManager(baseDirectory: tempDirectory))
        let viewModel = ConnectionsViewModel(groups: [], hosts: [], repository: repository)

        let host = SSHHost(name: "lab", address: "192.168.1.44", username: "pi")
        viewModel.save(host)

        #expect(viewModel.hosts.count == 1)
        #expect(viewModel.hosts.first?.name == "lab")
        #expect(viewModel.selectedHostID == host.id)

        let loaded = try repository.loadAll()
        #expect(loaded.hosts.count == 1)
        #expect(loaded.hosts.first?.address == "192.168.1.44")
    }

    @Test func deleteRemovesHostAndClearsSelection() throws {
        let tempDirectory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let repository = SSHHostRepository(fileManager: SSHHostTestFileManager(baseDirectory: tempDirectory))
        let host = SSHHost(name: "worker", address: "10.0.0.2", username: "ops")
        let viewModel = ConnectionsViewModel(groups: [], hosts: [host], repository: repository)

        viewModel.select(host)
        viewModel.delete(host.id)

        #expect(viewModel.hosts.isEmpty)
        #expect(viewModel.selectedHostID == nil)

        let loaded = try repository.loadAll()
        #expect(loaded.hosts.isEmpty)
    }

    @Test func filteredHostsMatchesSearchQuery() {
        let hosts = [
            SSHHost(name: "api-east", address: "10.18.4.21", username: "deploy"),
            SSHHost(name: "staging-app", address: "staging.internal", username: "developer")
        ]
        let viewModel = ConnectionsViewModel(groups: [], hosts: hosts)

        viewModel.searchText = "staging"
        #expect(viewModel.filteredHosts.count == 1)
        #expect(viewModel.filteredHosts.first?.name == "staging-app")

        viewModel.searchText = "deploy"
        #expect(viewModel.filteredHosts.count == 1)
        #expect(viewModel.filteredHosts.first?.username == "deploy")
    }

    private func makeTemporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class SSHHostTestFileManager: FileManager {
    private let baseDirectory: URL

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
        super.init()
    }

    override func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        guard directory == .applicationSupportDirectory else {
            return super.urls(for: directory, in: domainMask)
        }
        return [baseDirectory]
    }
}
