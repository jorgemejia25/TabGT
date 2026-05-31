import Foundation

struct LocalAutomationRuleRepository {
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

    var directoryURL: URL {
        if let customBaseURL { return customBaseURL }
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("TabGT", isDirectory: true)
            .appendingPathComponent("automations", isDirectory: true)
    }

    var fileURL: URL {
        directoryURL.appendingPathComponent("rules.json")
    }

    func loadAll() throws -> [AutomationRule] {
        try ensureDirectoryExists()
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let document = try decoder.decode(AutomationRulesDocument.self, from: data)
        return document.rules
    }

    func saveAll(_ rules: [AutomationRule]) throws {
        try ensureDirectoryExists()
        let document = AutomationRulesDocument(rules: rules)
        let data = try encoder.encode(document)
        try SecureFileStore.write(data, to: fileURL, fileManager: fileManager)
    }

    private func ensureDirectoryExists() throws {
        try SecureFileStore.ensureDirectory(directoryURL, fileManager: fileManager)
    }
}
