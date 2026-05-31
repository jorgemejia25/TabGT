import SwiftUI

struct GlassStatusPill: View {
    var state: ConnectionState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(state.label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(AppTheme.elevatedPanel.opacity(0.72), in: Capsule())
        .overlay(Capsule().stroke(AppTheme.panelStroke, lineWidth: 1))
    }

    private var color: Color {
        switch state {
        case .connected:
            return AppTheme.success
        case .connecting, .reconnecting:
            return AppTheme.warning
        case .failed:
            return AppTheme.danger
        case .disconnected:
            return AppTheme.textSecondary
        }
    }
}
