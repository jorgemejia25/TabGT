import AppKit
import Foundation
import SwiftTerm

/// Lightweight container returned from `NSViewRepresentable.makeNSView`.
///
/// SwiftUI dismantles this host when the hierarchy changes (e.g. pane split).
/// The pooled `TabGTTerminalView` is detached here so the running PTY survives
/// re-parenting into a new host.
final class TerminalSurfaceHostView: NSView {
    private(set) weak var hostedTerminal: TabGTTerminalView?

    func host(_ terminal: TabGTTerminalView) {
        guard hostedTerminal !== terminal || terminal.superview !== self else { return }

        hostedTerminal?.removeFromSuperview()
        hostedTerminal = terminal

        terminal.translatesAutoresizingMaskIntoConstraints = false
        addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: trailingAnchor),
            terminal.topAnchor.constraint(equalTo: topAnchor),
            terminal.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func detachHostedTerminal() {
        hostedTerminal?.removeFromSuperview()
        hostedTerminal = nil
    }
}

/// Keeps `TabGTTerminalView` instances alive across SwiftUI layout rebuilds.
///
/// When the workspace splits, SwiftUI replaces a `TerminalGroupView` with a
/// `WorkspaceSplitView`, destroying the previous NSViewRepresentable and its
/// NSView. Without the pool the underlying PTY process would be killed and the
/// session would restart. The pool holds a strong reference so the view (and
/// its running process) survive re-parenting.
@MainActor
final class TerminalViewPool {
    static let shared = TerminalViewPool()
    private var pool: [UUID: TabGTTerminalView] = [:]

    private init() {}

    func view(for id: UUID) -> TabGTTerminalView? {
        pool[id]
    }

    func store(_ view: TabGTTerminalView, for id: UUID) {
        pool[id] = view
    }

    func remove(for id: UUID) {
        pool[id]?.processDelegate = nil
        pool[id] = nil
    }
}
