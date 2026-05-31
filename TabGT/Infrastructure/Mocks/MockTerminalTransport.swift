import Foundation

final class MockTerminalTransport: TerminalTransport {
    let output: AsyncStream<TerminalOutput>

    private let continuation: AsyncStream<TerminalOutput>.Continuation
    private(set) var inputHistory: [Data] = []

    init(seedLines: [String] = []) {
        var streamContinuation: AsyncStream<TerminalOutput>.Continuation?
        self.output = AsyncStream { continuation in
            streamContinuation = continuation
        }
        self.continuation = streamContinuation!

        for line in seedLines {
            yield(line)
        }
    }

    func send(_ data: Data) async throws {
        inputHistory.append(data)
        let input = String(decoding: data, as: UTF8.self)
        yield("$ \(input)")
        yield("mock transport accepted \(data.count) bytes")
    }

    func resize(columns: Int, rows: Int) async throws {
        yield("resized terminal to \(columns)x\(rows)")
    }

    func close() async {
        yield("session closed")
        continuation.finish()
    }

    private func yield(_ text: String) {
        let data = Data((text + "\n").utf8)
        continuation.yield(TerminalOutput(data: data))
    }
}
