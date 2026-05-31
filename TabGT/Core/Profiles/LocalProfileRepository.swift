import Foundation

struct LocalProfileRepository {
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

    var localProfilesFileURL: URL {
        profilesDirectoryURL.appendingPathComponent("local.json")
    }

    func loadAll() throws -> [LocalTerminalProfile] {
        try ensureProfilesDirectoryExists()

        guard fileManager.fileExists(atPath: localProfilesFileURL.path) else {
            let seeds = LocalProfileSeeds.profiles()
            try saveAll(seeds)
            return seeds
        }

        let data = try Data(contentsOf: localProfilesFileURL)
        let document = try decoder.decode(LocalProfilesDocument.self, from: data)
        return document.profiles.sorted { $0.sortOrder < $1.sortOrder }
    }

    func saveAll(_ profiles: [LocalTerminalProfile]) throws {
        try ensureProfilesDirectoryExists()
        let document = LocalProfilesDocument(profiles: profiles)
        let data = try encoder.encode(document)
        try SecureFileStore.write(data, to: localProfilesFileURL, fileManager: fileManager)
    }

    private func ensureProfilesDirectoryExists() throws {
        try SecureFileStore.ensureDirectory(profilesDirectoryURL, fileManager: fileManager)
    }
}
