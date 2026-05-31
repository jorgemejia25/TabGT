import Foundation

enum KeybindingCatalog {
    static let presentationOrder: [KeybindingCommand] = [
        .newTerminal,
        .closeActiveTab,
        .splitRight,
        .splitDown,
        .toggleNavigator,
        .toggleInspector,
        .closeActiveGroup,
        .openSettings
    ]

    static var defaultDocument: KeybindingsDocument {
        KeybindingsDocument(
            schemaVersion: KeybindingsDocument.currentSchemaVersion,
            bindings: defaultBindings
        )
    }

    static var defaultBindings: [String: KeyChordDTO] {
        Dictionary(uniqueKeysWithValues: defaultChords.map { ($0.key.rawValue, $0.value.dto) })
    }

    static var defaultChords: [KeybindingCommand: KeyChord] {
        [
            .newTerminal: try! KeyChord(dto: KeyChordDTO(key: "t", modifiers: ["command"])),
            .closeActiveTab: try! KeyChord(dto: KeyChordDTO(key: "w", modifiers: ["command"])),
            .splitRight: try! KeyChord(dto: KeyChordDTO(key: "\\", modifiers: ["command"])),
            .splitDown: try! KeyChord(dto: KeyChordDTO(key: "\\", modifiers: ["command", "shift"])),
            .toggleNavigator: try! KeyChord(dto: KeyChordDTO(key: "b", modifiers: ["command"])),
            .toggleInspector: try! KeyChord(dto: KeyChordDTO(key: "b", modifiers: ["command", "option"])),
            .closeActiveGroup: try! KeyChord(dto: KeyChordDTO(key: "w", modifiers: ["command", "shift"])),
            .openSettings: try! KeyChord(dto: KeyChordDTO(key: ",", modifiers: ["command"]))
        ]
    }

    static func merge(defaults: [KeybindingCommand: KeyChord], overrides: KeybindingsDocument) throws -> [KeybindingCommand: KeyChord] {
        var merged = defaults
        let validated = try overrides.validated()

        for command in KeybindingCommand.allCases {
            guard let dto = validated.bindings[command.rawValue] else { continue }
            merged[command] = try KeyChord(dto: dto)
        }

        var seenChords: [KeyChord: KeybindingCommand] = [:]
        for command in presentationOrder {
            guard let chord = merged[command] else { continue }
            if let existing = seenChords[chord] {
                throw KeybindingImportError.duplicateChord(
                    "\(existing.rawValue) and \(command.rawValue) share \(chord.displayString)"
                )
            }
            seenChords[chord] = command
        }

        return merged
    }
}
