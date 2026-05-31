import Foundation

struct LocalProfilesDocument: Codable {
    var schemaVersion: Int = 1
    var profiles: [LocalTerminalProfile]
}

struct SSHHostsDocument: Codable {
    var schemaVersion: Int = 1
    var groups: [HostGroup]
    var hosts: [SSHHost]
}

struct ProfileDTO {
    static let currentSchemaVersion = 1
}
