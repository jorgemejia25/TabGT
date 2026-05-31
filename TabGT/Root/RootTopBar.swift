import SwiftUI

struct RootTopBar: View {
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var sessions: SessionsViewModel

    var onOpenLocal: () -> Void

    var body: some View {
        GlassTopBar {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workspace")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("\(sessions.sessions.count) active sessions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            if let session = sessions.selectedSession {
                GlassStatusPill(state: session.state)
            }

            GlassToolbarButton(
                systemImage: "plus",
                title: "Open local terminal",
                action: onOpenLocal
            )
        }
    }
}
