import SwiftUI

enum TerminalTheme {
    @MainActor
    static var background: Color { AppTheme.current.terminalBackground }

    @MainActor
    static var foreground: Color { AppTheme.current.terminalForeground }

    @MainActor
    static var dim: Color { AppTheme.textTertiary }

    @MainActor
    static var command: Color { AppTheme.current.terminalCommand }

    @MainActor
    static var system: Color { AppTheme.current.terminalSystem }

    @MainActor
    static var warning: Color { AppTheme.warning }

    @MainActor
    static var error: Color { AppTheme.danger }
}
