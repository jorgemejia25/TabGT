import Foundation
@testable import TabGT
import Testing

struct SSHConfigBuilderSecurityTests {
    @Test func rejectsUnsafeDestinationInput() {
        let unsafeUser = SSHHost(name: "bad", address: "example.com", username: "deploy;rm")
        let unsafeHost = SSHHost(name: "bad", address: "example.com -oProxyCommand=bad", username: "deploy")

        #expect(SSHConfigBuilder.launchConfig(for: unsafeUser, workingDirectory: nil) == nil)
        #expect(SSHConfigBuilder.launchConfig(for: unsafeHost, workingDirectory: nil) == nil)
    }

    @Test func omitsUnsafeRemoteShellCommand() throws {
        var host = SSHHost(name: "safe", address: "example.com", username: "deploy")
        host.remoteShell = "/bin/zsh;rm -rf /"

        let config = try #require(SSHConfigBuilder.launchConfig(for: host, workingDirectory: nil))
        #expect(!config.args.contains { $0.contains(";") })
    }

    @Test func askpassHelperDoesNotWritePasswordMaterial() throws {
        defer { SSHAskPassHelper.cleanup() }

        let path = try #require(SSHAskPassHelper.write(account: "ssh-host-test-account"))
        let script = try String(contentsOfFile: path, encoding: .utf8)

        #expect(script.contains("/usr/bin/security find-generic-password"))
        #expect(script.contains("ssh-host-test-account"))
        #expect(!script.contains("super-secret-password"))
    }
}
