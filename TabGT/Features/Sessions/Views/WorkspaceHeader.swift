import SwiftUI

struct WorkspaceHeader: View {
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var sessions: SessionsViewModel

    var onOpenLocal: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(sessions.selectedSession?.title ?? "Terminal Workspace")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(contextSubtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let session = sessions.selectedSession {
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor(for: session.state))
                        .frame(width: 6, height: 6)
                    Text(session.state.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            headerButton("plus", "New tab", action: onOpenLocal)
            headerButton("arrow.clockwise", "Reconnect") {}
            headerButton("stop.fill", "Disconnect") {}
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
        .background(AppTheme.editor)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.panelStroke)
                .frame(height: 1)
        }
    }

    private var contextSubtitle: String {
        if let host = connections.selectedHost {
            return host.displayAddress
        }

        return "Local and SSH terminal groups"
    }

    private func headerButton(
        _ systemImage: String,
        _ help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plainClickable)
        .foregroundStyle(AppTheme.textSecondary)
        .help(help)
    }

    private func statusColor(for state: ConnectionState) -> Color {
        switch state {
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
