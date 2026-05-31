import AppKit
import Combine
import SwiftUI

/// Common terminal font presets shown as quick picks in Settings.
enum TerminalFontPreset: String, CaseIterable, Identifiable {
    case sfMono = "sf-mono"
    case menlo = "menlo"
    case monaco = "monaco"
    case jetBrainsMono = "jetbrains-mono"
    case firaCode = "fira-code"
    case sourceCodePro = "source-code-pro"
    case courier = "courier"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sfMono:
            return "SF Mono"
        case .menlo:
            return "Menlo"
        case .monaco:
            return "Monaco"
        case .jetBrainsMono:
            return "JetBrains Mono"
        case .firaCode:
            return "Fira Code"
        case .sourceCodePro:
            return "Source Code Pro"
        case .courier:
            return "Courier"
        }
    }

    /// Value written into the font family field (VS Code-style).
    var fontFamilyValue: String {
        switch self {
        case .sfMono:
            return ""
        default:
            return displayName
        }
    }

    init?(legacyID: String) {
        guard let match = Self.allCases.first(where: { $0.rawValue == legacyID }) else {
            return nil
        }
        self = match
    }
}

enum TerminalFontResolver {
    /// Resolves a VS Code-style font family string.
    ///
    /// Supports comma-separated fallbacks, e.g. `"Fira Code, Menlo, monospace"`.
    static func resolve(name: String, size: CGFloat) -> NSFont {
        let candidates = parseCandidates(from: name)
        guard !candidates.isEmpty else {
            return fallbackMonospace(size: size)
        }

        for candidate in candidates {
            if candidate.lowercased() == "monospace" {
                return fallbackMonospace(size: size)
            }
            if let font = resolveSingle(candidate, size: size) {
                return font
            }
        }

        return fallbackMonospace(size: size)
    }

    static func isResolvable(name: String) -> Bool {
        let candidates = parseCandidates(from: name)
        if candidates.isEmpty { return true }
        return candidates.contains { candidate in
            candidate.lowercased() == "monospace" || resolveSingle(candidate, size: 12) != nil
        }
    }

    private static func parseCandidates(from name: String) -> [String] {
        name
            .split(separator: ",")
            .map { part in
                part
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            }
            .filter { !$0.isEmpty }
    }

    private static func resolveSingle(_ name: String, size: CGFloat) -> NSFont? {
        if let font = NSFont(name: name, size: size) {
            return font
        }

        let compact = name.replacingOccurrences(of: " ", with: "")
        let variants = [
            "\(name)-Regular",
            "\(compact)-Regular",
            compact,
            name
        ]

        for variant in variants {
            if let font = NSFont(name: variant, size: size) {
                return font
            }
        }

        if let font = NSFontManager.shared.font(
            withFamily: name,
            traits: [],
            weight: 5,
            size: size
        ) {
            return font
        }

        let normalized = name.lowercased()
        for family in NSFontManager.shared.availableFontFamilies {
            guard family.lowercased() == normalized else { continue }
            return NSFontManager.shared.font(
                withFamily: family,
                traits: [],
                weight: 5,
                size: size
            )
        }

        return nil
    }

    private static func fallbackMonospace(size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

@MainActor
final class TerminalFontSettings: ObservableObject {
    static let shared = TerminalFontSettings()

    private static let familyKey = "tabgt.terminalFontFamily"
    private static let sizeKey = "tabgt.terminalFontSize"

    @Published var fontFamily: String {
        didSet {
            UserDefaults.standard.set(fontFamily, forKey: Self.familyKey)
        }
    }

    @Published var size: Double {
        didSet {
            let clamped = min(max(size, Self.minSize), Self.maxSize)
            if clamped != size {
                size = clamped
                return
            }
            UserDefaults.standard.set(size, forKey: Self.sizeKey)
        }
    }

    static let minSize: Double = 10
    static let maxSize: Double = 18

    init(fontFamily: String? = nil, size: Double? = nil) {
        let storedFamily = fontFamily
            ?? UserDefaults.standard.string(forKey: Self.familyKey)
            ?? ""
        self.fontFamily = Self.migrateStoredFamily(storedFamily)

        let storedSize = size
            ?? UserDefaults.standard.object(forKey: Self.sizeKey) as? Double
            ?? 12
        self.size = min(max(storedSize, Self.minSize), Self.maxSize)
    }

    var nsFont: NSFont {
        TerminalFontResolver.resolve(name: fontFamily, size: CGFloat(size))
    }

    var swiftUIFont: Font {
        Font(nsFont)
    }

    func swiftUIFont(size: CGFloat) -> Font {
        Font(TerminalFontResolver.resolve(name: fontFamily, size: size))
    }

    var isFontResolved: Bool {
        TerminalFontResolver.isResolvable(name: fontFamily)
    }

    var resolvedFontDescription: String {
        let resolved = nsFont
        if fontFamily.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "SF Mono (system)"
        }
        if isFontResolved {
            return resolved.displayName ?? resolved.fontName
        }
        return "Not found — using SF Mono"
    }

    private static func migrateStoredFamily(_ stored: String) -> String {
        if let legacy = TerminalFontPreset(legacyID: stored) {
            return legacy.fontFamilyValue
        }
        return stored
    }
}

enum TerminalTypography {
    @MainActor
    private static var settings: TerminalFontSettings { TerminalFontSettings.shared }

    @MainActor
    static var font: Font { settings.swiftUIFont }

    @MainActor
    static var size: CGFloat { CGFloat(settings.size) }
}
