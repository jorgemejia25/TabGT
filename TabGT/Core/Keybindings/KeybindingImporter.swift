import Foundation

enum KeybindingImporter {
    static func decode(data: Data) throws -> KeybindingsDocument {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        let document: KeybindingsDocument
        do {
            document = try decoder.decode(KeybindingsDocument.self, from: data)
        } catch {
            throw KeybindingImportError.decodeFailed(error.localizedDescription)
        }

        return try document.validated()
    }

    static func importKeybindings(from url: URL) throws -> KeybindingsDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw KeybindingImportError.fileReadFailed
        }

        return try decode(data: data)
    }
}
