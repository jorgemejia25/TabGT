import Foundation

enum KeybindingImportError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)
    case unknownCommand(String)
    case invalidKey(String)
    case invalidModifier(String)
    case duplicateChord(String)
    case fileReadFailed
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported keybindings schema version \(version). Expected version 1."
        case .unknownCommand(let command):
            return "Unknown keybinding command \"\(command)\"."
        case .invalidKey(let key):
            return "Invalid key \"\(key)\"."
        case .invalidModifier(let modifier):
            return "Invalid modifier \"\(modifier)\". Use command, shift, option, or control."
        case .duplicateChord(let detail):
            return "Duplicate keybinding: \(detail)."
        case .fileReadFailed:
            return "Could not read the keybindings file."
        case .decodeFailed(let detail):
            return "Could not parse keybindings JSON: \(detail)"
        }
    }
}
