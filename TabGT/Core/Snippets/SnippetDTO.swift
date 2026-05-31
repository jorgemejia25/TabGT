import Foundation

struct SnippetsDocument: Codable {
    var schemaVersion: Int = 1
    var snippets: [CommandSnippet]
}

enum SnippetDTO {
    static let currentSchemaVersion = 1
}
