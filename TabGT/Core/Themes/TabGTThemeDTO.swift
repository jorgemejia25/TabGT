import Foundation
import SwiftUI

struct TabGTThemeDTO: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let customIDPrefix = "custom:"

    static let requiredColorKeys: [String] = [
        "windowBackground",
        "backgroundGradientMid",
        "backgroundGradientDeep",
        "blueWash",
        "navigator",
        "toolbar",
        "editor",
        "panel",
        "elevatedPanel",
        "separator",
        "textPrimary",
        "textSecondary",
        "textTertiary",
        "selectionBlue",
        "selectionBlueMuted",
        "warning",
        "danger",
        "success",
        "terminalBackground",
        "terminalForeground",
        "terminalCommand",
        "terminalSystem"
    ]

    var schemaVersion: Int
    var id: String
    var displayName: String
    var appearance: ThemeAppearance
    var blueWashOpacity: Double
    var colors: [String: String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case displayName
        case appearance
        case blueWashOpacity
        case colors
    }

    init(
        schemaVersion: Int,
        id: String,
        displayName: String,
        appearance: ThemeAppearance = .dark,
        blueWashOpacity: Double,
        colors: [String: String]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.appearance = appearance
        self.blueWashOpacity = blueWashOpacity
        self.colors = colors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        appearance = try container.decodeIfPresent(ThemeAppearance.self, forKey: .appearance) ?? .dark
        blueWashOpacity = try container.decode(Double.self, forKey: .blueWashOpacity)
        colors = try container.decode([String: String].self, forKey: .colors)
    }

    func validated(
        reservedBuiltInIDs: Set<String>,
        existingCustomSlugs: Set<String>
    ) throws -> TabGTThemeDTO {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ThemeImportError.unsupportedSchemaVersion(schemaVersion)
        }

        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidSlug(trimmedID) else {
            throw ThemeImportError.invalidThemeID(id)
        }

        if reservedBuiltInIDs.contains(trimmedID) || reservedBuiltInIDs.contains(Self.customThemeID(for: trimmedID)) {
            throw ThemeImportError.builtInIDConflict(trimmedID)
        }

        if existingCustomSlugs.contains(trimmedID) {
            throw ThemeImportError.duplicateThemeID(trimmedID)
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ThemeImportError.decodeFailed("displayName must not be empty.")
        }

        guard blueWashOpacity >= 0, blueWashOpacity <= 1 else {
            throw ThemeImportError.decodeFailed("blueWashOpacity must be between 0 and 1.")
        }

        let missingKeys = Self.requiredColorKeys.filter { colors[$0] == nil }
        if !missingKeys.isEmpty {
            throw ThemeImportError.missingColorKeys(missingKeys)
        }

        var normalizedColors: [String: String] = [:]
        for key in Self.requiredColorKeys {
            guard let rawValue = colors[key] else { continue }
            normalizedColors[key] = try ThemeHexColor.normalizedHex(from: rawValue)
        }

        return TabGTThemeDTO(
            schemaVersion: schemaVersion,
            id: trimmedID,
            displayName: trimmedName,
            appearance: appearance,
            blueWashOpacity: blueWashOpacity,
            colors: normalizedColors
        )
    }

    func toTabGTTheme() throws -> TabGTTheme {
        func color(_ key: String) throws -> Color {
            guard let hex = colors[key] else {
                throw ThemeImportError.missingColorKeys([key])
            }
            return try ThemeHexColor.color(from: hex)
        }

        return TabGTTheme(
            id: Self.customThemeID(for: id),
            displayName: displayName,
            appearance: appearance,
            windowBackground: try color("windowBackground"),
            backgroundGradientMid: try color("backgroundGradientMid"),
            backgroundGradientDeep: try color("backgroundGradientDeep"),
            blueWash: try color("blueWash"),
            blueWashOpacity: blueWashOpacity,
            navigator: try color("navigator"),
            toolbar: try color("toolbar"),
            editor: try color("editor"),
            panel: try color("panel"),
            elevatedPanel: try color("elevatedPanel"),
            separator: try color("separator"),
            textPrimary: try color("textPrimary"),
            textSecondary: try color("textSecondary"),
            textTertiary: try color("textTertiary"),
            selectionBlue: try color("selectionBlue"),
            selectionBlueMuted: try color("selectionBlueMuted"),
            warning: try color("warning"),
            danger: try color("danger"),
            success: try color("success"),
            terminalBackground: try color("terminalBackground"),
            terminalForeground: try color("terminalForeground"),
            terminalCommand: try color("terminalCommand"),
            terminalSystem: try color("terminalSystem")
        )
    }

    static func customThemeID(for slug: String) -> String {
        "\(customIDPrefix)\(slug)"
    }

    static func slug(from themeID: String) -> String? {
        guard themeID.hasPrefix(customIDPrefix) else { return nil }
        let slug = String(themeID.dropFirst(customIDPrefix.count))
        return slug.isEmpty ? nil : slug
    }

    static func isCustomThemeID(_ themeID: String) -> Bool {
        themeID.hasPrefix(customIDPrefix)
    }

    private static func isValidSlug(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 64 else { return false }
        let pattern = /^[a-z0-9-]+$/
        return value.wholeMatch(of: pattern) != nil
    }
}
