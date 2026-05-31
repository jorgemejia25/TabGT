import Combine
import Foundation
import os

@MainActor
final class ConnectionsViewModel: ObservableObject {
    private static var sharedInstance: ConnectionsViewModel?

    static var shared: ConnectionsViewModel {
        if let sharedInstance {
            return sharedInstance
        }
        let instance = live()
        sharedInstance = instance
        return instance
    }

    @Published var groups: [HostGroup]
    @Published var hosts: [SSHHost]
    @Published var searchText = ""
    @Published var selectedHostID: UUID?
    @Published private(set) var persistenceError: String?

    private let repository: SSHHostRepository
    private let logger = Logger(subsystem: "com.github.jorgemejia.TabGT", category: "SSHHostPersistence")

    init(
        groups: [HostGroup],
        hosts: [SSHHost],
        repository: SSHHostRepository? = nil
    ) {
        self.groups = groups.sorted { $0.sortOrder < $1.sortOrder }
        self.hosts = hosts
        self.repository = repository ?? SSHHostRepository()
        self.selectedHostID = hosts.first?.id
    }

    var filteredHosts: [SSHHost] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return hosts
        }

        let query = searchText.lowercased()
        return hosts.filter { host in
            host.name.lowercased().contains(query)
                || host.address.lowercased().contains(query)
                || host.username.lowercased().contains(query)
                || host.tags.contains { $0.lowercased().contains(query) }
        }
    }

    var selectedHost: SSHHost? {
        guard let selectedHostID else { return nil }
        return hosts.first { $0.id == selectedHostID }
    }

    func hosts(in group: HostGroup) -> [SSHHost] {
        filteredHosts.filter { $0.groupID == group.id }
    }

    func select(_ host: SSHHost) {
        selectedHostID = host.id
    }

    func save(_ host: SSHHost) {
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
        } else {
            hosts.append(host)
        }
        selectedHostID = host.id
        persist()
    }

    func sshLaunchConfig(for session: TerminalSession) -> SSHLaunchConfig? {
        guard case .ssh(let hostID, let workingDirectory) = session.kind,
              let host = hosts.first(where: { $0.id == hostID }) else {
            return nil
        }
        return SSHConfigBuilder.launchConfig(for: host, workingDirectory: workingDirectory)
    }

    func host(for session: TerminalSession) -> SSHHost? {
        guard case .ssh(let hostID, _) = session.kind else { return nil }
        return hosts.first { $0.id == hostID }
    }

    func delete(_ hostID: UUID) {
        if let host = hosts.first(where: { $0.id == hostID }),
           host.credentialRef?.kind == .password,
           let account = host.credentialRef?.keychainAccount {
            SSHCredentialStorage.deletePassword(account: account)
        }

        hosts.removeAll { $0.id == hostID }
        if selectedHostID == hostID {
            selectedHostID = hosts.first?.id
        }
        persist()
    }

    func flushToDisk() {
        persist()
    }

    private func persist() {
        do {
            try repository.saveAll(groups: groups, hosts: hosts)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
            logger.error("Failed to save SSH hosts: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func live(repository: SSHHostRepository? = nil) -> ConnectionsViewModel {
        let repository = repository ?? SSHHostRepository()
        let catalog: SSHHostCatalog
        do {
            catalog = try repository.loadCatalog()
        } catch {
            Logger(subsystem: "com.github.jorgemejia.TabGT", category: "SSHHostPersistence")
                .error("Failed to load SSH hosts: \(error.localizedDescription, privacy: .public)")
            let empty = SSHHostSeeds.emptyCatalog()
            catalog = SSHHostCatalog(groups: empty.groups, hosts: empty.hosts)
        }

        return ConnectionsViewModel(
            groups: catalog.groups,
            hosts: catalog.hosts,
            repository: repository
        )
    }

    static func preview() -> ConnectionsViewModel {
        ConnectionsViewModel(groups: PreviewData.groups, hosts: PreviewData.hosts)
    }
}
