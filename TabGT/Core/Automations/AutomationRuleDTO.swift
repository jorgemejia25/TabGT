import Foundation

struct AutomationRulesDocument: Codable {
    var schemaVersion: Int = 1
    var rules: [AutomationRule]
}
