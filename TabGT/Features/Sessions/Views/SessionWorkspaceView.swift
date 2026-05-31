import SwiftUI

struct SessionWorkspaceView: View {
    var session: TerminalSession?
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge

    var body: some View {
        Group {
            if let session {
                TerminalContainerView(
                    session: session,
                    sessions: sessions,
                    connections: connections,
                    terminalProfiles: terminalProfiles,
                    snippets: snippets,
                    inputBridge: inputBridge
                )
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Text("No session selected")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Open an SSH host or local shell from the sidebar.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassPanel(cornerRadius: 10)
    }
}
