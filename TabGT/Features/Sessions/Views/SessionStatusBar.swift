import SwiftUI

struct SessionStatusBar: View {
    var session: TerminalSession

    var body: some View {
        HStack(spacing: 14) {
            Label(session.state.label, systemImage: "circle.fill")
                .foregroundStyle(statusColor)

            Text(sessionKindLabel)
                .foregroundStyle(TerminalTheme.dim)

            if let git = session.gitRepoState {
                separator

                Label(git.isDetached ? "HEAD" : (git.branch ?? "—"), systemImage: "arrow.triangle.branch")
                    .foregroundStyle(git.isClean ? TerminalTheme.dim : AppTheme.warning)

                if git.aheadCount > 0 || git.behindCount > 0 {
                    HStack(spacing: 4) {
                        if git.aheadCount > 0  { Text("↑\(git.aheadCount)") }
                        if git.behindCount > 0 { Text("↓\(git.behindCount)") }
                    }
                    .foregroundStyle(TerminalTheme.dim)
                }
            }

            Spacer()

            Text("\(session.columns)×\(session.rows)")
            Text(session.encoding)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(TerminalTheme.dim)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppTheme.toolbar.opacity(0.76))
    }

    private var separator: some View {
        Text("·")
            .foregroundStyle(TerminalTheme.dim.opacity(0.4))
    }

    private var sessionKindLabel: String {
        switch session.kind {
        case .ssh:
            return "SSH"
        case .localShell:
            return "LOCAL"
        case .diagnostic:
            return "DIAG"
        }
    }

    private var statusColor: Color {
        switch session.state {
        case .connected:
            return AppTheme.success
        case .connecting, .reconnecting:
            return AppTheme.warning
        case .failed:
            return AppTheme.danger
        case .disconnected:
            return AppTheme.textTertiary
        }
    }
}
