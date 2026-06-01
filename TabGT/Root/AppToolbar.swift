import SwiftUI

struct AppToolbar: View {
    @ObservedObject var sessions: SessionsViewModel
    /// Whether the sidebar is currently visible.
    /// When hidden, we inject a left spacer so toolbar content clears the traffic lights.
    var sidebarVisible: Bool
    @Binding var isNavigatorVisible: Bool
    @Binding var isInspectorVisible: Bool
    var onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {

            // Traffic-light clearance — only needed when the sidebar is hidden.
            if !sidebarVisible {
                Color.clear.frame(width: ShellLayout.trafficLightClearanceWidth)
            }

            // Sidebar toggle
            toolbarButton("sidebar.left") {
                withAnimation(.easeInOut(duration: 0.15)) { isNavigatorVisible.toggle() }
            }
            .help("Toggle Navigator")
            .padding(.leading, sidebarVisible ? 8 : 2)

            breadcrumb
                .padding(.leading, 6)

            Spacer()

            // Status indicator
            statusPill
                .padding(.trailing, 8)

            toolbarDivider

            toolbarButton("gearshape", action: onOpenSettings)
                .help("Settings")

            toolbarButton("sidebar.right") {
                withAnimation(.easeInOut(duration: 0.15)) { isInspectorVisible.toggle() }
            }
            .help("Toggle Inspector")
            .padding(.trailing, 10)
        }
        .frame(height: ShellLayout.toolbarHeight)
        .background(AppTheme.navigator)
        .shellEdgeBorder(.bottom)
    }

    private var breadcrumb: some View {
        HStack(spacing: 2) {
            Text("TabGT")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if let title = sessions.selectedSession?.title {
                Text("›")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.textTertiary)

                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(sessions.selectedSession?.state.label ?? "Idle")
                .font(.system(size: 11, weight: .regular))
        }
        .foregroundStyle(AppTheme.textTertiary)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(AppTheme.splitSash)
            .frame(width: 1, height: 16)
            .padding(.horizontal, 6)
    }

    private func toolbarButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .regular))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plainClickable)
        .foregroundStyle(AppTheme.textSecondary)
    }

    private var statusColor: Color {
        switch sessions.selectedSession?.state {
        case .connected:                   return AppTheme.success
        case .connecting, .reconnecting:   return AppTheme.warning
        case .failed:                      return AppTheme.danger
        case .disconnected, .none:         return AppTheme.textTertiary
        }
    }
}
