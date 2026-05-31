import Foundation

struct TerminalOutput: Hashable {
    var data: Data
    var receivedAt: Date = Date()
}

enum TerminalFailure: Error, Equatable {
    case notImplemented
    case unavailable(String)
    case authenticationFailed
    case hostKeyRejected
}

enum HostKeyTrustDecision: Hashable {
    case trustOnce
    case trustPermanently
    case reject
}

protocol TerminalTransport: AnyObject {
    var output: AsyncStream<TerminalOutput> { get }

    func send(_ data: Data) async throws
    func resize(columns: Int, rows: Int) async throws
    func close() async
}

protocol SSHClientProtocol {
    func connect(to host: SSHHost, credential: CredentialRef?) async throws -> TerminalTransport
}

protocol LocalShellProtocol {
    func openShell(command: String?, environment: [String: String]) async throws -> TerminalTransport
}

protocol CredentialStoreProtocol {
    func saveSecret(_ secret: String, for credential: CredentialRef) async throws
    func readSecret(for credential: CredentialRef) async throws -> String?
    func deleteSecret(for credential: CredentialRef) async throws
}

protocol HostKeyStoreProtocol {
    func record(for hostID: UUID) async throws -> HostKeyRecord?
    func save(_ record: HostKeyRecord) async throws
    func removeRecord(for hostID: UUID) async throws
}

protocol TerminalEmulatorProtocol {
    func reset()
    func receive(_ output: TerminalOutput)
}
