import Foundation

struct ClipTrayDocument: Codable {
    var schemaVersion: Int = 1
    var clips: [CapturedClip]
}

enum ClipTrayDTO {
    static let currentSchemaVersion = 1
}
