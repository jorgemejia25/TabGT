import SwiftUI

struct StatusBar: View {
    var host: SSHHost?
    var session: TerminalSession?

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
                Text(session?.state.label ?? "Disconnected")
            }

            if let host {
                Text(host.displayAddress)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            Text(session.map { "\($0.columns)×\($0.rows)" } ?? "--")
                .foregroundStyle(AppTheme.textTertiary)
            Text(session?.encoding ?? "UTF-8")
                .foregroundStyle(AppTheme.textTertiary)
            Text(method)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .font(.system(size: 11, weight: .regular))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .appGlassSurface()
        .shellEdgeBorder(.top)
    }

    private var method: String {
        guard let session else { return "Idle" }
        switch session.kind {
        case .ssh:   return "SSH"
        case .localShell: return "Local"
        case .diagnostic: return "Diagnostic"
        }
    }

    private var statusColor: Color {
        switch session?.state {
        case .connected:                 return AppTheme.success
        case .connecting, .reconnecting: return AppTheme.warning
        case .failed:                    return AppTheme.danger
        case .disconnected, .none:       return AppTheme.textTertiary
        }
    }
}
