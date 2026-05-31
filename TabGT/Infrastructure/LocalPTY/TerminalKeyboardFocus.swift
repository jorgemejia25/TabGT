import AppKit

extension NSResponder {
    /// Returns the focused TabGT terminal view, if any.
    var enclosingTabGTTerminalView: TabGTTerminalView? {
        var responder: NSResponder? = self
        while let current = responder {
            if let terminal = current as? TabGTTerminalView {
                return terminal
            }
            responder = current.nextResponder
        }
        return nil
    }
}

enum TerminalKeyboardFocus {
    static var isTerminalFocused: Bool {
        NSApp.keyWindow?.firstResponder?.enclosingTabGTTerminalView != nil
    }
}
