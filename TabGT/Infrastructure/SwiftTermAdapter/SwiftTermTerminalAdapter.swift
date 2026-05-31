import Foundation

final class SwiftTermTerminalAdapter: TerminalEmulatorProtocol {
    private(set) var receivedOutput: [TerminalOutput] = []

    func reset() {
        receivedOutput.removeAll()
    }

    func receive(_ output: TerminalOutput) {
        receivedOutput.append(output)
    }
}
