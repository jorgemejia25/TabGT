import Foundation

enum ThemeImportError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidThemeID(String)
    case duplicateThemeID(String)
    case builtInIDConflict(String)
    case invalidColor(key: String, value: String)
    case missingColorKeys([String])
    case fileReadFailed
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported theme schema version \(version). Expected version 1."
        case .invalidThemeID(let id):
            return "Invalid theme id \"\(id)\". Use lowercase letters, numbers, and hyphens only."
        case .duplicateThemeID(let id):
            return "A custom theme with id \"\(id)\" already exists."
        case .builtInIDConflict(let id):
            return "Theme id \"\(id)\" conflicts with a built-in theme."
        case .invalidColor(let key, let value):
            return "Invalid color for \"\(key)\": \"\(value)\"."
        case .missingColorKeys(let keys):
            return "Missing required color keys: \(keys.joined(separator: ", "))."
        case .fileReadFailed:
            return "Could not read the theme file."
        case .decodeFailed(let detail):
            return "Could not parse theme JSON: \(detail)"
        }
    }
}
