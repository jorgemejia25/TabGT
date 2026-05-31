import Foundation

struct KeybindingRepository {
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    var keybindingsFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("TabGT", isDirectory: true)
            .appendingPathComponent("keybindings.json")
    }

    var displayPath: String {
        keybindingsFileURL.path(percentEncoded: false)
            .replacingOccurrences(of: fileManager.homeDirectoryForCurrentUser.path, with: "~")
    }

    func loadUserOverrides() throws -> KeybindingsDocument? {
        try ensureTabGTDirectoryExists()

        guard fileManager.fileExists(atPath: keybindingsFileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: keybindingsFileURL)
        return try KeybindingImporter.decode(data: data)
    }

    func seedIfNeeded() throws {
        try ensureTabGTDirectoryExists()

        guard !fileManager.fileExists(atPath: keybindingsFileURL.path) else {
            return
        }

        let seedData = try bundledSeedData()
        try SecureFileStore.write(seedData, to: keybindingsFileURL, fileManager: fileManager)
    }

    func save(_ document: KeybindingsDocument) throws {
        try ensureTabGTDirectoryExists()
        let data = try encoder.encode(document)
        try SecureFileStore.write(data, to: keybindingsFileURL, fileManager: fileManager)
    }

    func resetToDefaults() throws {
        if fileManager.fileExists(atPath: keybindingsFileURL.path) {
            try fileManager.removeItem(at: keybindingsFileURL)
        }
        try seedIfNeeded()
    }

    func bundledSeedData() throws -> Data {
        if let url = Bundle.main.url(forResource: "default-keybindings", withExtension: "json") {
            return try Data(contentsOf: url)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(KeybindingCatalog.defaultDocument)
    }

    private func ensureTabGTDirectoryExists() throws {
        let directoryURL = keybindingsFileURL.deletingLastPathComponent()
        try SecureFileStore.ensureDirectory(directoryURL, fileManager: fileManager)
    }
}
