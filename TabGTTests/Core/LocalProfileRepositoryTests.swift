import Foundation
import Testing
@testable import TabGT

@MainActor
struct LocalProfileRepositoryTests {
    @Test func seedsContainExpectedProfiles() {
        let profiles = LocalProfileSeeds.profiles()
        #expect(profiles.count == 3)
        #expect(profiles.map(\.name).contains("zsh"))
        #expect(profiles.map(\.name).contains("bash"))
        #expect(profiles.map(\.name).contains("Git"))
    }

    @Test func documentEncodingRoundTrip() throws {
        let profiles = LocalProfileSeeds.profiles()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()

        let document = LocalProfilesDocument(profiles: profiles)
        let data = try encoder.encode(document)
        let decoded = try decoder.decode(LocalProfilesDocument.self, from: data)

        #expect(decoded.profiles.count == profiles.count)
        #expect(decoded.profiles.map(\.shellPath).sorted() == profiles.map(\.shellPath).sorted())
    }

    @Test func sshHostsDocumentEncodesStartupFolders() throws {
        var host = PreviewData.hosts[0]
        let folder = StartupFolder(name: "Workspace", path: "~/workspace")
        host.startupFolders = [folder]
        host.defaultStartupFolderID = folder.id

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let document = SSHHostsDocument(groups: PreviewData.groups, hosts: [host])
        let data = try encoder.encode(document)
        let decoded = try decoder.decode(SSHHostsDocument.self, from: data)

        #expect(decoded.hosts.first?.startupFolders.count == 1)
        #expect(decoded.hosts.first?.startupFolders.first?.path == "~/workspace")
    }
}
