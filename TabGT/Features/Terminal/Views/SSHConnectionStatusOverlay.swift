import SwiftUI

struct SSHConnectionStatusOverlay: View {
    var session: TerminalSession

    var body: some View {
        switch session.state {
        case .connecting:
            statusBanner(
                message: session.connectionMessage ?? "Connecting…",
                tint: AppTheme.warning,
                icon: "arrow.triangle.2.circlepath"
            )
        case .failed:
            if let message = session.connectionMessage {
                statusBanner(
                    message: message,
                    tint: AppTheme.danger,
                    icon: "exclamationmark.triangle.fill"
                )
            }
        case .disconnected:
            if let message = session.connectionMessage {
                statusBanner(
                    message: message,
                    tint: AppTheme.textSecondary,
                    icon: "bolt.slash.fill"
                )
            }
        case .connected, .reconnecting:
            EmptyView()
        }
    }

    private func statusBanner(message: String, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppTheme.elevatedPanel.opacity(0.96), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.45), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct SSHConnectionErrorView: View {
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TerminalTheme.background)
    }
}
