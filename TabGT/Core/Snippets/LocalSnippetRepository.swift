import Foundation

struct LocalSnippetRepository {
    private let fileManager: FileManager
    private let customBaseURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, customBaseURL: URL? = nil) {
        self.fileManager = fileManager
        self.customBaseURL = customBaseURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    var snippetsDirectoryURL: URL {
        if let customBaseURL {
            return customBaseURL
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("TabGT", isDirectory: true)
            .appendingPathComponent("snippets", isDirectory: true)
    }

    var snippetsFileURL: URL {
        snippetsDirectoryURL.appendingPathComponent("snippets.json")
    }

    func loadAll() throws -> [CommandSnippet] {
        try ensureSnippetsDirectoryExists()

        guard fileManager.fileExists(atPath: snippetsFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: snippetsFileURL)
        let document = try decoder.decode(SnippetsDocument.self, from: data)
        return document.snippets
    }

    func saveAll(_ snippets: [CommandSnippet]) throws {
        try ensureSnippetsDirectoryExists()
        let document = SnippetsDocument(snippets: snippets)
        let data = try encoder.encode(document)
        try SecureFileStore.write(data, to: snippetsFileURL, fileManager: fileManager)
    }

    private func ensureSnippetsDirectoryExists() throws {
        try SecureFileStore.ensureDirectory(snippetsDirectoryURL, fileManager: fileManager)
    }
}
