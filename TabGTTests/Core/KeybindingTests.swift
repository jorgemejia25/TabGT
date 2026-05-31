import Foundation
@testable import TabGT
import Testing

struct KeybindingTests {
    private var validKeybindingsJSON: String {
        """
        {
          "schemaVersion": 1,
          "bindings": {
            "closeActiveTab": { "key": "w", "modifiers": ["command"] },
            "newTerminal": { "key": "t", "modifiers": ["command"] }
          }
        }
        """
    }

    @Test func decodeValidPartialOverrides() throws {
        let document = try KeybindingImporter.decode(data: Data(validKeybindingsJSON.utf8))

        #expect(document.schemaVersion == 1)
        #expect(document.bindings["closeActiveTab"]?.key == "w")
        #expect(document.bindings["newTerminal"]?.modifiers == ["command"])
    }

    @Test func mergePartialOverridesKeepsDefaults() throws {
        let overrides = try KeybindingImporter.decode(data: Data(validKeybindingsJSON.utf8))
        let merged = try KeybindingCatalog.merge(
            defaults: KeybindingCatalog.defaultChords,
            overrides: overrides
        )

        #expect(merged[.closeActiveTab]?.charactersIgnoringModifiers == "w")
        #expect(merged[.newTerminal]?.charactersIgnoringModifiers == "t")
        #expect(merged[.toggleNavigator]?.charactersIgnoringModifiers == "b")
        #expect(merged[.openSettings]?.charactersIgnoringModifiers == ",")
    }

    @Test func rejectsUnsupportedSchemaVersion() {
        let json = """
        { "schemaVersion": 99, "bindings": {} }
        """

        #expect(throws: KeybindingImportError.self) {
            _ = try KeybindingImporter.decode(data: Data(json.utf8))
        }
    }

    @Test func rejectsDuplicateChordsInDocument() {
        let json = """
        {
          "schemaVersion": 1,
          "bindings": {
            "closeActiveTab": { "key": "w", "modifiers": ["command"] },
            "newTerminal": { "key": "w", "modifiers": ["command"] }
          }
        }
        """

        #expect(throws: KeybindingImportError.self) {
            _ = try KeybindingImporter.decode(data: Data(json.utf8))
        }
    }

    @Test func parseColonAndCommaKeys() throws {
        let comma = try KeyChord(dto: KeyChordDTO(key: ",", modifiers: ["command"]))
        let backslash = try KeyChord(dto: KeyChordDTO(key: "\\", modifiers: ["command", "shift"]))

        #expect(comma.charactersIgnoringModifiers == ",")
        #expect(comma.keyCode == 43)
        #expect(backslash.charactersIgnoringModifiers == "\\")
        #expect(backslash.keyCode == 42)
    }

    @Test func displayStringFormatsModifiers() throws {
        let chord = try KeyChord(dto: KeyChordDTO(key: "w", modifiers: ["command", "shift"]))

        #expect(chord.displayString == "⌘⇧W")
    }

    @Test func rejectsInvalidModifier() {
        let json = """
        {
          "schemaVersion": 1,
          "bindings": {
            "newTerminal": { "key": "t", "modifiers": ["meta"] }
          }
        }
        """

        #expect(throws: KeybindingImportError.self) {
            _ = try KeybindingImporter.decode(data: Data(json.utf8))
        }
    }

    @Test func mergeRejectsDuplicateResolvedChords() throws {
        let overrides = KeybindingsDocument(
            bindings: [
                KeybindingCommand.toggleNavigator.rawValue: KeyChordDTO(
                    key: "t",
                    modifiers: ["command"]
                )
            ]
        )

        #expect(throws: KeybindingImportError.self) {
            _ = try KeybindingCatalog.merge(
                defaults: KeybindingCatalog.defaultChords,
                overrides: overrides
            )
        }
    }
}
