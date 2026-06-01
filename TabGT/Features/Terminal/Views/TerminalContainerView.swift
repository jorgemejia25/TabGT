import SwiftUI

struct TerminalContainerView: View {
    var session: TerminalSession
    @ObservedObject var sessions: SessionsViewModel
    @ObservedObject var connections: ConnectionsViewModel
    @ObservedObject var terminalProfiles: TerminalProfilesViewModel
    @ObservedObject var snippets: SnippetsViewModel
    @ObservedObject var inputBridge: SessionInputBridge

    var body: some View {
        switch session.kind {
        case .ssh:
            sshContent
        case .localShell:
            if let launchConfig = terminalProfiles.launchConfig(for: session) {
                LocalTerminalView(
                    session: session,
                    launchConfig: launchConfig,
                    sessions: sessions,
                    snippets: snippets,
                    inputBridge: inputBridge
                )
            } else {
                missingProfileView
            }
        default:
            TerminalSurfaceView(
                session: session,
                sessions: sessions,
                snippets: snippets
            )
        }
    }

    @ViewBuilder
    private var sshContent: some View {
        if let host = connections.host(for: session),
           session.state == .failed,
           SSHPreflightValidator.validate(host: host) != nil,
           let message = session.connectionMessage {
            SSHConnectionErrorView(
                title: "Cannot start SSH session",
                message: message
            )
        } else if let host = connections.host(for: session),
                  let launchConfig = connections.sshLaunchConfig(for: session) {
            ZStack {
                SSHTerminalView(
                    session: session,
                    host: host,
                    launchConfig: launchConfig,
                    sessions: sessions,
                    snippets: snippets,
                    inputBridge: inputBridge
                )

                if session.state != .connected {
                    SSHConnectionStatusOverlay(session: session) {
                        sessions.retrySSHSession(sessionID: session.id)
                    }
                }
            }
        } else {
            missingHostView
        }
    }

    private var missingHostView: some View {
        VStack(spacing: 8) {
            Text("SSH host not found")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)
            Text("The host for this session may have been deleted.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TerminalTheme.background)
    }

    private var missingProfileView: some View {
        VStack(spacing: 8) {
            Text("Terminal profile not found")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AppTheme.textTertiary)
            Text("The profile for this session may have been deleted.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TerminalTheme.background)
    }
}
