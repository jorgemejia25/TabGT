import Foundation
import SwiftTerm

/// Forwards SwiftTerm process events into `SessionsViewModel` session metrics.
///
/// Uses `LocalProcessTerminalViewDelegate` so `terminalDelegate` remains owned by
/// `LocalProcessTerminalView` for keyboard I/O.
@MainActor
class TerminalMetricsCoordinator: NSObject, LocalProcessTerminalViewDelegate {
    private let sessionID: UUID
    private weak var sessions: SessionsViewModel?
    var terminalView: TabGTTerminalView?
    var lastRequestID: UUID?

    init(sessionID: UUID, sessions: SessionsViewModel) {
        self.sessionID = sessionID
        self.sessions = sessions
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        sessions?.updateTerminalGeometry(sessionID: sessionID, columns: newCols, rows: newRows)
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {}

    func publishInitialGeometry(from source: TabGTTerminalView) {
        sizeChanged(
            source: source,
            newCols: source.terminal.cols,
            newRows: source.terminal.rows
        )
    }
}
