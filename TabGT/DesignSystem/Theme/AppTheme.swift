import Combine
import SwiftUI

struct TabGTTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let appearance: ThemeAppearance
    let windowBackground: Color
    let backgroundGradientMid: Color
    let backgroundGradientDeep: Color
    let blueWash: Color
    let blueWashOpacity: Double
    let navigator: Color
    let toolbar: Color
    let editor: Color
    let panel: Color
    let elevatedPanel: Color
    let separator: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let selectionBlue: Color
    let selectionBlueMuted: Color
    let warning: Color
    let danger: Color
    let success: Color
    let terminalBackground: Color
    let terminalForeground: Color
    let terminalCommand: Color
    let terminalSystem: Color

    init(
        id: String,
        displayName: String,
        appearance: ThemeAppearance = .dark,
        windowBackground: Color,
        backgroundGradientMid: Color,
        backgroundGradientDeep: Color,
        blueWash: Color,
        blueWashOpacity: Double,
        navigator: Color,
        toolbar: Color,
        editor: Color,
        panel: Color,
        elevatedPanel: Color,
        separator: Color,
        textPrimary: Color,
        textSecondary: Color,
        textTertiary: Color,
        selectionBlue: Color,
        selectionBlueMuted: Color,
        warning: Color,
        danger: Color,
        success: Color,
        terminalBackground: Color,
        terminalForeground: Color,
        terminalCommand: Color,
        terminalSystem: Color
    ) {
        self.id = id
        self.displayName = displayName
        self.appearance = appearance
        self.windowBackground = windowBackground
        self.backgroundGradientMid = backgroundGradientMid
        self.backgroundGradientDeep = backgroundGradientDeep
        self.blueWash = blueWash
        self.blueWashOpacity = blueWashOpacity
        self.navigator = navigator
        self.toolbar = toolbar
        self.editor = editor
        self.panel = panel
        self.elevatedPanel = elevatedPanel
        self.separator = separator
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.selectionBlue = selectionBlue
        self.selectionBlueMuted = selectionBlueMuted
        self.warning = warning
        self.danger = danger
        self.success = success
        self.terminalBackground = terminalBackground
        self.terminalForeground = terminalForeground
        self.terminalCommand = terminalCommand
        self.terminalSystem = terminalSystem
    }
}

enum ThemeCatalog {
    /// Pure neutral dark gray — default shell background (#141414).
    static let dark = TabGTTheme(
        id: "dark",
        displayName: "Dark",
        windowBackground: .themeHex(0x141414),
        backgroundGradientMid: .themeHex(0x121212),
        backgroundGradientDeep: .themeHex(0x0F0F0F),
        blueWash: .themeHex(0x141414),
        blueWashOpacity: 0,
        navigator: .themeHex(0x1C1C1C),
        toolbar: .themeHex(0x222222),
        editor: .themeHex(0x141414),
        panel: .themeHex(0x1C1C1C),
        elevatedPanel: .themeHex(0x2A2A2A),
        separator: .themeHex(0x333333),
        textPrimary: .themeHex(0xD4D4D4),
        textSecondary: .themeHex(0x969696),
        textTertiary: .themeHex(0x6E6E6E),
        selectionBlue: .themeHex(0x007ACC),
        selectionBlueMuted: .themeHex(0x003C6E),
        warning: .themeHex(0xFACC15),
        danger: .themeHex(0xF87171),
        success: .themeHex(0x4ADE80),
        terminalBackground: .themeHex(0x141414),
        terminalForeground: .themeHex(0xD4D4D4),
        terminalCommand: .themeHex(0x58A6FF),
        terminalSystem: .themeHex(0x8B949E)
    )

    /// Apple Xcode dark — cool blue tint and top wash.
    static let xcodeDark = TabGTTheme(
        id: "xcode-dark",
        displayName: "Xcode Dark",
        windowBackground: .themeHex(0x1E1E24),
        backgroundGradientMid: .themeHex(0x161620),
        backgroundGradientDeep: .themeHex(0x0F1018),
        blueWash: .themeHex(0x0A84FF),
        blueWashOpacity: 0.38,
        navigator: .themeHex(0x252530),
        toolbar: .themeHex(0x20202C),
        editor: .themeHex(0x1F1F28),
        panel: .themeHex(0x252530),
        elevatedPanel: .themeHex(0x2C2C38),
        separator: .themeHex(0x34344A),
        textPrimary: .themeHex(0xE5E5EA),
        textSecondary: .themeHex(0x9898A0),
        textTertiary: .themeHex(0x63636E),
        selectionBlue: .themeHex(0x0A84FF),
        selectionBlueMuted: .themeHex(0x0F3D6E),
        warning: .themeHex(0xFFD60A),
        danger: .themeHex(0xFF453A),
        success: .themeHex(0x30D158),
        terminalBackground: .themeHex(0x0B0B10),
        terminalForeground: .themeHex(0xD4D4DC),
        terminalCommand: .themeHex(0x85C1FF),
        terminalSystem: .themeHex(0x8EB4E8)
    )

    /// Atom One Dark — warm gray editor shell with soft blue accents.
    static let atomOneDark = TabGTTheme(
        id: "atom-one-dark",
        displayName: "Atom One Dark",
        windowBackground: .themeHex(0x282C34),
        backgroundGradientMid: .themeHex(0x252930),
        backgroundGradientDeep: .themeHex(0x21252B),
        blueWash: .themeHex(0x528BFF),
        blueWashOpacity: 0.14,
        navigator: .themeHex(0x21252B),
        toolbar: .themeHex(0x2C313A),
        editor: .themeHex(0x282C34),
        panel: .themeHex(0x21252B),
        elevatedPanel: .themeHex(0x333842),
        separator: .themeHex(0x181A1F),
        textPrimary: .themeHex(0xABB2BF),
        textSecondary: .themeHex(0x828997),
        textTertiary: .themeHex(0x5C6370),
        selectionBlue: .themeHex(0x528BFF),
        selectionBlueMuted: .themeHex(0x2A4470),
        warning: .themeHex(0xE5C07B),
        danger: .themeHex(0xE06C75),
        success: .themeHex(0x98C379),
        terminalBackground: .themeHex(0x282C34),
        terminalForeground: .themeHex(0xABB2BF),
        terminalCommand: .themeHex(0x61AFEF),
        terminalSystem: .themeHex(0x56B6C2)
    )

    /// Dracula — purple/pink accent on a blue-gray base.
    static let dracula = TabGTTheme(
        id: "dracula",
        displayName: "Dracula",
        windowBackground: .themeHex(0x282A36),
        backgroundGradientMid: .themeHex(0x242630),
        backgroundGradientDeep: .themeHex(0x1E202A),
        blueWash: .themeHex(0xBD93F9),
        blueWashOpacity: 0.12,
        navigator: .themeHex(0x21222C),
        toolbar: .themeHex(0x2D2F3D),
        editor: .themeHex(0x282A36),
        panel: .themeHex(0x21222C),
        elevatedPanel: .themeHex(0x44475A),
        separator: .themeHex(0x44475A),
        textPrimary: .themeHex(0xF8F8F2),
        textSecondary: .themeHex(0xBFBFD0),
        textTertiary: .themeHex(0x8A8A9A),
        selectionBlue: .themeHex(0xBD93F9),
        selectionBlueMuted: .themeHex(0x5A3D8A),
        warning: .themeHex(0xF1FA8C),
        danger: .themeHex(0xFF5555),
        success: .themeHex(0x50FA7B),
        terminalBackground: .themeHex(0x282A36),
        terminalForeground: .themeHex(0xF8F8F2),
        terminalCommand: .themeHex(0x8BE9FD),
        terminalSystem: .themeHex(0x6272A4)
    )

    /// Nord — cool arctic blue-gray palette.
    static let nord = TabGTTheme(
        id: "nord",
        displayName: "Nord",
        windowBackground: .themeHex(0x2E3440),
        backgroundGradientMid: .themeHex(0x2A303C),
        backgroundGradientDeep: .themeHex(0x242933),
        blueWash: .themeHex(0x88C0D0),
        blueWashOpacity: 0.10,
        navigator: .themeHex(0x3B4252),
        toolbar: .themeHex(0x343B49),
        editor: .themeHex(0x2E3440),
        panel: .themeHex(0x3B4252),
        elevatedPanel: .themeHex(0x434C5E),
        separator: .themeHex(0x4C566A),
        textPrimary: .themeHex(0xECEFF4),
        textSecondary: .themeHex(0xD8DEE9),
        textTertiary: .themeHex(0xA3AAB8),
        selectionBlue: .themeHex(0x88C0D0),
        selectionBlueMuted: .themeHex(0x3D5A72),
        warning: .themeHex(0xEBCB8B),
        danger: .themeHex(0xBF616A),
        success: .themeHex(0xA3BE8C),
        terminalBackground: .themeHex(0x2E3440),
        terminalForeground: .themeHex(0xECEFF4),
        terminalCommand: .themeHex(0x81A1C1),
        terminalSystem: .themeHex(0x5E81AC)
    )

    /// Monokai — warm olive base with vivid syntax-inspired accents.
    static let monokai = TabGTTheme(
        id: "monokai",
        displayName: "Monokai",
        windowBackground: .themeHex(0x272822),
        backgroundGradientMid: .themeHex(0x23241E),
        backgroundGradientDeep: .themeHex(0x1E1F1A),
        blueWash: .themeHex(0xA6E22E),
        blueWashOpacity: 0.06,
        navigator: .themeHex(0x1F201A),
        toolbar: .themeHex(0x2D2E27),
        editor: .themeHex(0x272822),
        panel: .themeHex(0x1F201A),
        elevatedPanel: .themeHex(0x3E3D32),
        separator: .themeHex(0x49483E),
        textPrimary: .themeHex(0xF8F8F2),
        textSecondary: .themeHex(0xC4C4BA),
        textTertiary: .themeHex(0x909088),
        selectionBlue: .themeHex(0xA6E22E),
        selectionBlueMuted: .themeHex(0x4A5A18),
        warning: .themeHex(0xE6DB74),
        danger: .themeHex(0xF92672),
        success: .themeHex(0xA6E22E),
        terminalBackground: .themeHex(0x272822),
        terminalForeground: .themeHex(0xF8F8F2),
        terminalCommand: .themeHex(0x66D9EF),
        terminalSystem: .themeHex(0x75715E)
    )

    /// GitHub Dark — deep blue-black with GitHub blue accent.
    static let githubDark = TabGTTheme(
        id: "github-dark",
        displayName: "GitHub Dark",
        windowBackground: .themeHex(0x0D1117),
        backgroundGradientMid: .themeHex(0x0B0F14),
        backgroundGradientDeep: .themeHex(0x010409),
        blueWash: .themeHex(0x58A6FF),
        blueWashOpacity: 0.16,
        navigator: .themeHex(0x161B22),
        toolbar: .themeHex(0x161B22),
        editor: .themeHex(0x0D1117),
        panel: .themeHex(0x161B22),
        elevatedPanel: .themeHex(0x21262D),
        separator: .themeHex(0x30363D),
        textPrimary: .themeHex(0xC9D1D9),
        textSecondary: .themeHex(0x8B949E),
        textTertiary: .themeHex(0x6E7681),
        selectionBlue: .themeHex(0x58A6FF),
        selectionBlueMuted: .themeHex(0x1F3A5F),
        warning: .themeHex(0xD29922),
        danger: .themeHex(0xF85149),
        success: .themeHex(0x3FB950),
        terminalBackground: .themeHex(0x0D1117),
        terminalForeground: .themeHex(0xC9D1D9),
        terminalCommand: .themeHex(0x79C0FF),
        terminalSystem: .themeHex(0x8B949E)
    )

    /// Warm charcoal — brown-gray tones, clearly distinct from blue-tinted Xcode.
    static let charcoal = TabGTTheme(
        id: "charcoal",
        displayName: "Charcoal",
        windowBackground: .themeHex(0x1A1814),
        backgroundGradientMid: .themeHex(0x161410),
        backgroundGradientDeep: .themeHex(0x12100C),
        blueWash: .themeHex(0xC4A574),
        blueWashOpacity: 0.05,
        navigator: .themeHex(0x221F1A),
        toolbar: .themeHex(0x2A2620),
        editor: .themeHex(0x1A1814),
        panel: .themeHex(0x221F1A),
        elevatedPanel: .themeHex(0x322E28),
        separator: .themeHex(0x3D3830),
        textPrimary: .themeHex(0xE8E4DC),
        textSecondary: .themeHex(0xA8A094),
        textTertiary: .themeHex(0x787068),
        selectionBlue: .themeHex(0xC4A574),
        selectionBlueMuted: .themeHex(0x5C4A30),
        warning: .themeHex(0xE8C468),
        danger: .themeHex(0xE07060),
        success: .themeHex(0x8CB870),
        terminalBackground: .themeHex(0x141210),
        terminalForeground: .themeHex(0xE0DCD4),
        terminalCommand: .themeHex(0xD4A870),
        terminalSystem: .themeHex(0x908878)
    )

    static let light = TabGTTheme(
        id: "light",
        displayName: "Light",
        appearance: .light,
        windowBackground: .themeHex(0xFFFFFF),
        backgroundGradientMid: .themeHex(0xFAFAFA),
        backgroundGradientDeep: .themeHex(0xF3F3F3),
        blueWash: .themeHex(0x0078D4),
        blueWashOpacity: 0.06,
        navigator: .themeHex(0xF3F3F3),
        toolbar: .themeHex(0xF3F3F3),
        editor: .themeHex(0xFFFFFF),
        panel: .themeHex(0xF3F3F3),
        elevatedPanel: .themeHex(0xE8E8E8),
        separator: .themeHex(0xE5E5E5),
        textPrimary: .themeHex(0x1E1E1E),
        textSecondary: .themeHex(0x616161),
        textTertiary: .themeHex(0x8A8A8A),
        selectionBlue: .themeHex(0x0078D4),
        selectionBlueMuted: .themeHex(0xCCE4F7),
        warning: .themeHex(0xCA8A04),
        danger: .themeHex(0xDC2626),
        success: .themeHex(0x16A34A),
        terminalBackground: .themeHex(0xFFFFFF),
        terminalForeground: .themeHex(0x1E1E1E),
        terminalCommand: .themeHex(0x0451A5),
        terminalSystem: .themeHex(0x6B7280)
    )

    static let `default` = dark

    static let all: [TabGTTheme] = [
        dark,
        light,
        xcodeDark,
        atomOneDark,
        dracula,
        nord,
        monokai,
        githubDark,
        charcoal
    ]

    static let legacyIDs: [String: String] = [
        "cursor-dark": dark.id,
        "graphite": charcoal.id
    ]

    static func theme(id: String) -> TabGTTheme {
        let resolvedID = legacyIDs[id] ?? id
        return all.first { $0.id == resolvedID } ?? `default`
    }

    static var builtInIDs: Set<String> {
        Set(all.map(\.id))
    }
}

@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()
    private static let storageKey = "tabgt.selectedThemeID"

    @Published private(set) var customThemes: [TabGTTheme] = []
    @Published var selectedThemeID: String {
        didSet {
            guard allThemes.contains(where: { $0.id == selectedThemeID }) else {
                selectedThemeID = ThemeCatalog.default.id
                return
            }
            UserDefaults.standard.set(selectedThemeID, forKey: Self.storageKey)
        }
    }

    private let repository = CustomThemeRepository()

    var allThemes: [TabGTTheme] {
        ThemeCatalog.all + customThemes
    }

    init(selectedThemeID initialThemeID: String? = nil) {
        let loadedCustomThemes = Self.loadCustomThemes(using: repository)
        customThemes = loadedCustomThemes
        let stored = initialThemeID
            ?? UserDefaults.standard.string(forKey: Self.storageKey)
            ?? ThemeCatalog.default.id
        self.selectedThemeID = Self.resolveThemeID(stored, in: ThemeCatalog.all + loadedCustomThemes)
    }

    var theme: TabGTTheme {
        Self.resolveTheme(id: selectedThemeID, in: allThemes)
    }

    func importTheme(from url: URL) throws {
        let existingSlugs = Set(customThemes.compactMap { TabGTThemeDTO.slug(from: $0.id) })
        let dto = try ThemeImporter.importTheme(
            from: url,
            reservedBuiltInIDs: ThemeCatalog.builtInIDs,
            existingCustomSlugs: existingSlugs
        )
        let importedTheme = try dto.toTabGTTheme()
        try repository.save(dto)
        customThemes.append(importedTheme)
        selectedThemeID = importedTheme.id
    }

    func deleteCustomTheme(id: String) throws {
        guard TabGTThemeDTO.isCustomThemeID(id) else { return }
        guard let slug = TabGTThemeDTO.slug(from: id) else { return }

        try repository.delete(slug: slug)
        customThemes.removeAll { $0.id == id }

        if selectedThemeID == id {
            selectedThemeID = ThemeCatalog.default.id
        }
    }

    private static func loadCustomThemes(using repository: CustomThemeRepository) -> [TabGTTheme] {
        do {
            return try repository.loadAll(reservedBuiltInIDs: ThemeCatalog.builtInIDs)
        } catch {
            return []
        }
    }

    private static func resolveThemeID(_ id: String, in themes: [TabGTTheme]) -> String {
        resolveTheme(id: id, in: themes).id
    }

    private static func resolveTheme(id: String, in themes: [TabGTTheme]) -> TabGTTheme {
        let legacyID = ThemeCatalog.legacyIDs[id] ?? id
        return themes.first { $0.id == legacyID } ?? ThemeCatalog.default
    }
}

/// Semantic color accessors for the active theme.
/// Reads from `ThemeStore.shared`; inject the store at the app root and use `.id(themeStore.selectedThemeID)` to refresh on change.
enum AppTheme {
    @MainActor
    private static var store: ThemeStore { ThemeStore.shared }

    @MainActor
    static var current: TabGTTheme { store.theme }

    @MainActor
    static var background: LinearGradient {
        let theme = store.theme
        return LinearGradient(
            colors: [
                theme.windowBackground,
                theme.backgroundGradientMid,
                theme.backgroundGradientDeep
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @MainActor static var panelFill: Color { store.theme.panel.opacity(0.92) }
    @MainActor static var panelStroke: Color { store.theme.separator.opacity(0.85) }
    @MainActor static var splitSash: Color { store.theme.separator.opacity(0.50) }
    /// Border between shell chrome (sidebar, toolbar, inspector) and the editor.
    @MainActor static var shellBorder: Color { store.theme.separator.opacity(0.78) }
    @MainActor static var splitSashActive: Color { store.theme.selectionBlue.opacity(0.72) }
    @MainActor static var groupFocusStroke: Color { store.theme.separator.opacity(0.28) }
    @MainActor static var navigator: Color { store.theme.navigator }
    @MainActor static var toolbar: Color { store.theme.toolbar }
    @MainActor static var windowBackground: Color { store.theme.windowBackground }
    @MainActor static var editor: Color { store.theme.editor }
    @MainActor static var elevatedPanel: Color { store.theme.elevatedPanel }
    @MainActor static var selectionBlue: Color { store.theme.selectionBlue }
    @MainActor static var selectionBlueMuted: Color { store.theme.selectionBlueMuted }
    @MainActor static var textPrimary: Color { store.theme.textPrimary }
    @MainActor static var textSecondary: Color { store.theme.textSecondary }
    @MainActor static var textTertiary: Color { store.theme.textTertiary }
    @MainActor static var accent: Color { store.theme.selectionBlue }
    @MainActor static var warning: Color { store.theme.warning }
    @MainActor static var danger: Color { store.theme.danger }
    @MainActor static var success: Color { store.theme.success }
    @MainActor static var cyan: Color { Color(red: 0.360, green: 0.660, blue: 0.950) }
    @MainActor static var appearance: ThemeAppearance { store.theme.appearance }

    /// Text on accent-colored surfaces (selection pills, blue rows).
    @MainActor static var onSelectionText: Color { .white }

    /// Subtle hover fill for list rows and tabs.
    @MainActor static var rowHoverFill: Color {
        store.theme.appearance == .light
            ? Color.black.opacity(0.05)
            : Color.white.opacity(0.06)
    }

    /// Selected row fill when not using the accent background.
    @MainActor static var rowSelectedFill: Color {
        store.theme.appearance == .light
            ? Color.black.opacity(0.08)
            : Color.white.opacity(0.12)
    }

    /// Top gradient highlight on the window background.
    @MainActor static var backgroundHighlight: Color {
        store.theme.appearance == .light
            ? Color.black.opacity(0.018)
            : Color.white.opacity(0.012)
    }

    /// Bottom gradient shadow on the window background.
    @MainActor static var backgroundShadow: Color {
        store.theme.appearance == .light
            ? Color.black.opacity(0.04)
            : Color.black.opacity(0.10)
    }
}
