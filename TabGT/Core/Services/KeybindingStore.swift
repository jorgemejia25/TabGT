import AppKit
import Combine
import Foundation

@MainActor
final class KeybindingStore: ObservableObject {
    static let shared = KeybindingStore()

    @Published private(set) var resolvedBindings: [ResolvedKeybinding] = []
    @Published private(set) var loadError: KeybindingImportError?
    @Published private(set) var filePath: String = ""

    private let repository: KeybindingRepository
    private var chordLookup: [KeyChord: KeybindingCommand] = [:]

    init(repository: KeybindingRepository? = nil) {
        self.repository = repository ?? KeybindingRepository()
        reload()
    }

    func reload() {
        filePath = repository.displayPath
        loadError = nil

        do {
            try repository.seedIfNeeded()
            let overrides = try repository.loadUserOverrides()
            let merged = try KeybindingCatalog.merge(
                defaults: KeybindingCatalog.defaultChords,
                overrides: overrides ?? KeybindingsDocument(bindings: [:])
            )
            applyMerged(merged)
        } catch let error as KeybindingImportError {
            loadError = error
            applyMerged(KeybindingCatalog.defaultChords)
        } catch {
            loadError = .decodeFailed(error.localizedDescription)
            applyMerged(KeybindingCatalog.defaultChords)
        }
    }

    func resetToDefaults() {
        do {
            try repository.resetToDefaults()
            reload()
        } catch let error as KeybindingImportError {
            loadError = error
        } catch {
            loadError = .decodeFailed(error.localizedDescription)
        }
    }

    func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([repository.keybindingsFileURL])
    }

    func command(for event: NSEvent) -> KeybindingCommand? {
        chordLookup.first { $0.key.matches(event) }?.value
    }

    func displayString(for command: KeybindingCommand) -> String {
        resolvedBindings.first { $0.command == command }?.chord.displayString ?? ""
    }

    private func applyMerged(_ merged: [KeybindingCommand: KeyChord]) {
        resolvedBindings = KeybindingCatalog.presentationOrder.compactMap { command in
            guard let chord = merged[command] else { return nil }
            return ResolvedKeybinding(command: command, chord: chord)
        }

        chordLookup = Dictionary(uniqueKeysWithValues: resolvedBindings.map { ($0.chord, $0.command) })
    }
}
