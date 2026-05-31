import SwiftUI

struct SessionStatusBar: View {
    var session: TerminalSession

    var body: some View {
        HStack(spacing: 14) {
            Label(session.state.label, systemImage: "circle.fill")
                .foregroundStyle(statusColor)

            Text(sessionKindLabel)
                .foregroundStyle(TerminalTheme.dim)

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
