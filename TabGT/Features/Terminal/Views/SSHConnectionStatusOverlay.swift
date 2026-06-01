import SwiftUI

/// Centered connection state panel aligned with TabGT inspector / settings surfaces.
struct SSHConnectionPanel: View {
    enum Mode {
        case connecting
        case reconnecting
        case failed
        case disconnected
    }

    var mode: Mode
    var title: String
    var message: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            if mode == .connecting || mode == .reconnecting {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 2)
            }

            if mode == .failed, let onRetry {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.selectionBlue)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(AppTheme.elevatedPanel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accentColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    private var iconName: String {
        switch mode {
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .reconnecting:
            return "arrow.clockwise"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "bolt.slash.fill"
        }
    }

    private var accentColor: Color {
        switch mode {
        case .connecting, .reconnecting:
            return AppTheme.warning
        case .failed:
            return AppTheme.danger
        case .disconnected:
            return AppTheme.textSecondary
        }
    }
}

/// Full-terminal scrim with a centered connection panel (no floating toast).
struct SSHConnectionStatusOverlay: View {
    var session: TerminalSession
    var onRetry: (() -> Void)?

    var body: some View {
        switch session.state {
        case .connecting:
            connectionScrim(
                panel: SSHConnectionPanel(
                    mode: .connecting,
                    title: "Connecting",
                    message: session.connectionMessage ?? "Establishing SSH session…"
                )
            )
        case .reconnecting:
            connectionScrim(
                panel: SSHConnectionPanel(
                    mode: .reconnecting,
                    title: "Reconnecting",
                    message: session.connectionMessage ?? "Retrying SSH connection…"
                )
            )
        case .failed:
            if let message = session.connectionMessage {
                connectionScrim(
                    panel: SSHConnectionPanel(
                        mode: .failed,
                        title: "Connection Failed",
                        message: message,
                        onRetry: onRetry
                    )
                )
            }
        case .disconnected:
            if let message = session.connectionMessage {
                connectionScrim(
                    panel: SSHConnectionPanel(
                        mode: .disconnected,
                        title: "Disconnected",
                        message: message,
                        onRetry: onRetry
                    ),
                    dimmed: false
                )
            }
        case .connected:
            EmptyView()
        }
    }

    private func connectionScrim(panel: SSHConnectionPanel, dimmed: Bool = true) -> some View {
        ZStack {
            if dimmed {
                TerminalTheme.background.opacity(0.88)
            }
            panel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Preflight / configuration errors when SSH cannot be launched.
struct SSHConnectionErrorView: View {
    var title: String
    var message: String

    var body: some View {
        ZStack {
            TerminalTheme.background
            SSHConnectionPanel(
                mode: .failed,
                title: title,
                message: message
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
