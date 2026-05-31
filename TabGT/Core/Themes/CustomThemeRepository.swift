import Foundation

struct CustomThemeRepository {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    var themesDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("TabGT", isDirectory: true)
            .appendingPathComponent("themes", isDirectory: true)
    }

    func loadAll(reservedBuiltInIDs: Set<String>) throws -> [TabGTTheme] {
        try ensureThemesDirectoryExists()

        guard fileManager.fileExists(atPath: themesDirectoryURL.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: themesDirectoryURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "json" }

        var themes: [TabGTTheme] = []
        var loadedSlugs = Set<String>()

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let data = try Data(contentsOf: url)
                let dto = try ThemeImporter.decode(
                    data: data,
                    reservedBuiltInIDs: reservedBuiltInIDs,
                    existingCustomSlugs: loadedSlugs
                )
                loadedSlugs.insert(dto.id)
                themes.append(try dto.toTabGTTheme())
            } catch {
                continue
            }
        }

        return themes
    }

    func save(_ dto: TabGTThemeDTO) throws {
        try ensureThemesDirectoryExists()
        let fileURL = fileURL(for: dto.id)
        let data = try encoder.encode(dto)
        try SecureFileStore.write(data, to: fileURL, fileManager: fileManager)
    }

    func delete(slug: String) throws {
        let fileURL = fileURL(for: slug)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func fileURL(for slug: String) -> URL {
        themesDirectoryURL.appendingPathComponent("\(slug).json")
    }

    private func ensureThemesDirectoryExists() throws {
        try SecureFileStore.ensureDirectory(themesDirectoryURL, fileManager: fileManager)
    }
}
