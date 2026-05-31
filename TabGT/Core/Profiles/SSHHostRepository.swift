import Foundation

struct SSHHostCatalog: Equatable {
    var groups: [HostGroup]
    var hosts: [SSHHost]
}

struct SSHHostRepository {
    static let legacySandboxHostsRelativePath =
        "Library/Containers/com.github.jorgemejia.TabGT/Data/Library/Application Support/TabGT/profiles/ssh-hosts.json"

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    var profilesDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("TabGT", isDirectory: true)
            .appendingPathComponent("profiles", isDirectory: true)
    }

    var sshHostsFileURL: URL {
        profilesDirectoryURL.appendingPathComponent("ssh-hosts.json")
    }

    var backupFileURL: URL {
        sshHostsFileURL.appendingPathExtension("bak")
    }

    func loadAll() throws -> (groups: [HostGroup], hosts: [SSHHost]) {
        let catalog = try loadCatalog()
        return (catalog.groups, catalog.hosts)
    }

    func loadCatalog() throws -> SSHHostCatalog {
        try ensureProfilesDirectoryExists()

        if fileManager.fileExists(atPath: sshHostsFileURL.path) {
            if let catalog = try? decodeCatalog(from: sshHostsFileURL), catalog.hasContent {
                return catalog
            }

            if let catalog = try? decodeCatalog(from: sshHostsFileURL), !catalog.hasContent {
                if let migrated = try migrateLegacyCatalogIfNeeded() {
                    try saveAll(groups: migrated.groups, hosts: migrated.hosts)
                    return migrated
                }
                return catalog
            }

            if let backupCatalog = try? decodeCatalog(from: backupFileURL), backupCatalog.hasContent {
                try saveAll(groups: backupCatalog.groups, hosts: backupCatalog.hosts)
                return backupCatalog
            }

            if let legacyCatalog = try migrateLegacyCatalogIfNeeded() {
                archiveCorruptPrimaryFile()
                try saveAll(groups: legacyCatalog.groups, hosts: legacyCatalog.hosts)
                return legacyCatalog
            }

            archiveCorruptPrimaryFile()
        } else if let legacyCatalog = try migrateLegacyCatalogIfNeeded() {
            try saveAll(groups: legacyCatalog.groups, hosts: legacyCatalog.hosts)
            return legacyCatalog
        }

        let empty = SSHHostSeeds.emptyCatalog()
        try saveAll(groups: empty.groups, hosts: empty.hosts)
        return SSHHostCatalog(groups: empty.groups, hosts: empty.hosts)
    }

    func saveAll(groups: [HostGroup], hosts: [SSHHost]) throws {
        try ensureProfilesDirectoryExists()

        let document = SSHHostsDocument(groups: groups, hosts: hosts)
        let data = try encoder.encode(document)
        try SecureFileStore.write(data, to: sshHostsFileURL, fileManager: fileManager)

        try? fileManager.removeItem(at: backupFileURL)
        try? fileManager.copyItem(at: sshHostsFileURL, to: backupFileURL)
    }

    private func decodeCatalog(from fileURL: URL) throws -> SSHHostCatalog {
        let data = try Data(contentsOf: fileURL)
        let document = try decoder.decode(SSHHostsDocument.self, from: data)
        return SSHHostCatalog(
            groups: document.groups.sorted { $0.sortOrder < $1.sortOrder },
            hosts: document.hosts
        )
    }

    private func migrateLegacyCatalogIfNeeded() throws -> SSHHostCatalog? {
        let legacyURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(Self.legacySandboxHostsRelativePath)

        guard fileManager.fileExists(atPath: legacyURL.path) else {
            return nil
        }

        let catalog = try decodeCatalog(from: legacyURL)
        guard catalog.hasContent else {
            return nil
        }

        return catalog
    }

    private func archiveCorruptPrimaryFile() {
        let corruptURL = sshHostsFileURL.appendingPathExtension("corrupt")
        try? fileManager.removeItem(at: corruptURL)
        try? fileManager.moveItem(at: sshHostsFileURL, to: corruptURL)
    }

    private func ensureProfilesDirectoryExists() throws {
        try SecureFileStore.ensureDirectory(profilesDirectoryURL, fileManager: fileManager)
    }
}

private extension SSHHostCatalog {
    var hasContent: Bool {
        !groups.isEmpty || !hosts.isEmpty
    }
}
