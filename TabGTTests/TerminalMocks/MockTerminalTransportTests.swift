import Foundation
import Testing
@testable import TabGT

@MainActor
struct MockTerminalTransportTests {
    @Test func recordsInputSentToTransport() async throws {
        let transport = MockTerminalTransport()
        let payload = Data("whoami".utf8)

        try await transport.send(payload)

        #expect(transport.inputHistory == [payload])
    }
}
