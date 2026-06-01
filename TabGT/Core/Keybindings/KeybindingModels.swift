import AppKit
import Foundation

enum KeybindingCommand: String, CaseIterable, Codable, Hashable, Identifiable {
    case newTerminal
    case closeActiveTab
    case splitRight
    case splitDown
    case toggleNavigator
    case toggleInspector
    case closeActiveGroup
    case openSettings
    case moveToNewWindow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newTerminal:
            return "New terminal"
        case .closeActiveTab:
            return "Close tab"
        case .splitRight:
            return "Split right"
        case .splitDown:
            return "Split down"
        case .toggleNavigator:
            return "Toggle navigator"
        case .toggleInspector:
            return "Toggle inspector"
        case .closeActiveGroup:
            return "Close group"
        case .openSettings:
            return "Open settings"
        case .moveToNewWindow:
            return "Move to new window"
        }
    }
}

enum KeybindingModifier: String, CaseIterable, Codable, Hashable {
    case command
    case shift
    case option
    case control

    var eventFlags: NSEvent.ModifierFlags {
        switch self {
        case .command:
            return .command
        case .shift:
            return .shift
        case .option:
            return .option
        case .control:
            return .control
        }
    }

    static func from(eventFlags flags: NSEvent.ModifierFlags) -> Set<KeybindingModifier> {
        var modifiers: Set<KeybindingModifier> = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        return modifiers
    }
}

struct KeyChordDTO: Codable, Equatable, Hashable {
    var key: String
    var modifiers: [String]
}

struct KeyChord: Equatable, Hashable {
    let keyCode: UInt16
    let charactersIgnoringModifiers: String
    let modifiers: Set<KeybindingModifier>

    init(keyCode: UInt16, charactersIgnoringModifiers: String, modifiers: Set<KeybindingModifier>) {
        self.keyCode = keyCode
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.modifiers = modifiers
    }

    init(dto: KeyChordDTO) throws {
        let parsedModifiers = try dto.modifiers.map { raw in
            guard let modifier = KeybindingModifier(rawValue: raw.lowercased()) else {
                throw KeybindingImportError.invalidModifier(raw)
            }
            return modifier
        }
        let parsedKey = try KeyChordParser.parseKey(dto.key)
        self.init(
            keyCode: parsedKey.keyCode,
            charactersIgnoringModifiers: parsedKey.characters,
            modifiers: Set(parsedModifiers)
        )
    }

    var dto: KeyChordDTO {
        KeyChordDTO(
            key: KeyChordParser.keyString(for: charactersIgnoringModifiers),
            modifiers: modifiers.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue)
        )
    }

    func matches(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        guard event.keyCode == keyCode else { return false }
        guard event.charactersIgnoringModifiers?.lowercased() == charactersIgnoringModifiers.lowercased() else {
            return false
        }
        return modifiers == KeybindingModifier.from(eventFlags: event.modifierFlags)
    }

    var displayString: String {
        let modifierSymbols = modifiers
            .sorted { lhs, rhs in
                KeybindingModifier.allCases.firstIndex(of: lhs)! < KeybindingModifier.allCases.firstIndex(of: rhs)!
            }
            .map { modifier in
                switch modifier {
                case .command:
                    return "⌘"
                case .shift:
                    return "⇧"
                case .option:
                    return "⌥"
                case .control:
                    return "⌃"
                }
            }
            .joined()

        return modifierSymbols + KeyChordParser.displayKey(for: charactersIgnoringModifiers)
    }
}

struct KeybindingsDocument: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var bindings: [String: KeyChordDTO]

    init(schemaVersion: Int = Self.currentSchemaVersion, bindings: [String: KeyChordDTO] = [:]) {
        self.schemaVersion = schemaVersion
        self.bindings = bindings
    }

    func validated() throws -> KeybindingsDocument {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw KeybindingImportError.unsupportedSchemaVersion(schemaVersion)
        }

        var normalized: [String: KeyChordDTO] = [:]
        var seenChords: [KeyChord: KeybindingCommand] = [:]

        for (rawCommand, dto) in bindings {
            guard let command = KeybindingCommand(rawValue: rawCommand) else {
                continue
            }

            let chord = try KeyChord(dto: dto)
            if let existing = seenChords[chord] {
                throw KeybindingImportError.duplicateChord(
                    "\(existing.rawValue) and \(command.rawValue) share \(chord.displayString)"
                )
            }

            seenChords[chord] = command
            normalized[command.rawValue] = chord.dto
        }

        return KeybindingsDocument(schemaVersion: schemaVersion, bindings: normalized)
    }
}

struct ResolvedKeybinding: Identifiable, Equatable {
    let command: KeybindingCommand
    let chord: KeyChord

    var id: String { command.rawValue }
}

enum KeyChordParser {
    private static let specialKeys: [String: (UInt16, String)] = [
        "return": (36, "\r"),
        "enter": (36, "\r"),
        "tab": (48, "\t"),
        "escape": (53, "\u{1b}"),
        "delete": (51, "\u{7f}"),
        "backspace": (51, "\u{7f}"),
        "space": (49, " "),
        "up": (126, "\u{f700}"),
        "down": (125, "\u{f701}"),
        "left": (123, "\u{f702}"),
        "right": (124, "\u{f703}")
    ]

    static func parseKey(_ raw: String) throws -> (keyCode: UInt16, characters: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw KeybindingImportError.invalidKey(raw)
        }

        let lowered = trimmed.lowercased()
        if let special = specialKeys[lowered] {
            return special
        }

        guard trimmed.count == 1, let scalar = trimmed.unicodeScalars.first else {
            throw KeybindingImportError.invalidKey(raw)
        }

        let character = String(scalar).lowercased()
        if let keyCode = keyCode(for: character) {
            return (keyCode, character)
        }

        throw KeybindingImportError.invalidKey(raw)
    }

    static func keyString(for characters: String) -> String {
        switch characters {
        case "\r":
            return "return"
        case "\t":
            return "tab"
        case "\u{1b}":
            return "escape"
        case "\u{7f}":
            return "delete"
        case " ":
            return "space"
        default:
            return characters
        }
    }

    static func displayKey(for characters: String) -> String {
        switch characters {
        case "\r":
            return "Return"
        case "\t":
            return "Tab"
        case "\u{1b}":
            return "Esc"
        case "\u{7f}":
            return "Delete"
        case " ":
            return "Space"
        case ":":
            return ":"
        case ",":
            return ","
        case "\\":
            return "\\"
        default:
            return characters.uppercased()
        }
    }

    private static func keyCode(for character: String) -> UInt16? {
        let mapping: [String: UInt16] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34,
            "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12,
            "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26,
            "8": 28, "9": 25,
            ";": 41, "=": 24, ",": 43, "-": 27, ".": 47, "/": 44, "`": 50, "[": 33,
            "\\": 42, "]": 30, "'": 39, ":": 41
        ]
        return mapping[character]
    }
}
