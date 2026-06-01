import Foundation
import SwiftTerm

/// Forwards SwiftTerm process events into `SessionsViewModel` session metrics.
///
/// Uses `LocalProcessTerminalViewDelegate` so `terminalDelegate` remains owned by
/// `LocalProcessTerminalView` for keyboard I/O.
@MainActor
class TerminalMetricsCoordinator: NSObject, LocalProcessTerminalViewDelegate {
    let sessionID: UUID
    weak var sessions: SessionsViewModel?
    var terminalView: TabGTTerminalView?
    var lastRequestID: UUID?
    /// Local shells are ready immediately; SSH coordinators flip this after handshake.
    private(set) var isInputDeliveryReady = true
    private(set) var isTerminalConfigured = false
    private var publishedColumns: Int?
    private var publishedRows: Int?

    init(sessionID: UUID, sessions: SessionsViewModel) {
        self.sessionID = sessionID
        self.sessions = sessions
    }

    func markTerminalConfigured() {
        isTerminalConfigured = true
    }

    func setInputDeliveryReady(_ ready: Bool) {
        isInputDeliveryReady = ready
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        sessions?.updateTerminalGeometry(sessionID: sessionID, columns: newCols, rows: newRows)
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        sessions?.updateCurrentDirectory(sessionID: sessionID, directory: directory)
    }

    func reportDirectoryChange(_ rawPath: String) {
        sessions?.reportDirectoryChange(sessionID: sessionID, rawPath: rawPath)
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {}

    func publishInitialGeometry(from source: TabGTTerminalView) {
        let cols = source.terminal.cols
        let rows = source.terminal.rows
        guard publishedColumns != cols || publishedRows != rows else { return }
        publishedColumns = cols
        publishedRows = rows
        sizeChanged(source: source, newCols: cols, newRows: rows)
    }
}
