import Foundation

final class CitadelSSHClient: SSHClientProtocol {
    func connect(to host: SSHHost, credential: CredentialRef?) async throws -> TerminalTransport {
        throw TerminalFailure.notImplemented
    }
}
