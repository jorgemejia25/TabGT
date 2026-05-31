import Foundation
@testable import TabGT
import Testing

@MainActor
struct ThemeImportTests {
    private let builtInIDs = ThemeCatalog.builtInIDs

    private var validThemeJSON: String {
        """
        {
          "schemaVersion": 1,
          "id": "test-solarized",
          "displayName": "Test Solarized",
          "blueWashOpacity": 0.12,
          "colors": {
            "windowBackground": "#141414",
            "backgroundGradientMid": "#121212",
            "backgroundGradientDeep": "#0F0F0F",
            "blueWash": "#007ACC",
            "navigator": "#1C1C1C",
            "toolbar": "#222222",
            "editor": "#141414",
            "panel": "#1C1C1C",
            "elevatedPanel": "#2A2A2A",
            "separator": "#333333",
            "textPrimary": "#D4D4D4",
            "textSecondary": "#969696",
            "textTertiary": "#6E6E6E",
            "selectionBlue": "#007ACC",
            "selectionBlueMuted": "#003C6E",
            "warning": "#FACC15",
            "danger": "#F87171",
            "success": "#4ADE80",
            "terminalBackground": "#141414",
            "terminalForeground": "#D4D4D4",
            "terminalCommand": "#58A6FF",
            "terminalSystem": "#8B949E"
          }
        }
        """
    }

    @Test func decodeValidThemeProducesCustomID() throws {
        let data = Data(validThemeJSON.utf8)
        let dto = try ThemeImporter.decode(
            data: data,
            reservedBuiltInIDs: builtInIDs,
            existingCustomSlugs: []
        )

        #expect(dto.id == "test-solarized")
        #expect(dto.displayName == "Test Solarized")
        #expect(dto.colors["windowBackground"] == "#141414")

        let theme = try dto.toTabGTTheme()
        #expect(theme.id == "custom:test-solarized")
        #expect(theme.displayName == "Test Solarized")
        #expect(theme.appearance == .dark)
    }

    @Test func decodeLightAppearance() throws {
        var json = validThemeJSON
        json = json.replacingOccurrences(of: "\"id\": \"test-solarized\"", with: "\"id\": \"test-light\"")
        json = json.replacingOccurrences(
            of: "\"displayName\": \"Test Solarized\"",
            with: "\"displayName\": \"Test Light\""
        )
        json = json.replacingOccurrences(
            of: "\"blueWashOpacity\": 0.12",
            with: "\"appearance\": \"light\",\n  \"blueWashOpacity\": 0.12"
        )

        let dto = try ThemeImporter.decode(
            data: Data(json.utf8),
            reservedBuiltInIDs: builtInIDs,
            existingCustomSlugs: []
        )
        let theme = try dto.toTabGTTheme()

        #expect(dto.appearance == .light)
        #expect(theme.appearance == .light)
    }

    @Test func defaultsAppearanceToDarkWhenMissing() throws {
        let dto = try ThemeImporter.decode(
            data: Data(validThemeJSON.utf8),
            reservedBuiltInIDs: builtInIDs,
            existingCustomSlugs: []
        )
        #expect(dto.appearance == .dark)
    }

    @Test func rejectsUnsupportedSchemaVersion() throws {
        let json = validThemeJSON.replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2")
        let data = Data(json.utf8)

        #expect(throws: ThemeImportError.unsupportedSchemaVersion(2)) {
            try ThemeImporter.decode(
                data: data,
                reservedBuiltInIDs: builtInIDs,
                existingCustomSlugs: []
            )
        }
    }

    @Test func rejectsInvalidThemeID() throws {
        let json = validThemeJSON.replacingOccurrences(of: "\"id\": \"test-solarized\"", with: "\"id\": \"Bad ID\"")
        let data = Data(json.utf8)

        #expect(throws: ThemeImportError.invalidThemeID("Bad ID")) {
            try ThemeImporter.decode(
                data: data,
                reservedBuiltInIDs: builtInIDs,
                existingCustomSlugs: []
            )
        }
    }

    @Test func rejectsBuiltInIDConflict() throws {
        let json = validThemeJSON.replacingOccurrences(of: "\"id\": \"test-solarized\"", with: "\"id\": \"dark\"")
        let data = Data(json.utf8)

        #expect(throws: ThemeImportError.builtInIDConflict("dark")) {
            try ThemeImporter.decode(
                data: data,
                reservedBuiltInIDs: builtInIDs,
                existingCustomSlugs: []
            )
        }
    }

    @Test func rejectsDuplicateCustomID() throws {
        let data = Data(validThemeJSON.utf8)

        #expect(throws: ThemeImportError.duplicateThemeID("test-solarized")) {
            try ThemeImporter.decode(
                data: data,
                reservedBuiltInIDs: builtInIDs,
                existingCustomSlugs: ["test-solarized"]
            )
        }
    }

    @Test func rejectsInvalidHexColor() throws {
        var json = validThemeJSON
        json = json.replacingOccurrences(of: "\"windowBackground\": \"#141414\"", with: "\"windowBackground\": \"not-a-color\"")
        let data = Data(json.utf8)

        #expect(throws: ThemeImportError.self) {
            try ThemeImporter.decode(
                data: data,
                reservedBuiltInIDs: builtInIDs,
                existingCustomSlugs: []
            )
        }
    }

    @Test func rejectsMissingColorKeys() throws {
        let json = """
        {
          "schemaVersion": 1,
          "id": "incomplete",
          "displayName": "Incomplete",
          "blueWashOpacity": 0,
          "colors": {
            "windowBackground": "#141414"
          }
        }
        """
        let data = Data(json.utf8)

        #expect(throws: ThemeImportError.self) {
            try ThemeImporter.decode(
                data: data,
                reservedBuiltInIDs: builtInIDs,
                existingCustomSlugs: []
            )
        }
    }

    @Test func roundTripEncodeDecodePreservesDTO() throws {
        let data = Data(validThemeJSON.utf8)
        let original = try ThemeImporter.decode(
            data: data,
            reservedBuiltInIDs: builtInIDs,
            existingCustomSlugs: []
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try ThemeImporter.decode(
            data: encoded,
            reservedBuiltInIDs: builtInIDs,
            existingCustomSlugs: []
        )

        #expect(decoded == original)
    }

    @Test func repositorySaveLoadAndDelete() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let repository = CustomThemeRepository(
            fileManager: ThemeImportTestFileManager(baseDirectory: tempDirectory)
        )

        let data = Data(validThemeJSON.utf8)
        let dto = try ThemeImporter.decode(
            data: data,
            reservedBuiltInIDs: builtInIDs,
            existingCustomSlugs: []
        )

        try repository.save(dto)
        let loaded = try repository.loadAll(reservedBuiltInIDs: builtInIDs)

        #expect(loaded.count == 1)
        #expect(loaded.first?.id == "custom:test-solarized")

        try repository.delete(slug: dto.id)
        let afterDelete = try repository.loadAll(reservedBuiltInIDs: builtInIDs)
        #expect(afterDelete.isEmpty)
    }
}

private final class ThemeImportTestFileManager: FileManager {
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
